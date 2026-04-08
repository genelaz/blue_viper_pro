import 'group_session.dart';
import 'ptt_queue.dart';
import 'realtime_ptt_service.dart';
import 'websocket_realtime_ptt_service.dart';

enum RealtimePttBackend { inMemory, remote }

class RealtimePttConfig {
  final RealtimePttBackend backend;
  final String currentUserId;
  final int maxMembers;
  final String sessionName;
  final Uri? websocketUri;

  /// Kabine bağlanırken kullanılan oda / oturum kimliği; boşsa `yerel-<currentUserId>`.
  final String? sessionId;

  const RealtimePttConfig({
    required this.backend,
    required this.currentUserId,
    this.maxMembers = 30,
    this.sessionName = 'Harita ekibi',
    this.websocketUri,
    this.sessionId,
  });

  String get resolvedSessionId =>
      sessionId ?? 'yerel-${currentUserId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')}';
}

class RealtimePttServiceFactory {
  static RealtimePttService create(RealtimePttConfig config) {
    switch (config.backend) {
      case RealtimePttBackend.inMemory:
        final sid = config.resolvedSessionId;
        if (sid == 'demo_session_1') {
          return InMemoryRealtimePttService.bootstrapDemo(
            ownerUserId: config.currentUserId,
          );
        }
        return InMemoryRealtimePttService(
          session: GroupSession(
            sessionId: sid,
            name: config.sessionName,
            ownerUserId: config.currentUserId,
            maxMembers: config.maxMembers,
            createdAt: DateTime.now(),
          ),
          owner: defaultOwnerFor(config.currentUserId),
        );
      case RealtimePttBackend.remote:
        return WebSocketRealtimePttService(
          session: GroupSession(
            sessionId: config.resolvedSessionId,
            name: config.sessionName,
            ownerUserId: config.currentUserId,
            maxMembers: config.maxMembers,
            createdAt: DateTime.now(),
          ),
          owner: defaultOwnerFor(config.currentUserId),
          websocketUri: config.websocketUri,
        );
    }
  }
}

class RealtimePttServiceProvider {
  static RealtimePttConfig _config = const RealtimePttConfig(
    backend: RealtimePttBackend.inMemory,
    currentUserId: 'u1',
  );

  static RealtimePttService? _cached;

  static void configure(RealtimePttConfig config) {
    _config = config;
    _cached = null;
  }

  static Future<void> disposeCurrent() async {
    final s = _cached;
    _cached = null;
    if (s is WebSocketRealtimePttService) {
      await s.dispose();
    }
  }

  static RealtimePttService get instance {
    _cached ??= RealtimePttServiceFactory.create(_config);
    return _cached!;
  }
}

GroupMember defaultOwnerFor(String userId) => GroupMember(
      userId: userId,
      displayName: 'Lider',
      role: GroupRole.owner,
    );
