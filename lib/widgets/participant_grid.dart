import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'video_track_widget.dart';

/// 参与者网格组件
class ParticipantGrid extends StatelessWidget {
  final List<RemoteParticipant> participants;
  final VideoTrack? localVideoTrack;
  final String localUserName;
  final Function(RemoteParticipant)? onParticipantTap;

  const ParticipantGrid({
    super.key,
    required this.participants,
    this.localVideoTrack,
    required this.localUserName,
    this.onParticipantTap,
  });

  @override
  Widget build(BuildContext context) {
    // 包含本地用户的所有参与者
    final totalParticipants = participants.length + 1;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // 本地用户
          _buildLocalParticipant(),
          
          const SizedBox(height: 8),
          
          // 远程参与者
          ...participants.map((participant) => 
            _buildRemoteParticipant(participant)
          ),
          
          // 如果没有其他参与者，显示提示
          if (participants.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '等待其他人加入...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建本地参与者项
  Widget _buildLocalParticipant() {
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 120,
        child: Stack(
          children: [
            // 本地视频
            if (localVideoTrack != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: VideoTrackWidget(
                  videoTrack: localVideoTrack!,
                  fit: BoxFit.cover,
                  mirror: true,
                  showName: false,
                ),
              )
            else
              _buildParticipantPlaceholder(localUserName, true),
            
            // 用户信息
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$localUserName (我)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 本地状态指示器
                    _buildStatusIndicators(
                      hasVideo: localVideoTrack != null,
                      hasAudio: true, // 这里可以根据实际音频状态设置
                      isMuted: false,
                    ),
                  ],
                ),
              ),
            ),
            
            // "我"标签
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '我',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建远程参与者项
  Widget _buildRemoteParticipant(RemoteParticipant participant) {
    final videoTrack = participant.videoTrackPublications.isNotEmpty
        ? participant.videoTrackPublications.first.track as VideoTrack?
        : null;
    
    final audioTrack = participant.audioTrackPublications.isNotEmpty
        ? participant.audioTrackPublications.first.track as AudioTrack?
        : null;

    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => onParticipantTap?.call(participant),
        child: Container(
          height: 120,
          child: Stack(
            children: [
              // 参与者视频
              if (videoTrack != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: VideoTrackWidget(
                    videoTrack: videoTrack,
                    fit: BoxFit.cover,
                    showName: false,
                  ),
                )
              else
                _buildParticipantPlaceholder(participant.identity, false),
              
              // 参与者信息
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getDisplayName(participant),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 状态指示器
                      _buildStatusIndicators(
                        hasVideo: videoTrack != null && videoTrack.enabled,
                        hasAudio: audioTrack != null && audioTrack.enabled,
                        isMuted: audioTrack?.muted ?? true,
                      ),
                    ],
                  ),
                ),
              ),
              
              // 连接状态指示器
              Positioned(
                top: 8,
                right: 8,
                child: _buildConnectionIndicator(participant.connectionQuality),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建参与者占位符
  Widget _buildParticipantPlaceholder(String name, bool isLocal) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isLocal ? Colors.blue : Colors.grey[600],
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建状态指示器
  Widget _buildStatusIndicators({
    required bool hasVideo,
    required bool hasAudio,
    required bool isMuted,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 视频状态
        Icon(
          hasVideo ? Icons.videocam : Icons.videocam_off,
          color: hasVideo ? Colors.green : Colors.red,
          size: 14,
        ),
        const SizedBox(width: 4),
        
        // 音频状态
        Icon(
          hasAudio && !isMuted ? Icons.mic : Icons.mic_off,
          color: hasAudio && !isMuted ? Colors.green : Colors.red,
          size: 14,
        ),
      ],
    );
  }

  /// 构建连接质量指示器
  Widget _buildConnectionIndicator(ConnectionQuality quality) {
    Color color;
    IconData icon;
    
    switch (quality) {
      case ConnectionQuality.excellent:
        color = Colors.green;
        icon = Icons.signal_cellular_4_bar;
        break;
      case ConnectionQuality.good:
        color = Colors.yellow;
        icon = Icons.signal_cellular_3_bar;
        break;
      case ConnectionQuality.poor:
        color = Colors.orange;
        icon = Icons.signal_cellular_2_bar;
        break;
      case ConnectionQuality.lost:
        color = Colors.red;
        icon = Icons.signal_cellular_0_bar;
        break;
      default:
        color = Colors.grey;
        icon = Icons.signal_cellular_null;
    }
    
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        color: color,
        size: 12,
      ),
    );
  }

  /// 获取参与者显示名称
  String _getDisplayName(RemoteParticipant participant) {
    // 可以从metadata或attributes中获取更友好的显示名称
    String name = participant.name.isNotEmpty 
        ? participant.name 
        : participant.identity;
    
    // 检查是否有角色信息
    final metadata = participant.metadata;
    if (metadata.isNotEmpty) {
      try {
        // 这里可以解析metadata中的角色信息
        // final data = jsonDecode(metadata);
        // final role = data['role_name'];
        // if (role == 'host') name += ' (主持人)';
        // if (role == 'admin') name += ' (管理员)';
      } catch (e) {
        // 忽略解析错误
      }
    }
    
    return name;
  }
}