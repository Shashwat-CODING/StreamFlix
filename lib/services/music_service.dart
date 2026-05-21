import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song_model.dart';
import 'audio_handler.dart';
import 'stream_provider.dart';
import 'music_history.dart';
import 'watch_history.dart';
import 'settings_service.dart';
import '../models/media_item.dart' as app_models;

class MusicService extends ChangeNotifier {
  static final MusicService instance = MusicService._internal();
  MusicService._internal();

  late MyAudioHandler _audioHandler;
  List<SongModel> _queue = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  AudioQuality? _selectedQuality;
  bool _isLooping = false;
  bool _isShuffled = false;
  final Map<String, String> _urlCache = {};
  bool _isPrefetching = false;

  SongModel? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;
  List<SongModel> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;

  bool get isPlaying => _audioHandler.player.playing;
  bool get isLoading => _isLoading;
  bool get isLooping => _isLooping;
  bool get isShuffled => _isShuffled;
  Duration get position => _audioHandler.player.position;
  Duration get duration => _audioHandler.player.duration ?? Duration.zero;
  AudioPlayer get player => _audioHandler.player;
  AudioQuality? get selectedQuality => _selectedQuality;

  Future<void> init() async {
    _audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.luxa.music',
        androidNotificationChannelName: 'Music Playback',
        androidNotificationOngoing: true,
      ),
    );

    _audioHandler.player.playbackEventStream.listen((event) {
      if (_audioHandler.player.currentIndex != null && _audioHandler.player.currentIndex != _currentIndex) {
        _currentIndex = _audioHandler.player.currentIndex!;
        if (currentSong != null) {
          _saveToHistory(currentSong!);
          _prefetchNextSongs();
        }
        notifyListeners();
      }
    });

    _audioHandler.player.playerStateStream.listen((state) {
      notifyListeners();
    });

    _audioHandler.player.positionStream.listen((pos) {
      notifyListeners();
    });
  }

  void _saveToHistory(SongModel song) {
    MusicHistory.addItem(song);
    WatchHistory.addItem(app_models.MediaItem(
      id: int.tryParse(song.id) ?? song.id.hashCode,
      title: song.name,
      artist: song.artistName,
      artUri: song.imageUrl,
      extras: {'type': 'music', 'thumbnail': song.imageUrl},
      mediaType: 'music',
      voteAverage: 0.0,
    ));
  }

  Future<List<SongModel>> searchSongs(String query, {int page = 0, int limit = 20}) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse('https://muzo-api.shashwat-coding.workers.dev/api/search?q=$encodedQuery&filter=songs');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null) {
          final List results = data['results'];
          return results.map((json) => SongModel.fromJson(json)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error searching songs: $e');
    }
    return [];
  }

  Future<String?> _getResolvedUrl(SongModel song) async {
    if (_urlCache.containsKey(song.id)) {
      return _urlCache[song.id];
    }

    try {
      final streamData = await StreamProvider.fetch(song.id);
      if (streamData.playable && streamData.highestQualityAudio != null) {
        final url = streamData.highestQualityAudio!.url;
        _urlCache[song.id] = url;
        return url;
      }
    } catch (e) {
      debugPrint('Error resolving URL for ${song.id}: $e');
    }
    return null;
  }

  Future<void> playSong(SongModel song, {AudioQuality? quality}) async {
    _isLoading = true;
    _selectedQuality = quality;
    
    // Clear and start new queue
    _queue = [song];
    _currentIndex = 0;
    notifyListeners();

    try {
      String? urlToPlay = quality?.url ?? _urlCache[song.id];
      
      if (urlToPlay == null) {
        urlToPlay = await _getResolvedUrl(song);
      }

      if (urlToPlay == null || urlToPlay.isEmpty) {
        debugPrint('Failed to get stream for ${song.id}');
        _isLoading = false;
        notifyListeners();
        return;
      }

      final mediaItem = _createMediaItem(song);
      await _audioHandler.setAudioSource(
        AudioSource.uri(Uri.parse(urlToPlay), tag: mediaItem), 
        mediaItem
      );
      await _audioHandler.play();
      _saveToHistory(song);

      // Fetch related songs and prefetch
      _fetchAndAddRelatedSongs(song.id);
    } catch (e) {
      debugPrint('Error playing song: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _prefetchNextSongs() async {
    if (_isPrefetching) return;
    _isPrefetching = true;

    try {
      // Look ahead up to 3 songs
      for (int i = 1; i <= 3; i++) {
        int targetIndex = _currentIndex + i;
        if (targetIndex < _queue.length) {
          final song = _queue[targetIndex];
          if (!_urlCache.containsKey(song.id)) {
            await _getResolvedUrl(song);
          }
          // Ensure it's in the audio handler's playlist
          await _ensureInPlaylist(targetIndex);
        }
      }
    } finally {
      _isPrefetching = false;
    }
  }

  Future<void> _ensureInPlaylist(int index) async {
    final playlist = _audioHandler.player.audioSource as ConcatenatingAudioSource?;
    if (playlist == null) return;

    // If playlist is shorter than index + 1, we need to add missing items
    while (playlist.length <= index && playlist.length < _queue.length) {
      final idxToAdd = playlist.length;
      final song = _queue[idxToAdd];
      String? url = _urlCache[song.id];
      
      if (url == null) {
        url = await _getResolvedUrl(song);
      }

      if (url != null) {
        final mediaItem = _createMediaItem(song);
        await _audioHandler.addToQueue(
          AudioSource.uri(Uri.parse(url), tag: mediaItem),
          mediaItem
        );
      } else {
        break; 
      }
    }
  }

  Future<void> _fetchAndAddRelatedSongs(String videoId) async {
    if (!SettingsService.instance.autoQueue) return;
    
    try {
      final url = Uri.parse('https://muzo-api.shashwat-coding.workers.dev/api/related?videoId=$videoId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['songs'] != null) {
          final List songsData = data['songs'];
          for (var jsonSong in songsData) {
            final sm = SongModel.fromJson(jsonSong);
            if (!_queue.any((s) => s.id == sm.id)) {
              _queue.add(sm);
            }
          }
          notifyListeners();
          // Ensure the immediately next song is prepared
          if (_queue.length > _currentIndex + 1) {
             _prefetchNextSongs();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching related songs: $e');
    }
  }

  Future<void> playFromQueue(int index) async {
    if (index >= 0 && index < _queue.length) {
      final song = _queue[index];
      if (!_urlCache.containsKey(song.id)) {
        _isLoading = true;
        notifyListeners();
        await _getResolvedUrl(song);
        _isLoading = false;
      }
      
      await _ensureInPlaylist(index);
      
      await _audioHandler.player.seek(Duration.zero, index: index);
      await _audioHandler.play();
      _currentIndex = index;
      notifyListeners();
      _prefetchNextSongs();
    }
  }

  Future<void> playNext(SongModel song) async {
    _queue.insert(_currentIndex + 1, song);
    final playlist = _audioHandler.player.audioSource as ConcatenatingAudioSource?;
    
    // We try to resolve URL if near
    final url = await _getResolvedUrl(song);
    if (url != null && playlist != null) {
      final mediaItem = _createMediaItem(song);
      await playlist.insert(_currentIndex + 1, AudioSource.uri(Uri.parse(url), tag: mediaItem));
    }
    notifyListeners();
  }

  Future<void> addToQueue(SongModel song) async {
    if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
      notifyListeners();
      _prefetchNextSongs();
    }
  }

  Future<void> toggleLoop() async {
    _isLooping = !_isLooping;
    await _audioHandler.player.setLoopMode(_isLooping ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    _isShuffled = !_isShuffled;
    await _audioHandler.player.setShuffleModeEnabled(_isShuffled);
    notifyListeners();
  }

  Future<void> rearrangeQueue(int oldIdx, int newIdx) async {
    if (newIdx > oldIdx) newIdx -= 1;
    final item = _queue.removeAt(oldIdx);
    _queue.insert(newIdx, item);
    
    // Sync with audio handler
    final playlist = _audioHandler.player.audioSource as ConcatenatingAudioSource?;
    if (playlist != null && oldIdx < playlist.length && newIdx < playlist.length) {
      await playlist.move(oldIdx, newIdx);
    }
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    _queue.removeAt(index);
    final playlist = _audioHandler.player.audioSource as ConcatenatingAudioSource?;
    if (playlist != null && index < playlist.length) {
      await playlist.removeAt(index);
    }
    notifyListeners();
  }

  Future<void> changeQuality(AudioQuality quality) async {
    _selectedQuality = quality;
    final song = currentSong;
    if (song != null) {
      // Re-play the current song with new quality at current position
      final resumePosition = position;
      final wasPlaying = isPlaying;
      
      _isLoading = true;
      notifyListeners();
      
      try {
        final url = quality.url;
        final mediaItem = _createMediaItem(song);
        // Note: setAudioSource clears the playlist in our current MyAudioHandler.
        // We should ideally just replace the source at current index.
        final playlist = _audioHandler.player.audioSource as ConcatenatingAudioSource?;
        if (playlist != null && _currentIndex >= 0 && _currentIndex < playlist.length) {
           await playlist.removeAt(_currentIndex);
           await playlist.insert(_currentIndex, AudioSource.uri(Uri.parse(url), tag: mediaItem));
           await _audioHandler.player.seek(resumePosition, index: _currentIndex);
           if (wasPlaying) _audioHandler.play();
        }
      } catch (e) {
        debugPrint('Error changing quality: $e');
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  MediaItem _createMediaItem(SongModel song) {
    return MediaItem(
      id: song.id,
      album: 'Luxa Music',
      title: song.name,
      artist: song.artistName,
      artUri: song.imageUrl != null ? Uri.parse(song.imageUrl!) : null,
      duration: Duration(seconds: song.durationSeconds),
    );
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
    notifyListeners();
  }

  void next() => _audioHandler.skipToNext();
  void previous() => _audioHandler.skipToPrevious();
  Future<void> seekTo(Duration position) async => await _audioHandler.seek(position);

  Future<void> stopMusic() async {
    await _audioHandler.stop();
    notifyListeners();
  }

  void disposePlayer() {
    _audioHandler.stop();
    _queue.clear();
    _currentIndex = -1;
    notifyListeners();
  }
}

