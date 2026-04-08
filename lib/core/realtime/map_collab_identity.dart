import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Kalıcı harita/PTT kullanıcı kimliği; [load] `main()` içinde `runApp` öncesi çağrılmalıdır.
class MapCollabIdentity {
  static const _key = 'map_collab_user_id';
  static String? _cached;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString(_key);
    if (id == null || id.isEmpty) {
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final r = Random.secure();
      id = List.generate(14, (_) => chars[r.nextInt(chars.length)]).join();
      await p.setString(_key, id);
    }
    _cached = id;
  }

  /// Testlerde mock tercihleri yüklendikten sonra çağrılabilir.
  static void debugSetCacheForTest(String id) {
    _cached = id;
  }

  static String get currentUserId {
    final c = _cached;
    if (c == null) {
      throw StateError(
        'MapCollabIdentity.load() çağrılmadı — main() içinde await edin.',
      );
    }
    return c;
  }
}
