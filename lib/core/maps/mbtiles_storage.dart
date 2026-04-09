import 'package:shared_preferences/shared_preferences.dart';

import 'mbtiles_basemap_probe.dart';

/// Sabitlenmiş offline MBTiles dosya yolu (uygulama belgeleri altında).
class MbtilesStorage {
  static const _keyPath = 'offline_mbtiles_resolved_path';
  static const _keyKind = 'offline_mbtiles_kind';

  static Future<String?> getSavedPath() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyPath);
  }

  static Future<MbtilesBasemapKind?> getSavedKind() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_keyKind);
    if (s == 'vector') return MbtilesBasemapKind.vector;
    if (s == 'raster') return MbtilesBasemapKind.raster;
    return null;
  }

  static Future<void> savePathWithKind(String absolutePath, MbtilesBasemapKind kind) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyPath, absolutePath);
    await p.setString(_keyKind, kind == MbtilesBasemapKind.vector ? 'vector' : 'raster');
  }

  static Future<void> savePath(String absolutePath) async {
    await savePathWithKind(absolutePath, MbtilesBasemapKind.raster);
  }

  static Future<void> clearPath() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyPath);
    await p.remove(_keyKind);
  }
}
