import 'dart:convert';

import 'package:dio/dio.dart';

/// 与 PC 端保持一致的网关 API 调用封装，负责登录/注册等动作。
class GatewayApiService {
  GatewayApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _defaultBaseUrl,
        connectTimeout: _defaultTimeout,
        receiveTimeout: _defaultTimeout,
        headers: const {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
          'User-Agent': 'livekit-app/flutter-meeting/1.0.0',
        },
      ),
    );
  }

  static final GatewayApiService _instance = GatewayApiService._internal();

  factory GatewayApiService() => _instance;

  static const String _defaultBaseUrl = 'https://met.pge006.com';
  static const Duration _defaultTimeout = Duration(seconds: 15);
  static const String _gatewayPath = '/gateway';

  late final Dio _dio;

  Future<GatewayAuthResult> login({
    required String username,
    required String password,
    bool forceLogin = false,
    String? roomId,
    String? inviteCode,
  }) async {
    final payload = <String, dynamic>{
      'user_name': username,
      'user_password': password,
    };

    if (forceLogin) {
      payload['force_login'] = true;
    }
    if (roomId != null && roomId.isNotEmpty) {
      payload['room_id'] = roomId;
    }
    if (inviteCode != null && inviteCode.isNotEmpty) {
      payload['invite_code'] = inviteCode;
    }

    final response = await _callGateway(
      endpoint: '/api/v1/auth/login',
      method: 'POST',
      data: payload,
    );

    return GatewayAuthResult.fromResponse(response);
  }

  Future<GatewayRegisterResult> register({
    required String username,
    required String password,
    required String nickname,
    String? clientIp,
  }) async {
    final payload = <String, dynamic>{
      'user_name': username,
      'user_password': password,
      'user_nickname': nickname,
    };

    if (clientIp != null && clientIp.isNotEmpty) {
      payload['user_ip'] = clientIp;
    } else {
      final ip = await _resolveClientIp();
      if (ip != null) {
        payload['user_ip'] = ip;
      }
    }

    final response = await _callGateway(
      endpoint: '/api/v1/auth/register',
      method: 'POST',
      data: payload,
    );

    return GatewayRegisterResult.fromResponse(response);
  }

  Future<bool> logout({String? jwtToken}) async {
    final response = await _callGateway(
      endpoint: '/api/v1/auth/logout',
      method: 'POST',
      headers: (jwtToken != null && jwtToken.isNotEmpty)
          ? {'Authorization': 'Bearer ${jwtToken!}'}
          : null,
    );
    return response['success'] == true;
  }

  Future<Map<String, dynamic>> fetchRoomList({int page = 1}) async {
    return _callGateway(
      endpoint: '/api/v1/rooms/list',
      method: 'GET',
      query: {
        'page': page,
      },
    );
  }

  Future<GatewayAuthStatusResult> getAuthStatus({String? jwtToken}) async {
    final response = await _callGateway(
      endpoint: '/api/v1/auth/status',
      method: 'GET',
      headers: jwtToken != null && jwtToken.isNotEmpty
          ? {'Authorization': 'Bearer ' + jwtToken}
          : null,
    );

    return GatewayAuthStatusResult.fromResponse(response);
  }

  Future<GatewayRoomDetailResult> fetchRoomDetail({
    required String roomId,
    required String inviteCode,
    required String userName,
    required String userJwtToken,
    String? wssUrl,
  }) async {
    final query = <String, dynamic>{
      'room_id': roomId,
      'invite_code': inviteCode,
      'user_name': userName,
      'user_jwt_token': userJwtToken,
      if (wssUrl != null && wssUrl.isNotEmpty) 'wss_url': wssUrl,
    };

    final response = await _callGateway(
      endpoint: '/api/v1/rooms/detail',
      method: 'GET',
      query: query,
      headers: userJwtToken.isNotEmpty
          ? {'Authorization': 'Bearer ' + userJwtToken}
          : null,
    );

    return GatewayRoomDetailResult.fromResponse(response);
  }

  Future<GatewayAuthResult> refreshAuthToken({
    required String refreshToken,
  }) async {
    final response = await _callGateway(
      endpoint: '/api/v1/auth/refresh',
      method: 'POST',
      data: {
        'refresh_token': refreshToken,
      },
    );

    return GatewayAuthResult.fromResponse(response);
  }

  Future<GatewayRoomDetailResult> joinRoom({
    required String roomId,
    required String inviteCode,
    required String userName,
    required String userJwtToken,
    String? wssUrl,
  }) async {
    return fetchRoomDetail(
      roomId: roomId,
      inviteCode: inviteCode,
      userName: userName,
      userJwtToken: userJwtToken,
      wssUrl: wssUrl,
    );
  }

  Future<GatewayActionResult> requestMicrophone({
    required String roomId,
    required int userUid,
    required String jwtToken,
    String? participantIdentity,
    int? userId,
    DateTime? requestTime,
    String action = 'raise_hand',
  }) async {
    final payload = <String, dynamic>{
      'room_id': roomId,
      'user_uid': userUid,
      'action': action,
      if (participantIdentity != null && participantIdentity.isNotEmpty)
        'participant_identity': participantIdentity,
      if (userId != null) 'user_id': userId,
      'request_time': (requestTime ?? DateTime.now()).toIso8601String(),
    };

    final response = await _callGateway(
      endpoint: '/api/v1/participants/request-microphone',
      method: 'POST',
      data: payload,
      headers:
          jwtToken.isNotEmpty ? {'Authorization': 'Bearer ' + jwtToken} : null,
    );

    return GatewayActionResult.fromResponse(response);
  }

  Future<Map<String, dynamic>> _callGateway({
    required String endpoint,
    required String method,
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final queryParameters = <String, dynamic>{
      'api': endpoint,
      if (query != null) ...query,
    };

    try {
      final response = await _dio.request<Map<String, dynamic>>(
        _gatewayPath,
        data: method.toUpperCase() == 'GET' ? null : data,
        queryParameters: method.toUpperCase() == 'GET'
            ? {...queryParameters, if (data != null) ...data}
            : queryParameters,
        options: Options(
          method: method.toUpperCase(),
          headers: headers,
        ),
      );

      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        return responseData;
      }
      return {
        'success': false,
        'error': _describeDioError(error),
      };
    } catch (error) {
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }

  Future<String?> _resolveClientIp() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.ipify.org',
        queryParameters: const {'format': 'json'},
        options: Options(responseType: ResponseType.json),
      );

      final data = response.data;
      if (data != null) {
        final ip = data['ip'];
        if (ip is String && ip.trim().isNotEmpty) {
          return ip.trim();
        }
      }
    } catch (_) {
      // 网络环境不稳定时允许静默失败。
    }
    return null;
  }

  String _describeDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络后重试';
      case DioExceptionType.sendTimeout:
        return '请求发送超时，请稍后重试';
      case DioExceptionType.receiveTimeout:
        return '服务器响应超时，请稍后重试';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        return status != null ? '请求失败，状态码：$status' : '请求失败，服务器异常';
      case DioExceptionType.cancel:
        return '请求已被取消';
      case DioExceptionType.badCertificate:
        return '证书校验失败，请检查网络环境';
      case DioExceptionType.connectionError:
        return '网络连接异常，请检查网络';
      case DioExceptionType.unknown:
      default:
        return error.message ?? '未知网络错误';
    }
  }
}

