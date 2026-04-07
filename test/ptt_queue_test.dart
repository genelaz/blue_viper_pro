import 'package:blue_viper_pro/core/realtime/ptt_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GroupMember owner() => const GroupMember(
        userId: 'u1',
        displayName: 'Owner',
        role: GroupRole.owner,
      );

  test('only owner/admin can add or remove members', () {
    final c = PttQueueController(owner: owner());
    final ok2 = c.addMember(
      actorId: 'u1',
      member: const GroupMember(
        userId: 'u2',
        displayName: 'M2',
        role: GroupRole.member,
      ),
      maxMembers: 10,
    );
    expect(ok2, isTrue);

    final fail3 = c.addMember(
      actorId: 'u2',
      member: const GroupMember(
        userId: 'u3',
        displayName: 'M3',
        role: GroupRole.member,
      ),
      maxMembers: 10,
    );
    expect(fail3, isFalse);

    final removeByMember = c.removeMember(actorId: 'u2', targetUserId: 'u1');
    expect(removeByMember, isFalse);
  });

  test('talk queue is single-speaker and FIFO', () {
    final c = PttQueueController(owner: owner());
    c.addMember(
      actorId: 'u1',
      member: const GroupMember(
        userId: 'u2',
        displayName: 'M2',
        role: GroupRole.member,
      ),
      maxMembers: 10,
    );
    c.addMember(
      actorId: 'u1',
      member: const GroupMember(
        userId: 'u3',
        displayName: 'M3',
        role: GroupRole.member,
      ),
      maxMembers: 10,
    );

    expect(c.requestTalk('u2'), QueueEnqueueResult.accepted);
    expect(c.state.currentSpeakerId, 'u2');

    expect(c.requestTalk('u3'), QueueEnqueueResult.accepted);
    expect(c.state.currentSpeakerId, 'u2');
    expect(c.state.queuedUserIds, ['u3']);

    expect(c.releaseTalk('u2'), isTrue);
    expect(c.state.currentSpeakerId, 'u3');
  });

  test('muted user cannot enter queue and is dropped if muted', () {
    final c = PttQueueController(owner: owner());
    c.addMember(
      actorId: 'u1',
      member: const GroupMember(
        userId: 'u2',
        displayName: 'M2',
        role: GroupRole.member,
      ),
      maxMembers: 10,
    );
    c.addMember(
      actorId: 'u1',
      member: const GroupMember(
        userId: 'u3',
        displayName: 'M3',
        role: GroupRole.member,
      ),
      maxMembers: 10,
    );

    expect(c.requestTalk('u2'), QueueEnqueueResult.accepted);
    expect(c.requestTalk('u3'), QueueEnqueueResult.accepted);
    expect(c.state.currentSpeakerId, 'u2');
    expect(c.state.queuedUserIds, ['u3']);

    expect(
      c.setMuted(actorId: 'u1', targetUserId: 'u3', muted: true),
      isTrue,
    );
    expect(c.state.queuedUserIds, isEmpty);
    expect(c.requestTalk('u3'), QueueEnqueueResult.muted);
  });

  test('max member capacity is enforced', () {
    final c = PttQueueController(owner: owner());
    expect(
      c.addMember(
        actorId: 'u1',
        member: const GroupMember(
          userId: 'u2',
          displayName: 'M2',
          role: GroupRole.member,
        ),
        maxMembers: 2,
      ),
      isTrue,
    );
    expect(
      c.addMember(
        actorId: 'u1',
        member: const GroupMember(
          userId: 'u3',
          displayName: 'M3',
          role: GroupRole.member,
        ),
        maxMembers: 2,
      ),
      isFalse,
    );
  });

  test('owner can rename others and member can rename self only', () {
    final c = PttQueueController(owner: owner());
    c.addMember(
      actorId: 'u1',
      member: const GroupMember(
        userId: 'u2',
        displayName: 'M2',
        role: GroupRole.member,
      ),
      maxMembers: 10,
    );
    expect(
      c.renameMember(
        actorId: 'u1',
        targetUserId: 'u2',
        newDisplayName: 'Yeni-2',
      ),
      isTrue,
    );
    expect(c.state.members['u2']?.displayName, 'Yeni-2');
    expect(
      c.renameMember(
        actorId: 'u2',
        targetUserId: 'u2',
        newDisplayName: 'Ben-2',
      ),
      isTrue,
    );
    expect(c.state.members['u2']?.displayName, 'Ben-2');
    c.addMember(
      actorId: 'u1',
      member: const GroupMember(
        userId: 'u3',
        displayName: 'M3',
        role: GroupRole.member,
      ),
      maxMembers: 10,
    );
    expect(
      c.renameMember(
        actorId: 'u2',
        targetUserId: 'u3',
        newDisplayName: 'HACK',
      ),
      isFalse,
    );
    expect(c.state.members['u3']?.displayName, 'M3');
  });
}
