import 'map_room_session.dart';

/// WhatsApp vb. ile paylaşılacak davet URL’si ve ayrıştırma.
///
/// Biçim: `blueviper://harita-oda?oda=...&sifre=...` (sorgu URI tarafından kodlanır).
class MapRoomInviteLink {
  MapRoomInviteLink._();

  static const scheme = 'blueviper';
  static const host = 'harita-oda';

  static Uri build({required String roomKey, required String password}) {
    return Uri(
      scheme: scheme,
      host: host,
      queryParameters: <String, String>{
        'oda': roomKey,
        'sifre': password,
      },
    );
  }

  /// [roomKey] türetilmiş anahtar (normalize edilir); [password] URL’deki ham değer.
  static MapRoomInviteParse? tryParse(Uri uri) {
    if (uri.scheme != scheme) return null;
    if (uri.host != host) return null;
    final rawOda =
        uri.queryParameters['oda'] ?? uri.queryParameters['isim'] ?? uri.queryParameters['name'];
    final rawSifre = uri.queryParameters['sifre'] ??
        uri.queryParameters['pwd'] ??
        uri.queryParameters['password'];
    if (rawOda == null || rawSifre == null) return null;
    final key = MapRoomSession.normalizeRoomNumber(rawOda);
    final pw = rawSifre.trim();
    if (key.isEmpty || pw.isEmpty) return null;
    return MapRoomInviteParse(roomKey: key, password: pw);
  }
}

class MapRoomInviteParse {
  final String roomKey;
  final String password;

  MapRoomInviteParse({required this.roomKey, required this.password});
}
