import 'package:flutter/foundation.dart';

import 'group_session.dart';
import 'ptt_queue.dart';
import 'ptt_service_notice.dart';

abstract class RealtimePttService {
  GroupSession get session;
  ValueListenable<PttQueueState> get stateListenable;
  PttQueueState get state;

  /// Errors and moderation denials from the remote gateway (empty for in-memory demo).
  Stream<PttServiceNotice> get uxNoticeStream;

  QueueEnqueueResult requestTalk(String userId);
  bool releaseTalk(String userId);
  bool forceNextSpeaker({required String actorId});
  bool setMuted({
    required String actorId,
    required String targetUserId,
    required bool muted,
  });
  bool removeMember({
    required String actorId,
    required String targetUserId,
  });
  bool renameMember({
    required String actorId,
    required String targetUserId,
    required String newDisplayName,
  });
  bool addMember({
    required String actorId,
    required GroupMember member,
  });
}

class InMemoryRealtimePttService implements RealtimePttService {
  @override
  final GroupSession session;
  final PttQueueController _controller;
  final ValueNotifier<PttQueueState> _state;

  InMemoryRealtimePttService({
    required this.session,
    required GroupMember owner,
  })  : _controller = PttQueueController(owner: owner),
        _state = ValueNotifier<PttQueueState>(
          PttQueueController(owner: owner).state,
        ) {
    _state.value = _controller.state;
  }

  @override
  Stream<PttServiceNotice> get uxNoticeStream => Stream<PttServiceNotice>.empty();

  factory InMemoryRealtimePttService.bootstrapDemo({
    required String ownerUserId,
  }) {
    final svc = InMemoryRealtimePttService(
      session: GroupSession(
        sessionId: 'demo_session_1',
        name: 'Dag Ekibi',
        ownerUserId: ownerUserId,
        maxMembers: 30,
        createdAt: DateTime.now(),
      ),
      owner: GroupMember(
        userId: ownerUserId,
        displayName: 'Lider',
        role: GroupRole.owner,
      ),
    );
    for (final m in const [
      GroupMember(userId: 'u2', displayName: 'Ekip-2', role: GroupRole.member),
      GroupMember(userId: 'u3', displayName: 'Ekip-3', role: GroupRole.member),
      GroupMember(userId: 'u4', displayName: 'Ekip-4', role: GroupRole.member),
    ]) {
      svc.addMember(actorId: ownerUserId, member: m);
    }
    return svc;
  }

  @override
  ValueListenable<PttQueueState> get stateListenable => _state;

  @override
  PttQueueState get state => _state.value;

  void _sync() {
    _state.value = _controller.state;
  }

  @override
  QueueEnqueueResult requestTalk(String userId) {
    final r = _controller.requestTalk(userId);
    _sync();
    return r;
  }

  @override
  bool releaseTalk(String userId) {
    final ok = _controller.releaseTalk(userId);
    _sync();
    return ok;
  }

  @override
  bool forceNextSpeaker({required String actorId}) {
    final ok = _controller.forceNextSpeaker(actorId: actorId);
    _sync();
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
    _sync();
    return ok;
  }

  @override
  bool removeMember({
    required String actorId,
    required String targetUserId,
  }) {
    final ok = _controller.removeMember(
      actorId: actorId,
      targetUserId: targetUserId,
    );
    _sync();
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
    _sync();
    return ok;
  }

  @override
  bool addMember({
    required String actorId,
    required GroupMember member,
  }) {
    final ok = _controller.addMember(
      actorId: actorId,
      member: member,
      maxMembers: session.maxMembers,
    );
    _sync();
    return ok;
  }
}
