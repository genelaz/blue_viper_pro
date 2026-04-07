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

  const RealtimePttConfig({
    required this.backend,
    required this.currentUserId,
    this.maxMembers = 30,
    this.sessionName = 'Dag Ekibi',
    this.websocketUri,
  });
}

class RealtimePttServiceFactory {
  static RealtimePttService create(RealtimePttConfig config) {
    switch (config.backend) {
      case RealtimePttBackend.inMemory:
        return InMemoryRealtimePttService.bootstrapDemo(
          ownerUserId: config.currentUserId,
        );
      case RealtimePttBackend.remote:
        final svc = WebSocketRealtimePttService(
          session: GroupSession(
            sessionId: 'remote_session_1',
            name: config.sessionName,
            ownerUserId: config.currentUserId,
            maxMembers: config.maxMembers,
            createdAt: DateTime.now(),
          ),
          owner: defaultOwnerFor(config.currentUserId),
          websocketUri: config.websocketUri,
        );
        for (final m in const [
          GroupMember(userId: 'u2', displayName: 'Ekip-2', role: GroupRole.member),
          GroupMember(userId: 'u3', displayName: 'Ekip-3', role: GroupRole.member),
          GroupMember(userId: 'u4', displayName: 'Ekip-4', role: GroupRole.member),
        ]) {
          svc.addMember(actorId: config.currentUserId, member: m);
        }
        return svc;
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
