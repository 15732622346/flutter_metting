import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../models/participant_model.dart';
import '../services/livekit_service.dart';
import '../services/api_service.dart';

class MeetingProvider extends ChangeNotifier {
  final LiveKitService _liveKitService = LiveKitService();
  final ApiService _apiService = ApiService();
  
  // 会议状态
  Room? _currentRoom;
  User? _currentUser;
  bool _isInMeeting = false;
  bool _isConnecting = false;
  bool _isCameraEnabled = false;
  bool _isMicrophoneEnabled = false;
  bool _isSpeakerEnabled = true;
  String? _lastError;
  
  // 参与者相关
  List<RemoteParticipant> _remoteParticipants = [];
  List<ParticipantInfo> _participantInfoList = [];
  
  // LiveKit相关
  ConnectionState _connectionState = ConnectionState.disconnected;
  VideoTrack? _localVideoTrack;
  AudioTrack? _localAudioTrack;
  
  // 聊天消息
  final List<ChatMessage> _chatMessages = [];
  
  // 事件订阅
  StreamSubscription<RoomEvent>? _eventSubscription;
  StreamSubscription<List<RemoteParticipant>>? _participantsSubscription;
  StreamSubscription<ConnectionState>? _connectionSubscription;
  StreamSubscription<VideoTrack?>? _localVideoSubscription;
  StreamSubscription<AudioTrack?>? _localAudioSubscription;
  
  // Getters
  Room? get currentRoom => _currentRoom;
  User? get currentUser => _currentUser;
  bool get isInMeeting => _isInMeeting;
  bool get isConnecting => _isConnecting;
  bool get isCameraEnabled => _isCameraEnabled;
  bool get isMicrophoneEnabled => _isMicrophoneEnabled;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  String? get lastError => _lastError;
  List<RemoteParticipant> get remoteParticipants => _remoteParticipants;
  List<ParticipantInfo> get participantInfoList => _participantInfoList;
  ConnectionState get connectionState => _connectionState;
  VideoTrack? get localVideoTrack => _localVideoTrack;
  AudioTrack? get localAudioTrack => _localAudioTrack;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  
  // 房间和用户信息
  String get roomName => _currentRoom?.roomName ?? '';
  String get roomId => _currentRoom?.roomId ?? '';
  int get userRole => _liveKitService.userRole;
  bool get isHost => userRole >= 2;
  bool get isAdmin => userRole >= 3;
  bool get canPublish => isHost && !_liveKitService.isDisabled;
  
  // 参与者统计
  int get totalParticipants => _remoteParticipants.length + (_isInMeeting ? 1 : 0);
  String get participantsSummary => '共${totalParticipants}人参会';
  
  /// 加入会议
  Future<bool> joinMeeting({
    required String token,
    required String wsUrl,
    required Room room,
    required User user,
  }) async {
    try {
      _setConnecting(true);
      _lastError = null;
      
      print('🚀 开始加入会议: ${room.roomName}');
      
      _currentRoom = room;
      _currentUser = user;
      
      // 订阅LiveKit服务事件
      _subscribeToLiveKitEvents();
      
      // 连接到LiveKit房间
      await _liveKitService.connectToRoom(wsUrl, token);
      
      _isInMeeting = true;
      _connectionState = ConnectionState.connected;
      
      // 获取参与者信息
      await _loadParticipants();
      
      print('✅ 成功加入会议: ${room.roomName}');
      notifyListeners();
      
      return true;
    } catch (e) {
      _lastError = e.toString();
      print('❌ 加入会议失败: $e');
      await _cleanup();
      return false;
    } finally {
      _setConnecting(false);
    }
  }
  
  /// 离开会议
  Future<void> leaveMeeting() async {
    try {
      print('🚪 开始离开会议...');
      
      await _liveKitService.disconnect();
      await _cleanup();
      
      print('✅ 已离开会议');
    } catch (e) {
      print('⚠️ 离开会议时出错: $e');
      await _cleanup();
    }
  }
  
  /// 订阅LiveKit服务事件
  void _subscribeToLiveKitEvents() {
    // 房间事件
    _eventSubscription = _liveKitService.events.listen((event) {
      _handleRoomEvent(event);
    });
    
    // 参与者变化
    _participantsSubscription = _liveKitService.participants.listen((participants) {
      _remoteParticipants = participants;
      notifyListeners();
    });
    
    // 连接状态变化
    _connectionSubscription = _liveKitService.connectionState.listen((state) {
      _connectionState = state;
      notifyListeners();
    });
    
    // 本地视频轨道变化
    _localVideoSubscription = _liveKitService.localVideoTrack.listen((track) {
      _localVideoTrack = track;
      _isCameraEnabled = track != null;
      notifyListeners();
    });
    
    // 本地音频轨道变化
    _localAudioSubscription = _liveKitService.localAudioTrack.listen((track) {
      _localAudioTrack = track;
      _isMicrophoneEnabled = track != null;
      notifyListeners();
    });
  }
  
