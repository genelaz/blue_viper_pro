import 'package:blue_viper_pro/core/realtime/ptt_queue.dart';
import 'package:blue_viper_pro/core/realtime/realtime_ptt_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-memory realtime service enforces maxMembers and state sync', () {
    final svc = InMemoryRealtimePttService.bootstrapDemo(ownerUserId: 'u1');
    expect(svc.session.maxMembers, 30);
    expect(svc.state.members.length, 4);

    final ok = svc.addMember(
      actorId: 'u1',
      member: const GroupMember(
        userId: 'u5',
        displayName: 'Ekip-5',
        role: GroupRole.member,
      ),
    );
    expect(ok, isTrue);
    expect(svc.state.members.containsKey('u5'), isTrue);
  });

  test('in-memory realtime service propagates queue transitions', () {
    final svc = InMemoryRealtimePttService.bootstrapDemo(ownerUserId: 'u1');
    expect(svc.requestTalk('u2'), QueueEnqueueResult.accepted);
    expect(svc.state.currentSpeakerId, 'u2');
    expect(svc.requestTalk('u3'), QueueEnqueueResult.accepted);
    expect(svc.state.queuedUserIds, ['u3']);
    expect(svc.releaseTalk('u2'), isTrue);
    expect(svc.state.currentSpeakerId, 'u3');
  });
}
