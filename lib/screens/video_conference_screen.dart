import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import '../providers/meeting_provider.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../widgets/video_track_widget.dart';
import '../widgets/participant_grid.dart';
import '../widgets/control_bar.dart';
import '../widgets/chat_panel.dart';

/// 视频会议主界面
class VideoConferenceScreen extends StatefulWidget {
  final String token;
  final String wsUrl;
  final Room room;
  final User user;

  const VideoConferenceScreen({
    super.key,
    required this.token,
    required this.wsUrl,
    required this.room,
    required this.user,
  });

  @override
  State<VideoConferenceScreen> createState() => _VideoConferenceScreenState();
}

class _VideoConferenceScreenState extends State<VideoConferenceScreen> {
  bool _showParticipants = false;
  bool _showChat = false;
  bool _isFullScreen = false;
  RemoteParticipant? _focusedParticipant;

  @override
  void initState() {
    super.initState();
    _joinMeeting();
  }

  @override
  void dispose() {
    // 离开会议会在Provider中自动处理
    super.dispose();
  }

  /// 加入会议
  Future<void> _joinMeeting() async {
    final meetingProvider = context.read<MeetingProvider>();
    
    final success = await meetingProvider.joinMeeting(
      token: widget.token,
      wsUrl: widget.wsUrl,
      room: widget.room,
      user: widget.user,
    );
    
    if (!success) {
      _showErrorAndExit('加入会议失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<MeetingProvider>(
          builder: (context, meetingProvider, child) {
            if (meetingProvider.isConnecting) {
              return _buildLoadingScreen();
            }

            if (!meetingProvider.isInMeeting) {
              return _buildErrorScreen(
                meetingProvider.lastError ?? '连接已断开'
              );
            }

            return _buildMeetingScreen(meetingProvider);
          },
        ),
      ),
    );
  }

  /// 构建加载屏幕
  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              '正在加入会议...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建错误屏幕
  Widget _buildErrorScreen(String error) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              error,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                '离开会议',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建会议屏幕
  Widget _buildMeetingScreen(MeetingProvider meetingProvider) {
    return Stack(
      children: [
        // 主视频区域
        _buildMainVideoArea(meetingProvider),
        
        // 顶部信息栏
        if (!_isFullScreen) _buildTopBar(meetingProvider),
        
        // 参与者网格（小窗口）
        if (!_isFullScreen && !_showParticipants)
          _buildParticipantThumbnails(meetingProvider),
        
        // 参与者列表面板
        if (_showParticipants) _buildParticipantsPanel(meetingProvider),
        
        // 聊天面板
        if (_showChat) _buildChatPanel(meetingProvider),
        
        // 底部控制栏
        if (!_isFullScreen) _buildBottomControls(meetingProvider),
        
        // 错误提示
        if (meetingProvider.lastError != null)
          _buildErrorBanner(meetingProvider.lastError!),
      ],
    );
  }

  /// 构建主视频区域
  Widget _buildMainVideoArea(MeetingProvider meetingProvider) {
    Widget mainVideo;
    
    if (_focusedParticipant != null) {
      // 显示选中的远程参与者视频
      final videoTrack = _focusedParticipant!.videoTrackPublications.isNotEmpty
          ? _focusedParticipant!.videoTrackPublications.first.track
          : null;
      
      if (videoTrack != null) {
        mainVideo = VideoTrackWidget(
          videoTrack: videoTrack as VideoTrack,
          fit: BoxFit.cover,
          participantName: _focusedParticipant!.identity,
        );
      } else {
        mainVideo = _buildAvatarPlaceholder(_focusedParticipant!.identity);
      }
    } else {
      // 显示本地视频
      if (meetingProvider.localVideoTrack != null) {
        mainVideo = VideoTrackWidget(
          videoTrack: meetingProvider.localVideoTrack!,
          fit: BoxFit.cover,
          participantName: '我',
          mirror: true, // 本地视频镜像显示
        );
      } else {
        mainVideo = _buildAvatarPlaceholder(widget.user.displayName);
      }
    }
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _isFullScreen = !_isFullScreen;
        });
      },
      onDoubleTap: () {
        setState(() {
          _focusedParticipant = null; // 双击回到本地视频
        });
      },
      child: SizedBox.expand(child: mainVideo),
    );
  }

  /// 构建头像占位符
  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建顶部信息栏
  Widget _buildTopBar(MeetingProvider meetingProvider) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 房间名称
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meetingProvider.roomName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        meetingProvider.participantsSummary,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 连接状态指示器
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: meetingProvider.connectionState == ConnectionState.connected
                        ? Colors.green
                        : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        meetingProvider.connectionState == ConnectionState.connected
                            ? '已连接'
                            : '连接中',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建参与者缩略图
  Widget _buildParticipantThumbnails(MeetingProvider meetingProvider) {
    final participants = meetingProvider.remoteParticipants;
    if (participants.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      right: 16,
      child: Column(
        children: participants.take(3).map((participant) {
          final videoTrack = participant.videoTrackPublications.isNotEmpty
              ? participant.videoTrackPublications.first.track as VideoTrack?
              : null;

          return GestureDetector(
            onTap: () {
              setState(() {
                _focusedParticipant = participant;
              });
            },
            child: Container(
              width: 80,
              height: 120,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: _focusedParticipant == participant
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: videoTrack != null
                    ? VideoTrackWidget(
                        videoTrack: videoTrack,
                        fit: BoxFit.cover,
                      )
                    : _buildAvatarPlaceholder(participant.identity),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 构建参与者面板
  Widget _buildParticipantsPanel(MeetingProvider meetingProvider) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          border: const Border(
            left: BorderSide(color: Colors.grey, width: 1),
          ),
        ),
        child: Column(
          children: [
            // 面板标题
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '参与者',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showParticipants = false;
                      });
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // 参与者网格
            Expanded(
              child: ParticipantGrid(
                participants: meetingProvider.remoteParticipants,
                localVideoTrack: meetingProvider.localVideoTrack,
                localUserName: widget.user.displayName,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建聊天面板
  Widget _buildChatPanel(MeetingProvider meetingProvider) {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      height: 300,
      child: ChatPanel(
        messages: meetingProvider.chatMessages,
        onSendMessage: (message) {
          meetingProvider.sendChatMessage(message);
        },
      ),
    );
  }

  /// 构建底部控制栏
  Widget _buildBottomControls(MeetingProvider meetingProvider) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: ControlBar(
            isCameraEnabled: meetingProvider.isCameraEnabled,
            isMicrophoneEnabled: meetingProvider.isMicrophoneEnabled,
            isSpeakerEnabled: meetingProvider.isSpeakerEnabled,
            canPublish: meetingProvider.canPublish,
            onCameraToggle: meetingProvider.toggleCamera,
            onMicrophoneToggle: meetingProvider.toggleMicrophone,
            onSpeakerToggle: meetingProvider.toggleSpeaker,
            onSwitchCamera: meetingProvider.switchCamera,
            onShowParticipants: () {
              setState(() {
                _showParticipants = !_showParticipants;
              });
            },
            onShowChat: () {
              setState(() {
                _showChat = !_showChat;
              });
            },
            onLeave: _leaveMeeting,
            onApplyMic: meetingProvider.isHost ? null : () {
              meetingProvider.applyForMic();
            },
            participantCount: meetingProvider.totalParticipants,
          ),
        ),
      ),
    );
  }

  /// 构建错误横幅
  Widget _buildErrorBanner(String error) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  context.read<MeetingProvider>().clearError();
                },
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 离开会议
  Future<void> _leaveMeeting() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('离开会议'),
        content: const Text('确定要离开当前会议吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              '离开',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      await context.read<MeetingProvider>().leaveMeeting();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  /// 处理返回按钮
  Future<bool> _onWillPop() async {
    await _leaveMeeting();
    return false; // 阻止默认返回行为，由_leaveMeeting处理
  }

  /// 显示错误并退出
  void _showErrorAndExit(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(error),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              Navigator.of(context).pop(); // 退出会议页面
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}