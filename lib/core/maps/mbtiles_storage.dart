import 'package:shared_preferences/shared_preferences.dart';

/// Sabitlenmiş offline MBTiles dosya yolu (uygulama belgeleri altında).
class MbtilesStorage {
  static const _keyPath = 'offline_mbtiles_resolved_path';

  static Future<String?> getSavedPath() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyPath);
  }

  static Future<void> savePath(String absolutePath) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyPath, absolutePath);
  }

  static Future<void> clearPath() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyPath);
  }
}
