import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'map_room_codes.dart';

/// Harita odası: yöneticinin belirlediği [roomNumber] + [password] ile türetilen
/// oturum kimliği. Aynı çift her zaman aynı `sessionId` üretir (paylaşılan sır).
class MapRoomSession {
  MapRoomSession._();

  static String normalizeRoomNumber(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// [roomNumber] ve [password] boş olamaz; dönen değer WebSocket `sessionId` olarak kullanılır.
  static String deriveSessionId({
    required String roomNumber,
    required String password,
  }) {
    final r = normalizeRoomNumber(roomNumber);
    final p = password.trim();
    if (r.isEmpty || p.isEmpty) {
      throw ArgumentError('Oda numarası ve şifre gerekli.');
    }
    if (r.length < 2) {
      throw ArgumentError('Oda numarası en az 2 karakter olmalı.');
    }
    final bytes =
        sha256.convert(utf8.encode('bvp_map_room_v1|$r|$p')).bytes;
    final chars = MapRoomCodes.safeAlphabet;
    final out = StringBuffer();
    for (var i = 0; i < 12; i++) {
      out.write(chars[bytes[i] % chars.length]);
    }
    return out.toString();
  }
}
