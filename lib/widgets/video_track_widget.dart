import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

/// 视频轨道显示组件
class VideoTrackWidget extends StatefulWidget {
  const VideoTrackWidget({
    super.key,
    required this.videoTrack,
    this.fit = BoxFit.contain,
    this.participantName,
    this.mirror = false,
    this.showName = true,
    this.onTap,
  });

  final lk.VideoTrack videoTrack;
  final BoxFit fit;
  final String? participantName;
  final bool mirror;
  final bool showName;
  final VoidCallback? onTap;

  @override
  State<VideoTrackWidget> createState() => _VideoTrackWidgetState();
}

class _VideoTrackWidgetState extends State<VideoTrackWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Transform(
              alignment: Alignment.center,
              transform: widget.mirror
                  ? (Matrix4.identity()..scale(-1.0, 1.0))
                  : Matrix4.identity(),
              child: lk.VideoTrackRenderer(
                widget.videoTrack,
                fit: _mapFit(widget.fit),
              ),
            ),
          ),
          if (widget.showName && widget.participantName != null)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.participantName!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: _buildVideoStatusIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoStatusIndicator() {
    final isEnabled = !widget.videoTrack.muted;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isEnabled ? Icons.videocam : Icons.videocam_off,
        color: isEnabled ? Colors.green : Colors.red,
        size: 16,
      ),
    );
  }

  rtc.RTCVideoViewObjectFit _mapFit(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover:
        return rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
      case BoxFit.fill:
      case BoxFit.fitHeight:
      case BoxFit.fitWidth:
        return rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
      case BoxFit.contain:
      case BoxFit.scaleDown:
      case BoxFit.none:
        return rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
    }
  }
}
