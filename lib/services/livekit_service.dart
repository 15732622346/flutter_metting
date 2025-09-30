import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

class LiveKitService {
  LiveKitService._internal();

  static final LiveKitService _instance = LiveKitService._internal();

  factory LiveKitService() => _instance;

  lk.Room? _room;
  lk.LocalParticipant? _localParticipant;
  lk.EventsListener<lk.RoomEvent>? _roomEvents;
  VoidCallback? _roomChangeListener;

  final _eventController = StreamController<LiveKitEvent>.broadcast();
  final _participantsController =
      StreamController<List<lk.RemoteParticipant>>.broadcast();
  final _connectionStateController =
      StreamController<lk.ConnectionState>.broadcast();
  final _localVideoController = StreamController<lk.VideoTrack?>.broadcast();

  bool _isSpeakerEnabled = true;

  lk.Room? get room => _room;

  lk.LocalParticipant? get localParticipant => _localParticipant;

  bool get isSpeakerEnabled => _isSpeakerEnabled;

  Stream<LiveKitEvent> get events => _eventController.stream;

  Stream<List<lk.RemoteParticipant>> get participants =>
      _participantsController.stream;

  Stream<lk.ConnectionState> get connectionState =>
      _connectionStateController.stream;

  Stream<lk.VideoTrack?> get localVideoTrack => _localVideoController.stream;

  Future<void> connectToRoom(String wsUrl, String token) async {
    await disconnect();

    _room = lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );

    _setupRoomListeners();

    await _room!.connect(wsUrl, token);
    _localParticipant = _room!.localParticipant;

    _notifyConnectionState();
    _emitParticipantsUpdate();
    _updateLocalVideoTrack();

    _eventController.add(
      LiveKitEvent(
        type: LiveKitEventType.connected,
        data: {'roomName': _room!.name},
      ),
    );
  }

  void _setupRoomListeners() {
    final room = _room!;
    _roomChangeListener ??= () {
      _notifyConnectionState();
      _emitParticipantsUpdate();
      _eventController.add(
        LiveKitEvent(
          type: LiveKitEventType.roomUpdate,
          data: {
            'participantCount': room.participants.length + 1,
            'connectionState': room.connectionState,
          },
        ),
      );
    };
    room.addListener(_roomChangeListener!);

    _roomEvents = room.createListener()
      ..on<lk.ParticipantConnectedEvent>((event) {
        _emitParticipantsUpdate();
        _eventController.add(
          LiveKitEvent(
            type: LiveKitEventType.participantConnected,
            data: {'participant': event.participant},
          ),
        );
      })
      ..on<lk.ParticipantDisconnectedEvent>((event) {
        _emitParticipantsUpdate();
        _eventController.add(
          LiveKitEvent(
            type: LiveKitEventType.participantDisconnected,
            data: {'participant': event.participant},
          ),
        );
      })
      ..on<lk.ParticipantMetadataUpdatedEvent>((event) {
        _eventController.add(
          LiveKitEvent(
            type: LiveKitEventType.metadataUpdated,
            data: {'participant': event.participant},
          ),
        );
      })
      ..on<lk.TrackPublishedEvent>((event) {
        _eventController.add(
          LiveKitEvent(
            type: LiveKitEventType.trackPublished,
            data: {
              'participant': event.participant,
              'publication': event.publication,
            },
          ),
        );
      })
      ..on<lk.TrackUnpublishedEvent>((event) {
        _eventController.add(
          LiveKitEvent(
            type: LiveKitEventType.trackUnpublished,
            data: {
              'participant': event.participant,
              'publication': event.publication,
            },
          ),
        );
      })
      ..on<lk.TrackSubscribedEvent>((event) {
        _eventController.add(
          LiveKitEvent(
            type: LiveKitEventType.trackSubscribed,
            data: {
              'participant': event.participant,
              'publication': event.publication,
              'track': event.track,
            },
          ),
        );
      })
      ..on<lk.TrackUnsubscribedEvent>((event) {
        _eventController.add(
          LiveKitEvent(
            type: LiveKitEventType.trackUnsubscribed,
            data: {
              'participant': event.participant,
              'publication': event.publication,
              'track': event.track,
            },
          ),
        );
      })
      ..on<lk.DataReceivedEvent>((event) {
        _eventController.add(
          LiveKitEvent(
            type: LiveKitEventType.dataReceived,
            data: {
              'data': event.data,
              'participant': event.participant,
              'topic': event.topic,
            },
          ),
        );
      })
      ..on<lk.RoomDisconnectedEvent>((event) {
        _eventController.add(
          LiveKitEvent(
            type: LiveKitEventType.disconnected,
            data: {'reason': event.reason},
          ),
        );
        _notifyConnectionState();
      })
      ..on<lk.RoomReconnectingEvent>((_) {
        _notifyConnectionState();
      })
      ..on<lk.RoomReconnectedEvent>((_) {
        _notifyConnectionState();
      });
  }

  void _notifyConnectionState() {
    final state = _room?.connectionState ?? lk.ConnectionState.disconnected;
    _connectionStateController.add(state);
  }

  void _emitParticipantsUpdate() {
    final current =
        _room?.participants.values.toList() ?? <lk.RemoteParticipant>[];
    _participantsController.add(current);
  }

  void _updateLocalVideoTrack() {
    lk.VideoTrack? videoTrack;
    final local = _room?.localParticipant;
    if (local != null) {
      for (final publication in local.videoTracks) {
        final track = publication.track;
        if (track != null) {
          videoTrack = track;
          break;
        }
      }
    }
    _localVideoController.add(videoTrack);
  }

  Future<void> enableSpeaker(bool enable) async {
    _isSpeakerEnabled = enable;
    _eventController.add(
      LiveKitEvent(
        type: LiveKitEventType.speakerToggled,
        data: {'enabled': enable},
      ),
    );
  }

  Future<void> sendChatMessage(String message) async {
    final participant = _room?.localParticipant;
    if (participant == null) {
      return;
    }

    final payload = utf8.encode(jsonEncode({
      'type': 'chat',
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sender': participant.identity,
    }));

    await participant.publishData(payload, topic: 'chat');
    _eventController.add(
      LiveKitEvent(
        type: LiveKitEventType.chatMessage,
        data: {
          'message': message,
          'sent': true,
        },
      ),
    );
  }

  Future<void> disconnect() async {
    try {
      _roomEvents?.dispose();
      _roomEvents = null;

      if (_room != null && _roomChangeListener != null) {
        _room!.removeListener(_roomChangeListener!);
      }

      if (_room != null) {
        await _room!.disconnect();
        await _room!.dispose();
      }
    } finally {
      _room = null;
      _localParticipant = null;
      _roomChangeListener = null;
      _notifyConnectionState();
      _participantsController.add(<lk.RemoteParticipant>[]);
      _localVideoController.add(null);
    }
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _participantsController.close();
    _connectionStateController.close();
    _localVideoController.close();
  }
}

class LiveKitEvent {
  LiveKitEvent({required this.type, required this.data});

  final LiveKitEventType type;
  final Map<String, dynamic> data;

  @override
  String toString() => 'LiveKitEvent(type: $type, data: $data)';
}

enum LiveKitEventType {
  connected,
  disconnected,
  connectionError,
  roomUpdate,
  participantConnected,
  participantDisconnected,
  metadataUpdated,
  trackPublished,
  trackUnpublished,
  trackSubscribed,
  trackUnsubscribed,
  dataReceived,
  chatMessage,
  microphoneToggled,
  cameraToggled,
  speakerToggled,
  cameraSwitched,
}
