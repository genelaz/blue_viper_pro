import 'package:shared_preferences/shared_preferences.dart';

/// Üst nişangah çubuğunda gösterilecek koordinat biçimi.
enum MapHudCoordFormat {
  decimalDegrees,
  dms,
  mgrs,
  utmCompact,
  utmEpsg,
  sk42,
}

/// Haritadaki mesafe gösterimi (nişangah ↔ referans noktası).
enum MapDistanceUnit {
  meters,
  kilometers,
  miles,
  nauticalMiles,
}

/// Kapalı alan (poligon) özeti için.
enum MapAreaUnit {
  squareMeters,
  hectares,
  acres,
  squareKilometers,
}

/// Harita üzerinde koordinat ızgarası (WGS veya UTM).
enum MapGridMode {
  off,
  wgs84,
  /// WGS 84 / UTM kuzey — «Ayrıntılar» zonu veya otomatik zon.
  utmNorth,
}

enum Cas3dTubePresetMode {
  all,
  none,
  high,
  custom,
}

/// SharedPreferences ile kalıcı harita görünümü / birimleri.
class MapDisplayPrefs {
  MapDisplayPrefs({
    required this.hudCoordFormat,
    required this.distanceUnit,
    required this.areaUnit,
    this.onlineBaseLayerName,
    this.baseLayerOpacity = 1.0,
    this.overlayBaseLayerName,
    this.overlayOpacity = 0.45,
    this.gridMode = MapGridMode.off,
    this.hillshadeOverlayEnabled = false,
    this.hillshadeOpacity = 0.45,
    this.vectorMbtilesMaxTiles = 20,
    this.vectorMbtilesPreviewMaxZoom = 15,
    this.vectorMbtilesMaxLabels = 32,
    this.vectorMbtilesScaleLabelsByZoom = true,
    this.vectorMbtilesFillOpacity = 0.18,
    this.vectorMbtilesStrokeOpacity = 0.88,
    this.vectorMbtilesUseMaplibreEngine = false,
    this.ntv2GsbPath,
    this.tacticalCrosshairEnabled = false,
    this.losThreatTubeHalfWidthM = 40,
    this.losThreatTubeTargetHalfWidthM = 80,
    this.cas3dEnabledTubeIds = const <String>{},
    this.cas3dTubePresetMode = Cas3dTubePresetMode.all,
    this.casRemoteAutoSyncEnabled = false,
    this.casRemoteAutoSyncSec = 120,
  });

  final MapHudCoordFormat hudCoordFormat;
  final MapDistanceUnit distanceUnit;
  final MapAreaUnit areaUnit;

  /// `_MapBaseLayer.name` ile uyumlu; null → kod varsayılanı.
  final String? onlineBaseLayerName;

  /// Çevrimiçi veya MBTiles raster altlık opaklığı (AlpineQuest tarzı yarı saydam harita).
  /// 0.35–1.0 aralığında tutulur.
  final double baseLayerOpacity;

  /// Üstte çizilen ikinci karonun `_MapBaseLayer.name`; null = tek katman.
  final String? overlayBaseLayerName;

  /// Üst referans katmanı saydamlığı (0.15–0.9).
  final double overlayOpacity;

  final MapGridMode gridMode;

  /// Esri World Hillshade üst katmanı (ağ); topo / MBTiles üzerinde arazi kabartması.
  final bool hillshadeOverlayEnabled;

  /// Gölgeleme opaklığı (0.15–0.85).
  final double hillshadeOpacity;

  /// Görünür alanda yüklenecek en çok MVT karo sayısı (vektör MBTiles önizleme).
  final int vectorMbtilesMaxTiles;

  /// MVT geometri önizlemesinde kullanılan zoom üst sınırı (karoya yuvarlanır); paket `maxzoom` ile kısıtlanır.
  final int vectorMbtilesPreviewMaxZoom;

  /// Özellik `name` / `ref` vb. ile gösterilecek en çok etiket; 0 = kapalı.
  final int vectorMbtilesMaxLabels;

  /// true ise zoom düşükken etiket kotası otomatik azalır (`MbtilesVectorOverlayBuilder.effectiveLabelBudget`).
  final bool vectorMbtilesScaleLabelsByZoom;

  /// Poligon dolgu opaklığı (vektör önizleme).
  final double vectorMbtilesFillOpacity;

  /// Çizgi ve poligon sınır çizgisi opaklığı (vektör önizleme).
  final double vectorMbtilesStrokeOpacity;

  /// true: vektör MBTiles altlığında MapLibre Native + OpenFreeMap Liberty stili (sprite/glif/Style Spec).
  /// false: mevcut flutter_map + MVT geometri önizlemesi.
  final bool vectorMbtilesUseMaplibreEngine;

