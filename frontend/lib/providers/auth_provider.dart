// CHANGE-2026-09-07: Created Authentication & Session State Provider.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  UserModel? _currentUser;
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    checkAuthStatus();
  }

  /// Checks persisted session on application startup
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('auth_token');
      final savedUserJson = prefs.getString('auth_user');

      if (savedToken != null && savedToken.isNotEmpty && savedUserJson != null) {
        _token = savedToken;
        ApiService.bearerToken = savedToken;
        _currentUser = UserModel.fromJson(jsonDecode(savedUserJson));
        _isAuthenticated = true;

        // Optionally refresh profile from server
        final response = await _api.get<UserModel>(
          ApiEndpoints.authMe,
          parser: (json) => UserModel.fromJson(json),
        );
        if (response.success && response.data != null) {
          _currentUser = response.data;
          await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));
        }
      } else {
        _token = null;
        _currentUser = null;
        _isAuthenticated = false;
        ApiService.bearerToken = null;
      }
    } catch (e) {
      _isAuthenticated = false;
      _token = null;
      _currentUser = null;
      ApiService.bearerToken = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Authenticates user with Node.js backend
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.authLogin,
      {
        'username': username.trim(),
        'password': password.trim(),
      },
      parser: (json) => json as Map<String, dynamic>,
    );

    if (response.success && response.data != null) {
      final data = response.data!;
      _token = data['token'];
      _currentUser = UserModel.fromJson(data['user']);
      _isAuthenticated = true;
      ApiService.bearerToken = _token;

      // Persist session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('auth_user', jsonEncode(_currentUser!.toJson()));

      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message.isNotEmpty ? response.message : 'Login failed. Please check your credentials.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logs out user and clears session state
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_user');
    } catch (_) {}

    _token = null;
    _currentUser = null;
    _isAuthenticated = false;
    ApiService.bearerToken = null;
    _isLoading = false;
    notifyListeners();
  }
}
