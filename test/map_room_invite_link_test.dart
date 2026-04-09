import 'package:blue_viper_pro/core/realtime/map_room_invite_link.dart';
import 'package:blue_viper_pro/core/realtime/map_room_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('build and tryParse roundtrip', () {
    final u = MapRoomInviteLink.build(roomKey: 'TAK01', password: 'abc234');
    expect(u.scheme, MapRoomInviteLink.scheme);
    expect(u.host, MapRoomInviteLink.host);
    final p = MapRoomInviteLink.tryParse(u);
    expect(p, isNotNull);
    expect(p!.roomKey, MapRoomSession.normalizeRoomNumber('TAK01'));
    expect(p.password, 'abc234');
  });

  test('tryParse rejects wrong scheme', () {
    expect(
      MapRoomInviteLink.tryParse(Uri.parse('https://example.com/x')),
      isNull,
    );
  });
}
