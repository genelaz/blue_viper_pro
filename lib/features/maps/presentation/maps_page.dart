import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, visibleForTesting, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/geo/elevation_service.dart';
import '../../../core/geo/geo_formatters.dart';
import '../../../core/geo/geo_measure.dart';
import '../../../core/geo/geopdf_extent.dart';
import '../../../core/geo/geopdf_streams.dart';
import '../../../core/geo/gpx_kml_codec.dart';
import '../../../core/geo/ntv2_gsb.dart';
import '../../../core/geo/cas_3d_package.dart';
import '../../../core/geo/shapefile_route.dart';
import '../../../core/geo/simple_los.dart';
import '../../../core/geo/wgs84_utm_epsg.dart';
import '../../../core/maps/map_coordinate_grid.dart';
import '../../../core/maps/map_display_prefs.dart';
import '../../../core/maps/maplibre_vector_mbtiles_style.dart';
import '../../../core/maps/mbtiles_basemap_probe.dart';
import '../../../core/maps/mbtiles_raster.dart';
import '../../../core/maps/mbtiles_raw_tile_reader.dart';
import '../../../core/maps/mbtiles_storage.dart';
import '../../../core/maps/mbtiles_vector_overlay_builder.dart';
import '../../../core/maps/mbtiles_vector_pick.dart';
import '../../../core/realtime/ptt_queue.dart';
import '../../../core/realtime/ptt_service_notice.dart';
import '../../../core/realtime/realtime_ptt_service.dart';
import '../../../core/realtime/realtime_ptt_service_factory.dart';
import '../../../core/sync/cas_remote_service.dart';
import 'coordinate_target_sheet.dart';
import 'elevation_profile_dialog.dart';
import 'los_analysis_dialog.dart';
import 'map_collab_overlay.dart';
import 'map_data_packages_sheet.dart';
import 'maps_comparison_sheet.dart';
import 'vector_mbtiles_pick_sheet.dart';
import '../../../core/realtime/map_collab_identity.dart';
import '../../../core/realtime/map_collab_models.dart';
import '../../../core/realtime/map_room_codes.dart';
import '../../../core/realtime/map_room_deep_link_controller.dart';
import '../../../core/realtime/map_room_invite_link.dart';
import '../../../core/realtime/map_room_session.dart';
import 'map_speaking_wave.dart';

const double _kMapBottomToolsHeight = 56;
const double _kMapBottomPaletteHeight = 28;
const double _kMapBottomBarTotalHeight = _kMapBottomToolsHeight + _kMapBottomPaletteHeight;

/// Kullanıcı işaretleri — ayırt edici renkler (aynı simge, farklı palet).
const List<Color> _kMapUserPinPalette = [
  Color(0xFFE53935),
  Color(0xFF43A047),
  Color(0xFF1E88E5),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
];

class _MapUserPin {
  _MapUserPin({
    required this.id,
    required this.point,
    this.colorIndex = 0,
  });

  final String id;
  LatLng point;
  String? name;
  String? note;
  int colorIndex;
}

class _KmlRouteMarkerStyle {
  const _KmlRouteMarkerStyle({
    required this.background,
    required this.markerScale,
    this.iconBytes,
    this.hotspot,
    this.placemarkName,
    this.balloonText,
    this.iconColorArgb,
  });

  final Color background;
  final double markerScale;
  final Uint8List? iconBytes;
  final KmlIconHotspot? hotspot;
  final String? placemarkName;
  final String? balloonText;
  final int? iconColorArgb;
}

/// GPX `<trk>` haritada (kayıtlı iz; canlı GPS izinden farklı mavi ton).
const int _kGpxImportTrackStrokeArgb = 0xFF1565C0;
const double _kGpxImportTrackStrokeWidth = 4;

/// GPX `<rte>` haritada plan rotası (turuncu).
const int _kGpxImportRouteStrokeArgb = 0xFFE65100;
const double _kGpxImportRouteStrokeWidth = 4;

/// ArcGIS World Hillshade (Web Mercator XYZ); AlpineQuest tarzı DEM gölgelendirmesi için üst katman.
const String _kEsriWorldHillshadeUrl =
    'https://services.arcgisonline.com/arcgis/rest/services/Elevation/World_Hillshade/MapServer/tile/{z}/{y}/{x}';

String _mapsPttServerNoticeTurkish(PttServiceNotice n) {
  final code = n.code ?? '';
  final detail = (n.message != null && n.message!.trim().isNotEmpty)
      ? ' ${n.message!.trim()}'
      : '';
  final base = switch (code) {
    'forbidden' => 'Bu işlem için yetkiniz yok.',
    'invalid_payload' => 'İstek sunucu tarafından reddedildi.',
    'rate_limited' => 'Çok hızlı işlem yapıldı. Lütfen kısa bir süre sonra deneyin.',
    'session_closed' => 'Oturum kapandı. Yeniden bağlanmayı deneyin.',
    'replay' => 'Ağ iletisinde çakışma algılandı; durum sunucudan yenileniyor.',
    _ => 'Sunucu işlemi reddetti.',
  };
  return '$base$detail'.trim();
}

/// Saf GIS / harita: WGS84, MGRS, UTM, rota, alan, GPX, iz — balistik veya atıcılık yok.
class MapsPage extends StatefulWidget {
  final RealtimePttBackend pttBackend;
  final String? pttWebsocketUrl;

  const MapsPage({
    super.key,
    this.pttBackend = RealtimePttBackend.remote,
    this.pttWebsocketUrl,
  });

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  final MapController _mapController = MapController();
  void Function(VoidCallback fn)? _mapDetailsSheetSetState;

  String get _collabUserId => MapCollabIdentity.currentUserId;

  RealtimePttService get _pttService => RealtimePttServiceProvider.instance;

  /// [flutter test] sets `FLUTTER_TEST=true`; the binding mocks HTTP with 400.
  /// Use silent tiles so map tests do not spam [ClientException] stack traces.
  TileProvider _onlineTileProvider() {
    if (!kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true') {
      return NetworkTileProvider(silenceExceptions: true);
    }
    return NetworkTileProvider();
  }

  /// GPS veya haritadan sabitlenen mevcut konum (mavi).
  LatLng? _myPosition;
  final List<_MapUserPin> _userPins = [];
  int _pinIdSeq = 0;
  /// Sonraki işaret için palet dizini (0–4); alt şerit renk çipleri ve «İş.1/2» kısayolları buna göre ayarlanır.
  int _selectedPinPaletteIndex = 0;
  final Map<String, double?> _pinDemMeters = {};

  double? _gpsAltDeviceMeters;
  bool _followGps = true;

  double? _demMy;
  /// Orta nişangah + taktik üst çubuk + ref→nişangah çizgisi ([MapDisplayPrefs.tacticalCrosshairEnabled]).
  bool _tacticalHudEnabled = false;

  LatLng? get _waypoint1 => _userPins.isNotEmpty ? _userPins.first.point : null;
  LatLng? get _waypoint2 => _userPins.length >= 2 ? _userPins[1].point : null;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<PttServiceNotice>? _pttUxSub;
  StreamSubscription<MapCollabPeerLocation>? _collabPeerSub;
  StreamSubscription<MapCollabTargetReport>? _collabTargetSub;
  Timer? _shareLocationTimer;
  final Map<String, MapCollabPeerLocation> _peerLiveByUser = {};
  final Map<String, MapCollabTargetReport> _collabTargetsByUser = {};
  /// Oda kurucusu konum paylaşımı.
  bool _ownerSharesLiveLocation = false;

  /// Üye olarak kendi konumumu haritada yayınla.
  bool _memberSharesLocation = false;

  /// Kurucunun canlı konumunu haritada takip (üyeler); varsayılan açık.
  bool _followRoomOwnerLive = true;

  String? _inviteRoomPassword;

  /// Davet metninde gösterilen oda numarası (sunucu `sessionId` değil).
  String? _inviteRoomNumber;

  _MapTapMode _tapMode = _MapTapMode.viewOnly;
  String _status = 'Konum izni bekleniyor';
  String _elevStatus = '';
  /// Açık hava / saha için varsayılan: topografya (uydu: katmanlar menüsünden).
  _MapBaseLayer _mapBase = _MapBaseLayer.openTopo;

  /// Harita merkezi (nişangah / taktik ölçü hedefi).
  LatLng _mapHudCenter = const LatLng(39.925533, 32.866287);
  double _mapRotationDeg = 0;

  /// Çevrimiçi karolar veya yerel MBTiles (raster / vektör önizleme).
  _MapRasterSource _rasterSource = _MapRasterSource.online;
  MbTilesTileProvider? _mbTilesProvider;
  MbtilesBasemapKind? _offlineMbtilesKind;
  String? _offlinePackLabel;
  int _mbtilesMinNativeZoom = 0;
  int _mbtilesMaxNativeZoom = 22;
  Timer? _vectorMbtilesDebounce;
  MbtilesRawTileReader? _vectorMbtilesReader;
  final List<Polygon> _vectorMbtilesPolygons = [];
  final List<Polyline> _vectorMbtilesPolylines = [];
  final List<LatLng> _vectorMbtilesPoints = [];
  final List<MbtilesVectorMapLabel> _vectorMbtilesLabels = [];
  Cas3dPackage? _cas3dPackage;
  final List<Polygon> _cas3dThreatPolygons = [];
  final List<Polyline> _cas3dThreatCenterLines = [];
  final List<(LatLng point, String text)> _cas3dThreatLabels = [];
  final Set<String> _cas3dEnabledTubeIds = <String>{};
  Cas3dTubePresetMode _cas3dPresetMode = Cas3dTubePresetMode.all;
  bool _casRemoteAutoSyncEnabled = false;
  int _casRemoteAutoSyncSec = 120;
  Timer? _casRemoteAutoSyncTimer;
  DateTime? _casRemoteLastSyncAt;
  List<String> _casRemoteProfileChips = const ['ayarsiz'];
  int _vectorMbtilesMaxTiles = 20;
  int _vectorMbtilesPreviewMaxZoom = 15;
  int _vectorMbtilesMaxLabels = 32;
  bool _vectorMbtilesScaleLabelsByZoom = true;
  double _vectorMbtilesFillOpacity = 0.18;
  double _vectorMbtilesStrokeOpacity = 0.88;
  bool _vectorMbtilesUseMaplibreEngine = false;
  ml.MapController? _maplibreController;
  String? _maplibreStyleJson;
  String? _maplibreStyleError;

  /// Paket 4: DEM LOS — pim 1 (gözlem) ile pim 2 (hedef) hizalı segment listesi.
  List<({List<LatLng> points, bool blocked})>? _losMapSegments;
  LatLng? _losMapObs;
  LatLng? _losMapTgt;
  LatLng? _losBlockedApprox;
  /// Paket 4 MVP: gözlem-hedef hattı etrafında basit tehdit koridoru (yarı genişlik metre).
  List<LatLng>? _losThreatTubeOuter;
  LatLng? _losThreatObs;
  LatLng? _losThreatTgt;
  double _losThreatHalfWidthM = 40;
  double _losThreatTargetHalfWidthM = 80;

  /// Üst nişangah çubuğu ve ölçü birimleri ([MapDisplayPrefs] ile kalıcı).
  MapHudCoordFormat _hudCoordFormat = MapHudCoordFormat.mgrs;
  MapDistanceUnit _distanceUnit = MapDistanceUnit.meters;
  MapAreaUnit _areaUnit = MapAreaUnit.squareMeters;

  /// Raster altlık (çevrimiçi / MBTiles) opaklığı — AlpineQuest benzeri yarı saydam harita.
  double _baseLayerOpacity = 1.0;

  /// İkinci karo katmanı (daima çevrimiçi); null = kapalı. Ana altlığın üstüne çizilir.
  _MapBaseLayer? _overlayBaseLayer;

  /// Üst katman opaklığı (altlık opaklığından bağımsız).
  double _overlayOpacity = 0.45;

  MapGridMode _mapGridMode = MapGridMode.off;

  /// Üstte yarı saydam DEM gölgelendirmesi (çevrimiçi Esri karoları).
  bool _hillshadeOverlayEnabled = false;
  double _hillshadeOpacity = 0.45;

  final List<LatLng> _routeVertices = [];
  final List<LatLng> _polygonVertices = [];
  /// KML `innerBoundaryIs` veya benzeri; elle çizimde genelde boş.
  final List<List<LatLng>> _polygonHoles = [];

  /// KML/KMZ içindeki ek kapalı alanlar (birincil parça [_polygonVertices] / [_polygonHoles]).
  final List<KmlPolygonPatch> _additionalPolygonPatches = [];

  /// İçe aktarılan KML çizgileri — Placemark adı, ARGB, isteğe bağlı KML `width`; genişlik yoksa ~4 px.
  final List<(String name, List<LatLng> line, int? strokeArgb, double? strokeWidthPx)>
      _kmlImportStyledPolylines = [];

  /// Son KML/KMZ içe aktarımındaki `Point` placemark’ları (çizgiden ayrı; GPX’te yinelenmesin diye).
  final List<KmlPointImport> _kmlImportPoints = [];

  /// KML `StyleMap` highlight için seçili rota köşesi; aynı köşeye tekrar dokununca kalkar.
  int? _selectedKmlRouteVertexIndex;

  /// Son GPX içe aktarımındaki `<trk>` parçaları (KML yüklemede temizlenir); dışa aktarımda `trk`.
  final List<(String name, List<LatLng> line)> _gpxImportTrackLinesOnly = [];

  /// Son GPX içe aktarımındaki `<rte>` parçaları; dışa aktarımda `rte`.
  final List<(String name, List<LatLng> line)> _gpxImportRouteLinesOnly = [];

  /// KML birincil poligon stili; elle çizim / yeni içe aktarım yoksa null (teal).
  int? _kmlPrimaryPolygonFillArgb32;
  int? _kmlPrimaryPolygonStrokeArgb32;
  double? _kmlPrimaryPolygonStrokeWidthPx;
  bool? _kmlPrimaryPolygonDrawStrokeOutline;

  /// [MapDisplayPrefs] ile kaydedilen NTv2 dosya yolu (açılışta yeniden yüklenir).
  String? _ntv2GsbPathPref;

  /// GeoPDF (GPTS) kapsamı — sadece görsel; rota / alan değil.
  final List<LatLng> _geoPdfExtentPolygon = [];

  /// GeoPDF ilk sayfadaki gömülü JPEG (DCTDecode); GPTS dikdörtgenine [OverlayImage] ile oturtulur.
  Uint8List? _geoPdfRasterJpeg;

  /// NTv2 (.gsb): HUD / ayrıntı koordinatları kaymalı gösterim; kapsam dışı uyarısı.
  Ntv2GsbShift? _ntv2GsbGrid;
  bool _recordingTrack = false;
  final List<LatLng> _recordedTrack = [];
  LatLng? _gpsLive;

  /// İz kaydı başlangıcı (yüklenen süre için); durdurulunca sıfırlanır.
  DateTime? _trackRecordingStartedAt;
  Timer? _trackStatsTimer;

  /// `null` → boylama göre UTM zon; 35–41 → Orta Doğu için sabit zon (EPSG satırında).
  int? _utmEpsgDisplayZone;

  int _polygonClosedPieceCount() {
    var n = 0;
    if (_polygonVertices.length >= 3) n++;
    for (final p in _additionalPolygonPatches) {
      if (p.outer.length >= 3) n++;
    }
    return n;
  }

  double? _totalPolygonAreaM2() {
    double t = 0;
    var any = false;
    if (_polygonVertices.length >= 3) {
      t += _polygonHoles.isEmpty
          ? sphericalPolygonAreaM2(_polygonVertices)
          : sphericalPolygonWithHolesAreaM2(_polygonVertices, _polygonHoles);
      any = true;
    }
    for (final p in _additionalPolygonPatches) {
      if (p.outer.length >= 3) {
        t += p.holes.isEmpty
            ? sphericalPolygonAreaM2(p.outer)
            : sphericalPolygonWithHolesAreaM2(p.outer, p.holes);
        any = true;
      }
    }
    return any ? t : null;
  }

  void _resetKmlPrimaryPolygonVisual() {
    _kmlPrimaryPolygonFillArgb32 = null;
    _kmlPrimaryPolygonStrokeArgb32 = null;
    _kmlPrimaryPolygonStrokeWidthPx = null;
    _kmlPrimaryPolygonDrawStrokeOutline = null;
  }

  void _clearKmlImportedPolylinesAndPoints() {
    _kmlImportStyledPolylines.clear();
    _kmlImportPoints.clear();
    _gpxImportTrackLinesOnly.clear();
    _gpxImportRouteLinesOnly.clear();
    _selectedKmlRouteVertexIndex = null;
  }

  static String _latLngDedupKey(LatLng p) =>
      '${p.latitude.toStringAsFixed(7)}_${p.longitude.toStringAsFixed(7)}';

  /// Yerel `.kml` yanındaki dosya veya `http`/`https` `Icon/href` ile ikon baytı doldurur.
  Future<List<KmlPointImport>> _hydrateKmlPointIcons(List<KmlPointImport> raw, String kmlFilePath) async {
    if (kIsWeb) return raw;
    final baseDir = File(kmlFilePath).parent.path;
    final out = <KmlPointImport>[];
    for (final pt in raw) {
      if (pt.iconImageBytes != null && pt.iconImageBytes!.isNotEmpty) {
        out.add(pt);
        continue;
      }
      final href = pt.iconHref?.trim();
      if (href == null || href.isEmpty) {
        out.add(pt);
        continue;
      }
      if (href.contains('://')) {
        if (href.startsWith('https://') || href.startsWith('http://')) {
          final uri = Uri.tryParse(href);
          if (uri != null) {
            final b = await fetchKmlIconBytesUri(uri);
            if (b != null && b.isNotEmpty) {
              out.add(pt.withResolvedIcon(b));
              continue;
            }
          }
        }
        out.add(pt);
        continue;
      }
      try {
        final full = p.normalize(p.join(baseDir, href.replaceAll('\\', p.separator)));
        final f = File(full);
        if (!await f.exists()) {
          out.add(pt);
          continue;
        }
        final len = await f.length();
        if (len > 4 * 1024 * 1024) {
          out.add(pt);
          continue;
        }
        final bytes = await f.readAsBytes();
        out.add(pt.withResolvedIcon(Uint8List.fromList(bytes)));
      } catch (_) {
        out.add(pt);
      }
    }
    return out;
  }

  /// KML `Point` + `IconStyle` / KMZ ikon baytı — rota köşe işareti ([vertexIndex] seçiliyse highlight).
  _KmlRouteMarkerStyle _kmlRouteMarkerStyleForVertex(LatLng p, int vertexIndex) {
    final k = _latLngDedupKey(p);
    final selectedHere = _selectedKmlRouteVertexIndex == vertexIndex;
    for (final e in _kmlImportPoints) {
      if (_latLngDedupKey(e.point) != k) continue;
      final useHi = selectedHere && e.hasKmlIconHighlight;
      final argb = useHi ? (e.iconHighlightColorArgb ?? e.iconColorArgb) : e.iconColorArgb;
      final bg = argb != null ? Color(argb) : Colors.deepPurple;
      final rawSc = useHi
          ? (e.iconHighlightScale ?? e.iconScale ?? 1.0)
          : (e.iconScale ?? 1.0);
      final sc = rawSc.clamp(0.5, 2.5).toDouble();
      final hot = useHi ? (e.iconHighlightHotspot ?? e.iconHotspot) : e.iconHotspot;
      final tip = e.balloonText?.trim();
      final tintArgb = useHi ? (e.iconHighlightColorArgb ?? e.iconColorArgb) : e.iconColorArgb;
      return _KmlRouteMarkerStyle(
        background: bg,
        markerScale: sc,
        iconBytes: e.iconImageBytes,
        hotspot: hot,
        placemarkName: e.name,
        balloonText: tip != null && tip.isNotEmpty ? tip : null,
        iconColorArgb: tintArgb,
      );
    }
    return const _KmlRouteMarkerStyle(background: Colors.deepPurple, markerScale: 1, iconColorArgb: null);
  }

  Alignment _kmlMarkerAlignmentForHotspot(KmlIconHotspot? hotspot, double imgW, double imgH) {
    final spot = hotspot ?? KmlIconHotspot.kmlDefault;
    final (pxL, pyB) = spot.anchorFromBottomLeft(imgW, imgH);
    final xAlign = 2.0 * (pxL / imgW) - 1.0;
    final yAlign = 2.0 * (pyB / imgH) - 1.0;
    return Alignment(xAlign, yAlign);
  }

