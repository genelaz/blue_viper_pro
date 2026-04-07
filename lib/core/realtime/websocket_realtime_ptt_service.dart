import 'dart:async';

import 'package:flutter/foundation.dart';

import 'group_session.dart';
import 'ptt_queue.dart';
import 'ptt_service_notice.dart';
import 'realtime_ptt_events.dart';
import 'realtime_ptt_service.dart';
import 'websocket_transport_client.dart';

/// Uzak PTT: [WebSocketTransportClient] üzerinden JSON olayları yayınlar / dinler;
/// kuyruk ve yeniden deneme mantığı yerelde tutulur.
class WebSocketRealtimePttService implements RealtimePttService {
  @override
  final GroupSession session;
  final PttQueueController _controller;
  final ValueNotifier<PttQueueState> _state;
  final WebSocketTransportClient? _transport;
  final Set<String> _appliedRemoteEventKeys = <String>{};
  final String _selfUserId;
  int _nextSeq = 1;
  final Duration _ackTimeout = const Duration(seconds: 2);
  final int _maxRetries = 2;
  final Map<int, _PendingCommand> _pendingBySeq = <int, _PendingCommand>{};
  final StreamController<PttServiceNotice> _uxNoticeController =
      StreamController<PttServiceNotice>.broadcast();

  WebSocketRealtimePttService({
    required this.session,
    required GroupMember owner,
    Uri? websocketUri,
    WebSocketTransportClient? transportClient,
  })  : _controller = PttQueueController(owner: owner),
        _state = ValueNotifier<PttQueueState>(
          PttQueueController(owner: owner).state,
        ),
        _selfUserId = owner.userId,
        _transport = transportClient ??
            (websocketUri == null
                ? null
                : WebSocketTransportClient(
                    uri: websocketUri,
                    onConnected: null,
                  )) {
    _state.value = _controller.state;
    _transport?.messages.listen((m) {
      final incomingSessionId = m['sessionId'] as String?;
      if (incomingSessionId != null && incomingSessionId != session.sessionId) {
        return;
      }
      final event = RealtimePttEvent.fromMap(m);
      onRemoteEvent(event);
    });
    _transport?.connect();
    _sendJoinAndSnapshotRequest();
  }

  void _sendJoinAndSnapshotRequest() {
    _publishEvent(
      RealtimePttEvent(
        type: RealtimePttEventType.join,
        actorUserId: _selfUserId,
        sentAt: DateTime.now(),
      ),
    );
    _publishEvent(
      RealtimePttEvent(
        type: RealtimePttEventType.stateSnapshotRequest,
        actorUserId: _selfUserId,
        sentAt: DateTime.now(),
      ),
    );
  }

  @override
  ValueListenable<PttQueueState> get stateListenable => _state;

  @override
  PttQueueState get state => _state.value;

  @override
  Stream<PttServiceNotice> get uxNoticeStream => _uxNoticeController.stream;

  void _emitServerError(RealtimePttEvent event) {
    if (_uxNoticeController.isClosed) return;
    _uxNoticeController.add(
      PttServiceNotice(
        code: event.code,
        message: event.message,
        refSeq: event.refSeq,
      ),
    );
  }

  void _requestStateReconcile() {
    if (_transport == null) return;
    _publishEvent(
      RealtimePttEvent(
        type: RealtimePttEventType.stateSnapshotRequest,
        actorUserId: _selfUserId,
        sentAt: DateTime.now(),
      ),
    );
  }

  void _syncAndPublish(RealtimePttEvent event) {
    _state.value = _controller.state;
    _publishEvent(event);
  }

  void _publishEvent(RealtimePttEvent event) {
    final seq = event.seq ?? _nextSeq++;
    final outbound = RealtimePttEvent(
      type: event.type,
      actorUserId: event.actorUserId,
      targetUserId: event.targetUserId,
      muted: event.muted,
      seq: seq,
      refSeq: event.refSeq,
      code: event.code,
      message: event.message,
      payload: event.payload,
      sentAt: event.sentAt,
    );
    final payload = <String, dynamic>{
      'sessionId': session.sessionId,
      ...outbound.toMap(),
    };
    _transport?.send(payload);
    _trackPendingAck(outbound);
  }

