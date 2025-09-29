import 'dart:async';
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
  Timer? _refreshTimer;
  Future<GatewayAuthResult?>? _refreshInFlight;

  static const Duration _refreshSafetyWindow = Duration(minutes: 5);

  String? _effectiveToken(GatewayAuthResult? auth) {
    if (auth == null) {
      return null;
    }
    if (auth.jwtToken != null && auth.jwtToken!.isNotEmpty) {
      return auth.jwtToken;
    }
    if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
      return auth.accessToken;
    }
    return null;
  }

  GatewayAuthResult _mergeAuthResults(GatewayAuthResult current, GatewayAuthResult next) {
    return GatewayAuthResult(
      success: current.success && next.success,
      message: next.message ?? current.message,
      error: next.error ?? current.error,
      payload: next.payload ?? current.payload,
      tokens: next.tokens ?? current.tokens,
      jwtToken: (next.jwtToken != null && next.jwtToken!.isNotEmpty) ? next.jwtToken : current.jwtToken,
      accessToken: (next.accessToken != null && next.accessToken!.isNotEmpty) ? next.accessToken : current.accessToken,
      refreshToken: (next.refreshToken != null && next.refreshToken!.isNotEmpty) ? next.refreshToken : current.refreshToken,
      accessExpiresAt: next.accessExpiresAt ?? current.accessExpiresAt,
      refreshExpiresAt: next.refreshExpiresAt ?? current.refreshExpiresAt,
      userId: next.userId ?? current.userId,
      userName: next.userName ?? current.userName,
      userNickname: next.userNickname ?? current.userNickname,
      userRoles: next.userRoles ?? current.userRoles,
      wsUrl: next.wsUrl ?? current.wsUrl,
    );
  }


  GatewayAuthResult? _restoreAuthResult(Map<String, dynamic>? stored) {
    if (stored == null || stored.isEmpty) {
      return null;
    }

    Map<String, dynamic>? parseMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          return null;
        }
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
          if (decoded is Map) {
            return decoded.map((key, val) => MapEntry(key.toString(), val));
          }
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    String? parseString(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      if (value is num) {
        return value.toString();
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is double) {
        return value.round();
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          return null;
        }
        final parsed = int.tryParse(trimmed);
        if (parsed != null) {
          return parsed;
        }
        final asDouble = double.tryParse(trimmed);
        if (asDouble != null) {
          return asDouble.round();
        }
      }
      return null;
    }

    DateTime? parseDate(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
      if (value is int) {
        if (value > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
        if (value > 0) {
          return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        }
      }
      if (value is double) {
        if (value > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value.round());
        }
        if (value > 0) {
          return DateTime.fromMillisecondsSinceEpoch((value * 1000).round());
        }
      }
      return null;
    }

    return GatewayAuthResult(
      success: stored['success'] != false,
      message: parseString(stored['message']),
      error: parseString(stored['error']),
      payload: parseMap(stored['payload']),
      tokens: parseMap(stored['tokens']),
      jwtToken: parseString(stored['jwtToken']) ?? parseString(stored['jwt_token']),
      accessToken: parseString(stored['accessToken']) ?? parseString(stored['access_token']),
      refreshToken: parseString(stored['refreshToken']) ?? parseString(stored['refresh_token']),
      accessExpiresAt: parseDate(stored['accessExpiresAt']) ?? parseDate(stored['access_expires_at']),
      refreshExpiresAt: parseDate(stored['refreshExpiresAt']) ?? parseDate(stored['refresh_expires_at']),
      userId: parseInt(stored['userId']) ?? parseInt(stored['user_id']),
      userName: parseString(stored['userName']) ?? parseString(stored['user_name']),
      userNickname: parseString(stored['userNickname']) ?? parseString(stored['user_nickname']),
      userRoles: parseInt(stored['userRoles']) ?? parseInt(stored['user_roles']),
      wsUrl: parseString(stored['wsUrl']) ?? parseString(stored['ws_url']),
    );
  }

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
        restoredAuth = _restoreAuthResult(storedUserData);
      } else {
        final rawAuth = await _secureStorage.read(key: _secureAuthKey);
        if (rawAuth != null && rawAuth.isNotEmpty) {
          final decoded = jsonDecode(rawAuth);
          if (decoded is Map<String, dynamic>) {
            restoredAuth = _restoreAuthResult(decoded);
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
        _scheduleTokenRefresh();
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
      _scheduleTokenRefresh();

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

  Future<String?> ensureValidGatewayToken({bool forceRefresh = false}) async {
    final auth = _authResult;
    if (auth == null) {
      return null;
    }

    if (!forceRefresh) {
      final expiresAt = _resolveAccessExpiry(auth);
      if (expiresAt != null && expiresAt.isAfter(DateTime.now().add(_refreshSafetyWindow))) {
        return _effectiveToken(auth);
      }
    }

    return _refreshGatewayToken(force: forceRefresh);
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
    _cancelScheduledRefresh();
    _refreshInFlight = null;
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

  Future<String?> _refreshGatewayToken({bool force = false}) async {
    final auth = _authResult;
    if (auth == null) {
      return null;
    }

    final refreshToken = auth.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return _effectiveToken(auth);
    }

    final refreshExpiry = auth.refreshExpiresAt;
    if (refreshExpiry != null && refreshExpiry.isBefore(DateTime.now())) {
      await _handleSessionExpired('Refresh token expired');
      return null;
    }

    if (_refreshInFlight != null) {
      await _refreshInFlight;
      return _effectiveToken(_authResult);
    }

    final completer = Completer<GatewayAuthResult?>();
    _refreshInFlight = completer.future;

    try {
      final result = await _gatewayService.refreshAuthToken(
        refreshToken: refreshToken,
        jwtToken: _effectiveToken(auth),
      );

      if (!result.success || !result.hasJwtToken) {
        final message = result.error ?? result.message ?? 'Token refresh failed';
        await _handleSessionExpired(message);
        throw Exception(message);
      }

      final merged = _mergeAuthResults(auth, result);
      _authResult = merged;

      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          userName: merged.userName ?? _currentUser!.userName,
          userNickname: merged.userNickname ?? _currentUser!.userNickname,
          lastLoginTime: merged.accessExpiresAt ?? _currentUser!.lastLoginTime,
        );
      }

      final usernameForStorage = merged.userName ?? _currentUser?.userName ?? 'user';
      await _persistAuthSession(usernameForStorage, merged);
      _scheduleTokenRefresh();
      notifyListeners();
      completer.complete(merged);
      return _effectiveToken(merged);
    } catch (error) {
      completer.completeError(error);
      if (force) {
        print('Token refresh failed: ' + error.toString());
      }
      rethrow;
    } finally {
      _refreshInFlight = null;
    }
  }

  void _scheduleTokenRefresh() {
    _cancelScheduledRefresh();

    final auth = _authResult;
    if (auth == null) {
      return;
    }

    final refreshToken = auth.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return;
    }

    final expiresAt = _resolveAccessExpiry(auth);
    if (expiresAt == null) {
      return;
    }

    final triggerAt = expiresAt.subtract(_refreshSafetyWindow);
    final now = DateTime.now();
    var delay = triggerAt.difference(now);
    if (delay.isNegative || delay.inSeconds <= 0) {
      delay = const Duration(seconds: 5);
    }

    _refreshTimer = Timer(delay, () {
      _refreshGatewayToken(force: true).catchError((error) {
        print('Automatic token refresh failed: $error');
      });
    });
  }

  void _cancelScheduledRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  DateTime? _resolveAccessExpiry(GatewayAuthResult auth) {
    if (auth.accessExpiresAt != null) {
      return auth.accessExpiresAt;
    }
    final token = _effectiveToken(auth);
    if (token == null || token.isEmpty) {
      return null;
    }
    return _decodeJwtExpiry(token);
  }

  DateTime? _decodeJwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }
    try {
      final normalized = base64.normalize(
        parts[1].replaceAll('-', '+').replaceAll('_', '/'),
      );
      final payload = jsonDecode(utf8.decode(base64.decode(normalized)));
      final exp = payload['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch((exp * 1000).round());
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> _handleSessionExpired(String reason) async {
    print('Gateway session expired: ' + reason);
    _cancelScheduledRefresh();
    await clearUserData();
    _authResult = null;
    _currentUser = null;
    _isLoggedIn = false;
    _lastError = reason;
    notifyListeners();
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