  /// Son seçilen NTv2 `.gsb` dosyasının tam yolu (mobil / masaüstü); yoksa null.
  final String? ntv2GsbPath;

  /// Ortadaki artı nişangah, üst taktik çubuk ve referans→nişangah çizgisi.
  final bool tacticalCrosshairEnabled;

  /// Paket 4 MVP tehdit tüpü yarı genişliği (m).
  final double losThreatTubeHalfWidthM;
  /// Paket 4: hedefe doğru genişleyen tüp için hedef tarafı yarı genişlik (m).
  final double losThreatTubeTargetHalfWidthM;
  /// CAS 3B katmanında kullanıcı tarafından etkin bırakılan tube id’leri.
  final Set<String> cas3dEnabledTubeIds;
  final Cas3dTubePresetMode cas3dTubePresetMode;
  final bool casRemoteAutoSyncEnabled;
  final int casRemoteAutoSyncSec;

  static const _kCoord = 'map_hud_coord_format_v2';
  static const _kDist = 'map_distance_unit_v1';
  static const _kArea = 'map_area_unit_v1';
  static const _kBase = 'map_online_base_layer_v1';
  static const _kOpacity = 'map_base_layer_opacity_v1';
  static const _kOverlayBase = 'map_overlay_base_layer_v1';
  static const _kOverlayOpacity = 'map_overlay_opacity_v1';
  static const _kGrid = 'map_grid_mode_v1';
  static const _kHillshade = 'map_hillshade_enabled_v1';
  static const _kHillshadeOpacity = 'map_hillshade_opacity_v1';
  static const _kVectorMaxTiles = 'map_vector_mbtiles_max_tiles_v1';
  static const _kVectorPreviewMaxZoom = 'map_vector_mbtiles_preview_max_zoom_v1';
  static const _kVectorMaxLabels = 'map_vector_mbtiles_max_labels_v1';
  static const _kVectorScaleLabels = 'map_vector_mbtiles_scale_labels_by_zoom_v1';
  static const _kVectorFillOp = 'map_vector_mbtiles_fill_opacity_v1';
  static const _kVectorStrokeOp = 'map_vector_mbtiles_stroke_opacity_v1';
  static const _kVectorMaplibreEngine = 'map_vector_mbtiles_maplibre_engine_v1';
  static const _kNtv2GsbPath = 'map_ntv2_gsb_path_v1';
  static const _kTacticalHud = 'map_tactical_crosshair_v1';
  static const _kLosThreatTubeHalfWidth = 'map_los_threat_tube_half_width_m_v1';
  static const _kLosThreatTubeTargetHalfWidth = 'map_los_threat_tube_target_half_width_m_v1';
  static const _kCas3dEnabledTubeIds = 'map_cas3d_enabled_tube_ids_v1';
  static const _kCas3dTubePresetMode = 'map_cas3d_tube_preset_mode_v1';
  static const _kCasRemoteAutoSyncEnabled = 'map_cas_remote_auto_sync_enabled_v1';
  static const _kCasRemoteAutoSyncSec = 'map_cas_remote_auto_sync_sec_v1';

  /// Varsayılan 20; düşük = daha az işlem, yüksek = daha fazla detay (daha ağır).
  static int _parseVectorMaxTiles(int? raw) {
    if (raw == null) return 20;
    return raw.clamp(10, 40);
  }

  static int _parseVectorPreviewMaxZoom(int? raw) {
    if (raw == null) return 15;
    return raw.clamp(10, 22);
  }

  static int _parseVectorMaxLabels(int? raw) {
    if (raw == null) return 32;
    return raw.clamp(0, 64);
  }

  static double _parseVectorFillOpacity(double? raw) {
    if (raw == null || raw.isNaN) return 0.18;
    return raw.clamp(0.08, 0.45);
  }

  static double _parseVectorStrokeOpacity(double? raw) {
    if (raw == null || raw.isNaN) return 0.88;
    return raw.clamp(0.4, 1.0);
  }

  static MapHudCoordFormat _parseCoord(String? raw) {
    if (raw == null) return MapHudCoordFormat.mgrs;
    for (final v in MapHudCoordFormat.values) {
      if (v.name == raw) return v;
    }
    return MapHudCoordFormat.mgrs;
  }

  static MapDistanceUnit _parseDist(String? raw) {
    if (raw == null) return MapDistanceUnit.meters;
    for (final v in MapDistanceUnit.values) {
      if (v.name == raw) return v;
    }
    return MapDistanceUnit.meters;
  }