class GatewayAuthResult {
  GatewayAuthResult({
    required this.success,
    this.message,
    this.error,
    this.payload,
    this.tokens,
    this.jwtToken,
    this.accessToken,
    this.refreshToken,
    this.accessExpiresAt,
    this.refreshExpiresAt,
    this.userId,
    this.userName,
    this.userNickname,
    this.userRoles,
    this.wsUrl,
  });

  final bool success;
  final String? message;
  final String? error;
  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? tokens;
  final String? jwtToken;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? accessExpiresAt;
  final DateTime? refreshExpiresAt;
  final int? userId;
  final String? userName;
  final String? userNickname;
  final int? userRoles;
  final String? wsUrl;

  bool get hasJwtToken => (jwtToken ?? accessToken)?.isNotEmpty ?? false;

  Map<String, dynamic> toSecureJson() {
    final data = <String, dynamic>{
      'userId': userId,
      'userName': userName,
      'userNickname': userNickname,
      'userRoles': userRoles,
      'jwtToken': jwtToken,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessExpiresAt': accessExpiresAt?.toIso8601String(),
      'refreshExpiresAt': refreshExpiresAt?.toIso8601String(),
      'wsUrl': wsUrl,
      'tokens': tokens,
      'payload': payload,
    };
    data.removeWhere((_, value) => value == null);
    return data;
  }

  Map<String, dynamic> toPublicJson() {
    return {
      'success': success,
      'message': message,
      'error': error,
      'userId': userId,
      'userName': userName,
      'userNickname': userNickname,
      'userRoles': userRoles,
      'wsUrl': wsUrl,
    }..removeWhere((key, value) => value == null);
  }

