import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class LiveKitService {
  Room? _room;
  LocalParticipant? _localParticipant;
  
  // 事件流控制器
  final _eventController = StreamController<RoomEvent>.broadcast();
  final _participantsController = StreamController<List<RemoteParticipant>>.broadcast();
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _localVideoController = StreamController<VideoTrack?>.broadcast();
  final _localAudioController = StreamController<AudioTrack?>.broadcast();
  
  // 状态变量
  bool _isCameraEnabled = false;
  bool _isMicrophoneEnabled = false;
  bool _isSpeakerEnabled = true;
  int _userRole = 1; // 1=普通用户, 2=主持人, 3=管理员
  bool _isDisabled = false;
  
  // Getters
  Room? get room => _room;
  LocalParticipant? get localParticipant => _localParticipant;
  bool get isConnected => _room?.connectionState == ConnectionState.connected;
  bool get isCameraEnabled => _isCameraEnabled;
  bool get isMicrophoneEnabled => _isMicrophoneEnabled;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  int get userRole => _userRole;
  bool get isDisabled => _isDisabled;
  
  // 流
  Stream<RoomEvent> get events => _eventController.stream;
  Stream<List<RemoteParticipant>> get participants => _participantsController.stream;
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  Stream<VideoTrack?> get localVideoTrack => _localVideoController.stream;
  Stream<AudioTrack?> get localAudioTrack => _localAudioController.stream;
  
  // 单例模式
  static final LiveKitService _instance = LiveKitService._internal();
  factory LiveKitService() => _instance;
  
  LiveKitService._internal();
  
  /// 连接到房间 - 使用从PHP获取的Token和WebSocket URL
  Future<void> connectToRoom(String wsUrl, String token) async {
    try {
      // 确保先断开之前的连接
      await disconnect();
      
      print('🚀 开始连接LiveKit房间...');
      print('🔗 WebSocket URL: $wsUrl');
      print('🎫 Token: ${token.substring(0, 50)}...');
      
      _room = Room(
        roomOptions: const RoomOptions(
          // 自适应流 - 根据网络状况调整视频质量
          adaptiveStream: true,
          // 动态投射 - 优化带宽使用
          dynacast: true,
          // 默认视频发布选项
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: true,
            videoCodec: VideoCodec.h264,
          ),
          // 默认音频发布选项
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'microphone',
          ),
          // 默认屏幕共享选项
          defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
            useiOSBroadcastExtension: true,
          ),
        ),
      );
      
      // 监听房间事件
      _setupRoomListeners();
      
      // 连接到房间
      await _room!.connect(wsUrl, token);
      _localParticipant = _room!.localParticipant;
      
      print('✅ LiveKit房间连接成功');
      
      // 解析Token中的权限信息并设置初始状态
      await _parseTokenAndSetupPermissions(token);
      
      // 广播连接状态变化
      _connectionStateController.add(ConnectionState.connected);
      
      // 触发连接成功事件
      _eventController.add(RoomEvent(
        type: RoomEventType.connected,
        data: {'roomName': _room!.name},
      ));
      
    } catch (e) {
      print('❌ 连接LiveKit房间失败: $e');
      _connectionStateController.add(ConnectionState.disconnected);
      _eventController.add(RoomEvent(
        type: RoomEventType.connectionError,
        data: {'error': e.toString()},
      ));
      throw Exception('连接房间失败: $e');
    }
  }
  
  /// 设置房间事件监听器
  void _setupRoomListeners() {
    if (_room == null) return;
    
    _room!.addListener(() {
      final room = _room!;
      
      // 更新参与者列表
      _participantsController.add(room.remoteParticipants.values.toList());
      
      // 更新连接状态
      _connectionStateController.add(room.connectionState);
      
      // 广播房间状态变化事件
      _eventController.add(RoomEvent(
        type: RoomEventType.roomUpdate,
        data: {
          'participantCount': room.remoteParticipants.length + 1, // +1 for local
          'connectionState': room.connectionState.toString(),
        },
      ));
    });
    
    // 监听参与者连接
    _room!.createListener()
      ..on<ParticipantConnectedEvent>((event) {
        print('👤 参与者加入: ${event.participant.identity}');
        _eventController.add(RoomEvent(
          type: RoomEventType.participantConnected,
          data: {'participant': event.participant},
        ));
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        print('👤 参与者离开: ${event.participant.identity}');
        _eventController.add(RoomEvent(
          type: RoomEventType.participantDisconnected,
          data: {'participant': event.participant},
        ));
      })
      // 监听轨道发布
      ..on<TrackPublishedEvent>((event) {
        print('📡 轨道发布: ${event.track.name}');
        _eventController.add(RoomEvent(
          type: RoomEventType.trackPublished,
          data: {'track': event.track, 'participant': event.participant},
        ));
      })
      ..on<TrackUnpublishedEvent>((event) {
        print('📡 轨道取消发布: ${event.track.name}');
        _eventController.add(RoomEvent(
          type: RoomEventType.trackUnpublished,
          data: {'track': event.track, 'participant': event.participant},
        ));
      })
      // 监听数据接收（聊天消息等）
      ..on<DataReceivedEvent>((event) {
        print('💬 接收到数据: ${String.fromCharCodes(event.data)}');
        _eventController.add(RoomEvent(
          type: RoomEventType.dataReceived,
          data: {
            'data': event.data,
            'participant': event.participant,
            'topic': event.topic,
          },
        ));
      });
  }
  
  /// 解析Token中的权限信息并设置初始权限
  Future<void> _parseTokenAndSetupPermissions(String token) async {
    try {
      // 获取本地参与者的metadata
      final metadata = _localParticipant?.metadata;
      if (metadata?.isNotEmpty == true) {
        final metaData = jsonDecode(metadata!);
        _userRole = metaData['role'] as int? ?? 1;
        final autoOnMic = metaData['auto_on_mic'] as bool? ?? false;
        
        print('🔐 解析Token权限信息:');
        print('   - 用户角色: $_userRole');
        print('   - 自动上麦: $autoOnMic');
        
        // 管理员和主持人自动开启权限（匹配PHP逻辑）
        if (_userRole >= 2 && autoOnMic && !_isDisabled) {
          print('🎤 自动开启麦克风和摄像头');
          await enableMicrophone(true);
          await enableCamera(true);
        }
      }
      
      // 检查参与者attributes中的禁用状态
      final attributes = _localParticipant?.attributes;
      if (attributes?.containsKey('isDisabledUser') == true) {
        _isDisabled = attributes!['isDisabledUser'] == 'true';
        if (_isDisabled) {
          print('⚠️ 用户已被禁用，限制权限');
        }
      }
      
    } catch (e) {
      print('⚠️ 解析Token权限信息失败: $e');
      // 使用默认权限
      _userRole = 1;
      _isDisabled = false;
    }
  }
  
  /// 控制麦克风 - 对应PHP的权限控制
  Future<void> enableMicrophone(bool enable) async {
    if (_room?.localParticipant == null) return;
    
    try {
      // 检查权限
      if (enable && _isDisabled) {
        throw Exception('用户已被禁用，无法开启麦克风');
      }
      
      if (enable && _userRole < 2) {
        // 普通用户需要申请上麦（这里可以添加申请逻辑）
        print('⚠️ 普通用户需要申请上麦权限');
        return;
      }
      
      await _room!.localParticipant!.setMicrophoneEnabled(enable);
      _isMicrophoneEnabled = enable;
      
      // 更新本地音频轨道流
      final audioTrack = _room!.localParticipant!.audioTrackPublications.isNotEmpty
          ? _room!.localParticipant!.audioTrackPublications.first.track as AudioTrack?
          : null;
      _localAudioController.add(audioTrack);
      
      print('🎤 麦克风${enable ? "开启" : "关闭"}');
      
      _eventController.add(RoomEvent(
        type: RoomEventType.microphoneToggled,
        data: {'enabled': enable},
      ));
    } catch (e) {
      print('❌ 控制麦克风失败: $e');
      throw e;
    }
  }
  
  /// 控制摄像头 - 对应PHP的权限控制  
  Future<void> enableCamera(bool enable) async {
    if (_room?.localParticipant == null) return;
    
    try {
      // 检查权限
      if (enable && _isDisabled) {
        throw Exception('用户已被禁用，无法开启摄像头');
      }
      
      if (enable && _userRole < 2) {
        // 普通用户需要申请上麦（这里可以添加申请逻辑）
        print('⚠️ 普通用户需要申请上麦权限');
        return;
      }
      
      await _room!.localParticipant!.setCameraEnabled(enable);
      _isCameraEnabled = enable;
      
      // 更新本地视频轨道流
      final videoTrack = _room!.localParticipant!.videoTrackPublications.isNotEmpty
          ? _room!.localParticipant!.videoTrackPublications.first.track as VideoTrack?
          : null;
      _localVideoController.add(videoTrack);
      
      print('📹 摄像头${enable ? "开启" : "关闭"}');
      
      _eventController.add(RoomEvent(
        type: RoomEventType.cameraToggled,
        data: {'enabled': enable},
      ));
    } catch (e) {
      print('❌ 控制摄像头失败: $e');
      throw e;
    }
  }
  
  /// 控制扬声器
  Future<void> enableSpeaker(bool enable) async {
    try {
      // 这里可以添加扬声器控制逻辑
      _isSpeakerEnabled = enable;
      print('🔊 扬声器${enable ? "开启" : "关闭"}');
      
      _eventController.add(RoomEvent(
        type: RoomEventType.speakerToggled,
        data: {'enabled': enable},
      ));
    } catch (e) {
      print('❌ 控制扬声器失败: $e');
    }
  }
  
  /// 切换摄像头（前/后摄像头）
  Future<void> switchCamera() async {
    try {
      final videoTrack = _room?.localParticipant?.videoTrackPublications.first.track;
      if (videoTrack is LocalVideoTrack) {
        await videoTrack.setCameraPosition(
          videoTrack.currentOptions.cameraPosition == CameraPosition.front
              ? CameraPosition.back
              : CameraPosition.front,
        );
        print('📹 摄像头已切换');
        
        _eventController.add(RoomEvent(
          type: RoomEventType.cameraSwitched,
          data: {'position': videoTrack.currentOptions.cameraPosition.toString()},
        ));
      }
    } catch (e) {
      print('❌ 切换摄像头失败: $e');
    }
  }
  
  /// 发送聊天消息
  Future<void> sendChatMessage(String message) async {
    try {
      if (_room?.localParticipant == null) return;
      
      final data = utf8.encode(jsonEncode({
        'type': 'chat',
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'sender': _localParticipant!.identity,
      }));
      
      await _room!.localParticipant!.publishData(data, topic: 'chat');
      
      _eventController.add(RoomEvent(
        type: RoomEventType.chatMessage,
        data: {'message': message, 'sent': true},
      ));
    } catch (e) {
      print('❌ 发送聊天消息失败: $e');
    }
  }
  
  /// 离开房间
  Future<void> disconnect() async {
    try {
      if (_room != null) {
        await _room!.disconnect();
        await _room!.dispose();
        _room = null;
        _localParticipant = null;
      }
      
      // 重置状态
      _isCameraEnabled = false;
      _isMicrophoneEnabled = false;
      _userRole = 1;
      _isDisabled = false;
      
      // 更新流
      _connectionStateController.add(ConnectionState.disconnected);
      _participantsController.add([]);
      _localVideoController.add(null);
      _localAudioController.add(null);
      
      _eventController.add(RoomEvent(
        type: RoomEventType.disconnected,
        data: {},
      ));
      
      print('✅ 已断开LiveKit连接');
    } catch (e) {
      print('⚠️ 断开连接时出错: $e');
    }
  }
  
  /// 释放资源
  void dispose() {
    disconnect();
    _eventController.close();
    _participantsController.close();
    _connectionStateController.close();
    _localVideoController.close();
    _localAudioController.close();
  }
}

/// 房间事件类型
enum RoomEventType {
  connected,
  disconnected,
  connectionError,
  roomUpdate,
  participantConnected,
  participantDisconnected,
  trackPublished,
  trackUnpublished,
  dataReceived,
  chatMessage,
  microphoneToggled,
  cameraToggled,
  speakerToggled,
  cameraSwitched,
}

/// 房间事件
class RoomEvent {
  final RoomEventType type;
  final Map<String, dynamic> data;
  
  RoomEvent({required this.type, required this.data});
  
  @override
  String toString() => 'RoomEvent(type: $type, data: $data)';
}