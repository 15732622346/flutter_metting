class LoginResponse {
  final bool success;
  final String? token;           // LiveKit Token
  final String? wsUrl;          // LiveKit WebSocket URL
  final String? roomName;       // 房间名称
  final int? userRoles;         // 用户在此房间的权限
  final int? id;                // 用户ID
  final int? userId;            // 用户ID (备用字段)
  final String? nickname;       // 用户昵称
  final String? message;        // 成功消息
  final String? error;          // 错误消息
  
  const LoginResponse({
    required this.success,
    this.token,
    this.wsUrl,
    this.roomName,
    this.userRoles,
    this.id,
    this.userId,
    this.nickname,
    this.message,
    this.error,
  });
  
  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    success: json['success'] ?? false,
    token: json['token'],
    wsUrl: json['ws_url'],
    roomName: json['room_name'],
    userRoles: json['user_roles'],
    id: json['id'],
    userId: json['user_id'],
    nickname: json['nickname'],
    message: json['message'],
    error: json['error'],
  );
  
  Map<String, dynamic> toJson() => {
    'success': success,
    'token': token,
    'ws_url': wsUrl,
    'room_name': roomName,
    'user_roles': userRoles,
    'id': id,
    'user_id': userId,
    'nickname': nickname,
    'message': message,
    'error': error,
  };
  Map<String, dynamic> toPublicJson() => {
        'success': success,
        'ws_url': wsUrl,
        'room_name': roomName,
        'user_roles': userRoles,
        'id': id,
        'user_id': userId,
        'nickname': nickname,
        'message': message,
      }..removeWhere((key, value) => value == null);

  
  /// 获取有效的用户ID
  int? get validUserId => id ?? userId;
  
  /// 是否登录成功且有Token
  bool get isValidLogin => success && token?.isNotEmpty == true;
  
  /// 获取显示用的错误信息
  String get displayError => error ?? '未知错误';
  
  /// 获取显示用的成功信息
  String get displayMessage => message ?? '登录成功';
}