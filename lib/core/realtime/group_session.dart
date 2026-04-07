class GroupSession {
  final String sessionId;
  final String name;
  final String ownerUserId;
  final int maxMembers;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const GroupSession({
    required this.sessionId,
    required this.name,
    required this.ownerUserId,
    required this.maxMembers,
    required this.createdAt,
    this.expiresAt,
  });
}
