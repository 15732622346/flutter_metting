class Room {
  final String roomId;
  final String roomName;
  final int userId;           // 房间创建者ID
  final int? hostUserId;      // 房间指定主持人ID
  final int roomState;        // 1=正常, 0=结束
  final int audioState;       // 1=开启, 0=关闭
  final int cameraState;      // 1=开启, 0=关闭
  final int chatState;        // 1=开启, 0=关闭
  final String inviteCode;    // 邀请码
  final int maxMicSlots;      // 最大麦位数
  final String? videoUrl;     // 录制视频URL
  final DateTime createTime;
  final DateTime? updateTime;
  final String? creatorName;  // 创建者名称
  final String? hostName;     // 主持人名称
  final String? hostNickname; // 主持人昵称
  
  const Room({
    required this.roomId,
    required this.roomName,
    required this.userId,
    this.hostUserId,
    required this.roomState,
    required this.audioState,
    required this.cameraState,
    required this.chatState,
    required this.inviteCode,
    required this.maxMicSlots,
    this.videoUrl,
    required this.createTime,
    this.updateTime,
    this.creatorName,
    this.hostName,
    this.hostNickname,
  });
  
  factory Room.fromJson(Map<String, dynamic> json) => Room(
    roomId: json['room_id'],
    roomName: json['room_name'],
    userId: json['user_id'],
    hostUserId: json['host_user_id'],
    roomState: json['room_state'],
    audioState: json['audio_state'],
    cameraState: json['camera_state'], 
    chatState: json['chat_state'],
    inviteCode: json['invite_code'] ?? '1315',
    maxMicSlots: json['max_mic_slots'] ?? 8,
    videoUrl: json['video_url'],
    createTime: DateTime.parse(json['create_time']),
    updateTime: json['updatetime'] != null 
        ? DateTime.tryParse(json['updatetime'])
        : null,
    creatorName: json['creator_name'],
    hostName: json['host_name'],
    hostNickname: json['host_nickname'],
  );
  
  Map<String, dynamic> toJson() => {
    'room_id': roomId,
    'room_name': roomName,
    'user_id': userId,
    'host_user_id': hostUserId,
    'room_state': roomState,
    'audio_state': audioState,
    'camera_state': cameraState,
    'chat_state': chatState,
    'invite_code': inviteCode,
    'max_mic_slots': maxMicSlots,
    'video_url': videoUrl,
    'create_time': createTime.toIso8601String(),
    'updatetime': updateTime?.toIso8601String(),
    'creator_name': creatorName,
    'host_name': hostName,
    'host_nickname': hostNickname,
  };
  
  // 状态判断方法
  bool get isActive => roomState == 1;
  bool get isEnded => roomState == 0;
  bool get audioEnabled => audioState == 1;
  bool get cameraEnabled => cameraState == 1;
  bool get chatEnabled => chatState == 1;
  
  String get statusText => isActive ? '进行中' : '已结束';
  String get hostDisplayName => hostNickname?.isNotEmpty == true 
      ? hostNickname! 
      : (hostName?.isNotEmpty == true ? hostName! : '未指定');
  
  /// 判断用户在此房间的权限
  int getUserRoleInRoom(int userId, int globalRole) {
    // 管理员在所有房间都有管理权限
    if (globalRole >= 3) return 3;
    
    // 被指定为此房间主持人
    if (hostUserId == userId) return 2;
    
    // 其他情况都是普通会员
    return 1;
  }
  
  /// 是否可以加入房间
  bool canJoin(String code) {
    return isActive && inviteCode == code;
  }
  
  Room copyWith({
    String? roomId,
    String? roomName,
    int? userId,
    int? hostUserId,
    int? roomState,
    int? audioState,
    int? cameraState,
    int? chatState,
    String? inviteCode,
    int? maxMicSlots,
    String? videoUrl,
    DateTime? createTime,
    DateTime? updateTime,
    String? creatorName,
    String? hostName,
    String? hostNickname,
  }) => Room(
    roomId: roomId ?? this.roomId,
    roomName: roomName ?? this.roomName,
    userId: userId ?? this.userId,
    hostUserId: hostUserId ?? this.hostUserId,
    roomState: roomState ?? this.roomState,
    audioState: audioState ?? this.audioState,
    cameraState: cameraState ?? this.cameraState,
    chatState: chatState ?? this.chatState,
    inviteCode: inviteCode ?? this.inviteCode,
    maxMicSlots: maxMicSlots ?? this.maxMicSlots,
    videoUrl: videoUrl ?? this.videoUrl,
    createTime: createTime ?? this.createTime,
    updateTime: updateTime ?? this.updateTime,
    creatorName: creatorName ?? this.creatorName,
    hostName: hostName ?? this.hostName,
    hostNickname: hostNickname ?? this.hostNickname,
  );
}