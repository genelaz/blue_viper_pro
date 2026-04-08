import 'dart:math';

/// İnsanların yazabileceği kısa oda kodu üretir (0/O ve I/1 karışmasın diye sınırlı alfabe).
class MapRoomCodes {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generate({int length = 8}) {
    final r = Random.secure();
    return List.generate(length, (_) => _chars[r.nextInt(_chars.length)]).join();
  }
}