  Marker _routeVertexNumberMarker(int index) {
    final v = _routeVertices[index];
    final st = _kmlRouteMarkerStyleForVertex(v, index);
    final sc = st.markerScale;
    final bytes = st.iconBytes;
    if (bytes != null && bytes.isNotEmpty) {
      final dim = kmlPngDimensionsIfAny(bytes);
      final iw = dim == null ? 48.0 : dim.$1.toDouble();
      final ih = dim == null ? 48.0 : dim.$2.toDouble();
      final dw = (iw * sc).clamp(16.0, 220.0);
      final dh = (ih * sc).clamp(16.0, 220.0);
      final align = _kmlMarkerAlignmentForHotspot(st.hotspot, dw, dh);
      Widget img = Image.memory(
        bytes,
        width: dw,
        height: dh,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
      if (st.iconColorArgb != null) {
        img = ColorFiltered(
          colorFilter: ColorFilter.mode(Color(st.iconColorArgb!), BlendMode.modulate),
          child: img,
        );
      }
      final tip = st.balloonText ?? st.placemarkName ?? 'Rota ${index + 1}';
      final stacked = Stack(
        clipBehavior: Clip.none,
        children: [
          img,
          Positioned(
            top: 0,
            right: 0,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Colors.black87,
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
      return Marker(
        point: v,
        width: dw,
        height: dh,
        alignment: align,
        child: Tooltip(
          message: tip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _setStateAndRefreshSheet(() {
              _selectedKmlRouteVertexIndex = _selectedKmlRouteVertexIndex == index ? null : index;
            }),
            child: stacked,
          ),
        ),
      );
    }
    final side = (34 * sc).clamp(28.0, 56.0);
    final tip = st.balloonText ?? st.placemarkName ?? 'Rota ${index + 1}';
    return Marker(
      point: v,
      width: side,
      height: side,
      child: Tooltip(
        message: tip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _setStateAndRefreshSheet(() {
            _selectedKmlRouteVertexIndex = _selectedKmlRouteVertexIndex == index ? null : index;
          }),
          child: CircleAvatar(
            radius: (15 * sc).clamp(12.0, 24.0),
            backgroundColor: st.background,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: (11 / sc).clamp(9.0, 13.0),
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _pinSheetTitle(_MapUserPin pin, int displayIndex) {
    final t = pin.name?.trim();
    if (t != null && t.isNotEmpty) return t;
    return 'İşaret ${displayIndex + 1}';
  }

  Color _pinColor(_MapUserPin pin) =>
      _kMapUserPinPalette[pin.colorIndex.clamp(0, _kMapUserPinPalette.length - 1)];

  Future<void> _showMapPinEditor(int index) async {
    if (!mounted || index < 0 || index >= _userPins.length) return;
    final pin = _userPins[index];
    final nameCtrl = TextEditingController(text: pin.name ?? '');
    final noteCtrl = TextEditingController(text: pin.note ?? '');
    var colorIdx = pin.colorIndex.clamp(0, _kMapUserPinPalette.length - 1);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPinDlg) => AlertDialog(
          title: Text('İşaret ${index + 1}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Renk', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var c = 0; c < _kMapUserPinPalette.length; c++)
                      InkWell(
                        onTap: () => setPinDlg(() => colorIdx = c),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _kMapUserPinPalette[c],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorIdx == c ? Colors.white : Colors.black45,
                              width: colorIdx == c ? 3 : 1,
                            ),
                            boxShadow: const [
                              BoxShadow(blurRadius: 3, color: Colors.black26),
                            ],
                          ),
                          child: colorIdx == c ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Görünen ad',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Not / bilgi',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('İptal')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: Text('Sil', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    final note = noteCtrl.text.trim();
    nameCtrl.dispose();
    noteCtrl.dispose();
    if (!mounted) return;
    if (action == 'delete') {
      _setStateAndRefreshSheet(() {
        _pinDemMeters.remove(pin.id);
        _userPins.removeAt(index);
        _status = 'İşaret silindi.';
      });
      return;
    }
    if (action != 'save') return;
    _setStateAndRefreshSheet(() {
      pin.name = name.isEmpty ? null : name;
      pin.note = note.isEmpty ? null : note;
      pin.colorIndex = colorIdx.clamp(0, _kMapUserPinPalette.length - 1);
      _status = '${_pinSheetTitle(pin, index)} güncellendi.';
    });
  }

  Widget _mapPinMarkerButton({required int index, required _MapUserPin pin}) {
    final title = _pinSheetTitle(pin, index);
    final note = pin.note?.trim();
    final tip =
        note != null && note.isNotEmpty ? '$title\n$note\n\nDokunun: ad · renk · not' : '$title\nDokunun: düzenle';
    final c = _pinColor(pin);
    return Tooltip(
      message: tip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_showMapPinEditor(index)),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(Icons.place, color: c, size: 38, shadows: const [
              Shadow(blurRadius: 4, color: Colors.black54),
            ]),
          ),
        ),
      ),
    );
  }

  /// KMZ/KML durum metni ön eki: çizgi segmenti ve işaret noktası sayıları.
  String _kmlImportLoadStatusPrefix() {
    final parts = <String>[];
    if (_kmlImportStyledPolylines.isNotEmpty) {
      parts.add('${_kmlImportStyledPolylines.length} çizgi');
    }
    if (_kmlImportPoints.isNotEmpty) {
      parts.add('${_kmlImportPoints.length} işaret');
    }
    if (parts.isEmpty) return '';
    return '${parts.join(' · ')} · ';
  }

  void _handleMapTap(LatLng point) {
    switch (_tapMode) {
      case _MapTapMode.viewOnly:
        break;
      case _MapTapMode.placemark:
        setState(() {
          final id = 'p${_pinIdSeq++}';
          final c = _selectedPinPaletteIndex.clamp(0, _kMapUserPinPalette.length - 1);
          _userPins.add(_MapUserPin(id: id, point: point, colorIndex: c));
          _pinDemMeters[id] = null;
          _status =
              'İşaret #${_userPins.length} eklendi. Pimlere dokunarak ad / renk / not. '
              'Alttaki renk çipleri sonraki işaret rengi.';
        });
        break;
      case _MapTapMode.mapAnchor:
        setState(() {
          _followGps = false;
          _myPosition = point;
          _status = 'Konum haritadan sabitlendi. «GPS takibini aç» ile tekrar canlı.';
        });
        break;
      case _MapTapMode.routeVertex:
        setState(() {
          _clearKmlImportedPolylinesAndPoints();
          _routeVertices.add(point);
          final n = _routeVertices.length;
          _status =
              'Rota: $n. köşe eklendi (şu an toplam $n nokta${n == 1 ? '; devam edin' : ''}).';
        });
        break;
      case _MapTapMode.polygonVertex:
        setState(() {
          _resetKmlPrimaryPolygonVisual();
          _polygonHoles.clear();
          _additionalPolygonPatches.clear();
          _polygonVertices.add(point);
          final n = _polygonVertices.length;
          _status = 'Alan: $n. köşe eklendi (toplam $n köşe).';
        });
        break;
      case _MapTapMode.vectorFeature:
        unawaited(_queryVectorMbtilesFeatureAt(point));
        break;
    }
    _refreshMapDetailsSheetIfOpen();
  }

  Future<void> _queryVectorMbtilesFeatureAt(LatLng point) async {
    if (!mounted || kIsWeb || !_usesOfflineVectorBasemap) return;
    final path = await MbtilesStorage.getSavedPath();
    if (path == null || !await File(path).exists()) return;
    final z = _readMapZoom()
        .round()
        .clamp(
          _mbtilesMinNativeZoom,
          math.min(_mbtilesMaxNativeZoom, _vectorMbtilesPreviewMaxZoom),
        )
        .toInt();
    final reader = MbtilesRawTileReader(path);
    try {
      final hits = MbtilesVectorPick.pickAt(reader: reader, point: point, zoom: z);
      if (!mounted) return;
      await showVectorMbtilesPickSheet(context, at: point, hits: hits);
    } finally {
      reader.dispose();
    }
  }

  void _coerceTapModeIfVectorUnavailable() {
    if (_tapMode == _MapTapMode.vectorFeature && !_usesOfflineVectorBasemap) {
      _tapMode = _MapTapMode.viewOnly;
    }
  }

  void _refreshMapDetailsSheetIfOpen() {
    final setSheetState = _mapDetailsSheetSetState;
    if (setSheetState != null) {
      setSheetState(() {});
    }
  }

  void _setStateAndRefreshSheet(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    _refreshMapDetailsSheetIfOpen();
  }

  @visibleForTesting
  void debugHandleMapTap(LatLng point) => _handleMapTap(point);

  @visibleForTesting
  LatLng? get debugWaypoint1 => _waypoint1;

  @visibleForTesting
  int get debugRouteVertexCount => _routeVertices.length;

  @visibleForTesting
  LatLng? get debugWaypoint2 => _waypoint2;

  @visibleForTesting
  LatLng? get debugMyPosition => _myPosition;

  @visibleForTesting
  bool get debugFollowGps => _followGps;

  @visibleForTesting
  int get debugPolygonVertexCount => _polygonVertices.length;

  @visibleForTesting
  bool get debugRecordingTrack => _recordingTrack;

  @visibleForTesting
  void debugToggleTrackRecording() => _toggleTrackRecording();

  @visibleForTesting
  LatLng? get debugGpsLive => _gpsLive;

  @visibleForTesting
  LatLng get debugMapHudCenter => _mapHudCenter;

  @visibleForTesting
  void debugSelectTapModeWaypoint1() => setState(() {
        _tapMode = _MapTapMode.placemark;
        _selectedPinPaletteIndex = 0;
      });

  @visibleForTesting
  void debugSelectTapModeWaypoint2() => setState(() {
        _tapMode = _MapTapMode.placemark;
        _selectedPinPaletteIndex = 1;
      });

  @visibleForTesting
  void debugSelectTapModeMapAnchor() => setState(() => _tapMode = _MapTapMode.mapAnchor);

  @visibleForTesting
  void debugSelectTapModeRouteVertex() => setState(() => _tapMode = _MapTapMode.routeVertex);

  @visibleForTesting
  void debugSelectTapModePolygonVertex() => setState(() => _tapMode = _MapTapMode.polygonVertex);

  @visibleForTesting
  void debugUndoLastRouteVertex() {
    if (_routeVertices.isEmpty) return;
    _setStateAndRefreshSheet(() {
      _clearKmlImportedPolylinesAndPoints();
      _routeVertices.removeLast();
    });
  }

  @visibleForTesting
  void debugClearRouteVertices() {
    if (_routeVertices.isEmpty) return;
    _setStateAndRefreshSheet(() {
      _clearKmlImportedPolylinesAndPoints();
      _routeVertices.clear();
      _status = 'Rota temizlendi.';
    });
  }

  @visibleForTesting
  _MapBaseLayer get debugMapBase => _mapBase;

  @visibleForTesting
  _MapBaseLayer? get debugOverlayBaseLayer => _overlayBaseLayer;

  @visibleForTesting
  double get debugOverlayOpacity => _overlayOpacity;

  @visibleForTesting
  MapGridMode get debugMapGridMode => _mapGridMode;

  @visibleForTesting
  bool get debugHillshadeEnabled => _hillshadeOverlayEnabled;

  @visibleForTesting
  double get debugHillshadeOpacity => _hillshadeOpacity;

  @override
  void initState() {
    super.initState();
    RealtimePttServiceProvider.configure(
      RealtimePttConfig(
        backend: widget.pttBackend,
        currentUserId: _collabUserId,
        maxMembers: 5,
        websocketUri: widget.pttWebsocketUrl == null
            ? null
            : Uri.tryParse(widget.pttWebsocketUrl!),
      ),
    );
    _pttUxSub = _pttService.uxNoticeStream.listen(_onPttUxNotice);
    _pttService.stateListenable.addListener(_onPttCollabListenable);
    _pttService.memberAudioPrefsListenable.addListener(_onPttCollabListenable);
    _attachCollabPeerStream();
    _attachCollabTargetStream();
    MapRoomDeepLinkController.instance.addListener(_flushHaritaOdaDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _flushHaritaOdaDeepLink());
    _restartShareLocationTimer();
    _initConnectivityAndPosition();
    unawaited(_restoreOfflineBasemapIfAny());
    unawaited(_loadMapDisplayPrefs());
    unawaited(_loadCasRemoteLastSyncAt());
    unawaited(_refreshCasRemoteProfileSummary());
  }

  void _flushHaritaOdaDeepLink() {
    if (!mounted) return;
    final invite = MapRoomDeepLinkController.instance.takePending();
    if (invite == null) return;
    unawaited(_joinRoomWithCredentials(invite.roomKey, invite.password, openingAsCreator: false));
  }

  Future<void> _loadMapDisplayPrefs() async {
    final data = await MapDisplayPrefs.load();
    if (!mounted) return;
    _MapBaseLayer? parsed;
    final n = data.onlineBaseLayerName;
    if (n != null) {
      for (final v in _MapBaseLayer.values) {
        if (v.name == n) {
          parsed = v;
          break;
        }
      }
    }
    _MapBaseLayer? overlayParsed;
    final on = data.overlayBaseLayerName;
    if (on != null) {
      for (final v in _MapBaseLayer.values) {
        if (v.name == on) {
          overlayParsed = v;
          break;
        }
      }
    }
    setState(() {
      _hudCoordFormat = data.hudCoordFormat;
      _distanceUnit = data.distanceUnit;
      _areaUnit = data.areaUnit;
      _baseLayerOpacity = data.baseLayerOpacity;
      if (parsed != null) _mapBase = parsed;
      _overlayBaseLayer = overlayParsed;
      _overlayOpacity = data.overlayOpacity;
      _mapGridMode = data.gridMode;
      _hillshadeOverlayEnabled = data.hillshadeOverlayEnabled;
      _hillshadeOpacity = data.hillshadeOpacity;
      _vectorMbtilesMaxTiles = data.vectorMbtilesMaxTiles;
      _vectorMbtilesPreviewMaxZoom = data.vectorMbtilesPreviewMaxZoom;
      _vectorMbtilesMaxLabels = data.vectorMbtilesMaxLabels;
      _vectorMbtilesScaleLabelsByZoom = data.vectorMbtilesScaleLabelsByZoom;
      _vectorMbtilesFillOpacity = data.vectorMbtilesFillOpacity;
      _vectorMbtilesStrokeOpacity = data.vectorMbtilesStrokeOpacity;
      _vectorMbtilesUseMaplibreEngine = data.vectorMbtilesUseMaplibreEngine;
      _ntv2GsbPathPref = data.ntv2GsbPath;
      _tacticalHudEnabled = data.tacticalCrosshairEnabled;
      _losThreatHalfWidthM = data.losThreatTubeHalfWidthM;
      _losThreatTargetHalfWidthM = data.losThreatTubeTargetHalfWidthM;
      _cas3dEnabledTubeIds
        ..clear()
        ..addAll(data.cas3dEnabledTubeIds);
      _cas3dPresetMode = data.cas3dTubePresetMode;
      _casRemoteAutoSyncEnabled = data.casRemoteAutoSyncEnabled;
      _casRemoteAutoSyncSec = data.casRemoteAutoSyncSec;
      _coerceTapModeIfVectorUnavailable();
    });
    _rescheduleCasRemoteAutoSync();
    if (_tacticalHudEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _mapHudCenter = _readMapCenterLatLng();
          _mapRotationDeg = _readMapRotationDeg();
        });
      });
    }
    if (_usesOfflineVectorBasemap) _scheduleVectorMbtilesOverlayRebuild();
    unawaited(_reloadMaplibreStyleNow());
    await _reloadNtv2GridFromSavedPath();
  }

  Future<void> _persistMapDisplayPrefs() async {
    await MapDisplayPrefs(
      hudCoordFormat: _hudCoordFormat,
      distanceUnit: _distanceUnit,
      areaUnit: _areaUnit,
      onlineBaseLayerName: _mapBase.name,
      baseLayerOpacity: _baseLayerOpacity,
      overlayBaseLayerName: _overlayBaseLayer?.name,
      overlayOpacity: _overlayOpacity,
      gridMode: _mapGridMode,
      hillshadeOverlayEnabled: _hillshadeOverlayEnabled,
      hillshadeOpacity: _hillshadeOpacity,
      vectorMbtilesMaxTiles: _vectorMbtilesMaxTiles,
      vectorMbtilesPreviewMaxZoom: _vectorMbtilesPreviewMaxZoom,
      vectorMbtilesMaxLabels: _vectorMbtilesMaxLabels,
      vectorMbtilesScaleLabelsByZoom: _vectorMbtilesScaleLabelsByZoom,
      vectorMbtilesFillOpacity: _vectorMbtilesFillOpacity,
      vectorMbtilesStrokeOpacity: _vectorMbtilesStrokeOpacity,
      vectorMbtilesUseMaplibreEngine: _vectorMbtilesUseMaplibreEngine,
      ntv2GsbPath: _ntv2GsbPathPref,
      tacticalCrosshairEnabled: _tacticalHudEnabled,
      losThreatTubeHalfWidthM: _losThreatHalfWidthM,
      losThreatTubeTargetHalfWidthM: _losThreatTargetHalfWidthM,
      cas3dEnabledTubeIds: _cas3dEnabledTubeIds,
      cas3dTubePresetMode: _cas3dPresetMode,
      casRemoteAutoSyncEnabled: _casRemoteAutoSyncEnabled,
      casRemoteAutoSyncSec: _casRemoteAutoSyncSec,
    ).save();
  }

  Future<void> _refreshCasRemoteProfileSummary() async {
    final url = await CasRemotePrefs.getUrl();
    final tenant = await CasRemotePrefs.getTenant();
    final tenantAsHeader = await CasRemotePrefs.getTenantAsHeader();
    final limit = await CasRemotePrefs.getLimit();
    final maxPages = await CasRemotePrefs.getMaxPages();
    final minAlt = await CasRemotePrefs.getMinAlt();
    final maxAlt = await CasRemotePrefs.getMaxAlt();
    final bbox = await CasRemotePrefs.getBbox();
    final paramStyle = await CasRemotePrefs.getParamStyle();
    final cursorStyle = await CasRemotePrefs.getCursorParamStyle();
    final strictNextCursor = await CasRemotePrefs.getStrictNextCursor();
    if (!mounted) return;
    final chips = <String>[];
    if (url == null) {
      chips.add('ayarsiz');
    } else {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.host.isNotEmpty) {
        chips.add('host:${uri.host}');
      } else {
        chips.add('url:hazir');
      }
    }
    if (tenant != null && tenant.isNotEmpty) {
      chips.add(tenantAsHeader ? 'tenant:header' : 'tenant:query');
    }
    chips.add('param:${paramStyle.name}');
    chips.add('cursor:${cursorStyle.name}');
    chips.add(strictNextCursor ? 'next:strict' : 'next:fallback');
    if (limit != null) chips.add('limit:$limit');
    chips.add('maxPages:$maxPages');
    if (minAlt != null || maxAlt != null) {
      chips.add('alt:${minAlt?.toStringAsFixed(0) ?? '*'}-${maxAlt?.toStringAsFixed(0) ?? '*'}');
    }
    if (bbox != null && bbox.isNotEmpty) chips.add('bbox:on');
    setState(() {
      _casRemoteProfileChips = chips;
    });
  }

  Future<void> _loadCasRemoteLastSyncAt() async {
    final dt = await CasRemotePrefs.getLastSyncAt();
    if (!mounted || dt == null) return;
    setState(() => _casRemoteLastSyncAt = dt);
  }

  Widget _buildCasRemoteProfileChip(BuildContext context, String value) {
    final scheme = Theme.of(context).colorScheme;
    IconData icon = Icons.tune;
    Color bg = scheme.surfaceContainerHighest;
    var tip = value;
    if (value.startsWith('host:') || value.startsWith('url:')) {
      icon = Icons.cloud_outlined;
      bg = scheme.primaryContainer;
      tip = 'Uzak CAS endpoint hedefi';
    } else if (value.startsWith('tenant:')) {
      icon = Icons.badge_outlined;
      bg = value.contains('header') ? scheme.secondaryContainer : scheme.tertiaryContainer;
      tip = value.contains('header')
          ? 'Tenant X-Tenant-Id header ile gonderilir'
          : 'Tenant query parametresi ile gonderilir';
    } else if (value.startsWith('param:')) {
      icon = Icons.code_outlined;
      tip = 'Query alan isim stili (camelCase/snake_case)';
    } else if (value.startsWith('cursor:')) {
      icon = Icons.alt_route_outlined;
      tip = 'Istekte kullanilan cursor query anahtari';
    } else if (value.startsWith('next:strict')) {
      icon = Icons.warning_amber_rounded;
      bg = Colors.orange.withValues(alpha: 0.20);
      tip = 'Yalnizca secilen cursor alanindan next okunur';
    } else if (value.startsWith('next:fallback')) {
      icon = Icons.swap_horiz_outlined;
      tip = 'nextCursor/next_cursor/cursor.next fallback okumasi acik';
    } else if (value.startsWith('limit:') || value.startsWith('maxPages:')) {
      icon = Icons.format_list_numbered_outlined;
      tip = value.startsWith('limit:')
          ? 'Sayfa basi kayit limiti'
          : 'Maksimum islenecek sayfa sayisi';
    } else if (value.startsWith('alt:')) {
      icon = Icons.height_outlined;
      bg = scheme.tertiaryContainer;
      tip = 'Irtifa filtre araligi (metre)';
    } else if (value.startsWith('bbox:')) {
      icon = Icons.crop_free_outlined;
      bg = scheme.secondaryContainer;
      tip = 'BBOX cografi filtre aktif';
    } else if (value == 'ayarsiz') {
      icon = Icons.settings_suggest_outlined;
      bg = scheme.errorContainer;
      tip = 'CAS remote endpoint henuz ayarlanmamis';
    }
    return Tooltip(
      message: tip,
      child: Chip(
        avatar: Icon(icon, size: 14),
        backgroundColor: bg,
        label: Text(value, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _copyCasRemoteProfileSummary() async {
    final text = await _buildCasRemoteProfileReport();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _status = 'CAS remote profil panoya kopyalandi.');
  }

  Future<void> _shareCasRemoteProfileSummary() async {
    final text = await _buildCasRemoteProfileReport();
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'CAS Remote Profil'),
    );
    if (!mounted) return;
    setState(() => _status = 'CAS remote profil paylasildi.');
  }

  Future<void> _resetCasRemoteLastSync() async {
    await CasRemotePrefs.setLastSyncAt(null);
    if (!mounted) return;
    setState(() => _casRemoteLastSyncAt = null);
    await _refreshCasRemoteProfileSummary();
    if (!mounted) return;
    setState(() => _status = 'CAS son senkron bilgisi sifirlandi.');
  }

  Future<String> _buildCasRemoteProfileReport() async {
    final url = await CasRemotePrefs.getUrl();
    final auth = await CasRemotePrefs.getAuthRaw();
    final tenant = await CasRemotePrefs.getTenant();
    final tenantAsHeader = await CasRemotePrefs.getTenantAsHeader();
    final paramStyle = await CasRemotePrefs.getParamStyle();
    final cursorStyle = await CasRemotePrefs.getCursorParamStyle();
    final strictNextCursor = await CasRemotePrefs.getStrictNextCursor();
    final limit = await CasRemotePrefs.getLimit();
    final maxPages = await CasRemotePrefs.getMaxPages();
    final minAlt = await CasRemotePrefs.getMinAlt();
    final maxAlt = await CasRemotePrefs.getMaxAlt();
    final bbox = await CasRemotePrefs.getBbox();
    final endpoint = url?.trim().isNotEmpty == true ? url! : '(ayarsiz)';
    final hasAuth = auth?.trim().isNotEmpty == true ? 'evet' : 'hayir';
    final tenantLine = (tenant == null || tenant.isEmpty)
        ? '(yok)'
        : '$tenant (${tenantAsHeader ? 'header' : 'query'})';
    final altLine = (minAlt == null && maxAlt == null)
        ? '(yok)'
        : '${minAlt?.toStringAsFixed(0) ?? '*'}..${maxAlt?.toStringAsFixed(0) ?? '*'} m';
    final bboxLine = (bbox == null || bbox.isEmpty) ? '(yok)' : bbox;
    final limitLine = limit?.toString() ?? '(yok)';
    final syncLine = _casRemoteLastSyncAt == null
        ? '(yok)'
        : '${_casRemoteLastSyncAt!.year.toString().padLeft(4, '0')}-'
              '${_casRemoteLastSyncAt!.month.toString().padLeft(2, '0')}-'
              '${_casRemoteLastSyncAt!.day.toString().padLeft(2, '0')} '
              '${_casRemoteLastSyncAt!.hour.toString().padLeft(2, '0')}:'
              '${_casRemoteLastSyncAt!.minute.toString().padLeft(2, '0')}:'
              '${_casRemoteLastSyncAt!.second.toString().padLeft(2, '0')}';
    return [
      'CAS remote profil',
      'endpoint: $endpoint',
      'auth: $hasAuth',
      'tenant: $tenantLine',
      'param_style: ${paramStyle.name}',
      'cursor_param: ${cursorStyle.name}',
      'next_cursor: ${strictNextCursor ? 'strict' : 'fallback'}',
      'limit: $limitLine',
      'max_pages: $maxPages',
      'son_sync: $syncLine',
      'alt_filter: $altLine',
      'bbox: $bboxLine',
    ].join('\n');
  }

  /// Çevrimiçi ana altlık ile aynı kaynaktan ikinci katman çizmeyi atla (gereksiz trafik).
  bool get _shouldDrawOverlayOnline =>
      _overlayBaseLayer != null && _overlayBaseLayer != _mapBase;

  Future<void> _openAttributionUri(Uri uri) async {
    try {
      if (!mounted) return;
      if (!await canLaunchUrl(uri)) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _registerAttributionsForRasterBase(
    _MapBaseLayer layer,
    void Function(String id, String text, Uri uri) register,
  ) {
    switch (layer) {
      case _MapBaseLayer.osm:
        register(
          'osm',
          'OpenStreetMap katkıcıları',
          Uri.parse('https://www.openstreetmap.org/copyright'),
        );
      case _MapBaseLayer.humanitarian:
        register(
          'hot',
          'Humanitarian OpenStreetMap Team ve OpenStreetMap katkıcıları',
          Uri.parse('https://www.hotosm.org/'),
        );
      case _MapBaseLayer.cartoLight:
      case _MapBaseLayer.cartoDark:
        register(
          'carto',
          'CARTO, © OpenStreetMap katkıcıları',
          Uri.parse('https://carto.com/help/building-maps/basemap-list/'),
        );
      case _MapBaseLayer.openTopo:
        register(
          'opentopo',
          'OpenTopoMap, © OpenStreetMap katkıcıları',
          Uri.parse('https://opentopomap.org/'),
        );
      case _MapBaseLayer.esriImagery:
        register(
          'esri_img',
          'Esri, Maxar, Earthstar Geographics ve diğer katkıcılar (World Imagery)',
          Uri.parse('https://www.esri.com/en-us/legal/terms/full-attribution-esri'),
        );
    }
  }

  bool get _usesOfflineVectorBasemap =>
      _rasterSource == _MapRasterSource.mbtiles &&
      !kIsWeb &&
      _offlineMbtilesKind == MbtilesBasemapKind.vector;

  bool get _maplibreVectorActive =>
      _usesOfflineVectorBasemap && !kIsWeb && _vectorMbtilesUseMaplibreEngine;

  LatLng _readMapCenterLatLng() {
    if (_maplibreVectorActive) {
      final c = _maplibreController?.getCamera();
      if (c != null) return LatLng(c.center.lat, c.center.lon);
    }
    return _mapController.camera.center;
  }

  double _readMapZoom() {
    if (_maplibreVectorActive) {
      final c = _maplibreController?.getCamera();
      if (c != null) return c.zoom;
    }
    return _mapController.camera.zoom;
  }

  double _readMapRotationDeg() {
    if (_maplibreVectorActive) {
      final c = _maplibreController?.getCamera();
      if (c != null) return c.bearing;
    }
    return _mapController.camera.rotation;
  }

  void _moveMapCamera(LatLng center, double zoom) {
    if (_maplibreVectorActive && _maplibreController != null) {
      unawaited(
        _maplibreController!.moveCamera(
          center: ml.Geographic(lon: center.longitude, lat: center.latitude),
          zoom: zoom,
        ),
      );
    } else {
      _mapController.move(center, zoom);
    }
  }

  Future<void> _fitMapCameraToCoordinates(
    List<LatLng> coordinates, {
    EdgeInsets padding = const EdgeInsets.all(32),
  }) async {
    if (coordinates.isEmpty) return;
    if (_maplibreVectorActive && _maplibreController != null) {
      final pts = <ml.Geographic>[
        for (final e in coordinates) ml.Geographic(lon: e.longitude, lat: e.latitude),
      ];
      final b = ml.LngLatBounds.fromPoints(pts);
      await _maplibreController!.fitBounds(bounds: b, padding: padding);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: coordinates,
          padding: padding,
          maxZoom: 16,
          minZoom: 1,
        ),
      );
    }
  }

  Future<void> _reloadMaplibreStyleNow() async {
    if (kIsWeb || !_vectorMbtilesUseMaplibreEngine) {
      if (!mounted) return;
      setState(() {
        _maplibreStyleJson = null;
        _maplibreStyleError = null;
      });
      return;
    }
    final path = await MbtilesStorage.getSavedPath();
    if (path == null || !await File(path).exists()) {
      if (!mounted) return;
      setState(() {
        _maplibreStyleJson = null;
        _maplibreStyleError = 'MBTiles yolu yok';
      });
      return;
    }
    try {
      final json = await buildOpenFreeMapLibertyStyleJsonWithMbtiles(
        mbtilesAbsolutePath: path,
        httpClient: http.Client(),
      );
      if (!mounted) return;
      setState(() {
        _maplibreStyleJson = json;
        _maplibreStyleError = null;
      });
      final ctrl = _maplibreController;
      if (ctrl != null && _vectorMbtilesUseMaplibreEngine) {
        ctrl.setStyle(json);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _maplibreStyleJson = null;
        _maplibreStyleError = '$e';
      });
    }
  }

  void _onMaplibreEvent(ml.MapEvent event) {
    if (event is ml.MapEventMoveCamera) {
      _onSyntheticMapPositionChanged();
    } else if (event is ml.MapEventCameraIdle) {
      _onSyntheticMapPositionChanged();
    } else if (event is ml.MapEventClick) {
      final p = LatLng(event.point.lat, event.point.lon);
      _handleMapTap(p);
    }
  }

  void _onSyntheticMapPositionChanged() {
    if (!_maplibreVectorActive) return;
    final ctr = _maplibreController;
    if (ctr == null) return;
    final cam = ctr.getCamera();
    final center = LatLng(cam.center.lat, cam.center.lon);
    final rot = cam.bearing;
    if ((center.latitude - _mapHudCenter.latitude).abs() < 1e-7 &&
        (center.longitude - _mapHudCenter.longitude).abs() < 1e-7 &&
        (rot - _mapRotationDeg).abs() < 1e-4) {
      return;
    }
    setState(() {
      _mapHudCenter = center;
      _mapRotationDeg = rot;
    });
  }

  List<ml.Layer> _maplibreUserAnnotationLayers({
    LatLng? tacticalRef,
    required LatLng tacticalHud,
    double? tacticalMeasM,
    LatLng? gpsForPins,
  }) {
    final layers = <ml.Layer>[];
    if (!_maplibreVectorActive) return layers;

    if (_geoPdfExtentPolygon.length >= 3) {
      final ring = [
        for (final p in _geoPdfExtentPolygon) ml.Geographic(lon: p.longitude, lat: p.latitude),
      ];
      layers.add(
        ml.PolygonLayer(
          polygons: [
            ml.Feature(geometry: ml.Polygon.from([ring])),
          ],
          color: Colors.deepOrange.withValues(alpha: 0.14),
          outlineColor: Colors.deepOrange.shade700,
        ),
      );
    } else if (_geoPdfExtentPolygon.length == 2) {
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                for (final p in _geoPdfExtentPolygon)
                  ml.Geographic(lon: p.longitude, lat: p.latitude),
              ]),
            ),
          ],
          color: Colors.deepOrange.shade600,
          width: 3,
        ),
      );
    }

    for (final pts in _coordinateGridSegments()) {
      if (pts.length < 2) continue;
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                for (final p in pts) ml.Geographic(lon: p.longitude, lat: p.latitude),
              ]),
            ),
          ],
          color: const Color(0xFF7FD0E8).withValues(alpha: 0.42),
          width: 2,
        ),
      );
    }

    if (_tacticalHudEnabled &&
        tacticalRef != null &&
        tacticalMeasM != null &&
        tacticalMeasM >= 0.5) {
      final ref = tacticalRef;
      final hud = tacticalHud;
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                ml.Geographic(lon: ref.longitude, lat: ref.latitude),
                ml.Geographic(lon: hud.longitude, lat: hud.latitude),
              ]),
            ),
          ],
          color: Colors.redAccent,
          width: 4,
        ),
      );
    }

    final threatOuter = _effectiveLosThreatTubeOuter;
    if (threatOuter != null && threatOuter.length >= 3) {
      final ring = [
        for (final p in threatOuter) ml.Geographic(lon: p.longitude, lat: p.latitude),
      ];
      layers.add(
        ml.PolygonLayer(
          polygons: [
            ml.Feature(geometry: ml.Polygon.from([ring])),
          ],
          color: Colors.redAccent.withValues(alpha: 0.14),
          outlineColor: Colors.redAccent.withValues(alpha: 0.85),
        ),
      );
    }
    if (_cas3dThreatPolygons.isNotEmpty) {
      for (final poly in _cas3dThreatPolygons) {
        if (poly.points.length < 3) continue;
        final ring = [
          for (final p in poly.points) ml.Geographic(lon: p.longitude, lat: p.latitude),
        ];
        layers.add(
          ml.PolygonLayer(
            polygons: [ml.Feature(geometry: ml.Polygon.from([ring]))],
            color: poly.color ?? Colors.redAccent.withValues(alpha: 0.12),
            outlineColor: poly.borderColor,
          ),
        );
      }
    }
    if (_cas3dThreatCenterLines.isNotEmpty) {
      for (final line in _cas3dThreatCenterLines) {
        if (line.points.length < 2) continue;
        layers.add(
          ml.PolylineLayer(
            polylines: [
              ml.Feature(
                geometry: ml.LineString.from([
                  for (final p in line.points) ml.Geographic(lon: p.longitude, lat: p.latitude),
                ]),
              ),
            ],
            color: line.color,
            width: line.strokeWidth.round().clamp(1, 8),
            dashArray: const [6, 4],
          ),
        );
      }
    }

    if (_polygonClosedPieceCount() > 0) {
      if (_polygonVertices.length >= 3) {
        final outer = [
          for (final p in _polygonVertices) ml.Geographic(lon: p.longitude, lat: p.latitude),
        ];
        final holes = <List<ml.Geographic>>[
          for (final h in _polygonHoles)
            if (h.length >= 3)
              [for (final p in h) ml.Geographic(lon: p.longitude, lat: p.latitude)],
        ];
        layers.add(
          ml.PolygonLayer(
            polygons: [
              ml.Feature(
                geometry: holes.isEmpty
                    ? ml.Polygon.from([outer])
                    : ml.Polygon.from([outer, ...holes]),
              ),
            ],
            color: (_kmlPrimaryPolygonFillArgb32 != null
                    ? Color(_kmlPrimaryPolygonFillArgb32!)
                    : Colors.teal)
                .withValues(alpha: 0.22),
            outlineColor: (_kmlPrimaryPolygonDrawStrokeOutline ?? true)
                ? (_kmlPrimaryPolygonStrokeArgb32 != null
                    ? Color(_kmlPrimaryPolygonStrokeArgb32!)
                    : Colors.teal.shade800)
                : Colors.transparent,
          ),
        );
      }
      for (final patch in _additionalPolygonPatches) {
        if (patch.outer.length < 3) continue;
        final outer = [
          for (final p in patch.outer) ml.Geographic(lon: p.longitude, lat: p.latitude),
        ];
        final holes = <List<ml.Geographic>>[
          for (final h in patch.holes)
            if (h.length >= 3)
              [for (final p in h) ml.Geographic(lon: p.longitude, lat: p.latitude)],
        ];
        layers.add(
          ml.PolygonLayer(
            polygons: [
              ml.Feature(
                geometry: holes.isEmpty
                    ? ml.Polygon.from([outer])
                    : ml.Polygon.from([outer, ...holes]),
              ),
            ],
            color: (patch.fillArgb32 != null ? Color(patch.fillArgb32!) : Colors.teal)
                .withValues(alpha: 0.2),
            outlineColor: patch.drawStrokeOutline
                ? (patch.strokeArgb32 != null ? Color(patch.strokeArgb32!) : Colors.teal.shade800)
                : Colors.transparent,
          ),
        );
      }
    }
    if (_polygonVertices.length == 2) {
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                for (final p in _polygonVertices)
                  ml.Geographic(lon: p.longitude, lat: p.latitude),
              ]),
            ),
          ],
          color: Colors.teal.shade600,
          width: 4,
        ),
      );
    }

    for (final e in _kmlImportStyledPolylines) {
      if (e.$2.length < 2) continue;
      final w = (e.$4 ?? 4).round().clamp(1, 12);
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                for (final p in e.$2) ml.Geographic(lon: p.longitude, lat: p.latitude),
              ]),
            ),
          ],
          color: Color(e.$3 ?? 0xFF673AB7),
          width: w,
        ),
      );
    }
    if (_kmlImportStyledPolylines.isEmpty && _routeVertices.length >= 2) {
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                for (final p in _routeVertices)
                  ml.Geographic(lon: p.longitude, lat: p.latitude),
              ]),
            ),
          ],
          color: Colors.deepPurple,
          width: 5,
        ),
      );
    }

    if (_recordedTrack.length >= 2) {
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                for (final p in _recordedTrack)
                  ml.Geographic(lon: p.longitude, lat: p.latitude),
              ]),
            ),
          ],
          color: Colors.lightGreen.shade700,
          width: 4,
        ),
      );
    }

    for (final line in _gpxImportRouteLinesOnly) {
      if (line.$2.length < 2) continue;
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                for (final p in line.$2) ml.Geographic(lon: p.longitude, lat: p.latitude),
              ]),
            ),
          ],
          color: const Color(_kGpxImportRouteStrokeArgb),
          width: _kGpxImportRouteStrokeWidth.round().clamp(1, 12),
        ),
      );
    }
    for (final line in _gpxImportTrackLinesOnly) {
      if (line.$2.length < 2) continue;
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                for (final p in line.$2) ml.Geographic(lon: p.longitude, lat: p.latitude),
              ]),
            ),
          ],
          color: const Color(_kGpxImportTrackStrokeArgb),
          width: _kGpxImportTrackStrokeWidth.round().clamp(1, 12),
        ),
      );
    }

    final g = gpsForPins;
    if (g != null && _userPins.isNotEmpty) {
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                ml.Geographic(lon: g.longitude, lat: g.latitude),
                ml.Geographic(
                  lon: _userPins.first.point.longitude,
                  lat: _userPins.first.point.latitude,
                ),
              ]),
            ),
          ],
          color: Colors.orange.shade700,
          width: 3,
        ),
      );
    }
    if (g != null && _userPins.length >= 2) {
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                ml.Geographic(lon: g.longitude, lat: g.latitude),
                ml.Geographic(
                  lon: _userPins[1].point.longitude,
                  lat: _userPins[1].point.latitude,
                ),
              ]),
            ),
          ],
          color: Colors.cyan.shade700,
          width: 2,
        ),
      );
    }
    if (_userPins.length >= 2) {
      layers.add(
        ml.PolylineLayer(
          polylines: [
            ml.Feature(
              geometry: ml.LineString.from([
                ml.Geographic(
                  lon: _userPins[0].point.longitude,
                  lat: _userPins[0].point.latitude,
                ),
                ml.Geographic(
                  lon: _userPins[1].point.longitude,
                  lat: _userPins[1].point.latitude,
                ),
              ]),
            ),
          ],
          color: Colors.amber.shade800,
          width: 2,
          dashArray: const [10, 6],
        ),
      );
    }

    final losSegs = _effectiveLosMapSegments;
    if (losSegs != null) {
      for (final s in losSegs) {
        if (s.points.length < 2) continue;
        layers.add(
          ml.PolylineLayer(
            polylines: [
              ml.Feature(
                geometry: ml.LineString.from([
                  for (final p in s.points) ml.Geographic(lon: p.longitude, lat: p.latitude),
                ]),
              ),
            ],
            color: s.blocked ? Colors.redAccent : Colors.green.shade600,
            width: 4,
          ),
        );
      }
      final blk = _effectiveLosBlockedApprox;
      if (blk != null) {
        layers.add(
          ml.CircleLayer(
            points: [
              ml.Feature(
                geometry: ml.Point(ml.Geographic(lon: blk.longitude, lat: blk.latitude)),
              ),
            ],
            color: Colors.red.shade900,
            radius: 6,
            strokeWidth: 2,
            strokeColor: Colors.white,
          ),
        );
      }
    }

    return layers;
  }

  List<ml.WidgetLayer> _maplibreWidgetLayers({
    required LatLng? gps,
    required PttQueueState pttState,
    required String? speakerId,
  }) {
    if (!_maplibreVectorActive) return const [];
    final markers = <ml.Marker>[];
    for (var i = 0; i < _polygonVertices.length; i++) {
      final p = _polygonVertices[i];
      markers.add(
        ml.Marker(
          point: ml.Geographic(lon: p.longitude, lat: p.latitude),
          size: const Size(30, 30),
          child: CircleAvatar(
            radius: 13,
            backgroundColor: Colors.teal.shade700,
            child: Text(
              '${i + 1}',
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }
    for (var i = 0; i < _routeVertices.length; i++) {
      markers.add(_routeVertexNumberMarkerMaplibre(i));
    }
    if (gps != null && !_shouldShareMyLocation()) {
      markers.add(
        ml.Marker(
          point: ml.Geographic(lon: gps.longitude, lat: gps.latitude),
          size: const Size(44, 44),
          child: Icon(Icons.navigation, color: Colors.blue.shade700, size: 40),
        ),
      );
    }
    for (var pi = 0; pi < _userPins.length; pi++) {
      final pin = _userPins[pi];
      markers.add(
        ml.Marker(
          point: ml.Geographic(lon: pin.point.longitude, lat: pin.point.latitude),
          size: const Size(48, 48),
          alignment: Alignment.center,
          child: _mapPinMarkerButton(index: pi, pin: pin),
        ),
      );
    }
    for (final e in _cas3dThreatLabels) {
      markers.add(
        ml.Marker(
          point: ml.Geographic(lon: e.$1.longitude, lat: e.$1.latitude),
          size: const Size(180, 36),
          alignment: Alignment.centerLeft,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                e.$2,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }
    for (final e in _collabPeerMarkersForMaplibre(pttState, speakerId)) {
      markers.add(e);
    }
    if (markers.isEmpty) return const [];
    return [ml.WidgetLayer(markers: markers)];
  }

  ml.Marker _routeVertexNumberMarkerMaplibre(int i) {
    final p = _routeVertices[i];
    return ml.Marker(
      point: ml.Geographic(lon: p.longitude, lat: p.latitude),
      size: const Size(32, 32),
      alignment: Alignment.center,
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.deepPurple.shade700,
        child: Text(
          '${i + 1}',
          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Iterable<ml.Marker> _collabPeerMarkersForMaplibre(
    PttQueueState pttState,
    String? speakerId,
  ) sync* {
    for (final e in _peerLiveByUser.entries) {
      if (e.key != _collabUserId || !_shouldShareMyLocation()) {
        yield _trackedPersonMarkerMaplibre(
          point: LatLng(e.value.latitude, e.value.longitude),
          label: pttState.members[e.key]?.displayName ?? e.key,
          isSpeaking: speakerId == e.key,
        );
      }
    }
    for (final t in _collabTargetsByUser.values) {
      yield _targetMarkerMaplibre(t);
    }
  }

  ml.Marker _trackedPersonMarkerMaplibre({
    required LatLng point,
    required String label,
    required bool isSpeaking,
  }) {
    return ml.Marker(
      point: ml.Geographic(lon: point.longitude, lat: point.latitude),
      size: Size(110, isSpeaking ? 92 : 74),
      alignment: Alignment.bottomCenter,
      child: _trackedPersonMarkerColumn(label: label, isSpeaking: isSpeaking),
    );
  }

  ml.Marker _targetMarkerMaplibre(MapCollabTargetReport t) {
    return ml.Marker(
      point: ml.Geographic(lon: t.longitude, lat: t.latitude),
      size: const Size(52, 52),
      alignment: Alignment.bottomCenter,
      child: Tooltip(
        message:
            'Hedef — ${t.displayName}\n${t.latitude.toStringAsFixed(6)}, ${t.longitude.toStringAsFixed(6)}'
            '${t.distanceFromReporterM != null ? '\n≈ ${t.distanceFromReporterM!.round()} m' : ''}'
            '${t.bearingFromReporterDeg != null ? ' · ${t.bearingFromReporterDeg!.toStringAsFixed(0)}°' : ''}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.priority_high,
              color: Colors.amberAccent,
              size: 38,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
            ),
            Text(
              'Hedef',
              style: TextStyle(
                color: Colors.amberAccent.shade100,
                fontSize: 9,
                shadows: const [Shadow(blurRadius: 2, color: Colors.black87)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SourceAttribution> _buildMapAttributions() {
    final ids = <String>{};
    final out = <SourceAttribution>[];

    void register(String id, String text, Uri uri) {
      if (!ids.add(id)) return;
      out.add(
        TextSourceAttribution(
          text,
          onTap: () => unawaited(_openAttributionUri(uri)),
        ),
      );
    }

    final onlineBase = _rasterSource == _MapRasterSource.online || kIsWeb;
    if (onlineBase) {
      _registerAttributionsForRasterBase(_mapBase, register);
    }
    if (onlineBase && _shouldDrawOverlayOnline && _overlayBaseLayer != null) {
      _registerAttributionsForRasterBase(_overlayBaseLayer!, register);
    }
    if (_rasterSource == _MapRasterSource.mbtiles && _overlayBaseLayer != null) {
      _registerAttributionsForRasterBase(_overlayBaseLayer!, register);
    }

    final hillOn = _hillshadeOverlayEnabled &&
        (_rasterSource == _MapRasterSource.online ||
            kIsWeb ||
            _mbTilesProvider != null ||
            _usesOfflineVectorBasemap);
    if (hillOn) {
      register(
        'esri_hill',
        'Esri World Hillshade (DEM gölgelendirmesi)',
        Uri.parse('https://www.esri.com/en-us/legal/terms/full-attribution-esri'),
      );
    }

    if (_maplibreVectorActive) {
      register(
        'openfreemap',
            'MapLibre + OpenFreeMap Liberty (stil, sprite, glif; yerel vektör karolar)',
        Uri.parse('https://openfreemap.org/'),
      );
    }

    return out;
  }

  List<List<LatLng>> _coordinateGridSegments() {
    if (_mapGridMode == MapGridMode.off) return const [];
    late LatLngBounds b;
    late double zoom;
    late LatLng center;
    if (_maplibreVectorActive && _maplibreController != null) {
      final r = _maplibreController!.getVisibleRegion();
      b = LatLngBounds(
        LatLng(r.latitudeSouth, r.longitudeWest),
        LatLng(r.latitudeNorth, r.longitudeEast),
      );
      zoom = _maplibreController!.getCamera().zoom;
      center = _readMapCenterLatLng();
    } else {
      final camera = _mapController.camera;
      if (camera.nonRotatedSize == MapCamera.kImpossibleSize) return const [];
      b = camera.visibleBounds;
      zoom = camera.zoom;
      center = camera.center;
    }
    if (_mapGridMode == MapGridMode.wgs84) {
      return MapCoordinateGrid.wgs84LineSegments(
        south: b.south,
        north: b.north,
        west: b.west,
        east: b.east,
        zoom: zoom,
      );
    }
    final zone = _utmEpsgDisplayZone ?? Wgs84UtmNorth.autoZoneFromLongitude(center.longitude);
    return MapCoordinateGrid.utmNorthLineSegments(
      south: b.south,
      north: b.north,
      west: b.west,
      east: b.east,
      zoom: zoom,
      utmZone: zone,
    );
  }

  void _onPttUxNotice(PttServiceNotice n) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_mapsPttServerNoticeTurkish(n))),
    );
  }

  void _onPttCollabListenable() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pttService.stateListenable.removeListener(_onPttCollabListenable);
    _pttService.memberAudioPrefsListenable.removeListener(_onPttCollabListenable);
    _connectivitySub?.cancel();
    _positionSub?.cancel();
    _pttUxSub?.cancel();
    _collabPeerSub?.cancel();
    _collabTargetSub?.cancel();
    MapRoomDeepLinkController.instance.removeListener(_flushHaritaOdaDeepLink);
    _shareLocationTimer?.cancel();
    _trackStatsTimer?.cancel();
    _casRemoteAutoSyncTimer?.cancel();
    _vectorMbtilesDebounce?.cancel();
    _vectorMbtilesReader?.dispose();
    _mbTilesProvider?.dispose();
    _geoPdfRasterJpeg = null;
    super.dispose();
  }

  Future<void> _reconnectPttWithSession(String sessionId) async {
    final prev = RealtimePttServiceProvider.instance;
    prev.stateListenable.removeListener(_onPttCollabListenable);
    prev.memberAudioPrefsListenable.removeListener(_onPttCollabListenable);
    _collabPeerSub?.cancel();
    _shareLocationTimer?.cancel();
    await RealtimePttServiceProvider.disposeCurrent();
    RealtimePttServiceProvider.configure(
      RealtimePttConfig(
        backend: widget.pttBackend,
        currentUserId: _collabUserId,
        maxMembers: 5,
        sessionId: sessionId,
        websocketUri: widget.pttWebsocketUrl == null
            ? null
            : Uri.tryParse(widget.pttWebsocketUrl!),
      ),
    );
    _pttUxSub?.cancel();
    _pttUxSub = RealtimePttServiceProvider.instance.uxNoticeStream.listen(_onPttUxNotice);
    final next = RealtimePttServiceProvider.instance;
    next.stateListenable.addListener(_onPttCollabListenable);
    next.memberAudioPrefsListenable.addListener(_onPttCollabListenable);
    if (mounted) {
      setState(() {
        _peerLiveByUser.clear();
        _collabTargetsByUser.clear();
      });
    } else {
      _peerLiveByUser.clear();
      _collabTargetsByUser.clear();
    }
    _attachCollabPeerStream();
    _attachCollabTargetStream();
    _restartShareLocationTimer();
  }

  void _attachCollabTargetStream() {
    _collabTargetSub?.cancel();
    _collabTargetSub =
        RealtimePttServiceProvider.instance.targetReports.listen((t) {
      if (!mounted) return;
      setState(() => _collabTargetsByUser[t.userId] = t);
      if (t.userId != _collabUserId && mounted) {
        final d = t.distanceFromReporterM;
        final b = t.bearingFromReporterDeg;
        final extra = (d != null && b != null)
            ? ' · ${d.round()} m / ${b.toStringAsFixed(0)}°'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hedef — ${t.displayName}: ${t.latitude.toStringAsFixed(5)}, ${t.longitude.toStringAsFixed(5)}$extra',
            ),
          ),
        );
      }
    });
  }

  String _roomOwnerUserId() {
    final st = _pttService.state;
    for (final e in st.members.entries) {
      if (e.value.role == GroupRole.owner) return e.key;
    }
    return _pttService.session.ownerUserId;
  }

  bool _isRoomOwner() {
    final st = _pttService.state;
    final m = st.members[_collabUserId];
    if (m != null) return m.role == GroupRole.owner;
    return _pttService.session.ownerUserId == _collabUserId;
  }

  bool _shouldShareMyLocation() {
    if (_isRoomOwner()) return _ownerSharesLiveLocation;
    return _memberSharesLocation;
  }

  Widget _trackedPersonMarkerColumn({
    required String label,
    required bool isSpeaking,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      verticalDirection: VerticalDirection.up,
      children: [
        Icon(
          Icons.person_pin_circle,
          size: 36,
          color: isSpeaking ? Colors.lightGreenAccent : Colors.deepOrange.shade400,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 104),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (isSpeaking) ...[
          const SizedBox(height: 3),
          const MapSpeakingWave(),
        ],
      ],
    );
  }

  Marker _trackedPersonMarker({
    required LatLng point,
    required String label,
    required bool isSpeaking,
  }) {
    return Marker(
      point: point,
      width: 110,
      height: isSpeaking ? 92 : 74,
      alignment: Alignment.bottomCenter,
      child: _trackedPersonMarkerColumn(label: label, isSpeaking: isSpeaking),
    );
  }

  void _attachCollabPeerStream() {
    _collabPeerSub?.cancel();
    _collabPeerSub = RealtimePttServiceProvider.instance.peerLocations.listen((loc) {
      if (!mounted) return;
      final ownerId = _roomOwnerUserId();

      setState(() => _peerLiveByUser[loc.userId] = loc);

      if (_followRoomOwnerLive &&
          _collabUserId != ownerId &&
          loc.userId == ownerId) {
        final z = _readMapZoom();
        _moveMapCamera(LatLng(loc.latitude, loc.longitude), z);
      }
    });
  }

  void _restartShareLocationTimer() {
    _shareLocationTimer?.cancel();
    if (!_shouldShareMyLocation()) return;
    _shareLocationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final g = _myPosition;
      if (g == null) return;
      RealtimePttServiceProvider.instance.broadcastPeerLocation(
        latitude: g.latitude,
        longitude: g.longitude,
        altitudeM: _gpsAltDeviceMeters,
      );
    });
  }

  Future<void> _joinRoomWithCredentials(
    String roomNorm,
    String pw, {
    required bool openingAsCreator,
  }) async {
    late final String sid;
    try {
      sid = MapRoomSession.deriveSessionId(roomNumber: roomNorm, password: pw);
    } on ArgumentError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oda ismi veya şifre geçersiz.')),
        );
      }
      return;
    }
    await _reconnectPttWithSession(sid);
    if (!mounted) return;
    setState(() {
      _inviteRoomNumber = roomNorm;
      _inviteRoomPassword = pw;
      if (openingAsCreator) {
        _ownerSharesLiveLocation = true;
        _memberSharesLocation = false;
        _followRoomOwnerLive = false;
      } else {
        _ownerSharesLiveLocation = false;
        _memberSharesLocation = false;
        _followRoomOwnerLive = true;
      }
    });
    _restartShareLocationTimer();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          openingAsCreator
              ? 'Oda hazır ($roomNorm). «Davet» ile bağlantı veya oda ismi + şifre gönderin.'
              : 'Odaya bağlandınız. Bağlantı açılmadıysa oda ismi + şifre yeterlidir.',
        ),
      ),
    );
  }

  Future<void> _promptCreateRoom() async {
    final roomCtrl = TextEditingController(
      text: 'ODA${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}',
    );
    final pwCtrl = TextEditingController(text: MapRoomCodes.generate(length: 6));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni harita odası'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Oda ismini siz verirsiniz. Şifre ilk açılışta otomatik üretilir; dilerseniz değiştirirsiniz. '
                'Sonradan «Davet bilgisini yenile» ile isim/şifreyi güncelleyebilirsiniz (eski bağlantı geçersiz kalır).',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roomCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Oda ismi',
                  hintText: 'Örn: TAKIM01',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pwCtrl,
                decoration: const InputDecoration(
                  labelText: 'Oda şifresi',
                  helperText: 'Otomatik — güvenli paylaşım için rastgele tutun',
                  border: OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    pwCtrl.text = MapRoomCodes.generate(length: 6);
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Yeni rastgele şifre'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oluştur')),
        ],
      ),
    );
    if (ok != true) return;
    final roomNorm = MapRoomSession.normalizeRoomNumber(roomCtrl.text);
    final pw = pwCtrl.text.trim();
    if (roomNorm.isEmpty || pw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oda ismi ve şifre gerekli.')),
        );
      }
      return;
    }
    await _joinRoomWithCredentials(roomNorm, pw, openingAsCreator: true);
  }

  Future<void> _promptRenewRoomInvite() async {
    if (!_isRoomOwner()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yalnızca oda kurucusu davet bilgisini yenileyebilir.')),
        );
      }
      return;
    }
    final roomCtrl = TextEditingController(text: _inviteRoomNumber ?? '');
    final pwCtrl = TextEditingController(text: MapRoomCodes.generate(length: 6));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Davet bilgisini yenile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Yeni oda ismi ve şifre belirlersiniz. Eski «Direkt aç» bağlantısı çalışmaz; '
                'ekipteki herkese güncel link veya yeni isim + şifre gönderin.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roomCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Yeni oda ismi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pwCtrl,
                decoration: const InputDecoration(
                  labelText: 'Yeni oda şifresi',
                  border: OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    pwCtrl.text = MapRoomCodes.generate(length: 6);
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Rastgele şifre üret'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Uygula')),
        ],
      ),
    );
    if (ok != true) return;
    final roomNorm = MapRoomSession.normalizeRoomNumber(roomCtrl.text);
    final pw = pwCtrl.text.trim();
    if (roomNorm.isEmpty || pw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oda ismi ve şifre gerekli.')),
        );
      }
      return;
    }
    await _joinRoomWithCredentials(roomNorm, pw, openingAsCreator: true);
  }

  Future<void> _promptJoinRoom() async {
    final roomCtrl = TextEditingController();
    final pwCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Harita odasına katıl'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mesajdaki bağlantı çalışmazsa aynı oda ismi ve şifreyi buraya yazmanız yeterlidir.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roomCtrl,
              decoration: const InputDecoration(
                labelText: 'Oda ismi',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwCtrl,
              decoration: const InputDecoration(
                labelText: 'Oda şifresi',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Katıl')),
        ],
      ),
    );
    if (ok != true) return;
    final roomNorm = MapRoomSession.normalizeRoomNumber(roomCtrl.text);
    final pw = pwCtrl.text.trim();
    if (roomNorm.isEmpty || pw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oda ismi ve şifre gerekli.')),
        );
      }
      return;
    }
    await _joinRoomWithCredentials(roomNorm, pw, openingAsCreator: false);
  }

  Future<void> _openCollabTargetReportSheet() async {
    final center = _myPosition ?? _readMapCenterLatLng();
    TileProvider? tp;
    if (_rasterSource == _MapRasterSource.online || kIsWeb) {
      tp = _onlineTileProvider();
    } else if (_mbTilesProvider != null) {
      tp = _mbTilesProvider;
    }
    await showCoordinateTargetPickerSheet(
      context,
      initialCenter: center,
      tileProvider: tp,
      onApply: (p) {
        final me = _myPosition;
        double? bear;
        double? dist;
        if (me != null) {
          dist = Geolocator.distanceBetween(
            me.latitude,
            me.longitude,
            p.latitude,
            p.longitude,
          );
          if (dist >= 0.5) {
            bear = _MapsPageState._bearingDeg360(me, p);
          }
        }
        final name = _pttService.state.members[_collabUserId]?.displayName ?? 'Ben';
        final report = MapCollabTargetReport(
          userId: _collabUserId,
          displayName: name,
          latitude: p.latitude,
          longitude: p.longitude,
          bearingFromReporterDeg: bear,
          distanceFromReporterM: dist,
          sentAt: DateTime.now(),
        );
        _pttService.broadcastTargetReport(report);
        if (mounted) {
          setState(() => _collabTargetsByUser[_collabUserId] = report);
        }
      },
    );
  }

  void _requestTalkWithGuards(void Function(VoidCallback fn) applyState) {
    final aud = _pttService.memberAudioPrefsFor(_collabUserId);
    if (aud.micSelfMuted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mikrofon sessize. Baloncuk → Ses bölümünden açın.')),
      );
      return;
    }
    final mem = _pttService.state.members[_collabUserId];
    if (mem?.muted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Susturuldunuz; konuşamazsınız.')),
      );
      return;
    }
    applyState(() {
      final r = _pttService.requestTalk(_collabUserId);
      if (r != QueueEnqueueResult.accepted && mounted) {
        final msg = switch (r) {
          QueueEnqueueResult.muted => 'Susturuldunuz; sıraya giremezsiniz.',
          QueueEnqueueResult.alreadySpeaker => 'Zaten konuşuyorsunuz.',
          QueueEnqueueResult.alreadyQueued => 'Zaten sıradasınız.',
          QueueEnqueueResult.forbidden => 'Konuşma isteği uygulanamadı.',
          _ => '',
        };
        if (msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    });
  }

  void _hubPttTalk() => _requestTalkWithGuards(setState);

  void _hubPttRelease() {
    setState(() {
      final ok = _pttService.releaseTalk(_collabUserId);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şu anda konuşmacı değilsiniz.')),
        );
      }
    });
  }

  void _hubForceNext() {
    setState(() {
      final ok = _pttService.forceNextSpeaker(actorId: _collabUserId);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sıradakine geçiş uygulanamadı.')),
        );
      }
    });
  }

  void _hubSelfRename() {
    unawaited(_showRenameDialog(
      targetUserId: _collabUserId,
      currentName: _pttService.state.members[_collabUserId]?.displayName ?? 'Ben',
      isSelf: true,
      updateState: (fn) => setState(fn),
    ));
  }

  Future<void> _shareCollabInvite() async {
    final code = _pttService.session.sessionId;
    final pw = _inviteRoomPassword;
    final g = _myPosition;
    final locLine = g != null
        ? 'Son bilinen konum (yaklaşık WGS84): ${g.latitude.toStringAsFixed(5)}, ${g.longitude.toStringAsFixed(5)}\n'
        : '';
    final room = _inviteRoomNumber;
    final buf = StringBuffer()..writeln('Blue Viper Pro — sesli harita odası');
    if (room != null &&
        room.isNotEmpty &&
        pw != null &&
        pw.isNotEmpty) {
      buf
        ..writeln('Direkt uygulamada aç (BlueViper yüklüyse bağlantıya dokun):')
        ..writeln(MapRoomInviteLink.build(roomKey: room, password: pw).toString())
        ..writeln('');
    }
    if (room != null && room.isNotEmpty) {
      buf.writeln('Oda ismi: $room');
    } else {
      buf.writeln('Oturum (yedek kimlik): $code');
    }
    if (pw != null && pw.isNotEmpty) {
      buf.writeln('Oda şifresi: $pw');
    }
    buf
      ..writeln(locLine)
      ..writeln(
        'Bağlantı açılmazsa: Harita sekmesi → «Konuşma» → «Katıl» → yukarıdaki oda ismi ve şifre.',
      )
      ..writeln(
        'Çoklu konum/hedef: APK derlemesinde PTT_WS_URL (wss://…) tanımlı olmalıdır.',
      );
    await SharePlus.instance.share(
      ShareParams(text: buf.toString(), subject: 'Blue Viper harita daveti'),
    );
  }

  Future<void> _initConnectivityAndPosition() async {
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    final initial = await Connectivity().checkConnectivity();
    _onConnectivityChanged(initial);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline =
        results.isNotEmpty && results.every((e) => e == ConnectivityResult.none);
    if (mounted) {
      setState(() {
        if (offline) {
          if (_rasterSource == _MapRasterSource.online) {
            _status = 'Ağ yok: çevrimiçi karolar görünmez. MBTiles yükleyin veya bağlantı bekleyin.';
          } else {
            _status = 'Ağ yok · offline harita kullanılıyor. GPS çalışmaya devam eder.';
          }
        }
      });
    }
    unawaited(_startPositionStreamWhenAllowed());
  }

  LocationSettings _locationSettingsForPositionStream() {
    const accuracy = LocationAccuracy.high;
    const distanceFilter = 8;
    if (kIsWeb) {
      return const LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
    }
    if (defaultTargetPlatform == TargetPlatform.android && _recordingTrack) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Blue Viper — iz kaydı',
          notificationText: 'GPS izi toplanıyor. Durdurmak için haritada «İz kaydı».',
          notificationChannelName: 'İz kaydı',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS && _recordingTrack) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
  }

  void _syncTrackStatsTimerForRecording(bool recording) {
    _trackStatsTimer?.cancel();
    _trackStatsTimer = null;
    if (!recording) return;
    _trackStatsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_recordingTrack) return;
      setState(() {});
    });
  }

  String _formatTrackRecordingElapsed() {
    final s = _trackRecordingStartedAt;
    if (s == null || !_recordingTrack) return '—';
    final d = DateTime.now().difference(s);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final sec = d.inSeconds.remainder(60);
    if (h > 0) return '${h}sa ${m}dk ${sec}sn';
    if (m > 0) return '${m}dk ${sec}sn';
    return '${sec}sn';
  }

  Future<void> _startPositionStreamWhenAllowed() async {
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service || !mounted) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) {
      return;
    }
    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _locationSettingsForPositionStream(),
    ).listen((pos) {
      if (!mounted) return;
      final ll = LatLng(pos.latitude, pos.longitude);
      _setStateAndRefreshSheet(() {
        _gpsLive = ll;
        _gpsAltDeviceMeters = pos.altitude;
        if (_followGps) {
          _myPosition = ll;
          final t = TimeOfDay.now();
          _status =
              'GPS ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} · canlı (≈8 m)';
        }
        if (_recordingTrack) {
          _recordedTrack.add(ll);
        }
      });
    });
  }

  Future<void> _refreshDemAll() async {
    _setStateAndRefreshSheet(() => _elevStatus = 'DEM alınıyor (ağ)…');
    final futures = <Future<void>>[];

    final p0 = _myPosition;
    if (p0 != null) {
      futures.add(() async {
        final e = await ElevationService.fetchMeters(p0.latitude, p0.longitude);
        if (!mounted) return;
        _setStateAndRefreshSheet(() => _demMy = e);
      }());
    }
    for (final pin in _userPins) {
      final id = pin.id;
      final pt = pin.point;
      futures.add(() async {
        final e = await ElevationService.fetchMeters(pt.latitude, pt.longitude);
        if (!mounted) return;
        _setStateAndRefreshSheet(() => _pinDemMeters[id] = e);
      }());
    }

    if (futures.isEmpty) {
      if (mounted) {
        _setStateAndRefreshSheet(() {
          _elevStatus = '';
          _status = 'Önce haritada nokta veya GPS konumu oluşturun.';
        });
      }
      return;
    }

    await Future.wait(futures);
    if (!mounted) return;
    _setStateAndRefreshSheet(() {
      _elevStatus = '';
      _status = 'DEM rakımları güncellendi.';
    });
  }

  String _tileUrlForBase(_MapBaseLayer base) {
    switch (base) {
      case _MapBaseLayer.osm:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case _MapBaseLayer.humanitarian:
        return 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
      case _MapBaseLayer.cartoLight:
        return 'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png';
      case _MapBaseLayer.cartoDark:
        return 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';
      case _MapBaseLayer.openTopo:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case _MapBaseLayer.esriImagery:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  List<String> _subdomainsForMapBase(_MapBaseLayer base) {
    switch (base) {
      case _MapBaseLayer.cartoLight:
      case _MapBaseLayer.cartoDark:
        return const [];
      case _MapBaseLayer.openTopo:
        return const ['a', 'b', 'c'];
      case _MapBaseLayer.osm:
      case _MapBaseLayer.humanitarian:
      case _MapBaseLayer.esriImagery:
        return const [];
    }
  }

  void _disposeVectorMbtilesDataOnly() {
    _vectorMbtilesReader?.dispose();
    _vectorMbtilesReader = null;
    _vectorMbtilesPolygons.clear();
    _vectorMbtilesPolylines.clear();
    _vectorMbtilesPoints.clear();
    _vectorMbtilesLabels.clear();
  }

  void _scheduleVectorMbtilesOverlayRebuild() {
    if (!_usesOfflineVectorBasemap) return;
    if (_maplibreVectorActive) return;
    _vectorMbtilesDebounce?.cancel();
    _vectorMbtilesDebounce = Timer(const Duration(milliseconds: 380), () {
      unawaited(_rebuildVectorMbtilesOverlay());
    });
  }

  Future<void> _rebuildVectorMbtilesOverlay() async {
    if (!mounted || !_usesOfflineVectorBasemap) return;
    final path = await MbtilesStorage.getSavedPath();
    if (path == null || !await File(path).exists()) return;
    final cam = _mapController.camera;
    final b = cam.visibleBounds;
    final z = cam.zoom
        .round()
        .clamp(
          _mbtilesMinNativeZoom,
          math.min(_mbtilesMaxNativeZoom, _vectorMbtilesPreviewMaxZoom),
        )
        .toInt();
    _vectorMbtilesReader ??= MbtilesRawTileReader(path);
    final labelCap = MbtilesVectorOverlayBuilder.effectiveLabelBudget(
      zoom: z,
      userMax: _vectorMbtilesMaxLabels,
      scaleByZoom: _vectorMbtilesScaleLabelsByZoom,
    );
    final data = MbtilesVectorOverlayBuilder.overlayForBounds(
      reader: _vectorMbtilesReader!,
      south: b.south,
      north: b.north,
      west: b.west,
      east: b.east,
      zoom: z,
      maxTiles: _vectorMbtilesMaxTiles,
      maxLabels: labelCap,
    );
    if (!mounted || !_usesOfflineVectorBasemap) return;
    final fillA = _vectorMbtilesFillOpacity;
    final strokeA = _vectorMbtilesStrokeOpacity;
    final borderA = (strokeA * 0.62).clamp(0.2, 1.0);
    setState(() {
      _vectorMbtilesPolygons
        ..clear()
        ..addAll(
          [
            for (final patch in data.polygonPatches)
              if (patch.outer.length >= 3)
                Polygon(
                  points: List<LatLng>.from(patch.outer),
                  holePointsList: patch.holes.isEmpty
                      ? null
                      : [for (final h in patch.holes) List<LatLng>.from(h)],
                  color: Color(patch.fillArgb).withValues(alpha: fillA),
                  borderStrokeWidth: 1.1,
                  borderColor: Color(patch.borderArgb).withValues(alpha: borderA),
                ),
          ],
        );
      _vectorMbtilesPolylines
        ..clear()
        ..addAll(
          [
            for (final s in data.lineSegments)
              if (s.points.length >= 2)
                Polyline(
                  points: s.points,
                  strokeWidth: s.strokeWidth,
                  color: Color(s.strokeArgb).withValues(alpha: strokeA),
                ),
          ],
        );
      _vectorMbtilesPoints
        ..clear()
        ..addAll(data.points);
      _vectorMbtilesLabels
        ..clear()
        ..addAll(data.labels);
    });
  }

  Future<void> _applySavedMbtilesAtPath(String path, {required bool moveMap}) async {
    if (kIsWeb) return;
    final probe = await MbtilesBasemapProbe.analyze(path);
    if (!probe.ok || probe.meta == null) return;
    var kind = await MbtilesStorage.getSavedKind() ?? probe.kind!;
    if (kind != probe.kind) {
      kind = probe.kind!;
      await MbtilesStorage.savePathWithKind(path, kind);
    }
    final meta = probe.meta!;
    final view = MbtilesRasterCheck.viewForMetadata(
      meta,
      _myPosition ?? _waypoint1 ?? const LatLng(39.925533, 32.866287),
    );
    if (!mounted) return;
    if (kind == MbtilesBasemapKind.vector) {
      _vectorMbtilesDebounce?.cancel();
      setState(() {
        _mbTilesProvider?.dispose();
        _mbTilesProvider = null;
        _disposeVectorMbtilesDataOnly();
        _rasterSource = _MapRasterSource.mbtiles;
        _offlineMbtilesKind = MbtilesBasemapKind.vector;
        _offlinePackLabel = '${path.split(RegExp(r'[\\/]')).last} · ${meta.name}';
        _mbtilesMinNativeZoom = (meta.minZoom ?? 0).floor().clamp(0, 22);
        _mbtilesMaxNativeZoom = (meta.maxZoom ?? 19).ceil().clamp(0, 22);
        _status = 'Offline vektör (önizleme): ${meta.name}';
        _coerceTapModeIfVectorUnavailable();
      });
      if (moveMap) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _moveMapCamera(view.$1, view.$2);
        });
      }
      _scheduleVectorMbtilesOverlayRebuild();
      unawaited(_reloadMaplibreStyleNow());
    } else {
      _vectorMbtilesDebounce?.cancel();
      setState(() {
        _disposeVectorMbtilesDataOnly();
        _mbTilesProvider?.dispose();
        _mbTilesProvider = MbTilesTileProvider.fromPath(path: path, silenceTileNotFound: true);
        _rasterSource = _MapRasterSource.mbtiles;
        _offlineMbtilesKind = MbtilesBasemapKind.raster;
        _offlinePackLabel = '${path.split(RegExp(r'[\\/]')).last} · ${meta.name}';
        _mbtilesMinNativeZoom = (meta.minZoom ?? 0).floor().clamp(0, 22);
        _mbtilesMaxNativeZoom = (meta.maxZoom ?? 19).ceil().clamp(0, 22);
        _status = 'Offline harita: ${meta.name}';
        _coerceTapModeIfVectorUnavailable();
      });
      if (moveMap) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _moveMapCamera(view.$1, view.$2);
        });
      }
    }
  }

  Future<void> _restoreOfflineBasemapIfAny() async {
    if (kIsWeb) return;
    final path = await MbtilesStorage.getSavedPath();
    if (path == null) return;
    if (!await File(path).exists()) {
      await MbtilesStorage.clearPath();
      return;
    }
    await _applySavedMbtilesAtPath(path, moveMap: true);
  }

  Future<void> _pickAndInstallMbtiles() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MBTiles şu an yalnızca mobil/masaüstü (native) derlemelerde.')),
        );
      }
      return;
    }
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mbtiles'],
    );
    if (pick == null || pick.files.single.path == null) return;
    final src = pick.files.single.path!;
    if (!mounted) return;
    setState(() => _status = 'MBTiles kopyalanıyor…');
    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/offline_basemap.mbtiles';
    try {
      await File(src).copy(destPath);
    } catch (_) {
      try {
        final bytes = await File(src).readAsBytes();
        await File(destPath).writeAsBytes(bytes, flush: true);
      } catch (e) {
        if (mounted) setState(() => _status = 'Dosya kopyalanamadı: $e');
        return;
      }
    }
    final probe = await MbtilesBasemapProbe.analyze(destPath);
    if (!probe.ok || probe.meta == null) {
      try {
        await File(destPath).delete();
      } catch (_) {}
      if (mounted) {
        setState(() => _status = probe.message ?? 'Paket geçersiz');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(probe.message ?? 'MBTiles açılamadı')),
        );
      }
      return;
    }
    await MbtilesStorage.savePathWithKind(destPath, probe.kind!);
    if (!mounted) return;
    await _applySavedMbtilesAtPath(destPath, moveMap: true);
    if (!mounted) return;
    final kindLabel =
        probe.kind == MbtilesBasemapKind.vector ? 'vektör önizleme' : probe.meta!.format;
    setState(() => _status = 'Offline harita aktif ($kindLabel).');
    if (probe.kind == MbtilesBasemapKind.vector && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vektör MBTiles: çizgi + alan + nokta önizlemesi (stil/etiket yok). Tam raster altlık için png/jpg/webp MBTiles kullanın.',
          ),
        ),
      );
    }
  }

  void _switchToOnlineRaster() {
    _vectorMbtilesDebounce?.cancel();
    _vectorMbtilesDebounce = null;
    _vectorMbtilesReader?.dispose();
    _vectorMbtilesReader = null;
    setState(() {
      _rasterSource = _MapRasterSource.online;
      _mbTilesProvider?.dispose();
      _mbTilesProvider = null;
      _offlineMbtilesKind = null;
      _vectorMbtilesPolygons.clear();
      _vectorMbtilesPolylines.clear();
      _vectorMbtilesPoints.clear();
      _vectorMbtilesLabels.clear();
      _status = 'Çevrimiçi karolar.';
      _coerceTapModeIfVectorUnavailable();
    });
  }

  Future<void> _ensureOfflineMbtilesActive() async {
    if (kIsWeb) return;
    final path = await MbtilesStorage.getSavedPath();
    if (path == null || !await File(path).exists()) {
      await _pickAndInstallMbtiles();
      return;
    }
    await _applySavedMbtilesAtPath(path, moveMap: false);
  }

  Future<void> _clearOfflinePackFile() async {
    if (kIsWeb) return;
    _vectorMbtilesDebounce?.cancel();
    _vectorMbtilesReader?.dispose();
    _vectorMbtilesReader = null;
    _vectorMbtilesPolygons.clear();
    _vectorMbtilesPolylines.clear();
    _vectorMbtilesPoints.clear();
    _vectorMbtilesLabels.clear();
    _mbTilesProvider?.dispose();
    _mbTilesProvider = null;
    await MbtilesStorage.clearPath();
    final dir = await getApplicationDocumentsDirectory();
    try {
      await File('${dir.path}/offline_basemap.mbtiles').delete();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _rasterSource = _MapRasterSource.online;
        _offlinePackLabel = null;
        _offlineMbtilesKind = null;
        _status = 'Offline paket kaldırıldı.';
        _coerceTapModeIfVectorUnavailable();
      });
    }
  }

  Future<void> _setupLocationAndCenter() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setStateAndRefreshSheet(() {
          _status = 'Konum (GPS) kapalı. Ayarlardan açıp tekrar deneyin.';
        });
        await Geolocator.openLocationSettings();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setStateAndRefreshSheet(() => _status = 'Konum izni yok.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setStateAndRefreshSheet(() {
          _status = 'Konum izni kalıcı reddedildi. Uygulama ayarlarından açın.';
        });
        await Geolocator.openAppSettings();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final me = LatLng(pos.latitude, pos.longitude);
      _setStateAndRefreshSheet(() {
        _followGps = true;
        _gpsLive = me;
        _myPosition = me;
        _gpsAltDeviceMeters = pos.altitude;
        _status = 'Konum alındı.';
      });
      _moveMapCamera(me, 14);
      unawaited(ElevationService.fetchMeters(me.latitude, me.longitude).then((dem) {
        if (!mounted || dem == null) return;
        _setStateAndRefreshSheet(() => _demMy = dem);
      }));
    } catch (e) {
      _setStateAndRefreshSheet(() => _status = 'Konum hatası: $e');
    }
  }

  double _polylineLengthMeters(List<LatLng> pts) {
    if (pts.length < 2) return 0;
    var sum = 0.0;
    for (var i = 1; i < pts.length; i++) {
      sum += Geolocator.distanceBetween(
        pts[i - 1].latitude,
        pts[i - 1].longitude,
        pts[i].latitude,
        pts[i].longitude,
      );
    }
    return sum;
  }

  String _shapefileImportStatusLine(ShapefilePrjStatus s, int n) {
    final base = 'Shapefile: $n köşe';
    return switch (s) {
      ShapefilePrjStatus.absent => '$base (.prj yok — ham x/y WGS84 varsayıldı)',
      ShapefilePrjStatus.applied => '$base (.prj → WGS84)',
      ShapefilePrjStatus.failed => '$base (.prj okunamadı — ham x/y)',
    };
  }

  String? _pairSummary(String label, LatLng? a, LatLng? b) {
    if (a == null || b == null) return null;
    final d = Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    final az = Geolocator.bearingBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    final mil = az * (6400.0 / 360.0);
    return '$label: ${d.toStringAsFixed(1)} m · azimut ${az.toStringAsFixed(2)}° · ${mil.toStringAsFixed(2)} mil';
  }

  void _onMapPositionChanged(MapCamera camera, bool _) {
    if (_usesOfflineVectorBasemap) {
      _scheduleVectorMbtilesOverlayRebuild();
    }
    final center = camera.center;
    final rot = camera.rotation;
    if ((center.latitude - _mapHudCenter.latitude).abs() < 1e-7 &&
        (center.longitude - _mapHudCenter.longitude).abs() < 1e-7 &&
        (rot - _mapRotationDeg).abs() < 1e-4) {
      return;
    }
    setState(() {
      _mapHudCenter = center;
      _mapRotationDeg = rot;
    });
  }

  static double _bearingDeg360(LatLng from, LatLng to) {
    var az = Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    az = az % 360.0;
    if (az < 0) az += 360.0;
    return az;
  }

  static double _natoMilFromAzimuthDeg(double azimuthDeg) {
    return azimuthDeg * (6400.0 / 360.0);
  }

  Future<void> _openLayersQuickSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Harita ayarları', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Üst çubuktaki nişangah ve mesafe birimleri; katman seçiminde saklanır.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Orta nişangah (artı) ve taktik çubuk'),
                subtitle: Text(
                  _tacticalHudEnabled
                      ? 'Açık: ekran ortası hedef, üstte MGRS/mesafe/mil, ref→nişangah kırmızı çizgi.'
                      : 'Kapalı: haritaya girince otomatik artı yok; ölçüm için buradan açın.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                value: _tacticalHudEnabled,
                onChanged: (v) {
                  setState(() {
                    _tacticalHudEnabled = v;
                    if (v) {
                      _mapHudCenter = _readMapCenterLatLng();
                      _mapRotationDeg = _readMapRotationDeg();
                    }
                  });
                  unawaited(_persistMapDisplayPrefs());
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<MapHudCoordFormat>(
                key: ValueKey(_hudCoordFormat.name),
                initialValue: _hudCoordFormat,
                decoration: const InputDecoration(
                  labelText: 'Nişangah koordinatı (artı hedefi)',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: MapHudCoordFormat.decimalDegrees,
                    child: Text('DD — ondalık derece'),
                  ),
                  DropdownMenuItem(
                    value: MapHudCoordFormat.dms,
                    child: Text('DMS — derece dakika saniye'),
                  ),
                  DropdownMenuItem(
                    value: MapHudCoordFormat.mgrs,
                    child: Text('MGRS'),
                  ),
                  DropdownMenuItem(
                    value: MapHudCoordFormat.utmCompact,
                    child: Text('UTM — zon E/N (kompakt)'),
                  ),
                  DropdownMenuItem(
                    value: MapHudCoordFormat.utmEpsg,
                    child: Text('UTM + EPSG satırı'),
                  ),
                  DropdownMenuItem(
                    value: MapHudCoordFormat.sk42,
                    child: Text('SK-42 TM (yaklaşık)'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _hudCoordFormat = v);
                  unawaited(_persistMapDisplayPrefs());
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<MapDistanceUnit>(
                key: ValueKey(_distanceUnit.name),
                initialValue: _distanceUnit,
                decoration: const InputDecoration(
                  labelText: 'Mesafe (işaret/GPS → nişangah)',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: MapDistanceUnit.meters, child: Text('Metre (m)')),
                  DropdownMenuItem(value: MapDistanceUnit.kilometers, child: Text('Kilometre (km)')),
                  DropdownMenuItem(value: MapDistanceUnit.miles, child: Text('Mil (mi)')),
                  DropdownMenuItem(
                    value: MapDistanceUnit.nauticalMiles,
                    child: Text('Deniz mili (NM)'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _distanceUnit = v);
                  unawaited(_persistMapDisplayPrefs());
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<MapAreaUnit>(
                key: ValueKey(_areaUnit.name),
                initialValue: _areaUnit,
                decoration: const InputDecoration(
                  labelText: 'Alan (poligon özeti)',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: MapAreaUnit.squareMeters,
                    child: Text('Metrekare (m²)'),
                  ),
                  DropdownMenuItem(value: MapAreaUnit.hectares, child: Text('Hektar (ha)')),
                  DropdownMenuItem(value: MapAreaUnit.acres, child: Text('Acre')),
                  DropdownMenuItem(
                    value: MapAreaUnit.squareKilometers,
                    child: Text('Kilometrekare (km²)'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _areaUnit = v);
                  unawaited(_persistMapDisplayPrefs());
                },
              ),
              const SizedBox(height: 16),
              Text('Altlık', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<_MapRasterSource>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<_MapRasterSource>(
                    value: _MapRasterSource.online,
                    label: Text('Çevrimiçi'),
                    icon: Icon(Icons.cloud_outlined, size: 18),
                  ),
                  ButtonSegment<_MapRasterSource>(
                    value: _MapRasterSource.mbtiles,
                    label: Text('MBTiles'),
                    icon: Icon(Icons.sd_storage_outlined, size: 18),
                  ),
                ],
                selected: {_rasterSource},
                onSelectionChanged: (s) {
                  final next = s.first;
                  if (next == _MapRasterSource.mbtiles) {
                    if (kIsWeb) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('MBTiles yalnızca Android / iOS / masaüstü sürümlerde.')),
                      );
                      return;
                    }
                    unawaited(_ensureOfflineMbtilesActive());
                  } else {
                    _switchToOnlineRaster();
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<_MapBaseLayer>(
                key: const ValueKey('maps_layers_online_base_dropdown'),
                initialValue: _mapBase,
                decoration: const InputDecoration(labelText: 'Çevrimiçi karo'),
                onChanged: _rasterSource == _MapRasterSource.mbtiles
                    ? null
                    : (v) {
                        if (v != null) {
                          setState(() {
                            _mapBase = v;
                            if (_overlayBaseLayer == v) _overlayBaseLayer = null;
                          });
                          unawaited(_persistMapDisplayPrefs());
                        }
                      },
                items: const [
                  DropdownMenuItem(value: _MapBaseLayer.osm, child: Text('OSM')),
                  DropdownMenuItem(value: _MapBaseLayer.humanitarian, child: Text('İnsani (HOT)')),
                  DropdownMenuItem(value: _MapBaseLayer.cartoLight, child: Text('Şehir açık')),
                  DropdownMenuItem(value: _MapBaseLayer.cartoDark, child: Text('Şehir koyu')),
                  DropdownMenuItem(value: _MapBaseLayer.openTopo, child: Text('Topo')),
                  DropdownMenuItem(value: _MapBaseLayer.esriImagery, child: Text('Uydu (Esri)')),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<_MapBaseLayer?>(
                key: ValueKey('maps_layers_overlay_${_overlayBaseLayer?.name ?? 'off'}'),
                initialValue: _overlayBaseLayer,
                decoration: const InputDecoration(
                  labelText: 'Üst referans katmanı (çevrimiçi)',
                  helperText: 'Örn. altta topo veya MBTiles, üstte yarı saydam uydu. MBTiles + üst katman için ağ gerekir.',
                  isDense: true,
                ),
                onChanged: (v) {
                  setState(() {
                    if (v != null &&
                        (_rasterSource == _MapRasterSource.online || kIsWeb) &&
                        v == _mapBase) {
                      _overlayBaseLayer = null;
                    } else {
                      _overlayBaseLayer = v;
                    }
                  });
                  unawaited(_persistMapDisplayPrefs());
                },
                items: const [
                  DropdownMenuItem<_MapBaseLayer?>(value: null, child: Text('Kapalı')),
                  DropdownMenuItem(value: _MapBaseLayer.osm, child: Text('OSM')),
                  DropdownMenuItem(value: _MapBaseLayer.humanitarian, child: Text('İnsani (HOT)')),
                  DropdownMenuItem(value: _MapBaseLayer.cartoLight, child: Text('Şehir açık')),
                  DropdownMenuItem(value: _MapBaseLayer.cartoDark, child: Text('Şehir koyu')),
                  DropdownMenuItem(value: _MapBaseLayer.openTopo, child: Text('Topo')),
                  DropdownMenuItem(value: _MapBaseLayer.esriImagery, child: Text('Uydu (Esri)')),
                ],
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (ctx, setModal) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Altlık saydamlığı', style: Theme.of(ctx).textTheme.labelLarge),
                      Text(
                        'Rota, iz ve nişangahları öne çıkarmak için (AlpineQuest vb. saha haritalarında yaygın).',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      Slider(
                        value: _baseLayerOpacity.clamp(0.35, 1.0),
                        min: 0.35,
                        max: 1.0,
                        divisions: 13,
                        label: '%${(_baseLayerOpacity * 100).round()}',
                        onChanged: (v) {
                          setState(() => _baseLayerOpacity = v);
                          setModal(() {});
                          unawaited(_persistMapDisplayPrefs());
                        },
                      ),
                      if (_overlayBaseLayer != null) ...[
                        const SizedBox(height: 8),
                        Text('Üst katman saydamlığı', style: Theme.of(ctx).textTheme.labelLarge),
                        Slider(
                          value: _overlayOpacity.clamp(0.15, 0.9),
                          min: 0.15,
                          max: 0.9,
                          divisions: 15,
                          label: '%${(_overlayOpacity * 100).round()}',
                          onChanged: (v) {
                            setState(() => _overlayOpacity = v);
                            setModal(() {});
                            unawaited(_persistMapDisplayPrefs());
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const ValueKey('maps_layers_hillshade_switch'),
                title: const Text('Arazi gölgesi (DEM hillshade)'),
                subtitle: const Text(
                  'Esri World Hillshade — ağ gerekir; altlığın üstüne (ızgara ve vektörlerin altında) karıştırılır.',
                ),
                value: _hillshadeOverlayEnabled,
                onChanged: (v) {
                  setState(() => _hillshadeOverlayEnabled = v);
                  unawaited(_persistMapDisplayPrefs());
                },
              ),
              if (_hillshadeOverlayEnabled)
                StatefulBuilder(
                  builder: (ctx, setModal) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Gölgeleme saydamlığı', style: Theme.of(ctx).textTheme.labelLarge),
                        Slider(
                          value: _hillshadeOpacity.clamp(0.15, 0.85),
                          min: 0.15,
                          max: 0.85,
                          divisions: 14,
                          label: '%${(_hillshadeOpacity * 100).round()}',
                          onChanged: (v) {
                            setState(() => _hillshadeOpacity = v);
                            setModal(() {});
                            unawaited(_persistMapDisplayPrefs());
                          },
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              Text('Koordinat ızgarası', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<MapGridMode>(
                key: ValueKey(_mapGridMode.name),
                initialValue: _mapGridMode,
                decoration: const InputDecoration(
                  labelText: 'Görünür ızgara',
                  isDense: true,
                  helperText:
                      'UTM: WGS 84 / UTM kuzey; zon «Harita · ayrıntılar» veya harita merkezine göre otomatik.',
                ),
                items: const [
                  DropdownMenuItem(value: MapGridMode.off, child: Text('Kapalı')),
                  DropdownMenuItem(value: MapGridMode.wgs84, child: Text('WGS — enlem / boylam')),
                  DropdownMenuItem(
                    value: MapGridMode.utmNorth,
                    child: Text('UTM kuzey (MGRS metre aralıkları)'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _mapGridMode = v);
                  unawaited(_persistMapDisplayPrefs());
                },
              ),
              if (_rasterSource == _MapRasterSource.mbtiles && !kIsWeb) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickAndInstallMbtiles,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('.mbtiles seç'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Paketi sil',
                      onPressed: _clearOfflinePackFile,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                if (_offlinePackLabel != null)
                  Text(_offlinePackLabel!, style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 14),
                Text('Vektör MBTiles önizleme', style: Theme.of(ctx).textTheme.titleSmall),
                Text(
                  'Yalnızca pbf/MVT paketinde geometri + sınırlı metin etiketi (`name` / `ref` vb.; katman önceliği, tekrar birleştirme, isteğe bağlı zoom ölçeklemesi). '
                  'Ayrıntılar → Dokunuş modu «Özellik» ile MVT alan/çizgi/nokta özeti. Raster pakette etkisiz.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                StatefulBuilder(
                  builder: (ctx, setModal) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_offlineMbtilesKind == MbtilesBasemapKind.vector)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('MapLibre motoru (tam stil)'),
                            subtitle: Text(
                              _vectorMbtilesUseMaplibreEngine
                                  ? 'OpenFreeMap Liberty (sprite, glif, Style Spec). Stil dosyası için ilk açılışta ağ; vektör karolar yerel paketten. GeoPDF JPEG üst katman bu modda çizilmez; üst raster OSM katmanı henüz eklenmedi.'
                                  : 'Kapalı: flutter_map üzerinde hafif MVT geometri önizlemesi.',
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                            value: _vectorMbtilesUseMaplibreEngine,
                            onChanged: (v) {
                              setState(() => _vectorMbtilesUseMaplibreEngine = v);
                              setModal(() {});
                              unawaited(_persistMapDisplayPrefs());
                              unawaited(_reloadMaplibreStyleNow());
                            },
                          ),
                        Text(
                          'Eşzamanlı karo: $_vectorMbtilesMaxTiles (10–40)',
                          style: Theme.of(ctx).textTheme.labelLarge,
                        ),
                        Slider(
                          value: _vectorMbtilesMaxTiles.toDouble().clamp(10.0, 40.0),
                          min: 10,
                          max: 40,
                          divisions: 30,
                          label: '$_vectorMbtilesMaxTiles',
                          onChanged: (v) {
                            setState(() => _vectorMbtilesMaxTiles = v.round());
                            setModal(() {});
                            unawaited(_persistMapDisplayPrefs());
                            if (_usesOfflineVectorBasemap) _scheduleVectorMbtilesOverlayRebuild();
                          },
                        ),
                        Text(
                          'Alan dolgusu %${(_vectorMbtilesFillOpacity * 100).round()}',
                          style: Theme.of(ctx).textTheme.labelLarge,
                        ),
                        Slider(
                          value: _vectorMbtilesFillOpacity,
                          min: 0.08,
                          max: 0.45,
                          divisions: 37,
                          label: '%${(_vectorMbtilesFillOpacity * 100).round()}',
                          onChanged: (v) {
                            setState(() => _vectorMbtilesFillOpacity = v);
                            setModal(() {});
                            unawaited(_persistMapDisplayPrefs());
                            if (_usesOfflineVectorBasemap) _scheduleVectorMbtilesOverlayRebuild();
                          },
                        ),
                        Text(
                          'Çizgi / sınır %${(_vectorMbtilesStrokeOpacity * 100).round()}',
                          style: Theme.of(ctx).textTheme.labelLarge,
                        ),
                        Slider(
                          value: _vectorMbtilesStrokeOpacity,
                          min: 0.4,
                          max: 1.0,
                          divisions: 12,
                          label: '%${(_vectorMbtilesStrokeOpacity * 100).round()}',
                          onChanged: (v) {
                            setState(() => _vectorMbtilesStrokeOpacity = v);
                            setModal(() {});
                            unawaited(_persistMapDisplayPrefs());
                            if (_usesOfflineVectorBasemap) _scheduleVectorMbtilesOverlayRebuild();
                          },
                        ),
                        Text(
                          'Önizleme zoom tavanı: z ≤ $_vectorMbtilesPreviewMaxZoom (10–22)',
                          style: Theme.of(ctx).textTheme.labelLarge,
                        ),
                        Slider(
                          value: _vectorMbtilesPreviewMaxZoom.toDouble().clamp(10.0, 22.0),
                          min: 10,
                          max: 22,
                          divisions: 12,
                          label: 'z≤$_vectorMbtilesPreviewMaxZoom',
                          onChanged: (v) {
                            setState(() => _vectorMbtilesPreviewMaxZoom = v.round());
                            setModal(() {});
                            unawaited(_persistMapDisplayPrefs());
                            if (_usesOfflineVectorBasemap) _scheduleVectorMbtilesOverlayRebuild();
                          },
                        ),
                        Text(
                          'Metin etiketi (en çok): $_vectorMbtilesMaxLabels (0 = kapalı, 64’e kadar)',
                          style: Theme.of(ctx).textTheme.labelLarge,
                        ),
                        Slider(
                          value: _vectorMbtilesMaxLabels.toDouble().clamp(0.0, 64.0),
                          min: 0,
                          max: 64,
                          divisions: 64,
                          label: '$_vectorMbtilesMaxLabels',
                          onChanged: (v) {
                            setState(() => _vectorMbtilesMaxLabels = v.round());
                            setModal(() {});
                            unawaited(_persistMapDisplayPrefs());
                            if (_usesOfflineVectorBasemap) _scheduleVectorMbtilesOverlayRebuild();
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Etiket kotasını zoom ile ölçekle'),
                          subtitle: Text(
                            _vectorMbtilesScaleLabelsByZoom ? 'Uzakta daha az etiket gösterilir.' : 'Her zoom’da üst sınır tam kullanılır.',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          value: _vectorMbtilesScaleLabelsByZoom,
                          onChanged: (v) {
                            setState(() => _vectorMbtilesScaleLabelsByZoom = v);
                            setModal(() {});
                            unawaited(_persistMapDisplayPrefs());
                            if (_usesOfflineVectorBasemap) _scheduleVectorMbtilesOverlayRebuild();
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMapDetailsSheet() async {
    if (!mounted) return;
    setState(_coerceTapModeIfVectorUnavailable);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              _mapDetailsSheetSetState = setModalState;
              void updateState(VoidCallback fn) {
                if (mounted) {
                  setState(fn);
                }
                setModalState(() {});
              }
              final gps = _myPosition;
              final w1 = _waypoint1;
              final w2 = _waypoint2;
              final polygon = _totalPolygonAreaM2();
              final hasAnyPoint = gps != null || _userPins.isNotEmpty;
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.78,
                minChildSize: 0.38,
                maxChildSize: 1.0,
                builder: (context, scrollController) {
                  final bottomInset =
                      MediaQuery.viewPaddingOf(context).bottom + MediaQuery.paddingOf(context).bottom;
                  return ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset + 96),
              children: [
                Text('Harita · ayrıntılar', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_status, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _setupLocationAndCenter,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Konumumu al'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('maps_details_goto_location_button'),
                      onPressed: gps == null ? null : () => _moveMapCamera(gps, 14),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Konuma git'),
                    ),
                    OutlinedButton.icon(
                      onPressed: w1 == null ? null : () => _moveMapCamera(w1, 14),
                      icon: const Icon(Icons.place_outlined),
                      label: const Text("İşaret 1'e git"),
                    ),
                    OutlinedButton.icon(
                      onPressed: w2 == null ? null : () => _moveMapCamera(w2, 14),
                      icon: const Icon(Icons.place),
                      label: const Text("İşaret 2'ye git"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Dokunuş modu', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<_MapTapMode>(
                  key: const ValueKey('maps_details_tap_mode_segmented'),
                  showSelectedIcon: false,
                  segments: [
                    const ButtonSegment<_MapTapMode>(
                      value: _MapTapMode.viewOnly,
                      label: Text('Gez'),
                      tooltip: 'Dokunuşla nokta koyma',
                      icon: Icon(Icons.explore_outlined, size: 16),
                    ),
                    const ButtonSegment<_MapTapMode>(
                      value: _MapTapMode.placemark,
                      label: Text('İşaret'),
                      tooltip: 'Seçili renkte işaret ekle',
                      icon: Icon(Icons.place_outlined, size: 16),
                    ),
                    const ButtonSegment<_MapTapMode>(
                      value: _MapTapMode.mapAnchor,
                      label: Text('Konum'),
                      tooltip: 'Konumu haritadan işaretle',
                      icon: Icon(Icons.location_searching, size: 16),
                    ),
                    const ButtonSegment<_MapTapMode>(
                      value: _MapTapMode.routeVertex,
                      label: Text('Rota'),
                      icon: Icon(Icons.route, size: 16),
                    ),
                    const ButtonSegment<_MapTapMode>(
                      value: _MapTapMode.polygonVertex,
                      label: Text('Alan'),
                      icon: Icon(Icons.polyline, size: 16),
                    ),
                    if (_usesOfflineVectorBasemap)
                      const ButtonSegment<_MapTapMode>(
                        value: _MapTapMode.vectorFeature,
                        label: Text('Özellik'),
                        tooltip: 'MVT özelliğini sorgula',
                        icon: Icon(Icons.info_outline, size: 16),
                      ),
                  ],
                  selected: {_tapMode},
                  onSelectionChanged: (s) => updateState(() => _tapMode = s.first),
                ),
                const SizedBox(height: 12),
                Text('UTM EPSG gösterim zonu', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                DropdownButtonFormField<int?>(
                  key: const ValueKey('maps_details_utm_zone_dropdown'),
                  initialValue: _utmEpsgDisplayZone,
                  decoration: const InputDecoration(labelText: 'Zon'),
                  onChanged: (v) => updateState(() => _utmEpsgDisplayZone = v),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Otomatik (boylam)'),
                    ),
                    for (final z in Wgs84UtmNorth.middleEastZones)
                      DropdownMenuItem<int?>(
                        value: z,
                        child: Text('EPSG:${Wgs84UtmNorth.epsgCode(z)} · UTM ${z}N'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'UTM EPSG: WGS 84 / UTM kuzey (32601–32660). SK-42: 3° GK; yaklaşık towgs84. MBTiles raster.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        updateState(() {
                          _followGps = true;
                          if (_gpsLive != null) _myPosition = _gpsLive;
                        });
                        unawaited(_startPositionStreamWhenAllowed());
                      },
                      icon: const Icon(Icons.satellite_alt, size: 18),
                      label: const Text('GPS takibini aç'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final c = w1 ?? gps ?? _mapHudCenter;
                        showCoordinateTargetPickerSheet(
                          context,
                          initialCenter: c,
                          tileProvider: _onlineTileProvider(),
                          onApply: (p) {
                            updateState(() {
                              if (_userPins.isEmpty) {
                                final id = 'p${_pinIdSeq++}';
                                _userPins.add(_MapUserPin(id: id, point: p, colorIndex: 0));
                                _pinDemMeters[id] = null;
                              } else {
                                final id0 = _userPins.first.id;
                                _userPins.first.point = p;
                                _pinDemMeters[id0] = null;
                              }
                              _status = 'Koordinat girdisi → ilk işaret güncellendi.';
                            });
                          },
                        );
                      },
                      icon: const Icon(Icons.grid_on, size: 18),
                      label: const Text('Koordinat gir'),
                    ),
                    TextButton.icon(
                      onPressed: _userPins.length < 2
                          ? null
                          : () => updateState(() {
                                final rm = _userPins.removeAt(1);
                                _pinDemMeters.remove(rm.id);
                              }),
                      icon: const Icon(Icons.clear),
                      label: const Text('İşaret 2 sil'),
                    ),
                    TextButton.icon(
                      onPressed: _userPins.isEmpty
                          ? null
                          : () => updateState(() {
                                for (final pin in _userPins) {
                                  _pinDemMeters.remove(pin.id);
                                }
                                _userPins.clear();
                                _status = 'Tüm işaretler silindi.';
                              }),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Tüm işaretleri temizle'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('maps_details_route_clear_button'),
                      onPressed: _routeVertices.isEmpty
                          ? null
                          : () => updateState(() {
                                _clearKmlImportedPolylinesAndPoints();
                                _routeVertices.clear();
                                _status = 'Rota temizlendi.';
                              }),
                      icon: const Icon(Icons.clear_all),
                      label: Text('Rota (${_routeVertices.length})'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('maps_details_route_undo_button'),
                      onPressed: _routeVertices.isEmpty
                          ? null
                          : () => updateState(() {
                                _clearKmlImportedPolylinesAndPoints();
                                _routeVertices.removeLast();
                              }),
                      icon: const Icon(Icons.undo),
                      label: const Text('Rota geri'),
                    ),
                    TextButton.icon(
                      onPressed: _polygonVertices.isEmpty && _additionalPolygonPatches.isEmpty
                          ? null
                          : () => updateState(() {
                                _resetKmlPrimaryPolygonVisual();
                                _polygonVertices.clear();
                                _polygonHoles.clear();
                                _additionalPolygonPatches.clear();
                              }),
                      icon: const Icon(Icons.layers_clear),
                      label: Text(
                        _additionalPolygonPatches.isEmpty
                            ? 'Alan (${_polygonVertices.length})'
                            : 'Alan (${_polygonClosedPieceCount()} parça)',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _polygonVertices.isEmpty
                          ? null
                          : () => updateState(() {
                                _polygonVertices.removeLast();
                                if (_polygonVertices.isEmpty) _resetKmlPrimaryPolygonVisual();
                                _polygonHoles.clear();
                                _additionalPolygonPatches.clear();
                              }),
                      icon: const Icon(Icons.undo_outlined),
                      label: const Text('Alan geri'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('maps_details_geopdf_frame_clear_button'),
                      onPressed: _geoPdfExtentPolygon.isEmpty && _geoPdfRasterJpeg == null
                          ? null
                          : () => updateState(() {
                                _geoPdfExtentPolygon.clear();
                                _geoPdfRasterJpeg = null;
                                _status = 'GeoPDF çerçevesi kaldırıldı.';
                              }),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('GeoPDF çerçevesi'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exportGpx,
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('GPX dışa'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('maps_details_export_kml_button'),
                      onPressed: _exportKml,
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('KML dışa'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('maps_details_export_kmz_button'),
                      onPressed: _exportKmz,
                      icon: const Icon(Icons.layers, size: 18),
                      label: const Text('KMZ dışa'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importGeoFile,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('GPX / KML / KMZ / SHP / GeoPDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importCas3dPackage,
                      icon: const Icon(Icons.view_in_ar_outlined, size: 18),
                      label: const Text('CAS 3B yükle (.json)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _configureCasRemote,
                      icon: const Icon(Icons.settings_ethernet_outlined, size: 18),
                      label: const Text('Kurumsal CAS ayarı'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(_pullCas3dPackageFromRemote()),
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: const Text('Kurumsal CAS çek'),
                    ),
                    FilterChip(
                      label: Text(
                        _casRemoteAutoSyncEnabled
                            ? 'Oto çekim açık (${_casRemoteAutoSyncSec}s)'
                            : 'Oto çekim kapalı',
                      ),
                      avatar: Icon(
                        _casRemoteAutoSyncEnabled ? Icons.sync : Icons.sync_disabled,
                        size: 16,
                      ),
                      selected: _casRemoteAutoSyncEnabled,
                      onSelected: (v) {
                        setState(() => _casRemoteAutoSyncEnabled = v);
                        _rescheduleCasRemoteAutoSync();
                        unawaited(_persistMapDisplayPrefs());
                      },
                    ),
                    if (_casRemoteAutoSyncEnabled)
                      SizedBox(
                        width: 250,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kurumsal CAS oto çekim aralığı: ${_casRemoteAutoSyncSec}s',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Slider(
                              value: _casRemoteAutoSyncSec.toDouble().clamp(30, 600),
                              min: 30,
                              max: 600,
                              divisions: 57,
                              label: '${_casRemoteAutoSyncSec}s',
                              onChanged: (v) {
                                setState(() {
                                  _casRemoteAutoSyncSec = v.round().clamp(30, 600).toInt();
                                });
                                _rescheduleCasRemoteAutoSync();
                              },
                              onChangeEnd: (_) => unawaited(_persistMapDisplayPrefs()),
                            ),
                          ],
                        ),
                      ),
                    if (_cas3dPackage != null)
                      OutlinedButton.icon(
                        onPressed: _clearCas3dPackage,
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text('CAS 3B temizle'),
                      ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _recordingTrack ? Theme.of(context).colorScheme.errorContainer : null,
                      ),
                      onPressed: _toggleTrackRecording,
                      icon: Icon(_recordingTrack ? Icons.stop_circle_outlined : Icons.fiber_manual_record, size: 20),
                      label: Text(_recordingTrack ? 'İzi durdur' : 'İz kaydı'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showElevationProfile,
                      icon: const Icon(Icons.area_chart, size: 18),
                      label: const Text('Yükseklik profili'),
                    ),
                    OutlinedButton.icon(
                      onPressed: w1 == null || w2 == null
                          ? null
                          : () => unawaited(
                                showLosAnalysisDialog(
                                  context,
                                  observer: w1,
                                  target: w2,
                                  onApplyToMap: _applyLosMapOverlay,
                                ),
                              ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Basit LOS (DEM)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: w1 == null || w2 == null ? null : _toggleLosThreatTubeMvp,
                      icon: Icon(
                        _effectiveLosThreatTubeOuter != null
                            ? Icons.radio_button_checked_outlined
                            : Icons.radio_button_unchecked_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _effectiveLosThreatTubeOuter != null
                            ? 'Tehdit tüpü açık'
                            : 'Tehdit tüpü (MVP)',
                      ),
                    ),
                    if (w1 != null && w2 != null)
                      SizedBox(
                        width: 260,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tehdit tüpü yarı genişlik (başlangıç): ${_losThreatHalfWidthM.toStringAsFixed(0)} m',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Slider(
                              value: _losThreatHalfWidthM.clamp(10.0, 300.0),
                              min: 10,
                              max: 300,
                              divisions: 58,
                              label: '${_losThreatHalfWidthM.toStringAsFixed(0)} m',
                              onChanged: _updateLosThreatHalfWidthM,
                              onChangeEnd: (_) => unawaited(_persistMapDisplayPrefs()),
                            ),
                            Text(
                              'Tehdit tüpü yarı genişlik (hedef): ${_losThreatTargetHalfWidthM.toStringAsFixed(0)} m',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Slider(
                              value: _losThreatTargetHalfWidthM.clamp(10.0, 600.0),
                              min: 10,
                              max: 600,
                              divisions: 59,
                              label: '${_losThreatTargetHalfWidthM.toStringAsFixed(0)} m',
                              onChanged: _updateLosThreatTargetHalfWidthM,
                              onChangeEnd: (_) => unawaited(_persistMapDisplayPrefs()),
                            ),
                          ],
                        ),
                      ),
                    if (_losMapSegments != null)
                      OutlinedButton.icon(
                        onPressed: _clearLosMapOverlay,
                        icon: const Icon(Icons.layers_clear_outlined, size: 18),
                        label: const Text('LOS çizgisini kaldır'),
                      ),
                    OutlinedButton.icon(
                      onPressed: kIsWeb ? null : () => unawaited(_pickNtv2GridFile()),
                      icon: const Icon(Icons.grid_4x4_outlined, size: 18),
                      label: const Text('NTv2 .gsb'),
                    ),
                    OutlinedButton.icon(
                      onPressed: hasAnyPoint ? _refreshDemAll : null,
                      icon: const Icon(Icons.terrain, size: 18),
                      label: const Text('DEM (noktalar)'),
                    ),
                  ],
                ),
                if (_elevStatus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_elevStatus, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CAS remote profil',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Tooltip(
                      message: 'Profili panoya kopyala',
                      child: TextButton.icon(
                        onPressed: _copyCasRemoteProfileSummary,
                        icon: const Icon(Icons.copy_outlined, size: 16),
                        label: const Text('Kopyala'),
                      ),
                    ),
                    Tooltip(
                      message: 'Profili paylas',
                      child: TextButton.icon(
                        onPressed: () => unawaited(_shareCasRemoteProfileSummary()),
                        icon: const Icon(Icons.ios_share_outlined, size: 16),
                        label: const Text('Paylas'),
                      ),
                    ),
                    if (_casRemoteLastSyncAt != null)
                      Tooltip(
                        message: 'Son senkron bilgisini sifirla',
                        child: TextButton.icon(
                          onPressed: () => unawaited(_resetCasRemoteLastSync()),
                          icon: const Icon(Icons.restart_alt, size: 16),
                          label: const Text('Sifirla'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in _casRemoteProfileChips)
                      _buildCasRemoteProfileChip(context, c),
                  ],
                ),
                if (_casRemoteLastSyncAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Son CAS senkron: ${_casRemoteLastSyncAt!.hour.toString().padLeft(2, '0')}:${_casRemoteLastSyncAt!.minute.toString().padLeft(2, '0')}:${_casRemoteLastSyncAt!.second.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_cas3dPackage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'CAS 3B: ${_cas3dPackage!.name} v${_cas3dPackage!.version} · '
                    '${_cas3dEnabledTubeIds.length}/${_cas3dPackage!.threatTubes.length} tube aktif · '
                    '${_cas3dThreatPolygons.length} footprint',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<Cas3dTubePresetMode>(
                    segments: const [
                      ButtonSegment(
                        value: Cas3dTubePresetMode.all,
                        icon: Icon(Icons.select_all, size: 16),
                        label: Text('Tümü'),
                      ),
                      ButtonSegment(
                        value: Cas3dTubePresetMode.none,
                        icon: Icon(Icons.block, size: 16),
                        label: Text('Hiçbiri'),
                      ),
                      ButtonSegment(
                        value: Cas3dTubePresetMode.high,
                        icon: Icon(Icons.priority_high, size: 16),
                        label: Text('Yüksek'),
                      ),
                      ButtonSegment(
                        value: Cas3dTubePresetMode.custom,
                        icon: Icon(Icons.tune, size: 16),
                        label: Text('Özel'),
                      ),
                    ],
                    selected: {_cas3dPresetMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) {
                      if (s.isEmpty) return;
                      _setCas3dPresetMode(s.first);
                    },
                  ),
                  if (_cas3dPackage!.threatTubes.isNotEmpty)
                    Text(
                      () {
                        double? minAlt;
                        double? maxAlt;
                        for (final t in _cas3dPackage!.threatTubes) {
                          if (t.minAltM != null) {
                            minAlt = minAlt == null ? t.minAltM : math.min(minAlt, t.minAltM!);
                          }
                          if (t.maxAltM != null) {
                            maxAlt = maxAlt == null ? t.maxAltM : math.max(maxAlt, t.maxAltM!);
                          }
                        }
                        if (minAlt == null && maxAlt == null) {
                          return 'Yükseklik bandı: tanımlı değil';
                        }
                        return 'Yükseklik bandı: ${minAlt?.round() ?? '?'}..${maxAlt?.round() ?? '?'} m';
                      }(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _cas3dPackage!.threatTubes)
                        FilterChip(
                          label: Text(
                            t.id,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: _cas3dEnabledTubeIds.contains(t.id),
                          selectedColor: _cas3dTubeColor(t).withValues(alpha: 0.25),
                          onSelected: (v) => _toggleCas3dTube(t.id, v),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    final rootCtx = this.context;
                    Navigator.pop(context);
                    showMapsReferenceComparisonSheet(rootCtx);
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Referans uygulamalar'),
                ),
                TextButton.icon(
                  onPressed: () {
                    final rootCtx = this.context;
                    Navigator.pop(context);
                    unawaited(showMapDataPackagesSheet(rootCtx));
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Harita veri kaynakları'),
                ),
                const SizedBox(height: 8),
                if (gps != null) ...[
                  _coordBlock('Mevcut konum (WGS84)', gps, demM: _demMy),
                  Text(
                    _followGps
                        ? 'Kaynak: canlı GPS'
                        : 'Kaynak: haritadan sabit${_gpsAltDeviceMeters != null ? ' · son GNSS yükseklik: ${_gpsAltDeviceMeters!.toStringAsFixed(0)} m' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                for (var pi = 0; pi < _userPins.length; pi++) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => unawaited(_showMapPinEditor(pi)),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text('İşaret ${pi + 1} — düzenle'),
                    ),
                  ),
                  if ((_userPins[pi].note ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _userPins[pi].note!.trim(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  _coordBlock(
                    _pinSheetTitle(_userPins[pi], pi),
                    _userPins[pi].point,
                    demM: _pinDemMeters[_userPins[pi].id],
                  ),
                ],
                if (gps != null && _userPins.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Mesafe / azimut', style: Theme.of(context).textTheme.titleSmall),
                  for (var pi = 0; pi < _userPins.length; pi++)
                    if (_pairSummary(
                          'Konum → ${_pinSheetTitle(_userPins[pi], pi)}',
                          gps,
                          _userPins[pi].point,
                        ) !=
                        null)
                      Text(
                        _pairSummary(
                          'Konum → ${_pinSheetTitle(_userPins[pi], pi)}',
                          gps,
                          _userPins[pi].point,
                        )!,
                      ),
                  if (_userPins.length >= 2 &&
                      _pairSummary(
                            'İşaret 1 → İşaret 2',
                            _userPins[0].point,
                            _userPins[1].point,
                          ) !=
                          null)
                    Text(
                      _pairSummary(
                        'İşaret 1 → İşaret 2',
                        _userPins[0].point,
                        _userPins[1].point,
                      )!,
                    ),
                ],
                if (_kmlImportStyledPolylines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Çizgi segmentleri: ${_kmlImportStyledPolylines.length}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (_gpxImportTrackLinesOnly.isNotEmpty ||
                      _gpxImportRouteLinesOnly.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                      child: Text(
                        'GPX: mavi = iz (trk), turuncu = plan (rte). KML renkleri dosyadan gelir.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (var i = 0; i < _kmlImportStyledPolylines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '· ${_kmlImportStyledPolylines[i].$1}: '
                        '${_kmlImportStyledPolylines[i].$2.length} nokta · '
                        '${_polylineLengthMeters(_kmlImportStyledPolylines[i].$2).toStringAsFixed(0)} m',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ] else if (_routeVertices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Rota: ${_routeVertices.length} köşe · ${_polylineLengthMeters(_routeVertices).toStringAsFixed(0)} m',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
                if (_polygonVertices.isNotEmpty || _additionalPolygonPatches.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Alan: ${_polygonClosedPieceCount()} parça'
                    '${_polygonVertices.isNotEmpty ? ' · birincil ${_polygonVertices.length} köşe' : ''}'
                    '${_polygonHoles.isNotEmpty ? ' · ${_polygonHoles.length} delik (birincil)' : ''}'
                    '${polygon != null ? ' · ${_areaUnit.formatAreaM2(polygon)} toplam' : ''}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
                if (_recordedTrack.length >= 2) ...[
                  const SizedBox(height: 12),
                  Text(
                    'İz: ${_recordedTrack.length} nokta · ${_polylineLengthMeters(_recordedTrack).toStringAsFixed(0)} m'
                    '${_recordingTrack && _trackRecordingStartedAt != null ? ' · süre ${_formatTrackRecordingElapsed()}' : ''}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
                const Divider(height: 20),
                _buildPttSection(context, updateState),
              ],
                  );
                },
              );
            },
          );
        },
      );
    } finally {
      _mapDetailsSheetSetState = null;
    }
  }

  List<(String, LatLng, String?)> _exportWaypoints() {
    final wpts = <(String, LatLng, String?)>[];
    final g = _myPosition;
    if (g != null) wpts.add(('GPS / konum', g, null));
    for (var i = 0; i < _userPins.length; i++) {
      final pin = _userPins[i];
      final nm = pin.name?.trim().isNotEmpty == true ? pin.name!.trim() : 'İşaret ${i + 1}';
      final desc = pin.note?.trim().isNotEmpty == true ? pin.note!.trim() : null;
      wpts.add((nm, pin.point, desc));
    }
    if (_kmlImportStyledPolylines.isNotEmpty) {
      for (final e in _kmlImportPoints) {
        wpts.add((e.name, e.point, null));
      }
      for (final seg in _kmlImportStyledPolylines) {
        for (var i = 0; i < seg.$2.length; i++) {
          wpts.add(('${seg.$1} · ${i + 1}', seg.$2[i], null));
        }
      }
    } else if (_kmlImportPoints.isNotEmpty) {
      for (final e in _kmlImportPoints) {
        wpts.add((e.name, e.point, null));
      }
      final covered = {for (final e in _kmlImportPoints) _latLngDedupKey(e.point)};
      for (var i = 0; i < _routeVertices.length; i++) {
        final v = _routeVertices[i];
        if (covered.contains(_latLngDedupKey(v))) continue;
        wpts.add(('Rota ${i + 1}', v, null));
      }
    } else {
      for (var i = 0; i < _routeVertices.length; i++) {
        wpts.add(('Rota ${i + 1}', _routeVertices[i], null));
      }
    }
    for (var i = 0; i < _polygonVertices.length; i++) {
      wpts.add(('Alan ${i + 1}', _polygonVertices[i], null));
    }
    for (var pi = 0; pi < _additionalPolygonPatches.length; pi++) {
      final ring = _additionalPolygonPatches[pi].outer;
      for (var i = 0; i < ring.length; i++) {
        wpts.add(('Alan ek ${pi + 1} · ${i + 1}', ring[i], null));
      }
    }
    return wpts;
  }

  List<(String, KmlPolygonPatch)> _namedPolygonPatchesForExport() {
    final out = <(String, KmlPolygonPatch)>[];
    if (_polygonVertices.length >= 3) {
      out.add((
        'Alan — birincil',
        KmlPolygonPatch(
          outer: List<LatLng>.from(_polygonVertices),
          holes: [for (final h in _polygonHoles) List<LatLng>.from(h)],
          fillArgb32: _kmlPrimaryPolygonFillArgb32,
          strokeArgb32: _kmlPrimaryPolygonStrokeArgb32,
          strokeWidthPx: _kmlPrimaryPolygonStrokeWidthPx,
          drawStrokeOutline: _kmlPrimaryPolygonDrawStrokeOutline ?? true,
        ),
      ));
    }
    for (var i = 0; i < _additionalPolygonPatches.length; i++) {
      final p = _additionalPolygonPatches[i];
      if (p.outer.length < 3) continue;
      out.add((
        'Alan — ek ${i + 1}',
        KmlPolygonPatch(
          outer: List<LatLng>.from(p.outer),
          holes: [for (final h in p.holes) List<LatLng>.from(h)],
          fillArgb32: p.fillArgb32,
          strokeArgb32: p.strokeArgb32,
          strokeWidthPx: p.strokeWidthPx,
          drawStrokeOutline: p.drawStrokeOutline,
        ),
      ));
    }
    return out;
  }

  /// KML/KMZ/GPX yüklemeden sonra `_routeVertices` = tüm çizgi noktaları + işaret noktaları (dosya sırası).
  /// Bu liste hâlâ aynıysa GPX `rte` / KML birleşik çizgi yazılmaz (`lineTracks` / styled placemark yeter).
  /// Arayüzde rota köşesi ekleme veya geri al KML çizgilerini temizler; eşleşme kalkarsa birleşik rota tekrar dışarı gider.
  bool _routeVerticesMatchesKmlImportBaseline() {
    final expected = <LatLng>[];
    for (final e in _kmlImportStyledPolylines) {
      if (e.$2.length >= 2) expected.addAll(e.$2);
    }
    for (final e in _kmlImportPoints) {
      expected.add(e.point);
    }
    if (expected.length != _routeVertices.length) return false;
    for (var i = 0; i < expected.length; i++) {
      final a = expected[i];
      final b = _routeVertices[i];
      if (a.latitude != b.latitude || a.longitude != b.longitude) return false;
    }
    return true;
  }

  List<LatLng>? _exportRoutePolylineOrNull() {
    if (_routeVertices.length < 2) return null;
    if (_kmlImportStyledPolylines.isNotEmpty && _routeVerticesMatchesKmlImportBaseline()) {
      return null;
    }
    return List<LatLng>.from(_routeVertices);
  }

  /// GPX dosyasından geldiyse yalnızca izler; aksi halde KML stilli çizgiler (hepsi `trk`).
  List<(String, List<LatLng>)>? _composeGpxLineTracksOrNull() {
    final fromGpx = _gpxImportTrackLinesOnly.isEmpty && _gpxImportRouteLinesOnly.isEmpty
        ? null
        : [
            for (final e in _gpxImportTrackLinesOnly)
              if (e.$2.length >= 2) (e.$1, List<LatLng>.from(e.$2)),
          ];
    if (fromGpx != null) {
      return fromGpx.isEmpty ? null : fromGpx;
    }
    if (_kmlImportStyledPolylines.isEmpty) return null;
    return [
      for (final e in _kmlImportStyledPolylines)
        if (e.$2.length >= 2) (e.$1, List<LatLng>.from(e.$2)),
    ];
  }

  /// İçe aktarılan GPX `<rte>` + varsa elle birleşik rota tek `rte` olarak.
  List<(String, List<LatLng>)>? _composeGpxRouteLinesOrNull() {
    final out = <(String, List<LatLng>)>[
      for (final e in _gpxImportRouteLinesOnly)
        if (e.$2.length >= 2) (e.$1, List<LatLng>.from(e.$2)),
    ];
    final manual = _exportRoutePolylineOrNull();
    if (manual != null) {
      out.add(('Blue Viper Harita — rota', manual));
    }
    return out.isEmpty ? null : out;
  }

  String _composeGpxExportDocument() {
    final wpts = _exportWaypoints();
    final namedPolys = _namedPolygonPatchesForExport();
    final areaLoops = [for (final e in namedPolys) (e.$1, e.$2.outer)];
    return buildGpxDocument(
      name: 'Blue Viper Harita',
      waypoints: wpts,
      routeLines: _composeGpxRouteLinesOrNull(),
      lineTracks: _composeGpxLineTracksOrNull(),
      trackPoints: _recordedTrack.length >= 2 ? List<LatLng>.from(_recordedTrack) : null,
      trackName: 'GPS izi',
      areaLoops: areaLoops.isEmpty ? null : areaLoops,
    );
  }

  @visibleForTesting
  String debugBuildGpxDocumentForTest() => _composeGpxExportDocument();

  @visibleForTesting
  int? debugImportPolylineStrokeArgbAt(int i) =>
      i < 0 || i >= _kmlImportStyledPolylines.length ? null : _kmlImportStyledPolylines[i].$3;

  @visibleForTesting
  void debugApplyKmlImportSnapshotForTest({
    List<(String, List<LatLng>, int?, double?)> styledLines = const [],
    List<KmlPointImport> importPoints = const [],
    List<LatLng> routeVertices = const [],
  }) {
    _setStateAndRefreshSheet(() {
      _gpxImportTrackLinesOnly.clear();
      _gpxImportRouteLinesOnly.clear();
      _kmlImportStyledPolylines
        ..clear()
        ..addAll(styledLines);
      _kmlImportPoints
        ..clear()
        ..addAll(importPoints);
      _routeVertices
        ..clear()
        ..addAll(routeVertices);
    });
  }

  @visibleForTesting
  void debugApplyGpxImportSnapshotForTest({
    List<(String, List<LatLng>)> trackLines = const [],
    List<(String, List<LatLng>)> routeLines = const [],
    List<(String, List<LatLng>, int?, double?)> styledUnion = const [],
    List<KmlPointImport> importPoints = const [],
    List<LatLng> routeVertices = const [],
  }) {
    _setStateAndRefreshSheet(() {
      _gpxImportTrackLinesOnly
        ..clear()
        ..addAll([
          for (final e in trackLines)
            if (e.$2.length >= 2) (e.$1, List<LatLng>.from(e.$2)),
        ]);
      _gpxImportRouteLinesOnly
        ..clear()
        ..addAll([
          for (final e in routeLines)
            if (e.$2.length >= 2) (e.$1, List<LatLng>.from(e.$2)),
        ]);
      final union = styledUnion.isNotEmpty
          ? styledUnion
          : [
              for (final e in trackLines)
                if (e.$2.length >= 2)
                  (
                    e.$1,
                    List<LatLng>.from(e.$2),
                    _kGpxImportTrackStrokeArgb,
                    _kGpxImportTrackStrokeWidth,
                  ),
              for (final e in routeLines)
                if (e.$2.length >= 2)
                  (
                    e.$1,
                    List<LatLng>.from(e.$2),
                    _kGpxImportRouteStrokeArgb,
                    _kGpxImportRouteStrokeWidth,
                  ),
            ];
      _kmlImportStyledPolylines..clear()..addAll(union);
      _kmlImportPoints
        ..clear()
        ..addAll(importPoints);
      _routeVertices
        ..clear()
        ..addAll(routeVertices);
    });
  }

  Future<void> _exportGpx() async {
    final gpx = _composeGpxExportDocument();
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/blue_viper_harita_${DateTime.now().millisecondsSinceEpoch}.gpx');
    await f.writeAsString(gpx);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)], subject: 'Blue Viper Harita GPX'),
    );
  }

  String _buildMapKmlExportString() {
    final wpts = _exportWaypoints();
    final namedPolys = _namedPolygonPatchesForExport();
    return buildKmlMapExport(
      documentName: 'Blue Viper Harita',
      waypoints: wpts,
      styledPolylines: _kmlImportStyledPolylines.isEmpty
          ? null
          : [
              for (final e in _kmlImportStyledPolylines)
                (
                  e.$1,
                  List<LatLng>.from(e.$2),
                  e.$3,
                  e.$4,
                ),
            ],
      routeLine: _exportRoutePolylineOrNull(),
      recordedTrackLine: _recordedTrack.length >= 2 ? List<LatLng>.from(_recordedTrack) : null,
      recordedTrackName: 'GPS izi',
      polygons: namedPolys.isEmpty ? null : namedPolys,
    );
  }

  Future<void> _exportKml() async {
    final kml = _buildMapKmlExportString();
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/blue_viper_harita_${DateTime.now().millisecondsSinceEpoch}.kml');
    await f.writeAsString(kml);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)], subject: 'Blue Viper Harita KML'),
    );
  }

  Future<void> _exportKmz() async {
    final kml = _buildMapKmlExportString();
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/blue_viper_harita_${DateTime.now().millisecondsSinceEpoch}.kmz');
    await f.writeAsBytes(encodeKmzFromKml(kml));
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)], subject: 'Blue Viper Harita KMZ'),
    );
  }

  LatLng _coordWithNtv2(LatLng wgs) => _ntv2GsbGrid?.shiftWgs84(wgs) ?? wgs;

  Future<void> _reloadNtv2GridFromSavedPath() async {
    if (kIsWeb || !mounted) return;
    final path = _ntv2GsbPathPref?.trim();
    if (path == null || path.isEmpty) {
      if (mounted) setState(() => _ntv2GsbGrid = null);
      return;
    }
    final f = File(path);
    if (!await f.exists()) {
      if (!mounted) return;
      setState(() {
        _ntv2GsbGrid = null;
        _ntv2GsbPathPref = null;
      });
      await _persistMapDisplayPrefs();
      return;
    }
    List<int> bytes;
    try {
      bytes = await f.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ntv2GsbGrid = null;
        _ntv2GsbPathPref = null;
      });
      await _persistMapDisplayPrefs();
      return;
    }
    final grid = Ntv2GsbShift.tryParse(bytes);
    if (!mounted) return;
    if (grid == null) {
      setState(() {
        _ntv2GsbGrid = null;
        _ntv2GsbPathPref = null;
      });
      await _persistMapDisplayPrefs();
      return;
    }
    setState(() => _ntv2GsbGrid = grid);
  }

  Future<void> _pickNtv2GridFile() async {
    if (kIsWeb) return;
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gsb'],
    );
    if (r == null || r.files.isEmpty) return;
    final plat = r.files.single;
    final path = plat.path;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya yolu alınamadı.')),
        );
      }
      return;
    }
    List<int> bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('.gsb okunamadı')),
        );
      }
      return;
    }
    final grid = Ntv2GsbShift.tryParse(bytes);
    if (!mounted) return;
    if (grid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NTv2 ızgarası tanınmadı (başlık / biçim).'),
        ),
      );
      return;
    }
    setState(() {
      _ntv2GsbGrid = grid;
      _ntv2GsbPathPref = path;
      var msg =
          'NTv2: ${grid.latCount}×${grid.lonCount} düğüm · ${grid.extentSummaryDegrees()} · kaymalı gösterim.';
      final gps = _myPosition ?? _gpsLive;
      if (gps != null && !grid.coversWgs84(gps)) {
        msg += ' GPS/merkez ızgara dışı.';
      }
      _status = msg;
    });
    unawaited(_persistMapDisplayPrefs());
  }

  Future<List<int>?> _readPickedFileBytes(PlatformFile plat) async {
    if (plat.path != null) {
      try {
        return await File(plat.path!).readAsBytes();
      } catch (_) {
        return null;
      }
    }
    final b = plat.bytes;
    return b == null ? null : List<int>.from(b);
  }

  Future<void> _importGeoFile() async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gpx', 'kml', 'kmz', 'shp', 'pdf'],
    );
    if (r == null || r.files.isEmpty) return;
    final plat = r.files.single;
    final nameLower = plat.name.toLowerCase();

    if (nameLower.endsWith('.shp')) {
      final path = plat.path;
      if (path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu ortamda shapefile yolu alınamadı.')),
          );
        }
        return;
      }
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shapefile bu derlemede yalnızca Android / iOS / masaüstü.')),
          );
        }
        return;
      }
      final shpRes = await importShapefileRoute(path);
      if (!mounted) return;
      final pts = shpRes.points;
      if (pts == null || pts.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shapefile okunamadı veya yeterli geometri yok (.shx aynı klasörde olsun).'),
          ),
        );
        return;
      }
      _setStateAndRefreshSheet(() {
        _geoPdfExtentPolygon.clear();
        _geoPdfRasterJpeg = null;
        _polygonVertices.clear();
        _polygonHoles.clear();
        _resetKmlPrimaryPolygonVisual();
        _additionalPolygonPatches.clear();
        _clearKmlImportedPolylinesAndPoints();
        _routeVertices.clear();
        _routeVertices.addAll(pts);
        _status = _shapefileImportStatusLine(shpRes.prjStatus, _routeVertices.length);
      });
      if (shpRes.prjStatus == ShapefilePrjStatus.failed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('.prj çözülemedi; koordinatlar WGS84 (x=boylam, y=enlem) varsayıldı.'),
          ),
        );
      }
      return;
    }

    final bytes = await _readPickedFileBytes(plat);
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosya okunamadı')));
      }
      return;
    }

    if (nameLower.endsWith('.pdf')) {
      final geo = tryParseGeoPdfGpts(bytes);
      if (!geo.found) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(geo.detail ?? 'GeoPDF kapsamı okunamadı')),
          );
        }
        return;
      }
      final jpeg = tryExtractFirstJpegFromPdf(bytes);
      _setStateAndRefreshSheet(() {
        _polygonVertices.clear();
        _polygonHoles.clear();
        _resetKmlPrimaryPolygonVisual();
        _additionalPolygonPatches.clear();
        _clearKmlImportedPolylinesAndPoints();
        _geoPdfExtentPolygon
          ..clear()
          ..addAll(geo.cornersWgs84);
        _geoPdfRasterJpeg = jpeg;
        _status =
            'GeoPDF: kapsam çizildi ve odaklandı${geo.detail != null ? ' (${geo.detail})' : ''}'
            '${jpeg != null ? ' · gömülü JPEG altlık' : ''}.';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _fitMapCameraToCoordinates(
            List<LatLng>.from(geo.cornersWgs84),
            padding: const EdgeInsets.all(32),
          ),
        );
      });
      return;
    }

    if (nameLower.endsWith('.kmz')) {
      final kmls = decodeKmzToKmlStrings(bytes);
      if (kmls.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KMZ içinde KML bulunamadı')));
        }
        return;
      }
      final embedded = decodeKmzEmbeddedFiles(bytes);
      final merged = await parseKmlDocumentsWithNetworkLinks(kmls, kmzEmbeddedFiles: embedded);
      if (!mounted) return;
      _setStateAndRefreshSheet(() {
        _geoPdfExtentPolygon.clear();
        _geoPdfRasterJpeg = null;
        _selectedKmlRouteVertexIndex = null;
        _routeVertices.clear();
        _polygonVertices.clear();
        _polygonHoles.clear();
        _resetKmlPrimaryPolygonVisual();
        _additionalPolygonPatches.clear();
        _gpxImportTrackLinesOnly.clear();
        _gpxImportRouteLinesOnly.clear();
        _kmlImportStyledPolylines
          ..clear()
          ..addAll([
            for (final e in merged.styledLines)
              if (e.$2.length >= 2) (e.$1, List<LatLng>.from(e.$2), e.$3, e.$4),
          ]);
        _kmlImportPoints
          ..clear()
          ..addAll(merged.points);
        var polygonFilled = false;
        for (final patch in merged.polygonPatches) {
          if (patch.outer.length < 3) continue;
          if (!polygonFilled) {
            _polygonVertices.addAll(patch.outer);
            _polygonHoles.addAll(patch.holes.map((e) => List<LatLng>.from(e)));
            _kmlPrimaryPolygonFillArgb32 = patch.fillArgb32;
            _kmlPrimaryPolygonStrokeArgb32 = patch.strokeArgb32;
            _kmlPrimaryPolygonStrokeWidthPx = patch.strokeWidthPx;
            _kmlPrimaryPolygonDrawStrokeOutline = patch.drawStrokeOutline;
            polygonFilled = true;
          } else {
            _additionalPolygonPatches.add(KmlPolygonPatch(
              outer: List<LatLng>.from(patch.outer),
              holes: patch.holes.map((e) => List<LatLng>.from(e)).toList(),
              fillArgb32: patch.fillArgb32,
              strokeArgb32: patch.strokeArgb32,
              strokeWidthPx: patch.strokeWidthPx,
              drawStrokeOutline: patch.drawStrokeOutline,
            ));
          }
        }
        for (final line in merged.lines) {
          if (line.length >= 2) _routeVertices.addAll(line);
        }
        for (final e in merged.points) {
          _routeVertices.add(e.point);
        }
        final nl = _kmlNetworkLinkImportSuffix(
          hadLink: merged.anyHadNetworkLink,
          resolved: merged.anyResolvedNetworkLink,
        );
        _status =
            'KMZ (${kmls.length} KML): ${_kmlImportLoadStatusPrefix()}${_routeVertices.length} rota noktası${_polygonClosedPieceCount() > 0 ? ', ${_polygonClosedPieceCount()} alan parçası' : ''}.$nl';
      });
      return;
    }

    final docText = utf8.decode(bytes, allowMalformed: true);
    if (docText.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosya boş')));
      }
      return;
    }

    if (nameLower.endsWith('.gpx') || docText.contains('<gpx')) {
      final p = parseGpx(docText);
      if (!mounted) return;
      _setStateAndRefreshSheet(() {
        _geoPdfExtentPolygon.clear();
        _geoPdfRasterJpeg = null;
        _polygonVertices.clear();
        _polygonHoles.clear();
        _resetKmlPrimaryPolygonVisual();
        _additionalPolygonPatches.clear();
        _kmlImportStyledPolylines
          ..clear()
          ..addAll([
            for (final e in p.namedTrackLines)
              if (e.$2.length >= 2)
                (
                  e.$1,
                  List<LatLng>.from(e.$2),
                  _kGpxImportTrackStrokeArgb,
                  _kGpxImportTrackStrokeWidth,
                ),
            for (final e in p.namedRouteLines)
              if (e.$2.length >= 2)
                (
                  e.$1,
                  List<LatLng>.from(e.$2),
                  _kGpxImportRouteStrokeArgb,
                  _kGpxImportRouteStrokeWidth,
                ),
          ]);
        _gpxImportTrackLinesOnly
          ..clear()
          ..addAll([
            for (final e in p.namedTrackLines)
              if (e.$2.length >= 2) (e.$1, List<LatLng>.from(e.$2)),
          ]);
        _gpxImportRouteLinesOnly
          ..clear()
          ..addAll([
            for (final e in p.namedRouteLines)
              if (e.$2.length >= 2) (e.$1, List<LatLng>.from(e.$2)),
          ]);
        _kmlImportPoints
          ..clear()
          ..addAll([
            for (final e in p.wpts) KmlPointImport(name: e.$1, point: e.$2),
          ]);
        _selectedKmlRouteVertexIndex = null;
        _routeVertices.clear();
        for (final t in p.tracks) {
          if (t.length >= 2) _routeVertices.addAll(t);
        }
        for (final rt in p.routes) {
          if (rt.length >= 2) _routeVertices.addAll(rt);
        }
        for (final e in p.wpts) {
          _routeVertices.add(e.$2);
        }
        _status = 'GPX: ${_kmlImportLoadStatusPrefix()}${_routeVertices.length} nokta (tüm iz/rotalar birleşik).';
      });
      return;
    }

    final mergedKml = await parseKmlDocumentsWithNetworkLinks([docText]);
    var kmlPoints = mergedKml.points;
    if (!kIsWeb && plat.path != null && nameLower.endsWith('.kml')) {
      kmlPoints = await _hydrateKmlPointIcons(mergedKml.points, plat.path!);
    }
    if (!mounted) return;
    _setStateAndRefreshSheet(() {
      _geoPdfExtentPolygon.clear();
      _geoPdfRasterJpeg = null;
      _selectedKmlRouteVertexIndex = null;
      _routeVertices.clear();
      _polygonVertices.clear();
      _polygonHoles.clear();
      _resetKmlPrimaryPolygonVisual();
      _additionalPolygonPatches.clear();
      _gpxImportTrackLinesOnly.clear();
      _gpxImportRouteLinesOnly.clear();
      _kmlImportStyledPolylines
        ..clear()
        ..addAll([
          for (final e in mergedKml.styledLines)
            if (e.$2.length >= 2) (e.$1, List<LatLng>.from(e.$2), e.$3, e.$4),
        ]);
      _kmlImportPoints
        ..clear()
        ..addAll(kmlPoints);
      var firstPoly = true;
      for (final patch in mergedKml.polygonPatches) {
        if (patch.outer.length < 3) continue;
        if (firstPoly) {
          _polygonVertices.addAll(patch.outer);
          _polygonHoles.addAll(patch.holes.map((e) => List<LatLng>.from(e)));
          _kmlPrimaryPolygonFillArgb32 = patch.fillArgb32;
          _kmlPrimaryPolygonStrokeArgb32 = patch.strokeArgb32;
          _kmlPrimaryPolygonStrokeWidthPx = patch.strokeWidthPx;
          _kmlPrimaryPolygonDrawStrokeOutline = patch.drawStrokeOutline;
          firstPoly = false;
        } else {
          _additionalPolygonPatches.add(KmlPolygonPatch(
            outer: List<LatLng>.from(patch.outer),
            holes: patch.holes.map((e) => List<LatLng>.from(e)).toList(),
            fillArgb32: patch.fillArgb32,
            strokeArgb32: patch.strokeArgb32,
            strokeWidthPx: patch.strokeWidthPx,
            drawStrokeOutline: patch.drawStrokeOutline,
          ));
        }
      }
      for (final line in mergedKml.lines) {
        if (line.length >= 2) _routeVertices.addAll(line);
      }
      for (final e in kmlPoints) {
        _routeVertices.add(e.point);
      }
      final nl = _kmlNetworkLinkImportSuffix(
        hadLink: mergedKml.anyHadNetworkLink,
        resolved: mergedKml.anyResolvedNetworkLink,
      );
      _status =
          'KML: ${_kmlImportLoadStatusPrefix()}${_routeVertices.length} rota noktası${_polygonClosedPieceCount() > 0 ? ', ${_polygonClosedPieceCount()} alan parçası' : ''}.$nl';
    });
  }

  String _kmlNetworkLinkImportSuffix({required bool hadLink, required bool resolved}) {
    if (!hadLink) return '';
    return resolved
        ? ' NetworkLink: bağlı KML birleştirildi.'
        : ' NetworkLink: HTTPS indirme yok veya sınır (boyut/süre).';
  }

  void _toggleTrackRecording() {
    final nowRecording = !_recordingTrack;
    _setStateAndRefreshSheet(() {
      _recordingTrack = nowRecording;
      if (nowRecording) {
        _recordedTrack.clear();
        _trackRecordingStartedAt = DateTime.now();
        _status =
            'İz kaydı · gerçek GPS (harita sabitlense bile); Android’de bildirim, iOS’ta «Her zaman» önerilir.';
      } else {
        _trackRecordingStartedAt = null;
        _status = 'İz durdu (${_recordedTrack.length} nokta).';
      }
    });
    _syncTrackStatsTimerForRecording(nowRecording);
    if (nowRecording && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(Permission.notification.request());
    }
    unawaited(_startPositionStreamWhenAllowed());
  }

  Future<void> _showElevationProfile() async {
    if (_routeVertices.length >= 2) {
      await showElevationProfileDialog(context, List<LatLng>.from(_routeVertices));
    } else if (_recordedTrack.length >= 2) {
      await showElevationProfileDialog(context, List<LatLng>.from(_recordedTrack));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az 2 noktalı rota veya kayıtlı iz gerekli.')),
      );
    }
  }

  static bool _losApproxSameLatLng(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < 1e-5 && (a.longitude - b.longitude).abs() < 1e-5;

  List<({List<LatLng> points, bool blocked})>? get _effectiveLosMapSegments {
    final w1 = _waypoint1;
    final w2 = _waypoint2;
    final segs = _losMapSegments;
    final o = _losMapObs;
    final t = _losMapTgt;
    if (segs == null || o == null || t == null || w1 == null || w2 == null) return null;
    if (!_losApproxSameLatLng(w1, o) || !_losApproxSameLatLng(w2, t)) return null;
    return segs;
  }

  LatLng? get _effectiveLosBlockedApprox =>
      _effectiveLosMapSegments == null ? null : _losBlockedApprox;

  List<LatLng>? get _effectiveLosThreatTubeOuter {
    final w1 = _waypoint1;
    final w2 = _waypoint2;
    final outer = _losThreatTubeOuter;
    final o = _losThreatObs;
    final t = _losThreatTgt;
    if (outer == null || o == null || t == null || w1 == null || w2 == null) return null;
    if (!_losApproxSameLatLng(w1, o) || !_losApproxSameLatLng(w2, t)) return null;
    return outer;
  }

  static LatLng _offsetByMeters(LatLng origin, {required double eastM, required double northM}) {
    const metersPerDegLat = 111320.0;
    final dLat = northM / metersPerDegLat;
    final cosLat = math.cos(origin.latitude * math.pi / 180).abs().clamp(0.1, 1.0);
    final dLon = eastM / (metersPerDegLat * cosLat);
    return LatLng(origin.latitude + dLat, origin.longitude + dLon);
  }

  static List<LatLng>? _buildThreatTubeOuter(
    LatLng a,
    LatLng b, {
    required double halfWidthStartM,
    required double halfWidthEndM,
  }) {
    final meanLat = (a.latitude + b.latitude) * 0.5;
    final cosLat = math.cos(meanLat * math.pi / 180).abs().clamp(0.1, 1.0);
    const metersPerDegLat = 111320.0;
    final north = (b.latitude - a.latitude) * metersPerDegLat;
    final east = (b.longitude - a.longitude) * metersPerDegLat * cosLat;
    final len = math.sqrt(east * east + north * north);
    if (len < 1) return null;

    final dirEast = east / len;
    final dirNorth = north / len;
    // Sol normal (ENU)
    final nLeftEast = -dirNorth;
    final nLeftNorth = dirEast;
    final nRightEast = -nLeftEast;
    final nRightNorth = -nLeftNorth;

    final aLeft = _offsetByMeters(
      a,
      eastM: nLeftEast * halfWidthStartM,
      northM: nLeftNorth * halfWidthStartM,
    );
    final bLeft = _offsetByMeters(
      b,
      eastM: nLeftEast * halfWidthEndM,
      northM: nLeftNorth * halfWidthEndM,
    );
    final bRight = _offsetByMeters(
      b,
      eastM: nRightEast * halfWidthEndM,
      northM: nRightNorth * halfWidthEndM,
    );
    final aRight = _offsetByMeters(
      a,
      eastM: nRightEast * halfWidthStartM,
      northM: nRightNorth * halfWidthStartM,
    );
    return [aLeft, bLeft, bRight, aRight];
  }

  void _toggleLosThreatTubeMvp() {
    final w1 = _waypoint1;
    final w2 = _waypoint2;
    if (w1 == null || w2 == null) return;
    final already = _effectiveLosThreatTubeOuter != null;
    if (already) {
      _setStateAndRefreshSheet(() {
        _losThreatTubeOuter = null;
        _losThreatObs = null;
        _losThreatTgt = null;
      });
      return;
    }
    final outer = _buildThreatTubeOuter(
      w1,
      w2,
      halfWidthStartM: _losThreatHalfWidthM,
      halfWidthEndM: _losThreatTargetHalfWidthM,
    );
    if (outer == null || outer.length < 3) return;
    _setStateAndRefreshSheet(() {
      _losThreatTubeOuter = outer;
      _losThreatObs = w1;
      _losThreatTgt = w2;
      _status = 'Paket 4 MVP: tehdit tüpü (${_losThreatHalfWidthM.toStringAsFixed(0)} m yarı genişlik) gösteriliyor.';
    });
  }

  void _updateLosThreatHalfWidthM(double halfWidthM) {
    _setStateAndRefreshSheet(() {
      _losThreatHalfWidthM = halfWidthM.clamp(10.0, 300.0);
      final w1 = _waypoint1;
      final w2 = _waypoint2;
      if (_effectiveLosThreatTubeOuter != null && w1 != null && w2 != null) {
        final outer = _buildThreatTubeOuter(
          w1,
          w2,
          halfWidthStartM: _losThreatHalfWidthM,
          halfWidthEndM: _losThreatTargetHalfWidthM,
        );
        if (outer != null && outer.length >= 3) {
          _losThreatTubeOuter = outer;
          _losThreatObs = w1;
          _losThreatTgt = w2;
        }
      }
    });
  }

  void _updateLosThreatTargetHalfWidthM(double halfWidthM) {
    _setStateAndRefreshSheet(() {
      _losThreatTargetHalfWidthM = halfWidthM.clamp(10.0, 600.0);
      final w1 = _waypoint1;
      final w2 = _waypoint2;
      if (_effectiveLosThreatTubeOuter != null && w1 != null && w2 != null) {
        final outer = _buildThreatTubeOuter(
          w1,
          w2,
          halfWidthStartM: _losThreatHalfWidthM,
          halfWidthEndM: _losThreatTargetHalfWidthM,
        );
        if (outer != null && outer.length >= 3) {
          _losThreatTubeOuter = outer;
          _losThreatObs = w1;
          _losThreatTgt = w2;
        }
      }
    });
  }

  void _applyLosMapOverlay(SimpleLosResult r, LatLng obs, LatLng tgt) {
    final segs = losSegmentsForMap(obs, tgt, r);
    if (segs.isEmpty) return;
    _setStateAndRefreshSheet(() {
      _losMapSegments = segs;
      _losMapObs = obs;
      _losMapTgt = tgt;
      _losBlockedApprox = losFirstBlockApproxPosition(obs, tgt, r);
    });
  }

  void _clearLosMapOverlay() {
    _setStateAndRefreshSheet(() {
      _losMapSegments = null;
      _losMapObs = null;
      _losMapTgt = null;
      _losBlockedApprox = null;
      _losThreatTubeOuter = null;
      _losThreatObs = null;
      _losThreatTgt = null;
    });
  }

  Future<void> _importCas3dPackage() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: kIsWeb,
      );
      if (picked == null || picked.files.isEmpty) return;
      final f = picked.files.first;
      final path = f.path;
      Cas3dPackage pack;
      if (path != null && path.trim().isNotEmpty && !kIsWeb) {
        pack = await loadCas3dPackageFromPath(path);
      } else {
        final bytes = f.bytes;
        if (bytes == null || bytes.isEmpty) {
          throw const FormatException('Seçilen dosya okunamadı.');
        }
        pack = parseCas3dPackageJson(utf8.decode(bytes));
      }
      _setStateAndRefreshSheet(() {
        _cas3dPackage = pack;
        final packIds = <String>{for (final e in pack.threatTubes) e.id};
        switch (_cas3dPresetMode) {
          case Cas3dTubePresetMode.all:
            _cas3dEnabledTubeIds
              ..clear()
              ..addAll(packIds);
            break;
          case Cas3dTubePresetMode.none:
            _cas3dEnabledTubeIds.clear();
            break;
          case Cas3dTubePresetMode.high:
            _cas3dEnabledTubeIds
              ..clear()
              ..addAll(
                pack.threatTubes
                    .where((t) => (t.maxAltM ?? 0) >= 600)
                    .map((e) => e.id),
              );
            break;
          case Cas3dTubePresetMode.custom:
            _cas3dEnabledTubeIds.removeWhere((e) => !packIds.contains(e));
            if (_cas3dEnabledTubeIds.isEmpty) {
              _cas3dEnabledTubeIds.addAll(packIds);
              _cas3dPresetMode = Cas3dTubePresetMode.all;
            }
            break;
        }
        _rebuildCas3dMapLayersFromSelection();
        _status =
            'CAS 3B yüklendi: ${pack.name} v${pack.version} · ${pack.threatTubes.length} threat tube.';
      });
      unawaited(_persistMapDisplayPrefs());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CAS 3B yükleme hatası: $e')),
      );
    }
  }

  Future<void> _configureCasRemote() async {
    final url0 = await CasRemotePrefs.getUrl() ?? '';
    final auth0 = await CasRemotePrefs.getAuthRaw() ?? '';
    final tenant0 = await CasRemotePrefs.getTenant() ?? '';
    final limit0 = (await CasRemotePrefs.getLimit())?.toString() ?? '';
    final maxPages0 = (await CasRemotePrefs.getMaxPages()).toString();
    final minAlt0 = (await CasRemotePrefs.getMinAlt())?.toStringAsFixed(0) ?? '';
    final maxAlt0 = (await CasRemotePrefs.getMaxAlt())?.toStringAsFixed(0) ?? '';
    final bbox0 = await CasRemotePrefs.getBbox() ?? '';
    final tenantAsHeader0 = await CasRemotePrefs.getTenantAsHeader();
    final paramStyle0 = await CasRemotePrefs.getParamStyle();
    final cursorParamStyle0 = await CasRemotePrefs.getCursorParamStyle();
    final strictNextCursor0 = await CasRemotePrefs.getStrictNextCursor();
    if (!mounted) return;
    final urlCtrl = TextEditingController(text: url0);
    final authCtrl = TextEditingController(text: auth0);
    final tenantCtrl = TextEditingController(text: tenant0);
    final limitCtrl = TextEditingController(text: limit0);
    final maxPagesCtrl = TextEditingController(text: maxPages0);
    final minAltCtrl = TextEditingController(text: minAlt0);
    final maxAltCtrl = TextEditingController(text: maxAlt0);
    final bboxCtrl = TextEditingController(text: bbox0);
    var tenantAsHeader = tenantAsHeader0;
    var paramStyle = paramStyle0;
    var cursorParamStyle = cursorParamStyle0;
    var strictNextCursor = strictNextCursor0;
    String? urlError;
    String? limitError;
    String? maxPagesError;
    String? minAltError;
    String? maxAltError;
    String? bboxError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Kurumsal CAS bağlantısı'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    labelText: 'CAS JSON URL',
                    hintText: 'https://cas.example.com/api/v1/threat-tubes',
                    errorText: urlError,
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setLocalState(() => urlError = null),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: authCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Authorization (opsiyonel)',
                    hintText: 'Bearer xxx veya Basic xxx',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tenantCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tenant (opsiyonel)',
                    hintText: 'acme-tr',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: tenantAsHeader,
                  onChanged: (v) => setLocalState(() => tenantAsHeader = v),
                  title: const Text('Tenant header ile gönder (X-Tenant-Id)'),
                  subtitle: const Text('Kapalıysa query param olarak gönderilir'),
                ),
                DropdownButtonFormField<CasRemoteParamStyle>(
                  initialValue: paramStyle,
                  decoration: const InputDecoration(
                    labelText: 'Parametre stili',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: CasRemoteParamStyle.camelCase,
                      child: Text('camelCase (minAlt, maxAlt)'),
                    ),
                    DropdownMenuItem(
                      value: CasRemoteParamStyle.snakeCase,
                      child: Text('snake_case (min_alt, max_alt)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setLocalState(() => paramStyle = v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<CasRemoteCursorParamStyle>(
                  initialValue: cursorParamStyle,
                  decoration: const InputDecoration(
                    labelText: 'Cursor parametresi',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: CasRemoteCursorParamStyle.cursor,
                      child: Text('cursor'),
                    ),
                    DropdownMenuItem(
                      value: CasRemoteCursorParamStyle.pageCursor,
                      child: Text('pageCursor'),
                    ),
                    DropdownMenuItem(
                      value: CasRemoteCursorParamStyle.pageSnakeCursor,
                      child: Text('page_cursor'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setLocalState(() => cursorParamStyle = v);
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: strictNextCursor,
                  onChanged: (v) => setLocalState(() => strictNextCursor = v),
                  title: const Text('Strict next cursor'),
                  subtitle: const Text('Açıksa sadece seçilen cursor alanı okunur'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: limitCtrl,
                  decoration: InputDecoration(
                    labelText: 'Sayfa başı kayıt (opsiyonel)',
                    hintText: '100',
                    errorText: limitError,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  ],
                  onChanged: (_) => setLocalState(() => limitError = null),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: maxPagesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Maksimum sayfa',
                    hintText: '8',
                    errorText: maxPagesError,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  ],
                  onChanged: (_) => setLocalState(() => maxPagesError = null),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: minAltCtrl,
                  decoration: InputDecoration(
                    labelText: 'Min irtifa filtresi (opsiyonel, m)',
                    hintText: '200',
                    errorText: minAltError,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[-0-9\.,]')),
                  ],
                  onChanged: (_) => setLocalState(() => minAltError = null),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: maxAltCtrl,
                  decoration: InputDecoration(
                    labelText: 'Max irtifa filtresi (opsiyonel, m)',
                    hintText: '1200',
                    errorText: maxAltError,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[-0-9\.,]')),
                  ],
                  onChanged: (_) => setLocalState(() => maxAltError = null),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bboxCtrl,
                  decoration: InputDecoration(
                    labelText: 'BBOX filtresi (opsiyonel)',
                    hintText: 'minLon,minLat,maxLon,maxLat',
                    errorText: bboxError,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[-0-9\.,\s]')),
                  ],
                  onChanged: (_) => setLocalState(() => bboxError = null),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(
              onPressed: () {
                final urlText = urlCtrl.text.trim();
                final limitText = limitCtrl.text.trim();
                final maxPagesText = maxPagesCtrl.text.trim();
                final minAltText = minAltCtrl.text.trim();
                final maxAltText = maxAltCtrl.text.trim();
                final bboxText = bboxCtrl.text.trim();

                String? nextUrlError;
                String? nextLimitError;
                String? nextMaxPagesError;
                String? nextMinAltError;
                String? nextMaxAltError;
                String? nextBboxError;

                final parsedUri = urlText.isEmpty ? null : Uri.tryParse(urlText);
                final urlOk =
                    parsedUri != null &&
                    parsedUri.hasScheme &&
                    (parsedUri.scheme == 'http' || parsedUri.scheme == 'https');
                if (urlText.isNotEmpty && !urlOk) {
                  nextUrlError = 'http/https adresi girin';
                }

                final parsedLimit = limitText.isEmpty ? null : int.tryParse(limitText);
                if (limitText.isNotEmpty && parsedLimit == null) {
                  nextLimitError = 'Sayısal olmalı';
                }

                final parsedMaxPages = maxPagesText.isEmpty ? null : int.tryParse(maxPagesText);
                if (maxPagesText.isNotEmpty && parsedMaxPages == null) {
                  nextMaxPagesError = 'Sayısal olmalı';
                }

                final parsedMinAlt = minAltText.isEmpty
                    ? null
                    : double.tryParse(minAltText.replaceAll(',', '.'));
                if (minAltText.isNotEmpty && parsedMinAlt == null) {
                  nextMinAltError = 'Sayısal olmalı';
                }

                final parsedMaxAlt = maxAltText.isEmpty
                    ? null
                    : double.tryParse(maxAltText.replaceAll(',', '.'));
                if (maxAltText.isNotEmpty && parsedMaxAlt == null) {
                  nextMaxAltError = 'Sayısal olmalı';
                }

                if (parsedMinAlt != null && parsedMaxAlt != null && parsedMinAlt > parsedMaxAlt) {
                  nextMaxAltError = 'Max, min irtifadan küçük olamaz';
                }

                if (bboxText.isNotEmpty) {
                  final parts =
                      bboxText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  if (parts.length != 4 ||
                      parts.any((e) => double.tryParse(e.replaceAll(',', '.')) == null)) {
                    nextBboxError = 'Format: minLon,minLat,maxLon,maxLat';
                  }
                }

                setLocalState(() {
                  urlError = nextUrlError;
                  limitError = nextLimitError;
                  maxPagesError = nextMaxPagesError;
                  minAltError = nextMinAltError;
                  maxAltError = nextMaxAltError;
                  bboxError = nextBboxError;
                });

                if (nextUrlError == null &&
                    nextLimitError == null &&
                    nextMaxPagesError == null &&
                    nextMinAltError == null &&
                    nextMaxAltError == null &&
                    nextBboxError == null) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final urlText = urlCtrl.text.trim();
      final limitText = limitCtrl.text.trim();
      final maxPagesText = maxPagesCtrl.text.trim();
      final minAltText = minAltCtrl.text.trim();
      final maxAltText = maxAltCtrl.text.trim();
      final bboxText = bboxCtrl.text.trim();
      final parsedLimit = limitText.isEmpty ? null : int.tryParse(limitText);
      final parsedMaxPages = maxPagesText.isEmpty ? null : int.tryParse(maxPagesText);
      final parsedMinAlt = minAltText.isEmpty
          ? null
          : double.tryParse(minAltText.replaceAll(',', '.'));
      final parsedMaxAlt = maxAltText.isEmpty
          ? null
          : double.tryParse(maxAltText.replaceAll(',', '.'));
      await CasRemotePrefs.save(
        url: urlText,
        auth: authCtrl.text,
        tenant: tenantCtrl.text,
        limit: parsedLimit,
        maxPages: parsedMaxPages,
        minAlt: parsedMinAlt,
        maxAlt: parsedMaxAlt,
        bbox: bboxText,
        tenantAsHeader: tenantAsHeader,
        paramStyle: paramStyle,
        cursorParamStyle: cursorParamStyle,
        strictNextCursor: strictNextCursor,
      );
      await _refreshCasRemoteProfileSummary();
      if (!mounted) return;
      setState(() => _status = 'CAS bağlantı ayarları kaydedildi.');
    }
  }

  void _rescheduleCasRemoteAutoSync() {
    _casRemoteAutoSyncTimer?.cancel();
    if (!_casRemoteAutoSyncEnabled) return;
    _casRemoteAutoSyncTimer = Timer.periodic(
      Duration(seconds: _casRemoteAutoSyncSec.clamp(30, 600).toInt()),
      (_) => unawaited(_pullCas3dPackageFromRemote(silentError: true, fromAutoSync: true)),
    );
  }

  Future<void> _pullCas3dPackageFromRemote({
    bool silentError = false,
    bool fromAutoSync = false,
  }) async {
    try {
      if (!fromAutoSync) {
        setState(() => _status = 'Kurumsal CAS verisi indiriliyor…');
      }
      final pack = await CasRemoteService.pullCas3dPackage();
      final syncNow = DateTime.now();
      _setStateAndRefreshSheet(() {
        _cas3dPackage = pack;
        _casRemoteLastSyncAt = syncNow;
        final packIds = <String>{for (final e in pack.threatTubes) e.id};
        switch (_cas3dPresetMode) {
          case Cas3dTubePresetMode.all:
            _cas3dEnabledTubeIds
              ..clear()
              ..addAll(packIds);
            break;
          case Cas3dTubePresetMode.none:
            _cas3dEnabledTubeIds.clear();
            break;
          case Cas3dTubePresetMode.high:
            _cas3dEnabledTubeIds
              ..clear()
              ..addAll(
                pack.threatTubes.where((t) => (t.maxAltM ?? 0) >= 600).map((e) => e.id),
              );
            break;
          case Cas3dTubePresetMode.custom:
            _cas3dEnabledTubeIds.removeWhere((e) => !packIds.contains(e));
            if (_cas3dEnabledTubeIds.isEmpty) {
              _cas3dEnabledTubeIds.addAll(packIds);
              _cas3dPresetMode = Cas3dTubePresetMode.all;
            }
            break;
        }
        _rebuildCas3dMapLayersFromSelection();
        final ts =
            '${_casRemoteLastSyncAt!.hour.toString().padLeft(2, '0')}:${_casRemoteLastSyncAt!.minute.toString().padLeft(2, '0')}';
        _status = 'CAS uzaktan yüklendi: ${pack.name} · ${pack.threatTubes.length} tube · $ts';
      });
      unawaited(CasRemotePrefs.setLastSyncAt(syncNow));
      unawaited(_persistMapDisplayPrefs());
    } catch (e) {
      if (!mounted) return;
      if (!silentError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kurumsal CAS hatası: $e')),
        );
      }
      setState(() => _status = fromAutoSync ? 'Kurumsal CAS otomatik çekimde hata.' : 'Kurumsal CAS hatası.');
    }
  }

  void _clearCas3dPackage() {
    _setStateAndRefreshSheet(() {
      _cas3dPackage = null;
      _cas3dThreatPolygons.clear();
      _cas3dThreatCenterLines.clear();
      _cas3dThreatLabels.clear();
      _cas3dEnabledTubeIds.clear();
      _status = 'CAS 3B katmanı temizlendi.';
    });
  }

  Color _cas3dTubeColor(Cas3dThreatTube t) {
    final maxAlt = t.maxAltM;
    if (maxAlt == null) return Colors.redAccent;
    if (maxAlt < 250) return Colors.lightGreen.shade600;
    if (maxAlt < 600) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  void _rebuildCas3dMapLayersFromSelection() {
    final pack = _cas3dPackage;
    if (pack == null) {
      _cas3dThreatPolygons.clear();
      _cas3dThreatCenterLines.clear();
      _cas3dThreatLabels.clear();
      _cas3dEnabledTubeIds.clear();
      return;
    }
    final polys = <Polygon>[];
    final lines = <Polyline>[];
    final labels = <(LatLng point, String text)>[];
    for (final t in pack.threatTubes) {
      if (!_cas3dEnabledTubeIds.contains(t.id)) continue;
      final ring = casThreatTubeFootprint(t);
      if (ring.length < 3) continue;
      final c = _cas3dTubeColor(t);
      polys.add(
        Polygon(
          points: ring,
          color: c.withValues(alpha: 0.12),
          borderColor: c.withValues(alpha: 0.85),
          borderStrokeWidth: 1.6,
        ),
      );
      lines.add(
        Polyline(
          points: [t.observer, t.target],
          strokeWidth: 2.2,
          color: c.withValues(alpha: 0.85),
          pattern: StrokePattern.dashed(segments: const [8, 5]),
        ),
      );
      final altText = (t.minAltM != null || t.maxAltM != null)
          ? ' ${t.minAltM?.round() ?? '?'}..${t.maxAltM?.round() ?? '?'} m'
          : '';
      labels.add((t.target, '${t.id}$altText'));
    }
    _cas3dThreatPolygons
      ..clear()
      ..addAll(polys);
    _cas3dThreatCenterLines
      ..clear()
      ..addAll(lines);
    _cas3dThreatLabels
      ..clear()
      ..addAll(labels);
  }

  void _toggleCas3dTube(String id, bool enabled) {
    _setStateAndRefreshSheet(() {
      if (enabled) {
        _cas3dEnabledTubeIds.add(id);
      } else {
        _cas3dEnabledTubeIds.remove(id);
      }
      _cas3dPresetMode = Cas3dTubePresetMode.custom;
      _rebuildCas3dMapLayersFromSelection();
    });
    unawaited(_persistMapDisplayPrefs());
  }

  void _enableAllCas3dTubes() {
    final pack = _cas3dPackage;
    if (pack == null) return;
    _setStateAndRefreshSheet(() {
      _cas3dEnabledTubeIds
        ..clear()
        ..addAll(pack.threatTubes.map((e) => e.id));
      _cas3dPresetMode = Cas3dTubePresetMode.all;
      _rebuildCas3dMapLayersFromSelection();
    });
    unawaited(_persistMapDisplayPrefs());
  }

  void _disableAllCas3dTubes() {
    _setStateAndRefreshSheet(() {
      _cas3dEnabledTubeIds.clear();
      _cas3dPresetMode = Cas3dTubePresetMode.none;
      _rebuildCas3dMapLayersFromSelection();
    });
    unawaited(_persistMapDisplayPrefs());
  }

  void _enableHighCas3dTubes() {
    final pack = _cas3dPackage;
    if (pack == null) return;
    _setStateAndRefreshSheet(() {
      _cas3dEnabledTubeIds
        ..clear()
        ..addAll(
          pack.threatTubes
              .where((t) => (t.maxAltM ?? 0) >= 600)
              .map((e) => e.id),
        );
      _cas3dPresetMode = Cas3dTubePresetMode.high;
      _rebuildCas3dMapLayersFromSelection();
    });
    unawaited(_persistMapDisplayPrefs());
  }

  void _setCas3dPresetMode(Cas3dTubePresetMode mode) {
    switch (mode) {
      case Cas3dTubePresetMode.all:
        _enableAllCas3dTubes();
        return;
      case Cas3dTubePresetMode.none:
        _disableAllCas3dTubes();
        return;
      case Cas3dTubePresetMode.high:
        _enableHighCas3dTubes();
        return;
      case Cas3dTubePresetMode.custom:
        _setStateAndRefreshSheet(() {
          _cas3dPresetMode = Cas3dTubePresetMode.custom;
        });
        unawaited(_persistMapDisplayPrefs());
        return;
    }
  }

  Widget _coordBlock(String title, LatLng p, {double? demM}) {
    final q = _coordWithNtv2(p);
    final ntv2 = _ntv2GsbGrid;
    final ntv2Inside = ntv2 != null && ntv2.coversWgs84(p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (ntv2 != null) ...[
          Text(
            ntv2Inside
                ? 'NTv2 kaymalı gösterim (ızgara içi)'
                : 'NTv2: nokta ızgara dışı — kayma uygulanmıyor',
            style: TextStyle(
              fontSize: 10,
              color: ntv2Inside ? Colors.amber.shade200 : Colors.orangeAccent,
            ),
          ),
          Text(
            'NTv2 kapsam: ${ntv2.extentSummaryDegrees()}',
            style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.72)),
          ),
        ],
        Text(GeoFormatters.decimalDegrees(q)),
        Text(GeoFormatters.dmsHuman(q)),
        Text(GeoFormatters.utmWgs84(q)),
        Text(GeoFormatters.utmWgs84EpsgLine(q, zoneOverride: _utmEpsgDisplayZone)),
        Text('MGRS: ${GeoFormatters.mgrs(q)}'),
        Text(GeoFormatters.sk42GridLine(q)),
        if (demM != null) Text('DEM rakım: ${demM.toStringAsFixed(1)} m'),
      ],
    );
  }

  String _hudPrimaryCoordinateLine(LatLng p) {
    final q = _coordWithNtv2(p);
    switch (_hudCoordFormat) {
      case MapHudCoordFormat.decimalDegrees:
        return GeoFormatters.decimalDegrees(q);
      case MapHudCoordFormat.dms:
        return GeoFormatters.dmsHuman(q);
      case MapHudCoordFormat.mgrs:
        return GeoFormatters.mgrsSpaced(q);
      case MapHudCoordFormat.utmCompact:
        return GeoFormatters.utmCompactEastingNorthing(
          q,
          zoneOverride: _utmEpsgDisplayZone,
        );
      case MapHudCoordFormat.utmEpsg:
        return GeoFormatters.utmWgs84EpsgLine(
          q,
          zoneOverride: _utmEpsgDisplayZone,
        );
      case MapHudCoordFormat.sk42:
        return GeoFormatters.sk42GridLine(q);
    }
  }

  String _hudFormatShortLabel(MapHudCoordFormat f) {
    return switch (f) {
      MapHudCoordFormat.decimalDegrees => 'DD',
      MapHudCoordFormat.dms => 'DMS',
      MapHudCoordFormat.mgrs => 'MGRS',
      MapHudCoordFormat.utmCompact => 'UTM',
      MapHudCoordFormat.utmEpsg => 'UTM+EPSG',
      MapHudCoordFormat.sk42 => 'SK-42',
    };
  }

  Widget _buildTacticalHudBar(
    BuildContext context,
    LatLng hudCenter,
    double? measM,
    double? azDeg,
    int? milNato,
  ) {
    final ntv2 = _ntv2GsbGrid;
    final ntv2Inside = ntv2 != null && ntv2.coversWgs84(hudCenter);
    final primary = _hudPrimaryCoordinateLine(hudCenter);
    final measStr = _distanceUnit.formatHudDistance(measM);
    final azStr = azDeg == null ? '—' : '∡${azDeg.toStringAsFixed(0)}°';
    final milStr = milNato == null ? '—' : '$milNato mil';
    const shadow = Shadow(blurRadius: 4, color: Colors.black87);

    return Material(
      color: Colors.transparent,
      elevation: 4,
      shadowColor: Colors.black54,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xE6101410),
              Color(0xE60F2818),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x994CAF50)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.2,
              shadows: [shadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x992E7D32),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0x6681C784)),
                      ),
                      child: Text(
                        _hudFormatShortLabel(_hudCoordFormat),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: Color(0xFFC8E6C9),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          primary,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            shadows: [shadow],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(milStr),
                      const Text('  ·  '),
                      Text(measStr),
                      const Text('  ·  '),
                      Text(azStr),
                    ],
                  ),
                ),
                if (ntv2 != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    ntv2Inside
                        ? 'NTv2 · ızgara içi · ${ntv2.extentSummaryDegrees()}'
                        : 'NTv2 · konum dışı (kayma yok) · ${ntv2.extentSummaryDegrees()}',
                    style: TextStyle(
                      fontSize: 10,
                      color: ntv2Inside ? const Color(0xFFC8E6C9) : Colors.amberAccent.shade100,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompassRose() {
    return Transform.rotate(
      angle: -_mapRotationDeg * math.pi / 180,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
          shape: BoxShape.circle,
        ),
        child: CustomPaint(painter: _CompassRosePainter()),
      ),
    );
  }

  Widget _buildTopRightTools(BuildContext context, LatLng? gps, LatLng? w1) {
    return Material(
      color: Colors.black.withValues(alpha: 0.52),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('maps_topright_coordinate_search_button'),
            tooltip: 'Koordinat / arama',
            onPressed: () {
              final c = w1 ?? gps ?? _mapHudCenter;
              showCoordinateTargetPickerSheet(
                context,
                initialCenter: c,
                tileProvider: _onlineTileProvider(),
                onApply: (p) {
                  setState(() {
                    if (_userPins.isEmpty) {
                      final id = 'p${_pinIdSeq++}';
                      _userPins.add(_MapUserPin(id: id, point: p, colorIndex: 0));
                      _pinDemMeters[id] = null;
                    } else {
                      final id0 = _userPins.first.id;
                      _userPins.first.point = p;
                      _pinDemMeters[id0] = null;
                    }
                    _status = 'Koordinat → ilk işaret güncellendi.';
                  });
                },
              );
            },
            icon: const Icon(Icons.search, color: Colors.white, size: 22),
          ),
          IconButton(
            key: const ValueKey('maps_topright_layers_button'),
            tooltip: 'Katmanlar',
            onPressed: _openLayersQuickSheet,
            icon: const Icon(Icons.layers_outlined, color: Colors.white, size: 22),
          ),
          IconButton(
            tooltip: _recordingTrack ? 'İz kaydını durdur' : 'İz kaydı',
            onPressed: _toggleTrackRecording,
            icon: Icon(
              _recordingTrack ? Icons.stop_circle_outlined : Icons.timeline,
              color: _recordingTrack ? Colors.redAccent : Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomAndLocationColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.black.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const ValueKey('maps_zoom_in_button'),
                tooltip: 'Yakınlaştır',
                onPressed: () {
                  _moveMapCamera(_readMapCenterLatLng(), _readMapZoom() + 1);
                },
                icon: const Icon(Icons.add, color: Colors.white),
              ),
              IconButton(
                key: const ValueKey('maps_zoom_out_button'),
                tooltip: 'Uzaklaştır',
                onPressed: () {
                  _moveMapCamera(_readMapCenterLatLng(), _readMapZoom() - 1);
                },
                icon: const Icon(Icons.remove, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.black.withValues(alpha: 0.52),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            tooltip: 'Konumumu al / merkezle',
            onPressed: _setupLocationAndCenter,
            icon: const Icon(Icons.my_location, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomToolStrip() {
    Color iconColor(_MapTapMode m) =>
        _tapMode == m ? Theme.of(context).colorScheme.primary : Colors.white;

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SizedBox(
        height: _kMapBottomBarTotalHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _kMapBottomPaletteHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'İşaret rengi',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  for (var i = 0; i < _kMapUserPinPalette.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _selectedPinPaletteIndex = i),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _kMapUserPinPalette[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedPinPaletteIndex == i ? Colors.white : Colors.black38,
                                width: _selectedPinPaletteIndex == i ? 2.5 : 1,
                              ),
                              boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black45)],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: _kMapBottomToolsHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    key: const ValueKey('maps_bottom_open_details_button'),
                    tooltip: 'Menü · nokta listesi · DEM',
                    onPressed: _openMapDetailsSheet,
                    icon: const Icon(Icons.menu, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Bilgi (referans)',
                    onPressed: () => showMapsReferenceComparisonSheet(context),
                    icon: const Icon(Icons.map_outlined, color: Colors.white),
                  ),
                  PopupMenuButton<String>(
                    key: const ValueKey('maps_bottom_export_menu_button'),
                    tooltip: 'Haritayı dışa aktar (GPX / KML / KMZ)',
                    icon: const Icon(Icons.ios_share, color: Colors.white),
                    onSelected: (v) {
                      if (v == 'gpx') {
                        unawaited(_exportGpx());
                      } else if (v == 'kml') {
                        unawaited(_exportKml());
                      } else if (v == 'kmz') {
                        unawaited(_exportKmz());
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'gpx', child: Text('GPX dışa aktar')),
                      PopupMenuItem(value: 'kml', child: Text('KML dışa aktar')),
                      PopupMenuItem(value: 'kmz', child: Text('KMZ dışa aktar')),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Konuma git (GPS)',
                    onPressed: () {
                      final g = _myPosition;
                      if (g != null) {
                        _moveMapCamera(g, 15);
                      } else {
                        unawaited(_setupLocationAndCenter());
                      }
                    },
                    icon: const Icon(Icons.filter_center_focus, color: Colors.white),
                  ),
                  IconButton(
                    key: const ValueKey('maps_bottom_tapmode_polygon_button'),
                    tooltip: 'Alan köşesi',
                    onPressed: () => setState(() => _tapMode = _MapTapMode.polygonVertex),
                    icon: Icon(Icons.pentagon_outlined, color: iconColor(_MapTapMode.polygonVertex)),
                  ),
                  IconButton(
                    key: const ValueKey('maps_bottom_tapmode_route_button'),
                    tooltip: 'Rota noktası',
                    onPressed: () => setState(() => _tapMode = _MapTapMode.routeVertex),
                    icon: Icon(Icons.timeline, color: iconColor(_MapTapMode.routeVertex)),
                  ),
                  IconButton(
                    key: const ValueKey('maps_bottom_tapmode_waypoint1_button'),
                    tooltip: 'İşaret koy (palet 1)',
                    onPressed: () => setState(() {
                      _tapMode = _MapTapMode.placemark;
                      _selectedPinPaletteIndex = 0;
                    }),
                    icon: Icon(
                      Icons.add_location_alt_outlined,
                      color: _tapMode == _MapTapMode.placemark && _selectedPinPaletteIndex == 0
                          ? Theme.of(context).colorScheme.primary
                          : _kMapUserPinPalette[0],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('maps_bottom_tapmode_waypoint2_button'),
                    tooltip: 'İşaret koy (palet 2)',
                    onPressed: () => setState(() {
                      _tapMode = _MapTapMode.placemark;
                      _selectedPinPaletteIndex = 1;
                    }),
                    icon: Icon(
                      Icons.add_location_alt,
                      color: _tapMode == _MapTapMode.placemark && _selectedPinPaletteIndex == 1
                          ? Theme.of(context).colorScheme.primary
                          : _kMapUserPinPalette[1],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPttSection(
    BuildContext context,
    void Function(VoidCallback fn) updateState,
  ) {
    final st = _pttService.state;
    final isLeader = st.members[_collabUserId]?.role == GroupRole.owner;
    final speakerName = st.currentSpeakerId == null
        ? 'Kanal boş'
        : (st.members[st.currentSpeakerId!]?.displayName ?? st.currentSpeakerId!);
    final queuedText = st.queuedUserIds.isEmpty ? '—' : st.queuedUserIds.join(', ');
    final roomId = _pttService.session.sessionId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Oda — $roomId', style: Theme.of(context).textTheme.titleSmall),
        Text(
          'Oluşturma, davet ve katılım: sağ alttaki «Konuşma» baloncuğu.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_inviteRoomPassword != null && _inviteRoomPassword!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Kayıtlı davet şifresi: ${_inviteRoomPassword!}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const Divider(height: 20),
        Text('Grup telsiz (PTT)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text('Aktif konuşan: $speakerName'),
        Text('Sıradakiler: $queuedText'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showRenameDialog(
                targetUserId: _collabUserId,
                currentName: st.members[_collabUserId]?.displayName ?? 'Ben',
                isSelf: true,
                updateState: updateState,
              ),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Adımı değiştir'),
            ),
            FilledButton.icon(
              onPressed: () => _requestTalkWithGuards(updateState),
              icon: const Icon(Icons.mic, size: 18),
              label: const Text('Konuş (PTT)'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                updateState(() {
                  final ok = _pttService.releaseTalk(_collabUserId);
                  if (!ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Şu anda konuşmacı değilsiniz.')),
                    );
                  }
                });
              },
              icon: const Icon(Icons.mic_off, size: 18),
              label: const Text('Bırak'),
            ),
            if (isLeader)
              OutlinedButton.icon(
                onPressed: () {
                  updateState(() {
                    final ok = _pttService.forceNextSpeaker(actorId: _collabUserId);
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sıradakine geçiş uygulanamadı.')),
                      );
                    }
                  });
                },
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('Sıradaki'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...st.members.values.where((m) => m.userId != _collabUserId).map((m) {
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(m.displayName),
            subtitle: Text('${m.role.name}${m.muted ? ' · susturuldu' : ''}'),
            trailing: isLeader
                ? Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Ad değiştir',
                        onPressed: () => _showRenameDialog(
                          targetUserId: m.userId,
                          currentName: m.displayName,
                          isSelf: false,
                          updateState: updateState,
                        ),
                        icon: const Icon(Icons.drive_file_rename_outline),
                      ),
                      IconButton(
                        tooltip: m.muted ? 'Susturmayı kaldır' : 'Sustur',
                        onPressed: () {
                          updateState(() {
                            final ok = _pttService.setMuted(
                              actorId: _collabUserId,
                              targetUserId: m.userId,
                              muted: !m.muted,
                            );
                            if (!ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Susturma durumu değiştirilemedi.')),
                              );
                            }
                          });
                        },
                        icon: Icon(m.muted ? Icons.volume_up : Icons.volume_off),
                      ),
                      IconButton(
                        tooltip: 'Gruptan çıkar',
                        onPressed: () {
                          updateState(() {
                            final ok = _pttService.removeMember(
                              actorId: _collabUserId,
                              targetUserId: m.userId,
                            );
                            if (!ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Üye gruptan çıkarılamadı.')),
                              );
                            }
                          });
                        },
                        icon: const Icon(Icons.person_remove),
                      ),
                    ],
                  )
                : null,
          );
        }),
      ],
    );
  }

  Future<void> _showRenameDialog({
    required String targetUserId,
    required String currentName,
    required bool isSelf,
    required void Function(VoidCallback fn) updateState,
  }) async {
    final ctrl = TextEditingController(text: currentName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isSelf ? 'Adını değiştir' : 'Üye adını değiştir'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Görünen ad',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true) return;
    final newName = ctrl.text.trim();
    if (newName.isEmpty) return;
    updateState(() {
      final ok = _pttService.renameMember(
        actorId: _collabUserId,
        targetUserId: targetUserId,
        newDisplayName: newName,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad güncellenemedi.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gps = _myPosition;
    final w1 = _waypoint1;

    final center = gps ?? w1 ?? const LatLng(39.925533, 32.866287);
    final refPoint = w1 ?? gps;
    final hud = _mapHudCenter;

    double? measM;
    double? azDeg;
    int? milNato;
    if (_tacticalHudEnabled && refPoint != null) {
      measM = Geolocator.distanceBetween(
        refPoint.latitude,
        refPoint.longitude,
        hud.latitude,
        hud.longitude,
      );
      if (measM >= 0.5) {
        azDeg = _bearingDeg360(refPoint, hud);
        milNato = _natoMilFromAzimuthDeg(azDeg).round();
      }
    }

    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final pttState = _pttService.state;
    final speakerId = pttState.currentSpeakerId;
    final mapAttributions = _buildMapAttributions();

    final needsWs =
        widget.pttBackend == RealtimePttBackend.remote &&
            (widget.pttWebsocketUrl == null ||
                widget.pttWebsocketUrl!.trim().isEmpty);

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (needsWs)
              Material(
                color: Colors.amber.shade900,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Text(
                    'Çoklu oda / hedef: APK derlenirken PTT_WS_URL (wss://…) tanımlanmadı — '
                    'cihazlar şu an aynı oturumu paylaşamaz. Tek telefon denemesi için «Yerel» akış çalışır.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_maplibreVectorActive)
                    ml.MapLibreMap(
                      key: ValueKey(_maplibreStyleJson?.length ?? 0),
                      options: ml.MapOptions(
                        initStyle: _maplibreStyleJson ?? 'https://demotiles.maplibre.org/style.json',
                        initCenter: ml.Geographic(lon: center.longitude, lat: center.latitude),
                        initZoom: 6,
                        minZoom: 0,
                        maxZoom: 22,
                      ),
                      onMapCreated: (c) {
                        setState(() => _maplibreController = c);
                        final s = _maplibreStyleJson;
                        if (s != null) c.setStyle(s);
                      },
                      onEvent: _onMaplibreEvent,
                      layers: _maplibreUserAnnotationLayers(
                        tacticalRef: refPoint,
                        tacticalHud: hud,
                        tacticalMeasM: measM,
                        gpsForPins: gps,
                      ),
                      children: [
                        ..._maplibreWidgetLayers(
                          gps: gps,
                          pttState: pttState,
                          speakerId: speakerId,
                        ),
                        const ml.MapScalebar(units: ml.ScaleBarUnit.metric),
                        if (_tacticalHudEnabled)
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 48),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: math.min(420, MediaQuery.sizeOf(context).width - 24),
                                ),
                                child: _buildTacticalHudBar(context, hud, measM, azDeg, milNato),
                              ),
                            ),
                          ),
                        if (_vectorMbtilesUseMaplibreEngine &&
                            _maplibreStyleJson == null &&
                            _maplibreStyleError == null)
                          const Center(child: CircularProgressIndicator()),
                        if (_maplibreStyleError != null)
                          Center(
                            child: Material(
                              color: Colors.black87,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'MapLibre stil yüklenemedi: $_maplibreStyleError',
                                  style: const TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        const ml.SourceAttribution(),
                      ],
                    )
                  else
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 6,
                        onPositionChanged: _onMapPositionChanged,
                        backgroundColor: const Color(0xFF0D160F),
                        onTap: (_, point) => _handleMapTap(point),
                      ),
                      children: [
                if (_rasterSource == _MapRasterSource.online || kIsWeb) ...[
                  Opacity(
                    opacity: _baseLayerOpacity.clamp(0.35, 1.0),
                    child: TileLayer(
                      urlTemplate: _tileUrlForBase(_mapBase),
                      userAgentPackageName: 'com.blueviperpro.app',
                      subdomains: _subdomainsForMapBase(_mapBase),
                      tileProvider: _onlineTileProvider(),
                    ),
                  ),
                  if (_shouldDrawOverlayOnline)
                    Opacity(
                      opacity: _overlayOpacity.clamp(0.15, 0.9),
                      child: TileLayer(
                        urlTemplate: _tileUrlForBase(_overlayBaseLayer!),
                        userAgentPackageName: 'com.blueviperpro.app',
                        subdomains: _subdomainsForMapBase(_overlayBaseLayer!),
                        tileProvider: _onlineTileProvider(),
                      ),
                    ),
                ] else if (_mbTilesProvider != null) ...[
                  Opacity(
                    opacity: _baseLayerOpacity.clamp(0.35, 1.0),
                    child: TileLayer(
                      key: ValueKey(_offlinePackLabel ?? 'mbtiles'),
                      tileProvider: _mbTilesProvider!,
                      userAgentPackageName: 'com.blueviperpro.app',
                      minNativeZoom: _mbtilesMinNativeZoom,
                      maxNativeZoom: _mbtilesMaxNativeZoom,
                    ),
                  ),
                  if (_overlayBaseLayer != null)
                    Opacity(
                      opacity: _overlayOpacity.clamp(0.15, 0.9),
                      child: TileLayer(
                        urlTemplate: _tileUrlForBase(_overlayBaseLayer!),
                        userAgentPackageName: 'com.blueviperpro.app',
                        subdomains: _subdomainsForMapBase(_overlayBaseLayer!),
                        tileProvider: _onlineTileProvider(),
                      ),
                    ),
                ] else if (_usesOfflineVectorBasemap) ...[
                  if (_overlayBaseLayer != null)
                    Opacity(
                      opacity: _overlayOpacity.clamp(0.15, 0.9),
                      child: TileLayer(
                        urlTemplate: _tileUrlForBase(_overlayBaseLayer!),
                        userAgentPackageName: 'com.blueviperpro.app',
                        subdomains: _subdomainsForMapBase(_overlayBaseLayer!),
                        tileProvider: _onlineTileProvider(),
                      ),
                    ),
                ],
                if (_hillshadeOverlayEnabled &&
                    (_rasterSource == _MapRasterSource.online ||
                        kIsWeb ||
                        _mbTilesProvider != null ||
                        _usesOfflineVectorBasemap))
                  Opacity(
                    opacity: _hillshadeOpacity.clamp(0.15, 0.85),
                    child: TileLayer(
                      urlTemplate: _kEsriWorldHillshadeUrl,
                      userAgentPackageName: 'com.blueviperpro.app',
                      tileProvider: _onlineTileProvider(),
                      maxNativeZoom: 15,
                    ),
                  ),
                if (_vectorMbtilesPolygons.isNotEmpty)
                  PolygonLayer(polygons: _vectorMbtilesPolygons),
                if (_vectorMbtilesPolylines.isNotEmpty)
                  PolylineLayer(polylines: _vectorMbtilesPolylines),
                if (_vectorMbtilesPoints.isNotEmpty)
                  CircleLayer(
                    circles: [
                      for (final p in _vectorMbtilesPoints)
                        CircleMarker(
                          point: p,
                          radius: 2.85,
                          color: const Color(0xFF8EB4D8).withValues(
                            alpha: (_vectorMbtilesStrokeOpacity * 0.88).clamp(0.08, 1.0),
                          ),
                          borderStrokeWidth: 0.75,
                          borderColor: const Color(0xFF4A6FA5).withValues(
                            alpha: (_vectorMbtilesStrokeOpacity * 0.62).clamp(0.08, 1.0),
                          ),
                        ),
                    ],
                  ),
                if (_geoPdfRasterJpeg != null && _geoPdfExtentPolygon.length >= 3)
                  OverlayImageLayer(
                    overlayImages: [
                      OverlayImage(
                        imageProvider: MemoryImage(_geoPdfRasterJpeg!),
                        opacity: 0.82,
                        bounds: LatLngBounds.fromPoints(_geoPdfExtentPolygon),
                      ),
                    ],
                  ),
                if (_mapGridMode != MapGridMode.off)
                  PolylineLayer(
                    polylines: [
                      for (final pts in _coordinateGridSegments())
                        if (pts.length >= 2)
                          Polyline(
                            points: pts,
                            strokeWidth: 1.15,
                            color: const Color(0xFF7FD0E8).withValues(alpha: 0.42),
                          ),
                    ],
                  ),
                if (_geoPdfExtentPolygon.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: List<LatLng>.from(_geoPdfExtentPolygon),
                        color: Colors.deepOrange.withValues(alpha: 0.14),
                        borderColor: Colors.deepOrange.shade700,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  )
                else if (_geoPdfExtentPolygon.length == 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: List<LatLng>.from(_geoPdfExtentPolygon),
                        strokeWidth: 2.5,
                        color: Colors.deepOrange.shade600,
                      ),
                    ],
                  ),
                if (_tacticalHudEnabled && refPoint != null && measM != null && measM >= 0.5)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [refPoint, hud],
                        strokeWidth: 3.5,
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                if (_effectiveLosThreatTubeOuter != null)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: List<LatLng>.from(_effectiveLosThreatTubeOuter!),
                        color: Colors.redAccent.withValues(alpha: 0.14),
                        borderColor: Colors.redAccent.withValues(alpha: 0.85),
                        borderStrokeWidth: 2.0,
                      ),
                    ],
                  ),
                if (_cas3dThreatPolygons.isNotEmpty)
                  PolygonLayer(polygons: _cas3dThreatPolygons),
                if (_cas3dThreatCenterLines.isNotEmpty)
                  PolylineLayer(polylines: _cas3dThreatCenterLines),
                ...[
                  if (_polygonClosedPieceCount() > 0)
                    PolygonLayer(
                      polygons: [
                        if (_polygonVertices.length >= 3)
                          Polygon(
                            points: List<LatLng>.from(_polygonVertices),
                            holePointsList: _polygonHoles.isEmpty
                                ? null
                                : [for (final h in _polygonHoles) List<LatLng>.from(h)],
                            color: _kmlPrimaryPolygonFillArgb32 != null
                                ? Color(_kmlPrimaryPolygonFillArgb32!)
                                : Colors.teal.withValues(alpha: 0.22),
                            borderColor: (_kmlPrimaryPolygonDrawStrokeOutline ?? true)
                                ? (_kmlPrimaryPolygonStrokeArgb32 != null
                                    ? Color(_kmlPrimaryPolygonStrokeArgb32!)
                                    : Colors.teal.shade800)
                                : Colors.transparent,
                            borderStrokeWidth: (_kmlPrimaryPolygonDrawStrokeOutline ?? true)
                                ? (_kmlPrimaryPolygonStrokeWidthPx ?? 2).clamp(0.5, 12.0)
                                : 0,
                          ),
                        for (final p in _additionalPolygonPatches)
                          if (p.outer.length >= 3)
                            Polygon(
                              points: List<LatLng>.from(p.outer),
                              holePointsList: p.holes.isEmpty
                                  ? null
                                  : [for (final h in p.holes) List<LatLng>.from(h)],
                              color: p.fillArgb32 != null ? Color(p.fillArgb32!) : Colors.teal.withValues(alpha: 0.17),
                              borderColor: p.drawStrokeOutline
                                  ? (p.strokeArgb32 != null ? Color(p.strokeArgb32!) : Colors.teal.shade800)
                                  : Colors.transparent,
                              borderStrokeWidth: p.drawStrokeOutline
                                  ? (p.strokeWidthPx ?? 1.75).clamp(0.5, 12.0)
                                  : 0,
                            ),
                      ],
                    ),
                  if (_polygonVertices.length == 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: List<LatLng>.from(_polygonVertices),
                          strokeWidth: 3,
                          color: Colors.teal.shade600,
                        ),
                      ],
                    ),
                ],
                if (_kmlImportStyledPolylines.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      for (final e in _kmlImportStyledPolylines)
                        if (e.$2.length >= 2)
                          Polyline(
                            points: List<LatLng>.from(e.$2),
                            strokeWidth: (e.$4 ?? 4).clamp(1.0, 12.0),
                            color: Color(e.$3 ?? 0xFF673AB7),
                          ),
                    ],
                  )
                else if (_routeVertices.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: List<LatLng>.from(_routeVertices),
                        strokeWidth: 4,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                if (_recordedTrack.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: List<LatLng>.from(_recordedTrack),
                        strokeWidth: 3,
                        color: Colors.lightGreen.shade700,
                      ),
                    ],
                  ),
                if (_vectorMbtilesLabels.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      for (final L in _vectorMbtilesLabels)
                        Marker(
                          point: L.point,
                          width: 132,
                          height: 22,
                          alignment: Alignment.centerLeft,
                          child: IgnorePointer(
                            child: Text(
                              L.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1C2E44).withValues(
                                  alpha: _vectorMbtilesStrokeOpacity.clamp(0.55, 1.0),
                                ),
                                shadows: const [
                                  Shadow(offset: Offset(0.5, 0.5), blurRadius: 2, color: Colors.white70),
                                  Shadow(offset: Offset(-0.5, -0.5), blurRadius: 3, color: Color(0x66FFFFFF)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < _polygonVertices.length; i++)
                      Marker(
                        point: _polygonVertices[i],
                        width: 30,
                        height: 30,
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: Colors.teal.shade700,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    for (var i = 0; i < _routeVertices.length; i++) _routeVertexNumberMarker(i),
                    if (gps != null && !_shouldShareMyLocation())
                      Marker(
                        point: gps,
                        width: 44,
                        height: 44,
                        child: Icon(Icons.navigation, color: Colors.blue.shade700, size: 40),
                      ),
                    if (gps != null && _shouldShareMyLocation())
                      _trackedPersonMarker(
                        point: gps,
                        label: pttState.members[_collabUserId]?.displayName ?? 'Sen',
                        isSpeaking: speakerId == _collabUserId,
                      ),
                    for (var pi = 0; pi < _userPins.length; pi++)
                      Marker(
                        point: _userPins[pi].point,
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: _mapPinMarkerButton(index: pi, pin: _userPins[pi]),
                      ),
                    for (final e in _peerLiveByUser.entries)
                      if (e.key != _collabUserId || !_shouldShareMyLocation())
                        _trackedPersonMarker(
                          point: LatLng(e.value.latitude, e.value.longitude),
                          label: pttState.members[e.key]?.displayName ?? e.key,
                          isSpeaking: speakerId == e.key,
                        ),
                    for (final t in _collabTargetsByUser.values)
                      Marker(
                        point: LatLng(t.latitude, t.longitude),
                        width: 52,
                        height: 52,
                        alignment: Alignment.bottomCenter,
                        child: Tooltip(
                          message:
                              'Hedef — ${t.displayName}\n${t.latitude.toStringAsFixed(6)}, ${t.longitude.toStringAsFixed(6)}'
                              '${t.distanceFromReporterM != null ? '\n≈ ${t.distanceFromReporterM!.round()} m' : ''}'
                              '${t.bearingFromReporterDeg != null ? ' · ${t.bearingFromReporterDeg!.toStringAsFixed(0)}°' : ''}',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.priority_high,
                                color: Colors.amberAccent,
                                size: 38,
                                shadows: const [
                                  Shadow(blurRadius: 4, color: Colors.black87),
                                ],
                              ),
                              Text(
                                'Hedef',
                                style: TextStyle(
                                  color: Colors.amberAccent.shade100,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  shadows: const [
                                    Shadow(blurRadius: 3, color: Colors.black),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (gps != null && _userPins.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [gps, _userPins.first.point],
                        strokeWidth: 3,
                        color: Colors.orange.shade700,
                      ),
                    ],
                  ),
                if (gps != null && _userPins.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [gps, _userPins[1].point],
                        strokeWidth: 2,
                        color: Colors.cyan.shade700,
                      ),
                    ],
                  ),
                if (_userPins.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [_userPins[0].point, _userPins[1].point],
                        strokeWidth: 2,
                        color: Colors.amber.shade800,
                        pattern: StrokePattern.dashed(segments: const [10, 6]),
                      ),
                    ],
                  ),
                if (_effectiveLosMapSegments != null)
                  PolylineLayer(
                    polylines: [
                      for (final s in _effectiveLosMapSegments!)
                        Polyline(
                          points: s.points,
                          strokeWidth: 4,
                          color: s.blocked ? Colors.redAccent : Colors.green.shade600,
                        ),
                    ],
                  ),
                if (_effectiveLosBlockedApprox != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _effectiveLosBlockedApprox!,
                        radius: 5.5,
                        color: Colors.red.shade900.withValues(alpha: 0.92),
                        borderStrokeWidth: 1.75,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),
                if (_cas3dThreatLabels.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      for (final e in _cas3dThreatLabels)
                        Marker(
                          point: e.$1,
                          width: 180,
                          height: 36,
                          alignment: Alignment.centerLeft,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black87.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                e.$2,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Scalebar(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                          ),
                          lineColor: Colors.white,
                          strokeWidth: 1.5,
                          lineHeight: 4,
                        ),
                        if (_tacticalHudEnabled) ...[
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: math.min(420, MediaQuery.sizeOf(context).width - 24),
                            ),
                            child: _buildTacticalHudBar(context, hud, measM, azDeg, milNato),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (mapAttributions.isNotEmpty)
                  RichAttributionWidget(
                    alignment: AttributionAlignment.bottomRight,
                    showFlutterMapAttribution: false,
                    attributions: mapAttributions,
                    popupBackgroundColor:
                        Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
                  ),
              ],
            ),
                  if (_tacticalHudEnabled)
                    IgnorePointer(
                      child: Center(
                        child: CustomPaint(
                          size: const Size(56, 56),
                          painter: _ScreenCrosshairPainter(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildBottomToolStrip(),
          ],
        ),
        if (_recordingTrack)
          Positioned(
            left: 8,
            right: 8,
            top: topInset + 8,
            child: Material(
              color: Colors.red.shade900.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'REC · ${_formatTrackRecordingElapsed()} · ${_polylineLengthMeters(_recordedTrack).toStringAsFixed(0)} m',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        Positioned(
          left: 8,
          top: topInset + (_recordingTrack ? 52 : 8),
          child: IgnorePointer(child: _buildCompassRose()),
        ),
        Positioned(
          right: 6,
          top: topInset + 4,
          child: _buildTopRightTools(context, gps, w1),
        ),
        Positioned(
          right: 6,
          bottom: _kMapBottomBarTotalHeight + MediaQuery.paddingOf(context).bottom + 8,
          child: _buildZoomAndLocationColumn(),
        ),
        Positioned(
          right: 8,
          bottom: _kMapBottomBarTotalHeight + MediaQuery.paddingOf(context).bottom + 168,
          child: MapCollabHubOverlay(
            service: _pttService,
            currentUserId: _collabUserId,
            inviteRoomNumber: _inviteRoomNumber,
            onReportTarget: () => unawaited(_openCollabTargetReportSheet()),
            ownerSharesLiveLocation: _ownerSharesLiveLocation,
            onOwnerSharesLiveChanged: (v) {
              setState(() => _ownerSharesLiveLocation = v);
              _restartShareLocationTimer();
            },
            followRoomOwnerLocation: _followRoomOwnerLive,
            onFollowRoomOwnerChanged: (v) => setState(() => _followRoomOwnerLive = v),
            memberSharesLocation: _memberSharesLocation,
            onMemberSharesLocationChanged: (v) {
              setState(() => _memberSharesLocation = v);
              _restartShareLocationTimer();
            },
            onCreateRoom: () => unawaited(_promptCreateRoom()),
            onJoinRoom: () => unawaited(_promptJoinRoom()),
            onRenewRoomInvite: () => unawaited(_promptRenewRoomInvite()),
            onShareInvite: () => unawaited(_shareCollabInvite()),
            onOpenMemberManagementSheet: () => unawaited(_openMapDetailsSheet()),
            onSelfRename: _hubSelfRename,
            onPttTalk: _hubPttTalk,
            onPttRelease: _hubPttRelease,
            onForceNextSpeaker: _hubForceNext,
          ),
        ),
      ],
    );
  }
}

class _CompassRosePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final nPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final r = size.shortestSide * 0.32;
    canvas.drawLine(c + Offset(0, r), c + Offset(0, -r), nPaint);
    canvas.drawLine(c + Offset(0, r * 0.15), c + Offset(0, r), sPaint);
    canvas.drawLine(c + Offset(-r, 0), c + Offset(r, 0), sPaint);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + Offset(-tp.width / 2, -r - 14));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScreenCrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF69F0AE)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final r = size.shortestSide * 0.38;
    canvas.drawCircle(c, r, paint);
    final tick = r * 0.5;
    canvas.drawLine(c + Offset(-tick, 0), c + Offset(-r - 4, 0), paint);
    canvas.drawLine(c + Offset(tick, 0), c + Offset(r + 4, 0), paint);
    canvas.drawLine(c + Offset(0, -tick), c + Offset(0, -r - 4), paint);
    canvas.drawLine(c + Offset(0, tick), c + Offset(0, r + 4), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _MapRasterSource { online, mbtiles }

enum _MapTapMode { viewOnly, placemark, mapAnchor, routeVertex, polygonVertex, vectorFeature }

enum _MapBaseLayer {
  osm,
  humanitarian,
  cartoLight,
  cartoDark,
  openTopo,
  esriImagery,
}
