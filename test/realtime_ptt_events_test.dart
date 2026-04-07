import 'package:blue_viper_pro/core/realtime/realtime_ptt_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event map round-trip keeps core fields', () {
    final e = RealtimePttEvent(
      type: RealtimePttEventType.mute,
      actorUserId: 'u1',
      targetUserId: 'u2',
      muted: true,
      seq: 10,
      refSeq: 8,
      code: 'ok',
      message: 'applied',
      sentAt: DateTime.parse('2026-04-07T10:00:00Z'),
    );
    final m = e.toMap();
    final d = RealtimePttEvent.fromMap(m);
    expect(d.type, RealtimePttEventType.mute);
    expect(d.actorUserId, 'u1');
    expect(d.targetUserId, 'u2');
    expect(d.muted, isTrue);
    expect(d.seq, 10);
    expect(d.refSeq, 8);
    expect(d.code, 'ok');
    expect(d.message, 'applied');
  });
}
