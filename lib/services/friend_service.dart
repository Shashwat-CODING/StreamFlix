import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'api_service.dart';
import 'auth_service.dart';

class FriendService extends ChangeNotifier {
  FriendService._();
  static final FriendService instance = FriendService._();

  List<FriendEntry> _friends = [];
  bool _isLoading = false;

  List<FriendEntry> get friends => _friends;
  bool get isLoading => _isLoading;

  Future<void> fetchFriends() async {
    if (!AuthService.instance.isAuthenticated) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.instance.rawGet(
        '/api/friends/list',
        headers: AuthService.instance.authHeaders,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _friends = data.map((e) => FriendEntry.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching friends: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> sendRequest(String username) async {
    try {
      final res = await ApiService.instance.rawPost(
        '/api/friends/request',
        headers: {
          ...AuthService.instance.authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'username': username}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> acceptRequest(int friendId) async {
    try {
      final res = await ApiService.instance.rawPost(
        '/api/friends/accept',
        headers: {
          ...AuthService.instance.authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'friendId': friendId}),
      );
      if (res.statusCode == 200) {
        await fetchFriends();
        return true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }
}

class FriendEntry {
  final int id;
  final String username;
  final String name;
  final String status;

  FriendEntry({
    required this.id,
    required this.username,
    required this.name,
    required this.status,
  });

  factory FriendEntry.fromJson(Map<String, dynamic> json) => FriendEntry(
    id: json['id'],
    username: json['username'],
    name: json['name'] ?? '',
    status: json['status'],
  );
}