  /// 处理房间事件
  void _handleRoomEvent(RoomEvent event) {
    print('📡 收到房间事件: ${event.type}');
    
    switch (event.type) {
      case RoomEventType.participantConnected:
        print('👤 新参与者加入');
        break;
        
      case RoomEventType.participantDisconnected:
        print('👤 参与者离开');
        break;
        
      case RoomEventType.chatMessage:
        final message = event.data['message'] as String?;
        final sent = event.data['sent'] as bool? ?? false;
        if (message != null) {
          _addChatMessage(ChatMessage(
            message: message,
            sender: sent ? '我' : '其他用户',
            timestamp: DateTime.now(),
            isMe: sent,
          ));
        }
        break;
        
      case RoomEventType.connectionError:
        _lastError = event.data['error'] as String?;
        break;
        
      default:
        break;
    }
    
    notifyListeners();
  }
  
  /// 控制摄像头
  Future<void> toggleCamera() async {
    try {
      await _liveKitService.enableCamera(!_isCameraEnabled);
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }
  
  /// 控制麦克风
  Future<void> toggleMicrophone() async {
    try {
      await _liveKitService.enableMicrophone(!_isMicrophoneEnabled);
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }
  
  /// 控制扬声器
  Future<void> toggleSpeaker() async {
    try {
      _isSpeakerEnabled = !_isSpeakerEnabled;
      await _liveKitService.enableSpeaker(_isSpeakerEnabled);
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }
  
  /// 切换摄像头
  Future<void> switchCamera() async {
    try {
      await _liveKitService.switchCamera();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }
  
  /// 发送聊天消息
  Future<void> sendChatMessage(String message) async {
    try {
      await _liveKitService.sendChatMessage(message);
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }
  
  /// 申请上麦
  Future<bool> applyForMic() async {
    try {
      if (_currentUser == null || _currentRoom == null) return false;
      
      final success = await _apiService.applyForMic(
        _currentRoom!.roomId,
        _currentUser!.id,
      );
      
      if (success) {
        print('✅ 申请上麦成功');
        await _loadParticipants(); // 刷新参与者状态
      } else {
        _lastError = '申请上麦失败';
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  /// 加载参与者信息
  Future<void> _loadParticipants() async {
    try {
      if (_currentRoom?.roomId != null) {
        _participantInfoList = await _apiService.getParticipants(_currentRoom!.roomId);
        notifyListeners();
      }
    } catch (e) {
      print('⚠️ 加载参与者信息失败: $e');
    }
  }
  
  /// 添加聊天消息
  void _addChatMessage(ChatMessage message) {
    _chatMessages.add(message);
    // 限制消息数量，避免内存占用过大
    if (_chatMessages.length > 100) {
      _chatMessages.removeRange(0, _chatMessages.length - 100);
    }
  }
  
  /// 设置连接状态
  void _setConnecting(bool connecting) {
    if (_isConnecting != connecting) {
      _isConnecting = connecting;
      notifyListeners();
    }
  }
  
  /// 清理资源
  Future<void> _cleanup() async {
    // 取消事件订阅
    await _eventSubscription?.cancel();
    await _participantsSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _localVideoSubscription?.cancel();
    await _localAudioSubscription?.cancel();
    
    // 重置状态
    _currentRoom = null;
    _currentUser = null;
    _isInMeeting = false;
    _isConnecting = false;
    _isCameraEnabled = false;
    _isMicrophoneEnabled = false;
    _connectionState = ConnectionState.disconnected;
    _remoteParticipants.clear();
    _participantInfoList.clear();
    _chatMessages.clear();
    _localVideoTrack = null;
    _localAudioTrack = null;
    _lastError = null;
    
    notifyListeners();
  }
  
  /// 清除错误信息
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _cleanup();
    _liveKitService.dispose();
    super.dispose();
  }
}

/// 聊天消息模型
class ChatMessage {
  final String message;
  final String sender;
  final DateTime timestamp;
  final bool isMe;
  
  ChatMessage({
    required this.message,
    required this.sender,
    required this.timestamp,
    required this.isMe,
  });
  
  String get timeString {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}