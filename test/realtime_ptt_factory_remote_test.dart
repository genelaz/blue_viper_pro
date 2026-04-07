import 'package:blue_viper_pro/core/realtime/realtime_ptt_service_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remote backend can be created without websocket uri', () {
    RealtimePttServiceProvider.configure(
      const RealtimePttConfig(
        backend: RealtimePttBackend.remote,
        currentUserId: 'u1',
      ),
    );
    final svc = RealtimePttServiceProvider.instance;
    expect(svc.session.sessionId, isNotEmpty);
    expect(svc.state.members.containsKey('u1'), isTrue);
  });
}
