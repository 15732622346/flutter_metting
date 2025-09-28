import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/room_model.dart';
import 'gateway_api_service.dart';

class RoomListService {
  RoomListService._internal();

  static final RoomListService _instance = RoomListService._internal();

  factory RoomListService() => _instance;

  final GatewayApiService _gateway = GatewayApiService();

  Future<List<Room>> fetchRooms({int page = 1}) async {
    try {
      final response = await _gateway.fetchRoomList(page: page);
      if (_responseFailed(response)) {
        final message =
            _readErrorMessage(response) ?? '获取房间列表失败，请稍后重试';
        throw Exception(message);
      }

      final rooms = _extractRoomList(response) ?? const [];
      return rooms
          .map(_normalizeRoomPayload)
          .whereType<Map<String, dynamic>>()
          .map(Room.fromJson)
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('房间列表请求失败: $error');
      if (error is Exception) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      Error.throwWithStackTrace(
        Exception('获取房间列表失败，请稍后重试'),
        stackTrace,
      );
    }
  }

  List<Map<String, dynamic>>? _extractRoomList(dynamic payload) {
    final map = _asJsonMap(payload);
    if (map == null) {
      return null;
    }

    final candidates = <dynamic?>[
      map['rooms'],
      map['list'],
      map['items'],
      map['data'],
      map['payload'],
      map['result'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<dynamic>()
            .map(_asJsonMap)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      if (candidate is Map) {
        final nested = _extractRoomList(candidate);
        if (nested != null) {
          return nested;
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? _normalizeRoomPayload(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final room = Map<String, dynamic>.from(raw);

    room['room_id'] ??= room['id']?.toString();
    room['room_name'] ??= room['name'] ?? room['title'];
    room['user_id'] ??= room['creator_user_id'] ?? room['host_user_id'] ?? 0;
    room['creator_name'] ??= room['creator_nickname'] ?? room['creator_name'];
    room['host_name'] ??= room['host_nickname'] ?? room['host_name'];
    room['host_nickname'] ??= room['host_name'];
    room['invite_code'] ??= room['inviteCode'] ?? room['code'] ?? '';
    room['max_mic_slots'] ??= room['maxMicSlots'] ?? 8;

    final createTime = room['create_time_formatted'] ?? room['createTime'];
    if (createTime != null && room['create_time'] == null) {
      room['create_time'] = createTime;
    }
    room['updatetime'] ??=
        room['status_updated_at'] ?? room['update_time'] ?? room['updatetime'];

    final currentStatus = room['current_room_status'];
    if (currentStatus is int) {
      room['room_state'] = currentStatus == 1 ? 1 : 0;
    } else if (room['room_state'] == null && currentStatus is String) {
      room['room_state'] = currentStatus == '1' ? 1 : 0;
    } else {
      room['room_state'] = room['room_state'] ?? 1;
    }

    room['audio_state'] ??= room['audioState'] ?? 1;
    room['camera_state'] ??= room['cameraState'] ?? 1;
    room['chat_state'] ??= room['chatState'] ?? 1;

    return room;
  }

  Map<String, dynamic>? _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      try {
        return value.cast<String, dynamic>();
      } catch (_) {
        return null;
      }
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        return _asJsonMap(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _readErrorMessage(dynamic payload) {
    final map = _asJsonMap(payload);
    if (map == null) {
      return null;
    }
    for (final key in const ['message', 'error', 'msg']) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  bool _responseFailed(Map<String, dynamic> response) {
    final successValue = response['success'];
    if (successValue is bool) {
      return !successValue;
    }
    if (successValue is String) {
      return successValue.toLowerCase() == 'false';
    }
    return response.containsKey('error');
  }
}