  factory GatewayAuthResult.fromResponse(Map<String, dynamic> response) {
    final normalized = _normalizeResponse(response);
    final payload = normalized.payload;
    final tokens = _extractMap(payload, 'tokens') ??
        _extractMap(normalized.envelope, 'tokens');

    final jwtToken = _pickString(payload, const ['jwt_token']) ??
        _pickString(tokens, const ['access_token']) ??
        _pickString(normalized.envelope, const ['jwt_token']);

    final accessToken = _pickString(tokens, const ['access_token']);
    final refreshToken = _pickString(tokens, const ['refresh_token']) ??
        _pickString(payload, const ['refresh_token']);
    final userId = _pickInt(payload, const ['uid', 'user_id', 'id']);
    final userRoles = _pickInt(payload, const ['user_roles']);
    final userName = _pickString(payload, const ['user_name', 'username']);
    final userNickname =
        _pickString(payload, const ['user_nickname', 'nickname']) ?? userName;
    final wsUrl = _pickString(payload, const ['ws_url']) ??
        _pickString(normalized.envelope, const ['ws_url']);

    final accessExpiresAt = _deriveExpiry(
      absolute: tokens?['access_expires_at'] ?? payload?['access_expires_at'],
      relative: tokens?['access_expires_in'] ?? tokens?['expires_in'],
    );
    final refreshExpiresAt = _deriveExpiry(
      absolute: tokens?['refresh_expires_at'] ?? payload?['refresh_expires_at'],
      relative: tokens?['refresh_expires_in'],
    );

    return GatewayAuthResult(
      success: normalized.success,
      message: normalized.message,
      error: normalized.error,
      payload: payload,
      tokens: tokens,
      jwtToken: jwtToken,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessExpiresAt: accessExpiresAt,
      refreshExpiresAt: refreshExpiresAt,
      userId: userId,
      userName: userName,
      userNickname: userNickname,
      userRoles: userRoles,
      wsUrl: wsUrl,
    );
  }
}

class GatewayRegisterResult {
  GatewayRegisterResult({
    required this.success,
    this.message,
    this.error,
    this.payload,
    this.userId,
    this.userName,
    this.userNickname,
  });

  final bool success;
  final String? message;
  final String? error;
  final Map<String, dynamic>? payload;
  final int? userId;
  final String? userName;
  final String? userNickname;

  factory GatewayRegisterResult.fromResponse(Map<String, dynamic> response) {
    final normalized = _normalizeResponse(response);
    final payload = normalized.payload;

    return GatewayRegisterResult(
      success: normalized.success,
      message: normalized.message,
      error: normalized.error,
      payload: payload,
      userId: _pickInt(payload, const ['uid', 'user_id', 'id']),
      userName: _pickString(payload, const ['user_name', 'username']),
      userNickname: _pickString(payload, const ['user_nickname', 'nickname']),
    );
  }
}

class GatewayAuthStatusResult {
  GatewayAuthStatusResult({
    required this.success,
    this.message,
    this.error,
    this.payload,
    this.userType,
    this.userName,
    this.userNickname,
    this.jwtToken,
    this.wsUrl,
  });

  final bool success;
  final String? message;
  final String? error;
  final Map<String, dynamic>? payload;
  final String? userType;
  final String? userName;
  final String? userNickname;
  final String? jwtToken;
  final String? wsUrl;

  bool get isGuest => userType == 'guest';

  factory GatewayAuthStatusResult.fromResponse(Map<String, dynamic> response) {
    final normalized = _normalizeResponse(response);
    final payload = normalized.payload;

    final userInfo = _extractMap(payload, 'user') ?? payload;

    return GatewayAuthStatusResult(
      success: normalized.success,
      message: normalized.message,
      error: normalized.error,
      payload: payload,
      userType: _pickString(payload, const ['user_type', 'type']),
      userName: _pickString(payload, const ['user_name', 'username']) ??
          _pickString(userInfo, const ['user_name', 'username']),
      userNickname: _pickString(payload, const ['user_nickname', 'nickname']) ??
          _pickString(userInfo, const ['user_nickname', 'nickname']),
      jwtToken: _pickString(payload, const ['jwt_token']) ??
          _pickString(userInfo, const ['jwt_token']),
      wsUrl: _pickString(payload, const ['ws_url', 'wss_url']) ??
          _pickString(userInfo, const ['ws_url', 'wss_url']),
    );
  }
}

class GatewayRoomDetailResult {
  GatewayRoomDetailResult({
    required this.success,
    this.message,
    this.error,
    this.payload,
    this.user,
    this.room,
    this.connection,
  });

