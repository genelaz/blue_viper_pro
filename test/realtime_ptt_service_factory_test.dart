import 'package:blue_viper_pro/core/realtime/realtime_ptt_service_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider returns cached instance until reconfigured', () {
    RealtimePttServiceProvider.configure(
      const RealtimePttConfig(
        backend: RealtimePttBackend.inMemory,
        currentUserId: 'u1',
      ),
    );
    final a = RealtimePttServiceProvider.instance;
    final b = RealtimePttServiceProvider.instance;
    expect(identical(a, b), isTrue);
  });

  test('reconfigure resets provider cache', () {
    RealtimePttServiceProvider.configure(
      const RealtimePttConfig(
        backend: RealtimePttBackend.inMemory,
        currentUserId: 'u1',
      ),
    );
    final a = RealtimePttServiceProvider.instance;
    RealtimePttServiceProvider.configure(
      const RealtimePttConfig(
        backend: RealtimePttBackend.remote,
        currentUserId: 'u2',
      ),
    );
    final b = RealtimePttServiceProvider.instance;
    expect(identical(a, b), isFalse);
  });
}
