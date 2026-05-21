import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_models.dart';
import 'api_service.dart';
import 'sync_service.dart';

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  User? _user;
  String? _token;
  bool _isLoading = false;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String get username => _user?.username ?? 'Guest';
  String? get lastError => _lastError;

  String? _lastError;

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _user = User.fromJson(jsonDecode(userJson));
      SyncService.instance.restoreAll();
    }
    notifyListeners();
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await ApiService.instance.post('/auth/login', {
        'email': identifier,
        'password': password
      });

      if (response != null && response['token'] != null) {
        _token = response['token'];
        _user = User.fromJson(response['user']);
        await _saveAuthData();
        SyncService.instance.restoreAll();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // API returned a response but no token — extract error message
      _lastError = response?['error'] ?? response?['message'] ?? 'Invalid credentials.';
    } catch (e) {
      debugPrint('Login error: $e');
      _lastError = 'Network error. Please check your connection.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> signup(String username, String email, String password, {String? name}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await ApiService.instance.post('/auth/signup', {
        'username': username,
        'name': name,
        'email': email,
        'password': password,
      });

      if (response != null && response['token'] != null) {
        _token = response['token'];
        _user = User.fromJson(response['user']);
        await _saveAuthData();
        SyncService.instance.restoreAll();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _lastError = response?['error'] ?? response?['message'] ?? 'Could not create account.';
    } catch (e) {
      debugPrint('Signup error: $e');
      _lastError = 'Network error. Please check your connection.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }

  Future<void> _saveAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString(_tokenKey, _token!);
    if (_user != null) await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
  }

  Map<String, String> get authHeaders {
    if (_token != null) {
      return {'Authorization': 'Bearer $_token'};
    }
    return {};
  }
}
