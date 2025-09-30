class RoomJoinData {
  const RoomJoinData({
    required this.roomId,
    required this.roomName,
    required this.inviteCode,
    required this.participantName,
    required this.liveKitToken,
    required this.wsUrl,
    this.roomInfo,
    this.userInfo,
    this.userRoles,
    this.userId,
    this.userJwtToken,
  });

  final String roomId;
  final String roomName;
  final String inviteCode;
  final String participantName;
  final String liveKitToken;
  final String wsUrl;
  final Map<String, dynamic>? roomInfo;
  final Map<String, dynamic>? userInfo;
  final int? userRoles;
  final int? userId;
  final String? userJwtToken;

  RoomJoinData copyWith({
    String? roomId,
    String? roomName,
    String? inviteCode,
    String? participantName,
    String? liveKitToken,
    String? wsUrl,
    Map<String, dynamic>? roomInfo,
    Map<String, dynamic>? userInfo,
    int? userRoles,
    int? userId,
    String? userJwtToken,
  }) {
    return RoomJoinData(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      inviteCode: inviteCode ?? this.inviteCode,
      participantName: participantName ?? this.participantName,
      liveKitToken: liveKitToken ?? this.liveKitToken,
      wsUrl: wsUrl ?? this.wsUrl,
      roomInfo: roomInfo ?? this.roomInfo,
      userInfo: userInfo ?? this.userInfo,
      userRoles: userRoles ?? this.userRoles,
      userId: userId ?? this.userId,
      userJwtToken: userJwtToken ?? this.userJwtToken,
    );
  }
}
