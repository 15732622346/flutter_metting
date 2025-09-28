import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/user_manager.dart';
import '../models/login_response.dart';
import '../models/user_model.dart';
import '../services/gateway_api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _secureUserKey = 'current_user';
  static const String _secureAuthKey = 'gateway_auth';
  static const String _secureCredentialsKey = 'user_credentials';

  final GatewayApiService _gatewayService = GatewayApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  User? _currentUser;
  GatewayAuthResult? _authResult;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _lastError;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isHost => _currentUser?.isHost ?? false;
  bool get isMember => _currentUser?.isMember ?? false;
  bool get isEnabled => _currentUser?.isEnabled ?? false;

  Future<void> initialize() async {
    try {
      _setLoading(true);

      final loginState = await UserManager.getLoginState();
      final storedUserData = loginState['userData'] as Map<String, dynamic>?;

      GatewayAuthResult? restoredAuth;
      if (storedUserData != null && storedUserData.isNotEmpty) {
        restoredAuth = GatewayAuthResult.fromStorageJson(storedUserData);
      } else {
        final rawAuth = await _secureStorage.read(key: _secureAuthKey);
        if (rawAuth != null && rawAuth.isNotEmpty) {
          final decoded = jsonDecode(rawAuth);
          if (decoded is Map<String, dynamic>) {
            restoredAuth = GatewayAuthResult.fromStorageJson(decoded);
          }
        }
      }

      if (restoredAuth != null && restoredAuth.hasJwtToken) {
        _authResult = restoredAuth;
        final fallbackUserName = (loginState['username'] as String?)?.trim();
        final resolvedUserName =
            restoredAuth.userName?.trim().isNotEmpty == true
                ? restoredAuth.userName!.trim()
                : (fallbackUserName?.isNotEmpty == true
                    ? fallbackUserName!
                    : 'user');
        _currentUser = _buildUserFromAuth(resolvedUserName, restoredAuth);
        _isLoggedIn = true;
        print('Restored login state: $resolvedUserName');
        return;
      }

      final rawUserJson = await _secureStorage.read(key: _secureUserKey);
      if (rawUserJson != null && rawUserJson.isNotEmpty) {
        final decoded = jsonDecode(rawUserJson);
        if (decoded is Map<String, dynamic>) {
          _currentUser = User.fromJson(decoded);
          _isLoggedIn = true;
          print('Restored local user info: ${_currentUser!.userName}');
        }
      }
    } catch (e) {
      print('Failed to initialise user state: $e');
      await clearUserData();
    } finally {
      _setLoading(false);
    }
  }

  Future<LoginResponse> loginToRoom({
    required String username,
    required String password,
    required String roomId,
    required String inviteCode,
    String? wssUrl,
    bool forceLogin = false,
  }) async {
    try {
      _setLoading(true);
      _lastError = null;

      final trimmedInvite = inviteCode.trim();
      if (trimmedInvite.isEmpty) {
        const message = 'Please enter a valid invite code';
        _lastError = message;
        return const LoginResponse(success: false, error: message);
      }

      final loginResult = await _gatewayService.login(
        username: username,
        password: password,
        forceLogin: forceLogin,
        roomId: roomId,
        inviteCode: trimmedInvite,
      );

      if (!loginResult.success || !loginResult.hasJwtToken) {
        final errorMessage = loginResult.error ??
            loginResult.message ??
            'Login failed, please try again later';
        _lastError = errorMessage;
        return LoginResponse(success: false, error: errorMessage);
      }

      final resolvedUserName = loginResult.userName?.trim().isNotEmpty == true
          ? loginResult.userName!.trim()
          : username;

      final tokenForJoin =
          loginResult.jwtToken ?? loginResult.accessToken ?? '';
      if (tokenForJoin.isEmpty) {
        const message = 'Unable to obtain login token';
        _lastError = message;
        return const LoginResponse(success: false, error: message);
      }

      final detailResult = await _gatewayService.joinRoom(
        roomId: roomId,
        inviteCode: trimmedInvite,
        userName: resolvedUserName,
        userJwtToken: tokenForJoin,
        wssUrl: wssUrl ?? loginResult.wsUrl,
      );

      if (!detailResult.success || !detailResult.hasLiveKitToken) {
        final errorMessage = detailResult.error ??
            detailResult.message ??
            'Unable to get room connection info';
        _lastError = errorMessage;
        return LoginResponse(success: false, error: errorMessage);
      }

      _authResult = loginResult;
      _currentUser = _buildUserFromAuth(resolvedUserName, loginResult)
          .copyWith(currentRoom: roomId);
      _isLoggedIn = true;

      await _persistAuthSession(resolvedUserName, loginResult);
      await _saveCredentials(username, password);

      final response = LoginResponse(
        success: true,
        token: detailResult.livekitToken,
        wsUrl: detailResult.wssUrl ?? loginResult.wsUrl,
        roomName: detailResult.roomName,
        userRoles: detailResult.userRoles ?? loginResult.userRoles,
        id: loginResult.userId,
        userId: loginResult.userId,
        nickname: detailResult.userNickname ??
            loginResult.userNickname ??
            resolvedUserName,
        message: detailResult.message ??
            loginResult.message ??
            'Joined room successfully',
      );

      print('Room login success: ${_currentUser!.userName} -> $roomId');
      notifyListeners();
      return response;
    } catch (error) {
      _lastError = error.toString();
      print('Room login exception: $error');
      return LoginResponse(success: false, error: _lastError);
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    try {
      _setLoading(true);
      _lastError = null;

      final result = await _gatewayService.register(
        username: username,
        password: password,
        nickname: nickname,
      );

      if (!result.success) {
        final errorMessage = result.error ??
            result.message ??
            'Registration failed, please try again later';
        _lastError = errorMessage;
        return {'success': false, 'message': errorMessage};
      }

      return {
        'success': true,
        'message': result.message ??
            'Registration succeeded, please log in with your account',
        'userId': result.userId,
        'userName': result.userName,
      };
    } catch (error) {
      _lastError = error.toString();
      print('User registration failed: $error');
      return {'success': false, 'message': _lastError};
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      _setLoading(true);

      final token = _authResult?.jwtToken ?? _authResult?.accessToken;
      if (token != null && token.isNotEmpty) {
        try {
          await _gatewayService.logout(jwtToken: token);
        } catch (error) {
          print('Logout API call failed: $error');
        }
      }

      await clearUserData();

      _authResult = null;
      _currentUser = null;
      _isLoggedIn = false;
      _lastError = null;

      print('User logged out');
      notifyListeners();
    } catch (error) {
      print('Failed to complete logout: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> clearUserData() async {
    try {
      await _secureStorage.delete(key: _secureUserKey);
      await _secureStorage.delete(key: _secureAuthKey);
      await _secureStorage.delete(key: _secureCredentialsKey);
      await UserManager.clearLoginState();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_username');
      await prefs.remove('remember_user');

      print('Local login data cleared');
    } catch (error) {
      print('Failed to clear local login data: $error');
    }
  }

  Future<String?> getRememberedUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberUser = prefs.getBool('remember_user') ?? false;
      if (rememberUser) {
        return prefs.getString('last_username');
      }
      return null;
    } catch (error) {
      print('Failed to read remembered username: $error');
      return null;
    }
  }

  Future<void> setRememberUser(String username, bool remember) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_user', remember);
      if (remember) {
        await prefs.setString('last_username', username);
      } else {
        await prefs.remove('last_username');
      }
    } catch (error) {
      print('Failed to update remember flag: $error');
    }
  }

  Future<void> _persistAuthSession(
      String username, GatewayAuthResult authResult) async {
    try {
      await UserManager.saveLoginState(
        username: username,
        extraData: authResult.toStorageJson(),
      );
      await _secureStorage.write(
        key: _secureAuthKey,
        value: jsonEncode(authResult.toStorageJson()),
      );
      if (_currentUser != null) {
        await _secureStorage.write(
          key: _secureUserKey,
          value: jsonEncode(_currentUser!.toJson()),
        );
      }
    } catch (error) {
      print('Failed to persist auth session: $error');
    }
  }

  Future<void> _saveCredentials(String username, String password) async {
    try {
      await _secureStorage.write(
        key: _secureCredentialsKey,
        value: '$username:$password',
      );
    } catch (error) {
      print('Failed to save credentials: $error');
    }
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final credentials = await _secureStorage.read(key: _secureCredentialsKey);
      if (credentials != null) {
        final parts = credentials.split(':');
        if (parts.length == 2) {
          return {
            'username': parts[0],
            'password': parts[1],
          };
        }
      }
      return null;
    } catch (error) {
      print('Failed to read saved credentials: $error');
      return null;
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  User _buildUserFromAuth(
      String fallbackUserName, GatewayAuthResult? authResult) {
    final resolvedName = authResult?.userName?.trim().isNotEmpty == true
        ? authResult!.userName!.trim()
        : fallbackUserName;
    return User(
      id: authResult?.userId ?? 0,
      userName: resolvedName,
      userRoles: authResult?.userRoles ?? 1,
      userNickname: authResult?.userNickname ?? resolvedName,
      userStatus: 1,
      isOnline: 1,
      currentRoom: null,
      lastLoginTime: authResult?.accessExpiresAt,
    );
  }
}
