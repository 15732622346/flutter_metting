class User {
  final int id;
  final String userName;
  final int userRoles;        // 1=普通会员, 2=主持人, 3=管理员
  final String? userNickname;
  final int userStatus;       // 1=正常, 0=禁用
  final String? userIp;
  final int isOnline;         // 0=离线, 1=在线
  final String? currentRoom;
  final DateTime? lastLoginTime;
  
  const User({
    required this.id,
    required this.userName,
    required this.userRoles,
    this.userNickname,
    required this.userStatus,
    this.userIp,
    required this.isOnline,
    this.currentRoom,
    this.lastLoginTime,
  });
  
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] ?? json['user_id'],
    userName: json['user_name'],
    userRoles: json['user_roles'],
    userNickname: json['user_nickname'] ?? json['nickname'],
    userStatus: json['user_status'] ?? 1,
    userIp: json['user_ip'],
    isOnline: json['is_online'] ?? 0,
    currentRoom: json['current_room'],
    lastLoginTime: json['user_lastlogintime'] != null 
        ? DateTime.tryParse(json['user_lastlogintime']) 
        : null,
  );
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_name': userName,
    'user_roles': userRoles,
    'user_nickname': userNickname,
    'user_status': userStatus,
    'user_ip': userIp,
    'is_online': isOnline,
    'current_room': currentRoom,
  };
  
  // 权限判断方法
  bool get isAdmin => userRoles >= 3;
  bool get isHost => userRoles >= 2; 
  bool get isMember => userRoles >= 1;
  bool get isEnabled => userStatus == 1;
  bool get isOnlineStatus => isOnline == 1;
  
  String get displayName => userNickname?.isNotEmpty == true ? userNickname! : userName;
  
  String get roleDisplayName {
    switch (userRoles) {
      case 3: return '管理员';
      case 2: return '主持人';
      case 1: return '普通会员';
      default: return '未知';
    }
  }
  
  User copyWith({
    int? id,
    String? userName,
    int? userRoles,
    String? userNickname,
    int? userStatus,
    String? userIp,
    int? isOnline,
    String? currentRoom,
    DateTime? lastLoginTime,
  }) => User(
    id: id ?? this.id,
    userName: userName ?? this.userName,
    userRoles: userRoles ?? this.userRoles,
    userNickname: userNickname ?? this.userNickname,
    userStatus: userStatus ?? this.userStatus,
    userIp: userIp ?? this.userIp,
    isOnline: isOnline ?? this.isOnline,
    currentRoom: currentRoom ?? this.currentRoom,
    lastLoginTime: lastLoginTime ?? this.lastLoginTime,
  );
}