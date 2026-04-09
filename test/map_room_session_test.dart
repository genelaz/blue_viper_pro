import 'package:blue_viper_pro/core/realtime/map_room_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deriveSessionId stable for same room + password', () {
    final a = MapRoomSession.deriveSessionId(roomNumber: 'TAKIM01', password: 'xyz12');
    final b = MapRoomSession.deriveSessionId(roomNumber: '  takim01  ', password: 'xyz12');
    expect(a, b);
    expect(a.length, 12);
  });

  test('deriveSessionId differs when password changes', () {
    final a = MapRoomSession.deriveSessionId(roomNumber: 'A1', password: 'p1');
    final b = MapRoomSession.deriveSessionId(roomNumber: 'A1', password: 'p2');
    expect(a, isNot(b));
  });

  test('normalizeRoomNumber strips non-alphanumeric', () {
    expect(MapRoomSession.normalizeRoomNumber('ab-12 cd'), 'AB12CD');
  });
}
