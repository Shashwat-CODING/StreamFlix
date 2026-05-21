import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.setAudioSource(_playlist);
    
    // Sync current media item with player index
    _player.currentIndexStream.listen((index) {
      if (index != null && index < _playlist.length) {
        final source = _playlist.children[index];
        if (source is UriAudioSource) {
          mediaItem.add(source.tag as MediaItem);
        }
      }
    });

    // Sync queue stream with player sequence
    _player.sequenceStream.listen((sequence) {
      if (sequence == null) return;
      final items = sequence
          .map((s) => s.tag as MediaItem?)
          .whereType<MediaItem>()
          .toList();
      queue.add(items);
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  Future<void> setAudioSource(AudioSource source, MediaItem item) async {
    mediaItem.add(item);
    await _playlist.clear();
    await _playlist.add(source);
  }

  Future<void> addToQueue(AudioSource source, MediaItem item) async {
    await _playlist.add(source);
  }

  Future<void> insertNext(AudioSource source, MediaItem item) async {
    final index = _player.currentIndex ?? -1;
    await _playlist.insert(index + 1, source);
  }

  Future<void> removeAt(int index) async {
    await _playlist.removeAt(index);
  }

  Future<void> move(int currentIndex, int newIndex) async {
    await _playlist.move(currentIndex, newIndex);
  }

  AudioPlayer get player => _player;

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.playPause,
      },
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}

