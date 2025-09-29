import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../models/room_join_data.dart';
import '../services/livekit_service.dart';
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

class _VideoConferenceScreenState extends State<VideoConferenceScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  // LiveKit 会话状态
  final LiveKitService _liveKitService = LiveKitService();
  StreamSubscription<List<lk.RemoteParticipant>>? _participantsSubscription;
  StreamSubscription<lk.VideoTrack?>? _localVideoTrackSubscription;
  StreamSubscription<lk.ConnectionState>? _connectionStateSubscription;
  StreamSubscription<LiveKitEvent>? _roomEventSubscription;

  List<lk.RemoteParticipant> _remoteParticipants =
      const <lk.RemoteParticipant>[];
  lk.VideoTrack? _primaryVideoTrack;
  lk.RemoteParticipant? _primaryParticipant;
  lk.VideoTrack? _localVideoTrack;
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
        normalizedWsUrl = normalizedWsUrl.substring(0, normalizedWsUrl.length - 4);
      } else if (normalizedWsUrl.endsWith('/rtc/')) {
        normalizedWsUrl = normalizedWsUrl.substring(0, normalizedWsUrl.length - 5);
      }
      if (normalizedWsUrl.endsWith('/')) {
        normalizedWsUrl = normalizedWsUrl.substring(0, normalizedWsUrl.length - 1);
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
          _occupiedMicSeats = participants.length + 1;
        });
        _updatePrimaryVideoTrack(participants: participants);
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
          _occupiedMicSeats = initialRemotes.length + 1;
        });
      }

      _updatePrimaryVideoTrack(participants: initialRemotes);

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
        _updatePrimaryVideoTrack();
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

  void _updatePrimaryVideoTrack({List<lk.RemoteParticipant>? participants}) {
    final list = participants ?? _remoteParticipants;

    lk.RemoteParticipant? candidateParticipant;
    lk.VideoTrack? candidateTrack;

    for (final participant in list) {
      final track = _firstVideoTrack(participant);
      if (track != null) {
        candidateParticipant = participant;
        candidateTrack = track;
        break;
      }
    }

    if (!mounted) return;

    if (_primaryVideoTrack == candidateTrack &&
        _primaryParticipant == candidateParticipant) {
      return;
    }

    setState(() {
      _primaryParticipant = candidateParticipant;
      _primaryVideoTrack = candidateTrack;
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
      resizeToAvoidBottomInset: true, // 明确开启键盘自动适配（默认就是true）
      body: SafeArea(
        child: Stack(
          children: [
            // 主容器
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

            // 小视频窗口 - 浮动在右上角
            _buildSmallVideoWindow(),
          ],
        ),
      ),
    );
  }

  /// 构建视频播放区域
  Widget _buildVideoArea() {
    Widget content;

    if (_connectionError != null) {
      content = _buildVideoStatus(
        _connectionError!,
        icon: Icons.error_outline,
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
          _resolveParticipantName(_primaryParticipant) ?? _moderator;
      content = _buildVideoStatus(
        '等待主持人 $hostDisplay 开播',
        icon: Icons.videocam_off,
      );
    }

    return Container(
      color: Colors.black,
      child: content,
    );
  }

  /// 构建小视频窗口
  Widget _buildSmallVideoWindow() {
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
              // 更新拖动位置，限制在屏幕边界内
              final screenSize = MediaQuery.of(context).size;
              _floatingWindowY = (_floatingWindowY + details.delta.dy)
                  .clamp(0.0, screenSize.height - 30);
              _floatingWindowX = (_floatingWindowX - details.delta.dx)
                  .clamp(0.0, screenSize.width - 75); // 60(width) + 15(padding)
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

    return Positioned(
      top: _floatingWindowY,
      right: _floatingWindowX + 15,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // 更新拖动位置，限制在屏幕边界内
            final screenSize = MediaQuery.of(context).size;
            _floatingWindowY = (_floatingWindowY + details.delta.dy)
                .clamp(0.0, screenSize.height - 140); // 140是小窗口高度
            _floatingWindowX = (_floatingWindowX - details.delta.dx)
                .clamp(0.0, screenSize.width - 135); // 120(width) + 15(padding)
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
              // 小视频内容
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: _buildSmallVideoContent(),
              ),
              // 控制按钮
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
                        '—',
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
                    const TextSpan(text: '麦位数 '),
                    TextSpan(
                      text: '$_totalMicSeats 个, ',
                      style: const TextStyle(color: Color(0xFFffe200)),
                    ),
                    const TextSpan(text: '上限 '),
                    TextSpan(
                      text: '$_occupiedMicSeats 人, ',
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
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFe0e0e0), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // 使用center对齐
        children: [
          // 输入框容器
          Expanded(
            child: SizedBox(
              height: 40, // 设置固定高度40px，与按钮匹配
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                style: const TextStyle(
                  color: Color(0xFF333333), // #333 文字颜色
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15, vertical: 8), // 调整内边距
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4), // 4px圆角
                    borderSide:
                        const BorderSide(color: Color(0xFFdddddd)), // #ddd
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFFdddddd)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(
                      color: Color(0xFF388e3c), // 聚焦时绿色边框
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),

          const SizedBox(width: 10), // 匹配HTML的gap: 10px

          // 按钮工具栏
          Row(
            children: [
              if (_isInputFocused) ...[
                // 发送按钮 - 聚焦时显示
                SizedBox(
                  height: 40, // 与输入框高度完全一致
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque, // 确保整个区域都能响应点击
                    onTap: () => _sendMessage(_messageController.text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFff5722), // #ff5722 橙红色
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
                // 开麦按钮
                SizedBox(
                  height: 40, // 与输入框高度完全一致
                  child: ElevatedButton(
                    onPressed: () => _showToast('开麦功能开发中'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFb5b5b5), // #b5b5b5 灰色
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('开麦', style: TextStyle(fontSize: 14)),
                  ),
                ),

                const SizedBox(width: 8), // 按钮间距

                // 上麦按钮
                SizedBox(
                  height: 40, // 与输入框高度完全一致
                  child: ElevatedButton(
                    onPressed: () => _showToast('上麦功能开发中'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4595d5), // #4595d5 蓝色
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('上麦', style: TextStyle(fontSize: 14)),
                  ),
                ),
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