  void _trackPendingAck(RealtimePttEvent event) {
    final seq = event.seq;
    if (seq == null) return;
    if (event.type == RealtimePttEventType.ack ||
        event.type == RealtimePttEventType.error) {
      return;
    }
    // Handshake and snapshot pull are not ACK-gated on the client; avoid retry storms.
    if (event.type == RealtimePttEventType.join ||
        event.type == RealtimePttEventType.stateSnapshotRequest) {
      return;
    }
    _pendingBySeq[seq]?.timer.cancel();
    _pendingBySeq[seq] = _PendingCommand(
      event: event,
      retryCount: 0,
      timer: Timer(_ackTimeout, () => _retryPending(seq)),
    );
  }

  void _retryPending(int seq) {
    final p = _pendingBySeq[seq];
    if (p == null) return;
    if (p.retryCount >= _maxRetries) {
      _pendingBySeq.remove(seq);
      return;
    }
    _transport?.send({
      'sessionId': session.sessionId,
      ...p.event.toMap(),
    });
    final next = p.retryCount + 1;
    _pendingBySeq[seq] = _PendingCommand(
      event: p.event,
      retryCount: next,
      timer: Timer(_ackTimeout, () => _retryPending(seq)),
    );
  }

  void _resolvePending(int seq) {
    final p = _pendingBySeq.remove(seq);
    p?.timer.cancel();
  }

  void onRemoteEvent(RealtimePttEvent event) {
    final key = [
      event.type.name,
      event.actorUserId,
      event.targetUserId ?? '',
      event.muted?.toString() ?? '',
      event.sentAt.toIso8601String(),
    ].join('|');
    if (!_appliedRemoteEventKeys.add(key)) {
      return;
    }
    if (_appliedRemoteEventKeys.length > 512) {
      _appliedRemoteEventKeys.remove(_appliedRemoteEventKeys.first);
    }
    switch (event.type) {
      case RealtimePttEventType.join:
        final id = event.targetUserId;
        if (id != null && !_controller.state.members.containsKey(id)) {
          _controller.addMember(
            actorId: event.actorUserId,
            member: GroupMember(
              userId: id,
              displayName: id,
              role: GroupRole.member,
            ),
            maxMembers: session.maxMembers,
          );
        }
        break;
      case RealtimePttEventType.leave:
      case RealtimePttEventType.removeMember:
        final id = event.targetUserId;
        if (id != null) {
          _controller.removeMember(actorId: event.actorUserId, targetUserId: id);
        }
        break;
      case RealtimePttEventType.requestTalk:
        _controller.requestTalk(event.actorUserId);
        break;
      case RealtimePttEventType.stateSnapshotRequest:
        // Client-initiated command, should not mutate local state.
        break;
      case RealtimePttEventType.ack:
        final ref = event.refSeq;
        if (ref != null) _resolvePending(ref);
        break;
      case RealtimePttEventType.error:
        final ref = event.refSeq;
        if (ref != null) _resolvePending(ref);
        _emitServerError(event);
        _requestStateReconcile();
        break;
      case RealtimePttEventType.releaseTalk:
        _controller.releaseTalk(event.actorUserId);
        break;
      case RealtimePttEventType.forceNext:
        _controller.forceNextSpeaker(actorId: event.actorUserId);
        break;
      case RealtimePttEventType.mute:
        final id = event.targetUserId;
        final muted = event.muted;
        if (id != null && muted != null) {
          _controller.setMuted(
            actorId: event.actorUserId,
            targetUserId: id,
            muted: muted,
          );
        }
        break;
      case RealtimePttEventType.renameMember:
        final id = event.targetUserId;
        final newName = event.payload?['displayName'] as String?;
        if (id != null && newName != null) {
          _controller.renameMember(
            actorId: event.actorUserId,
            targetUserId: id,
            newDisplayName: newName,
          );
        }
        break;
      case RealtimePttEventType.stateSnapshot:
        final p = event.payload;
        if (p != null) {
          final rawMembers = p['members'];
          final members = <GroupMember>[];
          if (rawMembers is List) {
            for (final e in rawMembers) {
              if (e is! Map) continue;
              final m = Map<String, dynamic>.from(e);
              final roleRaw = (m['role'] as String?) ?? GroupRole.member.name;
              final role = GroupRole.values.firstWhere(
                (r) => r.name == roleRaw,
                orElse: () => GroupRole.member,
              );
              final uid = m['userId'] as String?;
              if (uid == null) continue;
              members.add(
                GroupMember(
                  userId: uid,
                  displayName: (m['displayName'] as String?) ?? uid,
                  role: role,
                  muted: (m['muted'] as bool?) ?? false,
                ),
              );
            }
          }
          if (members.isNotEmpty) {
            _controller.applySnapshot(
              PttQueueSnapshot(
                currentSpeakerId: p['currentSpeakerId'] as String?,
                queuedUserIds: (p['queuedUserIds'] is List)
                    ? List<String>.from(p['queuedUserIds'] as List)
                    : const [],
                members: members,
              ),
            );
          }
        }
        break;
    }
    _state.value = _controller.state;
  }