  static MapAreaUnit _parseArea(String? raw) {
    if (raw == null) return MapAreaUnit.squareMeters;
    for (final v in MapAreaUnit.values) {
      if (v.name == raw) return v;
    }
    return MapAreaUnit.squareMeters;
  }

  static MapGridMode _parseGrid(String? raw) {
    if (raw == null) return MapGridMode.off;
    for (final v in MapGridMode.values) {
      if (v.name == raw) return v;
    }
    return MapGridMode.off;
  }

  static double _parseOpacity(double? raw) {
    if (raw == null || raw.isNaN) return 1.0;
    if (raw < 0.35) return 0.35;
    if (raw > 1.0) return 1.0;
    return raw;
  }

  static double _parseOverlayOpacity(double? raw) {
    if (raw == null || raw.isNaN) return 0.45;
    if (raw < 0.15) return 0.15;
    if (raw > 0.9) return 0.9;
    return raw;
  }

  static double _parseHillshadeOpacity(double? raw) {
    if (raw == null || raw.isNaN) return 0.45;
    if (raw < 0.15) return 0.15;
    if (raw > 0.85) return 0.85;
    return raw;
  }

  static double _parseLosThreatTubeHalfWidth(double? raw) {
    if (raw == null || raw.isNaN) return 40;
    return raw.clamp(10, 300);
  }

  static double _parseLosThreatTubeTargetHalfWidth(double? raw) {
    if (raw == null || raw.isNaN) return 80;
    return raw.clamp(10, 600);
  }

  static Set<String> _parseCas3dEnabledTubeIds(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String>{};
    final out = <String>{};
    for (final p in raw.split(',')) {
      final t = p.trim();
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }

  static Cas3dTubePresetMode _parseCas3dTubePresetMode(String? raw) {
    if (raw == null) return Cas3dTubePresetMode.all;
    for (final v in Cas3dTubePresetMode.values) {
      if (v.name == raw) return v;
    }
    return Cas3dTubePresetMode.all;
  }

  static int _parseCasRemoteAutoSyncSec(int? raw) {
    if (raw == null) return 120;
    return raw.clamp(30, 600);
  }

  static Future<MapDisplayPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return MapDisplayPrefs(
      hudCoordFormat: _parseCoord(p.getString(_kCoord)),
      distanceUnit: _parseDist(p.getString(_kDist)),
      areaUnit: _parseArea(p.getString(_kArea)),
      onlineBaseLayerName: p.getString(_kBase),
      baseLayerOpacity: _parseOpacity(p.getDouble(_kOpacity)),
      overlayBaseLayerName: p.getString(_kOverlayBase),
      overlayOpacity: _parseOverlayOpacity(p.getDouble(_kOverlayOpacity)),
      gridMode: _parseGrid(p.getString(_kGrid)),
      hillshadeOverlayEnabled: p.getBool(_kHillshade) ?? false,
      hillshadeOpacity: _parseHillshadeOpacity(p.getDouble(_kHillshadeOpacity)),
      vectorMbtilesMaxTiles: _parseVectorMaxTiles(p.getInt(_kVectorMaxTiles)),
      vectorMbtilesPreviewMaxZoom: _parseVectorPreviewMaxZoom(p.getInt(_kVectorPreviewMaxZoom)),
      vectorMbtilesMaxLabels: _parseVectorMaxLabels(p.getInt(_kVectorMaxLabels)),
      vectorMbtilesScaleLabelsByZoom: p.getBool(_kVectorScaleLabels) ?? true,
      vectorMbtilesFillOpacity: _parseVectorFillOpacity(p.getDouble(_kVectorFillOp)),
      vectorMbtilesStrokeOpacity: _parseVectorStrokeOpacity(p.getDouble(_kVectorStrokeOp)),
      vectorMbtilesUseMaplibreEngine: p.getBool(_kVectorMaplibreEngine) ?? false,
      ntv2GsbPath: p.getString(_kNtv2GsbPath),
      tacticalCrosshairEnabled: p.getBool(_kTacticalHud) ?? false,
      losThreatTubeHalfWidthM: _parseLosThreatTubeHalfWidth(
        p.getDouble(_kLosThreatTubeHalfWidth),
      ),
      losThreatTubeTargetHalfWidthM: _parseLosThreatTubeTargetHalfWidth(
        p.getDouble(_kLosThreatTubeTargetHalfWidth),
      ),
      cas3dEnabledTubeIds: _parseCas3dEnabledTubeIds(
        p.getString(_kCas3dEnabledTubeIds),
      ),
      cas3dTubePresetMode: _parseCas3dTubePresetMode(
        p.getString(_kCas3dTubePresetMode),
      ),
      casRemoteAutoSyncEnabled: p.getBool(_kCasRemoteAutoSyncEnabled) ?? false,
      casRemoteAutoSyncSec: _parseCasRemoteAutoSyncSec(
        p.getInt(_kCasRemoteAutoSyncSec),
      ),
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCoord, hudCoordFormat.name);
    await p.setString(_kDist, distanceUnit.name);
    await p.setString(_kArea, areaUnit.name);
    await p.setString(_kGrid, gridMode.name);
    await p.setDouble(_kOpacity, _parseOpacity(baseLayerOpacity));
    await p.setDouble(_kOverlayOpacity, _parseOverlayOpacity(overlayOpacity));
    if (onlineBaseLayerName != null) {
      await p.setString(_kBase, onlineBaseLayerName!);
    } else {
      await p.remove(_kBase);
    }
    if (overlayBaseLayerName != null) {
      await p.setString(_kOverlayBase, overlayBaseLayerName!);
    } else {
      await p.remove(_kOverlayBase);
    }
    await p.setBool(_kHillshade, hillshadeOverlayEnabled);
    await p.setDouble(_kHillshadeOpacity, _parseHillshadeOpacity(hillshadeOpacity));
    await p.setInt(_kVectorMaxTiles, _parseVectorMaxTiles(vectorMbtilesMaxTiles));
    await p.setInt(_kVectorPreviewMaxZoom, _parseVectorPreviewMaxZoom(vectorMbtilesPreviewMaxZoom));
    await p.setInt(_kVectorMaxLabels, _parseVectorMaxLabels(vectorMbtilesMaxLabels));
    await p.setBool(_kVectorScaleLabels, vectorMbtilesScaleLabelsByZoom);
    await p.setDouble(_kVectorFillOp, _parseVectorFillOpacity(vectorMbtilesFillOpacity));
    await p.setDouble(_kVectorStrokeOp, _parseVectorStrokeOpacity(vectorMbtilesStrokeOpacity));
    await p.setBool(_kVectorMaplibreEngine, vectorMbtilesUseMaplibreEngine);
    final g = ntv2GsbPath?.trim();
    if (g != null && g.isNotEmpty) {
      await p.setString(_kNtv2GsbPath, g);
    } else {
      await p.remove(_kNtv2GsbPath);
    }
    await p.setBool(_kTacticalHud, tacticalCrosshairEnabled);
    await p.setDouble(
      _kLosThreatTubeHalfWidth,
      _parseLosThreatTubeHalfWidth(losThreatTubeHalfWidthM),
    );
    await p.setDouble(
      _kLosThreatTubeTargetHalfWidth,
      _parseLosThreatTubeTargetHalfWidth(losThreatTubeTargetHalfWidthM),
    );
    if (cas3dEnabledTubeIds.isEmpty) {
      await p.remove(_kCas3dEnabledTubeIds);
    } else {
      await p.setString(_kCas3dEnabledTubeIds, cas3dEnabledTubeIds.join(','));
    }
    await p.setString(_kCas3dTubePresetMode, cas3dTubePresetMode.name);
    await p.setBool(_kCasRemoteAutoSyncEnabled, casRemoteAutoSyncEnabled);
    await p.setInt(_kCasRemoteAutoSyncSec, _parseCasRemoteAutoSyncSec(casRemoteAutoSyncSec));
  }
}

