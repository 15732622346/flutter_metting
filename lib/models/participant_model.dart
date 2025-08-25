class ParticipantInfo {
  final String roomId;
  final int userId;
  final String username;
  final String identity;         // LiveKit identity
  final DateTime joinTime;
  final String status;          // active, inactive, left
  final int applicationStatus;  // 0=未上麦, 1=已上麦, 2=申请中
  final bool isMicrophone;      // 麦克风状态
  final bool isCamera;          // 摄像头状态
  
  const ParticipantInfo({
    required this.roomId,
    required this.userId,
    required this.username,
    required this.identity,
    required this.joinTime,
    required this.status,
    required this.applicationStatus,
    required this.isMicrophone,
    required this.isCamera,
  });
  
  factory ParticipantInfo.fromJson(Map<String, dynamic> json) => ParticipantInfo(
    roomId: json['room_id'],
    userId: json['user_id'],
    username: json['username'],
    identity: json['identity'],
    joinTime: DateTime.parse(json['join_time']),
    status: json['status'],
    applicationStatus: json['application_status'] ?? 0,
    isMicrophone: (json['is_microphone'] ?? 0) == 1,
    isCamera: (json['is_camera'] ?? 0) == 1,
  );
  
  Map<String, dynamic> toJson() => {
    'room_id': roomId,
    'user_id': userId,
    'username': username,
    'identity': identity,
    'join_time': joinTime.toIso8601String(),
    'status': status,
    'application_status': applicationStatus,
    'is_microphone': isMicrophone ? 1 : 0,
    'is_camera': isCamera ? 1 : 0,
  };
  
  // 状态判断
  bool get isActive => status == 'active';
  bool get isOnMic => applicationStatus == 1;
  bool get isApplyingMic => applicationStatus == 2;
  bool get isOffMic => applicationStatus == 0;
  
  String get micStatusText {
    switch (applicationStatus) {
      case 1: return '已上麦';
      case 2: return '申请中';
      case 0: return '未上麦';
      default: return '未知';
    }
  }
  
  String get mediaStatusText {
    final mic = isMicrophone ? '🎤' : '🔇';
    final camera = isCamera ? '📹' : '📷';
    return '$mic $camera';
  }
}

/// 房间参与者统计信息
class RoomParticipantStats {
  final int totalCount;       // 总参与者数
  final int activeCount;      // 活跃参与者数
  final int onMicCount;       // 已上麦人数
  final int applyingCount;    // 申请上麦人数
  
  const RoomParticipantStats({
    required this.totalCount,
    required this.activeCount,
    required this.onMicCount,
    required this.applyingCount,
  });
  
  factory RoomParticipantStats.fromParticipants(List<ParticipantInfo> participants) {
    return RoomParticipantStats(
      totalCount: participants.length,
      activeCount: participants.where((p) => p.isActive).length,
      onMicCount: participants.where((p) => p.isOnMic).length,
      applyingCount: participants.where((p) => p.isApplyingMic).length,
    );
  }
  
  String get summaryText => '总计$totalCount人，已上麦$onMicCount人';
}