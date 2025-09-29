import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'video_track_widget.dart';

/// 参与者网格组件
class ParticipantGrid extends StatelessWidget {
  const ParticipantGrid({
    super.key,
    required this.participants,
    this.localVideoTrack,
    required this.localUserName,
    this.onParticipantTap,
  });

  final List<lk.RemoteParticipant> participants;
  final lk.VideoTrack? localVideoTrack;
  final String localUserName;
  final ValueChanged<lk.RemoteParticipant>? onParticipantTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _buildLocalParticipant(),
          const SizedBox(height: 8),
          ...participants.map(_buildRemoteParticipant),
          if (participants.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '等待其他人加入..',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocalParticipant() {
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 120,
        child: Stack(
          children: [
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
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    _buildStatusIndicators(
                      hasVideo: localVideoTrack != null,
                      hasAudio: true,
                      isMuted: false,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
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

  Widget _buildRemoteParticipant(lk.RemoteParticipant participant) {
    final videoTrack = _firstRemoteVideoTrack(participant);
    final audioTrack = _firstRemoteAudioTrack(participant);

    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onParticipantTap == null
            ? null
            : () => onParticipantTap!.call(participant),
        child: SizedBox(
          height: 120,
          child: Stack(
            children: [
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
                _buildParticipantPlaceholder(
                  _getDisplayName(participant),
                  false,
                ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      _buildStatusIndicators(
                        hasVideo: videoTrack != null && !videoTrack.muted,
                        hasAudio: audioTrack != null,
                        isMuted: audioTrack?.muted ?? true,
                      ),
                      const SizedBox(width: 4),
                      _buildConnectionIndicator(participant.connectionQuality),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  lk.VideoTrack? _firstRemoteVideoTrack(lk.RemoteParticipant participant) {
    for (final publication in participant.videoTracks) {
      final track = publication.track;
      if (track != null && publication.subscribed) {
        return track;
      }
    }
    return null;
  }

  lk.AudioTrack? _firstRemoteAudioTrack(lk.RemoteParticipant participant) {
    for (final publication in participant.audioTracks) {
      final track = publication.track;
      if (track != null && publication.subscribed) {
        return track;
      }
    }
    return null;
  }

  Widget _buildParticipantPlaceholder(String name, bool isLocal) {
    final display = name.isNotEmpty ? name[0].toUpperCase() : '?';
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
                display,
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

  Widget _buildStatusIndicators({
    required bool hasVideo,
    required bool hasAudio,
    required bool isMuted,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasVideo ? Icons.videocam : Icons.videocam_off,
          color: hasVideo ? Colors.green : Colors.red,
          size: 14,
        ),
        const SizedBox(width: 4),
        Icon(
          hasAudio && !isMuted ? Icons.mic : Icons.mic_off,
          color: hasAudio && !isMuted ? Colors.green : Colors.red,
          size: 14,
        ),
      ],
    );
  }

  Widget _buildConnectionIndicator(lk.ConnectionQuality quality) {
    Color color;
    IconData icon;
    switch (quality) {
      case lk.ConnectionQuality.excellent:
        color = Colors.green;
        icon = Icons.signal_cellular_4_bar;
        break;
      case lk.ConnectionQuality.good:
        color = Colors.orange;
        icon = Icons.signal_cellular_alt;
        break;
      case lk.ConnectionQuality.poor:
        color = Colors.redAccent;
        icon = Icons.network_check;
        break;
      case lk.ConnectionQuality.unknown:
      default:
        color = Colors.grey;
        icon = Icons.signal_cellular_null;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: 12),
    );
  }

  String _getDisplayName(lk.RemoteParticipant participant) {
    final name = participant.name.trim();
    if (name.isNotEmpty) {
      return name;
    }
    if (participant.identity.isNotEmpty) {
      return participant.identity;
    }
    return '匿名用户';
  }
}