  final bool success;
  final String? message;
  final String? error;
  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? room;
  final Map<String, dynamic>? connection;

  String? get livekitToken =>
      _pickString(connection, const ['livekit_token', 'token']);
  String? get wssUrl => _pickString(connection, const ['wss_url', 'ws_url']);
  String? get userName => _pickString(user, const ['user_name', 'username']);
  String? get userNickname =>
      _pickString(user, const ['user_nickname', 'nickname']);
  int? get userRoles => _pickInt(user, const ['user_roles']);
  int? get userId => _pickInt(user, const ['uid', 'user_id', 'id']);
  String? get roomId => _pickString(room, const ['room_id', 'id']);
  String? get roomName => _pickString(room, const ['room_name', 'name']);
  bool get hasLiveKitToken => (livekitToken?.isNotEmpty ?? false);

  factory GatewayRoomDetailResult.fromResponse(Map<String, dynamic> response) {
    final normalized = _normalizeResponse(response);
    final payload = normalized.payload ?? response;

    final user = _extractMap(payload, 'user');
    final room = _extractMap(payload, 'room');
    final connection = _extractMap(payload, 'connection');

    return GatewayRoomDetailResult(
      success: normalized.success,
      message: normalized.message,
      error: normalized.error,
      payload: payload,
      user: user,
      room: room,
      connection: connection,
    );
  }
}

class GatewayActionResult {
  GatewayActionResult({
    required this.success,
    this.message,
    this.error,
    this.payload,
  });

  final bool success;
  final String? message;
  final String? error;
  final Map<String, dynamic>? payload;

  factory GatewayActionResult.fromResponse(Map<String, dynamic> response) {
    final normalized = _normalizeResponse(response);
    return GatewayActionResult(
      success: normalized.success,
      message: normalized.message,
      error: normalized.error,
      payload: normalized.payload,
    );
  }
}

class _NormalizedResponse {
  const _NormalizedResponse({
    required this.envelope,
    required this.payload,
    required this.success,
    this.message,
    this.error,
  });

  final Map<String, dynamic> envelope;
  final Map<String, dynamic>? payload;
  final bool success;
  final String? message;
  final String? error;
}

_NormalizedResponse _normalizeResponse(Map<String, dynamic> raw) {
  final envelope = raw;
  Map<String, dynamic>? payload;

  if (envelope.containsKey('data')) {
    final data = envelope['data'];
    if (data is Map<String, dynamic>) {
      payload = data;
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } catch (_) {
        // 忽略解析异常
      }
    }
  }

  payload ??= envelope;

  final success = (payload['success'] ?? envelope['success']) == true;
  final message = _pickString(payload, const ['message', 'error']) ??
      _pickString(envelope, const ['message', 'error']);
  final error = success
      ? null
      : (_pickString(payload, const ['error']) ??
          _pickString(envelope, const ['error']));

  return _NormalizedResponse(
    envelope: envelope,
    payload: payload,
    success: success,
    message: message,
    error: error,
  );
}

Map<String, dynamic>? _extractMap(Map<String, dynamic>? source, String key) {
  if (source == null) {
    return null;
  }
  final value = source[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));
  }
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // 忽略异常
    }
  }
  return null;
}

String? _pickString(Map<String, dynamic>? source, List<String> keys) {
  if (source == null) {
    return null;
  }
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
  }
  return null;
}

int? _pickInt(Map<String, dynamic>? source, List<String> keys) {
  if (source == null) {
    return null;
  }
  for (final key in keys) {
    final value = source[key];
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

DateTime? _deriveExpiry({dynamic absolute, dynamic relative}) {
  final absoluteDate = _parseTimestamp(absolute);
  if (absoluteDate != null) {
    return absoluteDate;
  }
  final seconds = _parseSeconds(relative);
  if (seconds != null && seconds > 0) {
    return DateTime.now().add(Duration(seconds: seconds));
  }
  return null;
}

DateTime? _parseTimestamp(dynamic value) {
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
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final asInt = int.tryParse(trimmed);
    if (asInt != null) {
      if (asInt > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      if (asInt > 0) {
        return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
      }
    }
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null) {
      if (asDouble > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(asDouble.round());
      }
      if (asDouble > 0) {
        return DateTime.fromMillisecondsSinceEpoch((asDouble * 1000).round());
      }
    }
    final parsedDate = DateTime.tryParse(trimmed);
    if (parsedDate != null) {
      return parsedDate;
    }
  }
  return null;
}

int? _parseSeconds(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      return parsed.round();
    }
  }
  return null;
}
