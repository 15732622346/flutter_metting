import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../models/room_join_data.dart';
import '../services/livekit_service.dart';
import '../services/gateway_api_service.dart';
import '../widgets/video_track_widget.dart';

/// 直播间界面
class VideoConferenceScreen extends StatefulWidget {
  const VideoConferenceScreen({
    super.key,
    required this.joinData,
  });

  final RoomJoinData joinData;

  @override
  State<VideoConferenceScreen> createState() => _VideoConferenceScreenState();
}

class _ParticipantRoleInfo {
  const _ParticipantRoleInfo({required this.role, this.userUid});

  final int role;
  final int? userUid;

  bool get isHostOrAdmin => role >= 2;
}

class _VideoConferenceScreenState extends State<VideoConferenceScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  // LiveKit 会话状态
  final LiveKitService _liveKitService = LiveKitService();
  final GatewayApiService _gatewayApiService = GatewayApiService();

  StreamSubscription<List<lk.RemoteParticipant>>? _participantsSubscription;
  StreamSubscription<lk.VideoTrack?>? _localVideoTrackSubscription;
  StreamSubscription<lk.ConnectionState>? _connectionStateSubscription;
  StreamSubscription<LiveKitEvent>? _roomEventSubscription;

  bool _isMicrophoneToggleInProgress = false;
  bool _isApplyingMic = false;
  bool _hasAudioPublishPermission = false;
  bool _isLocalMicrophoneEnabled = false;
  bool _isLocalUserDisabled = false;
  String _localMicStatus = 'off_mic';
  String? _localMicStatusOverride;
  int _requestingMicCount = 0;
  int? _localUserRole;
  int? _localUserUid;

  List<lk.RemoteParticipant> _remoteParticipants =
      const <lk.RemoteParticipant>[];
  lk.VideoTrack? _primaryVideoTrack;
  lk.RemoteParticipant? _primaryParticipant;
  lk.RemoteParticipant? _hostParticipant;
  lk.VideoTrack? _hostScreenShareTrack;
  lk.VideoTrack? _hostCameraTrack;
  lk.VideoTrack? _localVideoTrack;
  int? _hostUserUid;
  String? _hostIdentity;
  bool _isPrimaryScreenShare = false;
  bool _isConnectingRoom = false;
  bool _isRoomConnected = false;
  String? _connectionError;

  // 小视频窗口状态
  bool _isSmallVideoMinimized = false;

  // 浮动窗口拖动位置
  double _floatingWindowX = 0.0; // 距离右边的距离
  double _floatingWindowY = 305.0; // 距离顶部的距离

  // 麦位和聊天数据
  int _totalMicSeats = 10;
  int _occupiedMicSeats = 8;
  String _moderator = '主持人';

  // 模拟聊天消息
  List<ChatMessage> _chatMessages = [];
  bool _isInputFocused = false; // 输入框焦点状态
  bool _isSending = false; // 发送状态，防止按钮冲突

  // 浮动窗口全屏按钮防抖
  bool _isFullscreenButtonClickable = true;
  bool _isVideoMaximized = false;
  late RoomJoinData _session;

  @override
  void initState() {
    super.initState();
    _session = widget.joinData;
    _initializeData();
    _connectToLiveKit();

    // 监听输入框焦点变化
    _inputFocusNode.addListener(() {
      setState(() {
        _isInputFocused = _inputFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    _inputFocusNode.dispose();

    _participantsSubscription?.cancel();
    _localVideoTrackSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _roomEventSubscription?.cancel();

    // 离开页面时恢复默认显示与方向设置
    unawaited(_applyDeviceOrientation(fullscreen: false));
    unawaited(_liveKitService.disconnect());

    super.dispose();
  }

  /// 全屏按钮防抖函数
  void _debounceFullscreenButton(VoidCallback action) {
    if (!_isFullscreenButtonClickable) return;

    setState(() {
      _isFullscreenButtonClickable = false;
    });

    // 执行操作
    action();

    // 2秒后重置点击状态（稍长一些，因为全屏操作比较重要）
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isFullscreenButtonClickable = true;
        });
      }
    });
  }

  Future<void> _applyDeviceOrientation({required bool fullscreen}) async {
    if (fullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await _restoreSystemUI();
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  Future<void> _restoreSystemUI() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _setVideoMaximized(bool enable) async {
    if (_isVideoMaximized == enable) {
      return;
    }

    await _applyDeviceOrientation(fullscreen: enable);

    if (!mounted) {
      return;
    }

    setState(() {
      _isVideoMaximized = enable;
      if (enable) {
        _isSmallVideoMinimized = false;
      }
    });
  }

  void _handleMaximizeTap() {
    unawaited(_setVideoMaximized(true));
  }

  void _handleRestoreTap() {
    unawaited(_setVideoMaximized(false));
  }

  Widget _buildOverlayButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    double borderRadius = 22,
  }) {
    final Color effectiveBackground =
        backgroundColor ?? Colors.black.withOpacity(0.6);
    final Color effectiveForeground = foregroundColor ?? Colors.white;

    return Material(
      color: effectiveBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: effectiveForeground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: effectiveForeground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenButton() {
    return _buildOverlayButton(
      icon: Icons.fullscreen,
      label: '最大化',
      onTap: _handleMaximizeTap,
    );
  }

  Widget _buildFullscreenRestoreButton() {
    return _buildOverlayButton(
      icon: Icons.fullscreen_exit,
      label: '还原',
      onTap: _handleRestoreTap,
      backgroundColor: Colors.white.withOpacity(0.9),
      foregroundColor: Colors.black87,
    );
  }

  /// 连接 LiveKit 房间并监听状态

  Future<void> _connectToLiveKit() async {
    if (_session.liveKitToken.isEmpty || _session.wsUrl.isEmpty) {
      setState(() {
        _connectionError = '缺少房间连接信息';
        _isConnectingRoom = false;
        _isRoomConnected = false;
      });
      return;
    }

    setState(() {
      _isConnectingRoom = true;
      _connectionError = null;
    });

    try {
      var normalizedWsUrl = _session.wsUrl.trim();
      if (normalizedWsUrl.endsWith('/rtc')) {
        normalizedWsUrl =
            normalizedWsUrl.substring(0, normalizedWsUrl.length - 4);
      } else if (normalizedWsUrl.endsWith('/rtc/')) {
        normalizedWsUrl =
            normalizedWsUrl.substring(0, normalizedWsUrl.length - 5);
      }
      if (normalizedWsUrl.endsWith('/')) {
        normalizedWsUrl =
            normalizedWsUrl.substring(0, normalizedWsUrl.length - 1);
      }
      await _liveKitService.connectToRoom(
        normalizedWsUrl,
        _session.liveKitToken,
      );

      _connectionStateSubscription?.cancel();
      _connectionStateSubscription =
          _liveKitService.connectionState.listen((state) {
        if (!mounted) return;
        setState(() {
          _isRoomConnected = state == lk.ConnectionState.connected;
          _isConnectingRoom = state == lk.ConnectionState.connecting ||
              state == lk.ConnectionState.reconnecting;
          if (state == lk.ConnectionState.disconnected && _isRoomConnected) {
            _connectionError ??= '房间连接已断开';
          }
        });
      });

      _participantsSubscription?.cancel();
      _participantsSubscription =
          _liveKitService.participants.listen((participants) {
        if (!mounted) return;
        setState(() {
          _remoteParticipants = participants;
        });
        _updateActiveVideoTracks(participants: participants);
        _refreshParticipantStates();
      });

      _localVideoTrackSubscription?.cancel();
      _localVideoTrackSubscription =
          _liveKitService.localVideoTrack.listen((track) {
        if (!mounted) return;
        setState(() {
          _localVideoTrack = track;
        });
      });

      _roomEventSubscription?.cancel();
      _roomEventSubscription = _liveKitService.events.listen(_handleRoomEvent);

      final initialRemotes =
          _liveKitService.room?.participants.values.toList() ??
              const <lk.RemoteParticipant>[];

      if (mounted) {
        setState(() {
          _remoteParticipants = initialRemotes;
        });
      }

      _updateActiveVideoTracks(participants: initialRemotes);
      _refreshParticipantStates();

      lk.VideoTrack? initialLocalTrack;
      final localParticipant = _liveKitService.room?.localParticipant;
      if (localParticipant != null) {
        for (final publication in localParticipant.videoTracks) {
          final track = publication.track;
          if (track != null) {
            initialLocalTrack = track;
            break;
          }
        }
      }

      if (initialLocalTrack != null && mounted) {
        setState(() {
          _localVideoTrack = initialLocalTrack;
        });
      }

      setState(() {
        _isConnectingRoom = false;
        _isRoomConnected = true;
      });

      _refreshParticipantStates();
      unawaited(_liveKitService.enableSpeaker(true));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isConnectingRoom = false;
        _isRoomConnected = false;
        _connectionError = error.toString();
      });
    }
  }

  void _handleRoomEvent(LiveKitEvent event) {
    switch (event.type) {
      case LiveKitEventType.trackPublished:
      case LiveKitEventType.trackUnpublished:
      case LiveKitEventType.participantConnected:
      case LiveKitEventType.participantDisconnected:
      case LiveKitEventType.trackSubscribed:
      case LiveKitEventType.trackUnsubscribed:
        _updateActiveVideoTracks();
        _refreshParticipantStates();
        break;
      case LiveKitEventType.metadataUpdated:
        _refreshParticipantStates();
        break;
      case LiveKitEventType.dataReceived:
        _handleIncomingData(event);
        break;
      case LiveKitEventType.disconnected:
        if (mounted) {
          setState(() {
            _connectionError = event.data['reason']?.toString() ?? '房间连接已断开';
          });
        }
        break;
      default:
        break;
    }
  }

  void _refreshParticipantStates() {
    final room = _liveKitService.room;
    final lk.LocalParticipant? localParticipant = room?.localParticipant;
    int requestingCount = 0;
    int onMicCount = 0;
    bool localMicEnabled = false;
    bool localDisabled = false;
    bool canPublishAudio = false;
    String localStatus = 'off_mic';
    int? localRole = _localUserRole ?? _session.userRoles;
    int? localUid = _localUserUid ?? _session.userId;

    if (localParticipant != null) {
      localMicEnabled = localParticipant.isMicrophoneEnabled();
      final roleInfo = _participantRoleInfo(localParticipant);
      localRole = roleInfo.role;
      localUid = roleInfo.userUid ?? localUid;

      final metadata = _decodeParticipantMetadata(localParticipant.metadata);
      localDisabled = _extractBool(
            metadata,
            [
              'is_disabled_user',
              'isDisabledUser',
              'disabled',
              'is_forbidden_user'
            ],
          ) ==
          true;
      localStatus = _resolveLocalMicStatus(
        metadata,
        localMicEnabled: localMicEnabled,
      );

      if (localStatus == 'requesting') {
        requestingCount += 1;
      } else if (_isMicSeatStatus(localStatus)) {
        onMicCount += 1;
      }

      canPublishAudio = roleInfo.isHostOrAdmin ||
          localParticipant.permissions.canPublish ||
          _extractBool(
                metadata,
                ['publish_audio', 'can_publish_audio', 'publishAudio'],
              ) ==
              true ||
          _isMicSeatStatus(localStatus);
    }

    final participants = room?.participants.values ??
        const Iterable<lk.RemoteParticipant>.empty();
    for (final participant in participants) {
      final metadata = _decodeParticipantMetadata(participant.metadata);
      if (!_shouldDisplayParticipant(metadata)) {
        continue;
      }
      final status = _extractMicStatus(metadata);
      if (status == 'requesting') {
        requestingCount += 1;
      } else if (_isMicSeatStatus(status)) {
        onMicCount += 1;
      }
    }

    final hasLocal = localParticipant != null;
    final fallbackOccupied = _remoteParticipants.length + (hasLocal ? 1 : 0);
    final effectiveOccupied = onMicCount > 0 ? onMicCount : fallbackOccupied;
    final clampedOccupied =
        math.max(0, math.min(_totalMicSeats, effectiveOccupied));

    if (!mounted) {
      return;
    }

    setState(() {
      _isLocalMicrophoneEnabled = localMicEnabled;
      _isLocalUserDisabled = localDisabled;
      _hasAudioPublishPermission = canPublishAudio;
      _localMicStatus = localStatus;
      _localUserRole = localRole;
      _localUserUid = localUid;
      _requestingMicCount = requestingCount;
      _occupiedMicSeats = clampedOccupied;
    });
  }

  bool _isMicSeatStatus(String status) {
    switch (status) {
      case 'on_mic':
      case 'muted':
        return true;
      default:
        return false;
    }
  }

  bool _shouldDisplayParticipant(Map<String, dynamic>? metadata) {
    final display =
        _extractString(metadata, ['display_status', 'displayStatus']);
    if (display == null) {
      return true;
    }
    final normalized = display.toLowerCase();
    return normalized != 'hidden';
  }

  String _resolveLocalMicStatus(Map<String, dynamic>? metadata,
      {required bool localMicEnabled}) {
    var status = _extractMicStatus(metadata);
    if (_localMicStatusOverride != null) {
      if (status == 'off_mic' && _localMicStatusOverride == 'requesting') {
        status = _localMicStatusOverride!;
      } else if (status != 'off_mic') {
        _localMicStatusOverride = null;
      }
    }
    if (status == 'off_mic' && localMicEnabled) {
      status = 'on_mic';
    }
    return status;
  }

  String _extractMicStatus(Map<String, dynamic>? metadata) {
    final raw = _extractString(metadata,
        ['mic_status', 'micStatus', 'mic_state', 'micState', 'mic', 'status']);
    if (raw == null) {
      return 'off_mic';
    }
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'off_mic';
    }
    if (normalized.contains('request')) {
      return 'requesting';
    }
    if (normalized.contains('pending')) {
      return 'requesting';
    }
    if (normalized.contains('mute')) {
      return 'muted';
    }
    if (normalized.contains('on')) {
      return 'on_mic';
    }
    if (normalized.contains('approve')) {
      return 'on_mic';
    }
    return 'off_mic';
  }

  bool? _extractBool(Map<String, dynamic>? metadata, List<String> keys) {
    final value = _searchValue(metadata, keys);
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) {
        return null;
      }
      if (['true', 'yes', 'y', 'on', 'enabled', '1'].contains(normalized)) {
        return true;
      }
      if (['false', 'no', 'n', 'off', 'disabled', '0'].contains(normalized)) {
        return false;
      }
    }
    return null;
  }

  String? _extractString(Map<String, dynamic>? metadata, List<String> keys) {
    final value = _searchValue(metadata, keys);
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      return value.toString();
    }
    if (value is bool) {
      return value ? 'true' : 'false';
    }
    return null;
  }

  dynamic _searchValue(dynamic source, List<String> keys, [int depth = 0]) {
    if (source == null || depth > 4) {
      return null;
    }
    if (source is Map) {
      for (final key in keys) {
        if (source.containsKey(key)) {
          final value = source[key];
          if (value != null) {
            return value;
          }
        }
      }
      for (final value in source.values) {
        final result = _searchValue(value, keys, depth + 1);
        if (result != null) {
          return result;
        }
      }
    } else if (source is Iterable) {
      for (final item in source) {
        final result = _searchValue(item, keys, depth + 1);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  Future<void> _handleRequestMic() async {
    if (_isApplyingMic) {
      return;
    }
    final jwt = _session.userJwtToken ?? '';
    if (jwt.isEmpty) {
      _showToast('缺少登录凭证，无法申请上麦');
      return;
    }
    final localParticipant = _liveKitService.room?.localParticipant;
    if (localParticipant == null) {
      _showToast('尚未加入房间，无法申请上麦');
      return;
    }
    if (_isLocalUserDisabled) {
      _showToast('您已被禁用，无法申请上麦');
      return;
    }
    if (_localMicStatus == 'requesting') {
      _showToast('已发送申请，等待主持人处理');
      return;
    }
    if (_isMicSeatStatus(_localMicStatus)) {
      _showToast('您已在麦位上');
      return;
    }
    final userUid = _localUserUid ?? _session.userId;
    if (userUid == null) {
      _showToast('缺少用户标识，无法申请上麦');
      return;
    }

    setState(() {
      _isApplyingMic = true;
    });

    try {
      final result = await _gatewayApiService.requestMicrophone(
        roomId: _session.roomId,
        userUid: userUid,
        jwtToken: jwt,
        participantIdentity: localParticipant.identity,
        userId: _session.userId,
        requestTime: DateTime.now(),
      );
      if (!result.success) {
        final message = result.message ?? result.error ?? '申请上麦失败';
        throw Exception(message);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _localMicStatusOverride = 'requesting';
      });
      _showToast('申请成功，等待主持人批准');
      _refreshParticipantStates();
    } catch (error) {
      _showToast('申请上麦失败: ' + error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingMic = false;
        });
      }
    }
  }

  Future<void> _toggleLocalMicrophone() async {
    if (_isMicrophoneToggleInProgress) {
      return;
    }
    final localParticipant = _liveKitService.room?.localParticipant;
    if (localParticipant == null) {
      _showToast('尚未加入房间，无法控制麦克风');
      return;
    }
    if (_isLocalUserDisabled) {
      _showToast('您已被禁用，无法使用麦克风');
      return;
    }
    if (!_hasAudioPublishPermission) {
      _showToast('请先申请上麦');
      return;
    }

    setState(() {
      _isMicrophoneToggleInProgress = true;
    });

    try {
      final shouldEnable = !localParticipant.isMicrophoneEnabled();
      await localParticipant.setMicrophoneEnabled(shouldEnable);
      final effective = localParticipant.isMicrophoneEnabled();
      if (mounted) {
        setState(() {
          _isLocalMicrophoneEnabled = effective;
        });
      }
      _refreshParticipantStates();
      _showToast(effective ? '已开麦' : '已关麦');
    } catch (error) {
      _showToast('切换麦克风失败: ' + error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isMicrophoneToggleInProgress = false;
        });
      }
    }
  }

  void _handleIncomingData(LiveKitEvent event) {
    final rawData = event.data['data'];
    final participant = event.data['participant'];

    if (participant is lk.LocalParticipant) {
      return;
    }

    if (rawData is Uint8List) {
      try {
        final decoded = utf8.decode(rawData);
        final payload = jsonDecode(decoded);

        if (payload is Map<String, dynamic> && payload['type'] == 'chat') {
          final senderName = _resolveParticipantName(participant) ??
              payload['sender']?.toString() ??
              '匿名用户';
          final message = payload['message']?.toString() ?? decoded;
          _addChatMessage(ChatMessage(
            username: senderName,
            message: message,
            isSystem: false,
            isOwn: false,
          ));
          return;
        }

        final senderName = _resolveParticipantName(participant) ?? '系统消息';
        _addChatMessage(ChatMessage(
          username: senderName,
          message: decoded,
          isSystem: false,
          isOwn: false,
        ));
      } catch (_) {
        final senderName = _resolveParticipantName(participant) ?? '系统消息';
        _addChatMessage(ChatMessage(
          username: senderName,
          message: '收到了一条消息',
          isSystem: false,
          isOwn: false,
        ));
      }
    }
  }

  Map<String, dynamic>? _decodeParticipantMetadata(String? metadata) {
    if (metadata == null) {
      return null;
    }
    final trimmed = metadata.trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'undefined') {
      return null;
    }

    Map<String, dynamic>? tryParse(String value) {
      try {
        final result = jsonDecode(value);
        if (result is Map<String, dynamic>) {
          return result;
        }
        if (result is String) {
          return tryParse(result);
        }
      } catch (_) {
        // ignore parse errors
      }
      return null;
    }

    final direct = tryParse(trimmed);
    if (direct != null) {
      return direct;
    }

    final normalized = _normalizeBase64(trimmed);
    if (normalized != null) {
      try {
        final decoded = utf8.decode(base64Decode(normalized));
        final parsed = tryParse(decoded);
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        // ignore base64 errors
      }
    }

    return null;
  }

  String? _normalizeBase64(String value) {
    final candidate = value.replaceAll('\n', '').replaceAll('\r', '');
    final regex = RegExp(r'^[A-Za-z0-9+/=_-]+$');
    if (!regex.hasMatch(candidate)) {
      return null;
    }
    final normalized = candidate.replaceAll('-', '+').replaceAll('_', '/');
    final remainder = normalized.length % 4;
    if (remainder == 0) {
      return normalized;
    }
    return normalized + '=' * (4 - remainder);
  }

  int? _tryParseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      if (value == value.floor()) {
        return value.toInt();
      }
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return int.tryParse(trimmed);
    }
    return null;
  }

  int? _extractUserUidFrom(dynamic source) {
    if (source is Map) {
      for (final entry in source.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String) {
          switch (key) {
            case 'user_uid':
            case 'userUid':
            case 'uid':
            case 'user_id':
            case 'userId':
            case 'participant_uid':
            case 'participantUid':
              final parsed = _tryParseInt(value);
              if (parsed != null) {
                return parsed;
              }
              break;
          }
        }
      }
      for (final value in source.values) {
        final nested = _extractUserUidFrom(value);
        if (nested != null) {
          return nested;
        }
      }
    } else if (source is Iterable) {
      for (final value in source) {
        final nested = _extractUserUidFrom(value);
        if (nested != null) {
          return nested;
        }
      }
    } else if (source is String) {
      final decoded = _decodeParticipantMetadata(source);
      if (decoded != null) {
        return _extractUserUidFrom(decoded);
      }
      final parsed = _tryParseInt(source);
      if (parsed != null) {
        return parsed;
      }
    } else {
      final parsed = _tryParseInt(source);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  _ParticipantRoleInfo _participantRoleInfo(lk.Participant participant) {
    final metadataMap = _decodeParticipantMetadata(participant.metadata);
    int role = 1;
    int? userUid;

    if (metadataMap != null) {
      final roleCandidate = metadataMap['role'] ??
          metadataMap['role_id'] ??
          metadataMap['roleId'];
      final parsedRole = _tryParseInt(roleCandidate);
      if (parsedRole != null) {
        role = parsedRole;
      } else if (roleCandidate is String) {
        final trimmed = roleCandidate.trim();
        if (trimmed.isNotEmpty) {
          role = int.tryParse(trimmed) ?? role;
        }
      }
      userUid = _extractUserUidFrom(metadataMap);
    }

    userUid ??= _tryParseInt(
      participant.identity.replaceFirst(RegExp(r'^user[_-]?'), ''),
    );

    return _ParticipantRoleInfo(role: role, userUid: userUid);
  }

  bool _matchesHostIdentity(lk.Participant participant) {
    if (_hostIdentity == null || _hostIdentity!.isEmpty) {
      return false;
    }
    final identity = participant.identity.trim();
    if (identity == _hostIdentity) {
      return true;
    }
    final normalized = identity.replaceFirst(RegExp(r'^user[_-]?'), '');
    if (normalized == _hostIdentity) {
      return true;
    }
    final targetInt = _tryParseInt(_hostIdentity);
    if (targetInt != null) {
      final identityInt = _tryParseInt(normalized);
      if (identityInt != null && identityInt == targetInt) {
        return true;
      }
    }
    return false;
  }

  lk.RemoteParticipant? _selectHostParticipant(
      List<lk.RemoteParticipant> participants) {
    if (participants.isEmpty) {
      return null;
    }

    lk.RemoteParticipant? roleCandidate;

    for (final participant in participants) {
      final roleInfo = _participantRoleInfo(participant);
      if (_hostUserUid != null && roleInfo.userUid == _hostUserUid) {
        return participant;
      }
      if (_matchesHostIdentity(participant)) {
        return participant;
      }
      if (roleInfo.isHostOrAdmin && roleCandidate == null) {
        roleCandidate = participant;
      }
    }

    if (roleCandidate != null) {
      return roleCandidate;
    }

    if (_hostIdentity != null) {
      for (final participant in participants) {
        if (_matchesHostIdentity(participant)) {
          return participant;
        }
      }
    }

    if (_hostUserUid != null) {
      for (final participant in participants) {
        final roleInfo = _participantRoleInfo(participant);
        if (roleInfo.userUid == _hostUserUid) {
          return participant;
        }
      }
    }

    return participants.first;
  }

  lk.VideoTrack? _firstVideoTrackOfSource(
      lk.RemoteParticipant participant, lk.TrackSource source) {
    for (final publication in participant.videoTracks) {
      final track = publication.track;
      if (track == null || !publication.subscribed) {
        continue;
      }
      if (publication.source == source) {
        return track;
      }
      if (source == lk.TrackSource.screenShareVideo &&
          publication.isScreenShare) {
        return track;
      }
    }
    return null;
  }

  void _updateActiveVideoTracks({List<lk.RemoteParticipant>? participants}) {
    final list = participants ?? _remoteParticipants;

    final hostParticipant =
        list.isNotEmpty ? _selectHostParticipant(list) : null;

    lk.RemoteParticipant? screenShareParticipant;
    lk.VideoTrack? screenShareTrack;

    if (hostParticipant != null) {
      final hostShare = _firstVideoTrackOfSource(
          hostParticipant, lk.TrackSource.screenShareVideo);
      if (hostShare != null) {
        screenShareParticipant = hostParticipant;
        screenShareTrack = hostShare;
      }
    }

    if (screenShareTrack == null) {
      for (final participant in list) {
        final track = _firstVideoTrackOfSource(
            participant, lk.TrackSource.screenShareVideo);
        if (track != null) {
          screenShareParticipant = participant;
          screenShareTrack = track;
          break;
        }
      }
    }

    final hostCameraTrack = hostParticipant != null
        ? _firstVideoTrackOfSource(hostParticipant, lk.TrackSource.camera)
        : null;

    lk.RemoteParticipant? fallbackParticipant =
        screenShareParticipant ?? hostParticipant;
    if (fallbackParticipant == null && list.isNotEmpty) {
      fallbackParticipant = list.first;
    }

    lk.VideoTrack? fallbackTrack = screenShareTrack;
    if (fallbackTrack == null && fallbackParticipant != null) {
      fallbackTrack = _firstVideoTrack(fallbackParticipant);
    }

    if (!mounted) {
      return;
    }

    final shouldUpdate = _hostParticipant != hostParticipant ||
        _hostScreenShareTrack != screenShareTrack ||
        _hostCameraTrack != hostCameraTrack ||
        _primaryVideoTrack != fallbackTrack ||
        _primaryParticipant != fallbackParticipant ||
        _isPrimaryScreenShare != (screenShareTrack != null);

    if (!shouldUpdate) {
      return;
    }

    setState(() {
      _hostParticipant = hostParticipant;
      _hostScreenShareTrack = screenShareTrack;
      _hostCameraTrack = hostCameraTrack;
      _primaryParticipant = fallbackParticipant;
      _primaryVideoTrack = fallbackTrack;
      _isPrimaryScreenShare = screenShareTrack != null;
    });
  }

  lk.VideoTrack? _firstVideoTrack(lk.RemoteParticipant participant) {
    for (final publication in participant.videoTracks) {
      final track = publication.track;
      if (track != null && publication.subscribed) {
        return track;
      }
    }
    return null;
  }

  String? _resolveParticipantName(dynamic participant) {
    if (participant is lk.Participant) {
      final trimmedName = participant.name.trim();
      if (trimmedName.isNotEmpty) {
        return trimmedName;
      }
      if (participant.identity.isNotEmpty) {
        return participant.identity;
      }
    }
    return null;
  }

  void _addChatMessage(ChatMessage message) {
    setState(() {
      _chatMessages.add(message);
    });

    _scheduleScrollToBottom();
  }

  void _scheduleScrollToBottom() {
    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;

      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 初始化模拟数据 - 结合实时房间信息
  void _initializeData() {
    final roomInfo = _session.roomInfo ?? <String, dynamic>{};
    final hostName = roomInfo['host_nickname'] ??
        roomInfo['hostNickname'] ??
        roomInfo['creator_nickname'] ??
        roomInfo['creatorName'] ??
        _moderator;

    if (hostName is String && hostName.trim().isNotEmpty) {
      _moderator = hostName.trim();
    }

    final hostIdCandidates = [
      roomInfo['host_user_id'],
      roomInfo['hostUserId'],
      roomInfo['host_uid'],
      roomInfo['hostUid'],
      roomInfo['hostUserUid'],
      roomInfo['creator_user_id'],
      roomInfo['creatorUserId'],
    ];
    for (final candidate in hostIdCandidates) {
      final parsed = _tryParseInt(candidate);
      if (parsed != null) {
        _hostUserUid = parsed;
        break;
      }
    }

    final identityCandidates = [
      roomInfo['host_identity'],
      roomInfo['hostIdentity'],
      roomInfo['host_livekit_identity'],
      roomInfo['hostLivekitIdentity'],
    ];
    for (final candidate in identityCandidates) {
      if (candidate is String) {
        final trimmed = candidate.trim();
        if (trimmed.isNotEmpty) {
          _hostIdentity = trimmed;
          break;
        }
      }
    }

    final maxSlots = roomInfo['max_mic_slots'] ?? roomInfo['maxMicSlots'];
    if (maxSlots is int && maxSlots > 0) {
      _totalMicSeats = maxSlots;
    }

    final onlineCount = roomInfo['online_count'] ?? roomInfo['onlineCount'];
    if (onlineCount is int && onlineCount >= 0) {
      _occupiedMicSeats = onlineCount;
    }

    final participantName =
        _session.participantName.isNotEmpty ? _session.participantName : '访客';

    _chatMessages = [
      ChatMessage(
        username: '系统',
        message: '系统：欢迎 $participantName 加入 ${_session.roomName}',
        isSystem: true,
      ),
      ChatMessage(
        username: '系统',
        message: '系统：主持人 $_moderator 正在等待大家入场',
        isSystem: true,
      ),
    ];
  }

  // 移除计时器相关代码，聚焦于聊天功能

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF), // 纯白背景
      resizeToAvoidBottomInset: !_isVideoMaximized,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isVideoMaximized)
              Positioned.fill(
                child: _buildVideoArea(isFullscreen: true),
              )
            else
              Column(
                children: [
                  // 视频播放区域 - 固定16:9宽高比
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildVideoArea(),
                  ),

                  // 聊天区域 - 填充剩余空间
                  Expanded(
                    child: _buildChatSection(),
                  ),
                ],
              ),
            if (!_isVideoMaximized) _buildSmallVideoWindow(),
            if (_isVideoMaximized)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 12),
                    child: _buildFullscreenRestoreButton(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建视频播放区域
  Widget _buildVideoArea({bool isFullscreen = false}) {
    Widget content;

    if (_connectionError != null) {
      content = _buildVideoStatus(
        _connectionError!,
        icon: Icons.error_outline,
      );
    } else if (_hostScreenShareTrack != null) {
      content = VideoTrackWidget(
        key: ValueKey('${_hostScreenShareTrack.hashCode}-screen-share'),
        videoTrack: _hostScreenShareTrack!,
        fit: BoxFit.contain,
        showName: false,
      );
    } else if (_primaryVideoTrack != null) {
      content = VideoTrackWidget(
        key: ValueKey(_primaryVideoTrack),
        videoTrack: _primaryVideoTrack!,
        fit: BoxFit.cover,
        showName: false,
      );
    } else if (_localVideoTrack != null) {
      content = VideoTrackWidget(
        key: ValueKey('${_localVideoTrack.hashCode}-primary'),
        videoTrack: _localVideoTrack!,
        fit: BoxFit.cover,
        mirror: true,
        showName: false,
      );
    } else if (_isConnectingRoom || !_isRoomConnected) {
      content = _buildVideoStatus(
        '正在连接房间...',
        showProgress: true,
      );
    } else {
      final hostDisplay =
          _resolveParticipantName(_hostParticipant) ?? _moderator;
      content = _buildVideoStatus(
        '等待主持人 $hostDisplay 开始共享屏幕',
        icon: Icons.desktop_windows,
      );
    }

    final video = Container(
      color: Colors.black,
      child: content,
    );

    if (isFullscreen) {
      return video;
    }

    return Stack(
      children: [
        Positioned.fill(child: video),
        Positioned(
          right: 16,
          bottom: 16,
          child: _buildFullscreenButton(),
        ),
      ],
    );
  }

  /// 构建小视频窗口
  Widget _buildSmallVideoWindow() {
    if (_isVideoMaximized) {
      return const SizedBox.shrink();
    }

    if (_isSmallVideoMinimized) {
      return Positioned(
        top: _floatingWindowY,
        right: _floatingWindowX + 15,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isSmallVideoMinimized = false;
            });
          },
          onPanUpdate: (details) {
            setState(() {
              final screenSize = MediaQuery.of(context).size;
              _floatingWindowY = (_floatingWindowY + details.delta.dy)
                  .clamp(0.0, screenSize.height - 30);
              _floatingWindowX = (_floatingWindowX - details.delta.dx)
                  .clamp(0.0, screenSize.width - 75);
            });
          },
          child: Container(
            width: 60,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF388e3c).withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                '恢复',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_hostCameraTrack == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: _floatingWindowY,
      right: _floatingWindowX + 15,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final screenSize = MediaQuery.of(context).size;
            _floatingWindowY = (_floatingWindowY + details.delta.dy)
                .clamp(0.0, screenSize.height - 140);
            _floatingWindowX = (_floatingWindowX - details.delta.dx)
                .clamp(0.0, screenSize.width - 135);
          });
        },
        child: Container(
          width: 120,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: _buildSmallVideoContent(),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSmallVideoMinimized = true;
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '收',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () => _debounceFullscreenButton(() {
                    _showToast('小窗全屏功能开发中');
                  }),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.fullscreen,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallVideoContent() {
    if (_hostCameraTrack != null) {
      return VideoTrackWidget(
        key: ValueKey('${_hostCameraTrack.hashCode}-host-camera'),
        videoTrack: _hostCameraTrack!,
        fit: BoxFit.cover,
        showName: false,
      );
    }

    if (_localVideoTrack != null) {
      return VideoTrackWidget(
        key: ValueKey(_localVideoTrack),
        videoTrack: _localVideoTrack!,
        fit: BoxFit.cover,
        mirror: true,
        showName: false,
      );
    }

    if (_primaryVideoTrack != null) {
      return VideoTrackWidget(
        key: ValueKey('${_primaryVideoTrack.hashCode}-fallback'),
        videoTrack: _primaryVideoTrack!,
        fit: BoxFit.cover,
        showName: false,
      );
    }

    for (final participant in _remoteParticipants) {
      final cameraTrack =
          _firstVideoTrackOfSource(participant, lk.TrackSource.camera);
      if (cameraTrack != null && cameraTrack != _primaryVideoTrack) {
        return VideoTrackWidget(
          key: ValueKey('${cameraTrack.hashCode}-remote-camera'),
          videoTrack: cameraTrack,
          fit: BoxFit.cover,
          showName: false,
        );
      }
    }

    for (final participant in _remoteParticipants) {
      final track = _firstVideoTrack(participant);
      if (track != null && track != _primaryVideoTrack) {
        return VideoTrackWidget(
          key: ValueKey('${track.hashCode}-remote-fallback'),
          videoTrack: track,
          fit: BoxFit.cover,
          showName: false,
        );
      }
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.videocam_off,
          color: Colors.white70,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildVideoStatus(String text,
      {bool showProgress = false, IconData? icon}) {
    final children = <Widget>[];

    if (showProgress) {
      children.add(const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(color: Colors.white),
      ));
    } else if (icon != null) {
      children.add(Icon(icon, color: Colors.white70, size: 42));
    }

    children.add(Text(
      text,
      style: const TextStyle(color: Colors.white70),
      textAlign: TextAlign.center,
    ));

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (children.length > 1) ...[
            children.first,
            const SizedBox(height: 16),
            children.last,
          ] else
            children.first,
        ],
      ),
    );
  }

  /// 构建聊天区域
  Widget _buildChatSection() {
    return Column(
      children: [
        // 聊天标题栏 - 完全匹配HTML样式
        _buildChatHeader(),

        // 聊天容器
        Expanded(
          child: _buildChatContainer(),
        ),
      ],
    );
  }

  /// 构建聊天标题栏
  Widget _buildChatHeader() {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF388e3c), // #388e3c
            Color(0xFF2e7d32), // #2e7d32
          ],
        ),
      ),
      child: Row(
        children: [
          // 聊天标题 - 带下划线
          SizedBox(
            width: 60,
            child: Stack(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '聊天',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 2,
                    color: const Color(0xFFffe200), // #ffe200 黄色下划线
                  ),
                ),
              ],
            ),
          ),

          // 房间信息 - 右对齐，使用Flexible防止溢出，数字显示为黄色
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  children: [
                    const TextSpan(text: '麦位 '),
                    TextSpan(
                      text: '$_totalMicSeats 个, ',
                      style: const TextStyle(color: Color(0xFFffe200)),
                    ),
                    const TextSpan(text: '主持人：'),
                    TextSpan(
                      text: _moderator,
                      style: const TextStyle(color: Color(0xFFffe200)),
                    ),
                    const TextSpan(text: '主持人：'),
                    TextSpan(
                      text: _moderator,
                      style: const TextStyle(color: Color(0xFFffe200)),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建聊天容器
  Widget _buildChatContainer() {
    return Column(
      children: [
        // 聊天消息列表 - 完全匹配HTML的卡片样式
        Expanded(
          child: Container(
            color: const Color(0xFFf9f9f9), // #f9f9f9 背景色
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(15),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final message = _chatMessages[index];
                return _buildChatMessage(message);
              },
            ),
          ),
        ),

        // 底部输入区域
        _buildInputContainer(),
      ],
    );
  }

  /// 构建单条聊天消息 - 完全匹配HTML卡片样式
  Widget _buildChatMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15), // 匹配HTML的12px 15px
      decoration: BoxDecoration(
        color: message.isSystem
            ? const Color(0xFFe8f5e9) // 系统消息浅绿色背景
            : message.isOwn
                ? const Color(0xFFe3f2fd) // 用户消息浅蓝色背景
                : Colors.white, // 其他消息白色背景
        borderRadius: BorderRadius.circular(8), // 8px圆角
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // rgba(0, 0, 0, 0.05)
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Text(
        message.isSystem
            ? message.message // 系统消息直接显示
            : '${message.username}: ${message.message}', // 用户消息带用户名
        style: TextStyle(
          color: message.isSystem
              ? const Color(0xFF2e7d32) // 系统消息深绿色文字
              : Colors.black87, // 其他消息黑色文字
          fontSize: 14,
        ),
      ),
    );
  }

  /// 构建输入容器 - 完全匹配HTML样式
  Widget _buildInputContainer() {
    final int resolvedRole = _localUserRole ?? _session.userRoles ?? 1;
    final bool isHostLike = resolvedRole >= 2;
    final bool micBusy = _isMicrophoneToggleInProgress;
    final bool micDisabled =
        micBusy || _isLocalUserDisabled || !_hasAudioPublishPermission;
    final Color micBackgroundColor = micDisabled
        ? const Color(0xFFb5b5b5)
        : (_isLocalMicrophoneEnabled
            ? const Color(0xFFff7043)
            : const Color(0xFF4595d5));
    final String micLabel = micBusy
        ? '处理中...'
        : _isLocalMicrophoneEnabled
            ? '关麦'
            : '开麦';
    final VoidCallback? micOnPressed =
        micDisabled ? null : _toggleLocalMicrophone;

    final bool showApplyButton = !isHostLike;
    final bool localRequesting = _localMicStatus == 'requesting';
    final bool alreadyOnMic = _isMicSeatStatus(_localMicStatus);
    final bool applyBusy = _isApplyingMic;
    final bool applyDisabled = !showApplyButton ||
        applyBusy ||
        localRequesting ||
        alreadyOnMic ||
        _isLocalUserDisabled;
    final String applyLabel = !showApplyButton
        ? '申请上麦'
        : applyBusy
            ? '申请中...'
            : _isLocalUserDisabled
                ? '已禁用'
                : localRequesting
                    ? '等待审批'
                    : alreadyOnMic
                        ? '已在麦位'
                        : '申请上麦';
    final Color applyBackgroundColor =
        applyDisabled ? const Color(0xFFb5b5b5) : const Color(0xFF4595d5);
    final VoidCallback? applyOnPressed =
        (!applyDisabled && showApplyButton) ? _handleRequestMic : null;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFe0e0e0), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                style: const TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFFdddddd)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFFdddddd)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(
                      color: Color(0xFF388e3c),
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Row(
            children: [
              if (_isInputFocused) ...[
                SizedBox(
                  height: 40,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _sendMessage(_messageController.text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFff5722),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '发送',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: micOnPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: micBackgroundColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      micLabel,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                if (showApplyButton) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: applyOnPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: applyBackgroundColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        applyLabel,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 发送消息 - 简化版，依赖Flutter自动适配
  Future<void> _sendMessage(String message) async {
    final text = message.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    final displayName =
        _session.participantName.isNotEmpty ? _session.participantName : '我';

    _addChatMessage(ChatMessage(
      username: displayName,
      message: text,
      isSystem: false,
      isOwn: true,
    ));

    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _inputFocusNode.unfocus();
      }
    });

    try {
      await _liveKitService.sendChatMessage(text);
    } catch (error) {
      _showToast('消息发送失败: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  /// 显示提示消息 - 如果已有提示在显示则不显示新提示
  void _showToast(String message) {
    // 检查是否已经有SnackBar在显示
    if (ScaffoldMessenger.of(context).mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      // 如果当前没有SnackBar显示，才显示新的
      try {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.grey[800],
          ),
        );
      } catch (e) {
        // 如果有SnackBar正在显示，会抛出异常，忽略即可
        debugPrint('Toast already visible, ignoring new toast');
      }
    }
  }
}

/// 聊天消息数据模型
class ChatMessage {
  final String username;
  final String message;
  final bool isSystem;
  final bool isOwn;
  final DateTime timestamp;

  ChatMessage({
    required this.username,
    required this.message,
    required this.isSystem,
    this.isOwn = false,
  }) : timestamp = DateTime.now();
}
