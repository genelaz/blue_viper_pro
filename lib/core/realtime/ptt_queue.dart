import 'dart:collection';

enum GroupRole { owner, admin, member }

enum QueueEnqueueResult {
  accepted,
  alreadySpeaker,
  alreadyQueued,
  muted,
  forbidden,
}

class GroupMember {
  final String userId;
  final String displayName;
  final GroupRole role;
  final bool muted;

  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.role,
    this.muted = false,
  });

  GroupMember copyWith({
    String? userId,
    String? displayName,
    GroupRole? role,
    bool? muted,
  }) {
    return GroupMember(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      muted: muted ?? this.muted,
    );
  }
}

class PttQueueState {
  final String? currentSpeakerId;
  final List<String> queuedUserIds;
  final Map<String, GroupMember> members;

  const PttQueueState({
    required this.currentSpeakerId,
    required this.queuedUserIds,
    required this.members,
  });
}

class PttQueueSnapshot {
  final String? currentSpeakerId;
  final List<String> queuedUserIds;
  final List<GroupMember> members;

  const PttQueueSnapshot({
    required this.currentSpeakerId,
    required this.queuedUserIds,
    required this.members,
  });
}

class PttQueueController {
  final Map<String, GroupMember> _members = <String, GroupMember>{};
  final Queue<String> _queue = Queue<String>();
  String? _currentSpeakerId;

  PttQueueController({required GroupMember owner}) {
    _members[owner.userId] = owner.role == GroupRole.owner
        ? owner
        : owner.copyWith(role: GroupRole.owner);
  }

  PttQueueState get state => PttQueueState(
        currentSpeakerId: _currentSpeakerId,
        queuedUserIds: _queue.toList(growable: false),
        members: Map.unmodifiable(_members),
      );

  bool _hasAdminRights(String actorId) {
    final role = _members[actorId]?.role;
    return role == GroupRole.owner || role == GroupRole.admin;
  }

  bool addMember({
    required String actorId,
    required GroupMember member,
    required int maxMembers,
  }) {
    if (!_hasAdminRights(actorId)) return false;
    if (_members.length >= maxMembers) return false;
    if (_members.containsKey(member.userId)) return false;
    _members[member.userId] = member;
    return true;
  }

  bool removeMember({required String actorId, required String targetUserId}) {
    if (!_hasAdminRights(actorId)) return false;
    final target = _members[targetUserId];
    if (target == null) return false;
    if (target.role == GroupRole.owner) return false;
    _members.remove(targetUserId);
    _queue.removeWhere((id) => id == targetUserId);
    if (_currentSpeakerId == targetUserId) {
      _currentSpeakerId = null;
      _promoteNext();
    }
    return true;
  }

  bool setMuted({
    required String actorId,
    required String targetUserId,
    required bool muted,
  }) {
    if (!_hasAdminRights(actorId)) return false;
    final target = _members[targetUserId];
    if (target == null) return false;
    _members[targetUserId] = target.copyWith(muted: muted);
    if (muted) {
      _queue.removeWhere((id) => id == targetUserId);
      if (_currentSpeakerId == targetUserId) {
        _currentSpeakerId = null;
        _promoteNext();
      }
    }
    return true;
  }

  bool renameMember({
    required String actorId,
    required String targetUserId,
    required String newDisplayName,
  }) {
    final clean = newDisplayName.trim();
    if (clean.isEmpty) return false;
    final isSelf = actorId == targetUserId;
    if (!isSelf && !_hasAdminRights(actorId)) return false;
    final target = _members[targetUserId];
    if (target == null) return false;
    _members[targetUserId] = target.copyWith(displayName: clean);
    return true;
  }

  QueueEnqueueResult requestTalk(String userId) {
    final m = _members[userId];
    if (m == null) return QueueEnqueueResult.forbidden;
    if (m.muted) return QueueEnqueueResult.muted;
    if (_currentSpeakerId == userId) return QueueEnqueueResult.alreadySpeaker;
    if (_queue.contains(userId)) return QueueEnqueueResult.alreadyQueued;
    _queue.addLast(userId);
    _promoteNext();
    return QueueEnqueueResult.accepted;
  }

  bool releaseTalk(String userId) {
    if (_currentSpeakerId != userId) return false;
    _currentSpeakerId = null;
    _promoteNext();
    return true;
  }

  bool forceNextSpeaker({required String actorId}) {
    if (!_hasAdminRights(actorId)) return false;
    _currentSpeakerId = null;
    _promoteNext();
    return true;
  }

  void _promoteNext() {
    if (_currentSpeakerId != null) return;
    while (_queue.isNotEmpty) {
      final candidateId = _queue.removeFirst();
      final m = _members[candidateId];
      if (m == null || m.muted) continue;
      _currentSpeakerId = candidateId;
      return;
    }
  }

  void applySnapshot(PttQueueSnapshot snapshot) {
    _members
      ..clear()
      ..addEntries(snapshot.members.map((m) => MapEntry(m.userId, m)));
    _queue
      ..clear()
      ..addAll(snapshot.queuedUserIds);
    final s = snapshot.currentSpeakerId;
    if (s != null && _members.containsKey(s) && !_members[s]!.muted) {
      _currentSpeakerId = s;
    } else {
      _currentSpeakerId = null;
      _promoteNext();
    }
  }
}
