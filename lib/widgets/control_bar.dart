import 'package:flutter/material.dart';

/// 会议控制栏组件
class ControlBar extends StatelessWidget {
  final bool isCameraEnabled;
  final bool isMicrophoneEnabled;
  final bool isSpeakerEnabled;
  final bool canPublish;
  final int participantCount;
  
  final VoidCallback onCameraToggle;
  final VoidCallback onMicrophoneToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onSwitchCamera;
  final VoidCallback onShowParticipants;
  final VoidCallback onShowChat;
  final VoidCallback onLeave;
  final VoidCallback? onApplyMic; // 申请上麦，普通用户使用

  const ControlBar({
    super.key,
    required this.isCameraEnabled,
    required this.isMicrophoneEnabled,
    required this.isSpeakerEnabled,
    required this.canPublish,
    required this.participantCount,
    required this.onCameraToggle,
    required this.onMicrophoneToggle,
    required this.onSpeakerToggle,
    required this.onSwitchCamera,
    required this.onShowParticipants,
    required this.onShowChat,
    required this.onLeave,
    this.onApplyMic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 麦克风控制
          _buildControlButton(
            icon: isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
            isEnabled: isMicrophoneEnabled,
            canInteract: canPublish,
            onPressed: canPublish ? onMicrophoneToggle : onApplyMic,
            tooltip: canPublish 
                ? (isMicrophoneEnabled ? '关闭麦克风' : '开启麦克风')
                : '申请上麦',
          ),
          
          // 摄像头控制
          _buildControlButton(
            icon: isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            isEnabled: isCameraEnabled,
            canInteract: canPublish,
            onPressed: canPublish ? onCameraToggle : null,
            tooltip: isCameraEnabled ? '关闭摄像头' : '开启摄像头',
          ),
          
          // 扬声器控制
          _buildControlButton(
            icon: isSpeakerEnabled ? Icons.volume_up : Icons.volume_off,
            isEnabled: isSpeakerEnabled,
            canInteract: true,
            onPressed: onSpeakerToggle,
            tooltip: isSpeakerEnabled ? '关闭扬声器' : '开启扬声器',
          ),
          
          // 切换摄像头
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            isEnabled: true,
            canInteract: isCameraEnabled,
            onPressed: isCameraEnabled ? onSwitchCamera : null,
            tooltip: '切换摄像头',
            size: 20,
          ),
          
          // 参与者列表
          _buildControlButton(
            icon: Icons.people,
            isEnabled: false,
            canInteract: true,
            onPressed: onShowParticipants,
            tooltip: '参与者 ($participantCount)',
            badge: participantCount > 0 ? '$participantCount' : null,
          ),
          
          // 聊天
          _buildControlButton(
            icon: Icons.chat,
            isEnabled: false,
            canInteract: true,
            onPressed: onShowChat,
            tooltip: '聊天',
          ),
          
          // 离开会议
          _buildControlButton(
            icon: Icons.call_end,
            isEnabled: false,
            canInteract: true,
            onPressed: onLeave,
            tooltip: '离开会议',
            backgroundColor: Colors.red,
          ),
        ],
      ),
    );
  }

  /// 构建控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required bool isEnabled,
    required bool canInteract,
    required VoidCallback? onPressed,
    required String tooltip,
    Color? backgroundColor,
    double size = 24,
    String? badge,
  }) {
    // 确定按钮颜色
    Color buttonColor;
    if (backgroundColor != null) {
      buttonColor = backgroundColor;
    } else if (!canInteract) {
      buttonColor = Colors.grey[600]!;
    } else if (isEnabled) {
      buttonColor = Colors.green;
    } else {
      buttonColor = Colors.grey[700]!;
    }

    return Tooltip(
      message: tooltip,
      child: Stack(
        children: [
          // 主按钮
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: buttonColor,
              shape: BoxShape.circle,
              border: canInteract 
                  ? null 
                  : Border.all(color: Colors.grey, width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: canInteract ? onPressed : null,
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: size,
                ),
              ),
            ),
          ),
          
          // 徽章
          if (badge != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          
          // 不可用状态覆盖层
          if (!canInteract && onPressed == null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}