extension MapDistanceUnitFormat on MapDistanceUnit {
  /// [meters] nişangah ile referans noktası arası mesafe; &lt; 0,5 m ise yok sayılır.
  String formatHudDistance(double? meters) {
    if (meters == null || meters < 0.5) return '—';
    switch (this) {
      case MapDistanceUnit.meters:
        return '~${meters.toStringAsFixed(meters >= 100 ? 0 : 1)} m';
      case MapDistanceUnit.kilometers:
        return '~${(meters / 1000).toStringAsFixed(meters >= 10000 ? 2 : 3)} km';
      case MapDistanceUnit.miles:
        return '~${(meters / 1609.344).toStringAsFixed(3)} mil';
      case MapDistanceUnit.nauticalMiles:
        return '~${(meters / 1852).toStringAsFixed(3)} deniz mil';
    }
  }
}

extension MapAreaUnitFormat on MapAreaUnit {
  String formatAreaM2(double m2) {
    switch (this) {
      case MapAreaUnit.squareMeters:
        return '${m2.toStringAsFixed(0)} m²';
      case MapAreaUnit.hectares:
        return '${(m2 / 10000).toStringAsFixed(2)} ha';
      case MapAreaUnit.acres:
        return '${(m2 / 4046.8564224).toStringAsFixed(2)} acre';
      case MapAreaUnit.squareKilometers:
        return '${(m2 / 1e6).toStringAsFixed(3)} km²';
    }
  }
}