  Future<void> dispose() async {
    for (final p in _pendingBySeq.values) {
      p.timer.cancel();
    }
    _pendingBySeq.clear();
    await _uxNoticeController.close();
    await _transport?.dispose();
  }

  @override
  QueueEnqueueResult requestTalk(String userId) {
    final r = _controller.requestTalk(userId);
    if (r == QueueEnqueueResult.accepted) {
      _syncAndPublish(
        RealtimePttEvent(
          type: RealtimePttEventType.requestTalk,
          actorUserId: userId,
          sentAt: DateTime.now(),
        ),
      );
    } else {
      _state.value = _controller.state;
    }
    return r;
  }

  @override
  bool releaseTalk(String userId) {
    final ok = _controller.releaseTalk(userId);
    if (ok) {
      _syncAndPublish(
        RealtimePttEvent(
          type: RealtimePttEventType.releaseTalk,
          actorUserId: userId,
          sentAt: DateTime.now(),
        ),
      );
    } else {
      _state.value = _controller.state;
    }
    return ok;
  }

  @override
  bool forceNextSpeaker({required String actorId}) {
    final ok = _controller.forceNextSpeaker(actorId: actorId);
    if (ok) {
      _syncAndPublish(
        RealtimePttEvent(
          type: RealtimePttEventType.forceNext,
          actorUserId: actorId,
          sentAt: DateTime.now(),
        ),
      );
    } else {
      _state.value = _controller.state;
    }
    return ok;
  }

  @override
  bool setMuted({
    required String actorId,
    required String targetUserId,
    required bool muted,
  }) {
    final ok = _controller.setMuted(
      actorId: actorId,
      targetUserId: targetUserId,
      muted: muted,
    );
    if (ok) {
      _syncAndPublish(
        RealtimePttEvent(
          type: RealtimePttEventType.mute,
          actorUserId: actorId,
          targetUserId: targetUserId,
          muted: muted,
          sentAt: DateTime.now(),
        ),
      );
    } else {
      _state.value = _controller.state;
    }
    return ok;
  }

  @override
  bool removeMember({required String actorId, required String targetUserId}) {
    final ok = _controller.removeMember(
      actorId: actorId,
      targetUserId: targetUserId,
    );
    if (ok) {
      _syncAndPublish(
        RealtimePttEvent(
          type: RealtimePttEventType.removeMember,
          actorUserId: actorId,
          targetUserId: targetUserId,
          sentAt: DateTime.now(),
        ),
      );
    } else {
      _state.value = _controller.state;
    }
    return ok;
  }

  @override
  bool renameMember({
    required String actorId,
    required String targetUserId,
    required String newDisplayName,
  }) {
    final ok = _controller.renameMember(
      actorId: actorId,
      targetUserId: targetUserId,
      newDisplayName: newDisplayName,
    );
    if (ok) {
      _syncAndPublish(
        RealtimePttEvent(
          type: RealtimePttEventType.renameMember,
          actorUserId: actorId,
          targetUserId: targetUserId,
          payload: {'displayName': newDisplayName},
          sentAt: DateTime.now(),
        ),
      );
    } else {
      _state.value = _controller.state;
    }
    return ok;
  }

  @override
  bool addMember({required String actorId, required GroupMember member}) {
    final ok = _controller.addMember(
      actorId: actorId,
      member: member,
      maxMembers: session.maxMembers,
    );
    if (ok) {
      _syncAndPublish(
        RealtimePttEvent(
          type: RealtimePttEventType.join,
          actorUserId: actorId,
          targetUserId: member.userId,
          sentAt: DateTime.now(),
        ),
      );
    } else {
      _state.value = _controller.state;
    }
    return ok;
  }
}

class _PendingCommand {
  final RealtimePttEvent event;
  final int retryCount;
  final Timer timer;

  const _PendingCommand({
    required this.event,
    required this.retryCount,
    required this.timer,
  });
}
