import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/geo/elevation_service.dart';
import '../../../core/geo/geo_formatters.dart';
import '../../../core/geo/geo_measure.dart';
import '../../../core/geo/gpx_kml_codec.dart';
import '../../../core/geo/wgs84_utm_epsg.dart';
import '../../../core/maps/mbtiles_raster.dart';
import '../../../core/maps/mbtiles_storage.dart';
import '../../../core/realtime/ptt_queue.dart';
import '../../../core/realtime/ptt_service_notice.dart';
import '../../../core/realtime/realtime_ptt_service.dart';
import '../../../core/realtime/realtime_ptt_service_factory.dart';
import 'coordinate_target_sheet.dart';
import 'elevation_profile_dialog.dart';
import 'maps_comparison_sheet.dart';

const double _kMapBottomToolsHeight = 56;

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
  static const String _currentUserId = 'u1';
  late final RealtimePttService _pttService;

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
  LatLng? _waypoint1;
  LatLng? _waypoint2;

  double? _gpsAltDeviceMeters;
  bool _followGps = true;

  double? _demMy;
  double? _demWp1;
  double? _demWp2;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<PttServiceNotice>? _pttUxSub;

  _MapTapMode _tapMode = _MapTapMode.waypoint1;
  String _status = 'Konum izni bekleniyor';
  String _elevStatus = '';
  _MapBaseLayer _mapBase = _MapBaseLayer.esriImagery;

  /// Harita merkezi (nişangah / taktik ölçü hedefi).
  LatLng _mapHudCenter = const LatLng(39.925533, 32.866287);
  double _mapRotationDeg = 0;

  /// Çevrimiçi karolar veya yerel raster MBTiles.
  _MapRasterSource _rasterSource = _MapRasterSource.online;
  MbTilesTileProvider? _mbTilesProvider;
  String? _offlinePackLabel;
  int _mbtilesMinNativeZoom = 0;
  int _mbtilesMaxNativeZoom = 22;

  final List<LatLng> _routeVertices = [];
  final List<LatLng> _polygonVertices = [];
  bool _recordingTrack = false;
  final List<LatLng> _recordedTrack = [];

  /// `null` → boylama göre UTM zon; 35–41 → Orta Doğu için sabit zon (EPSG satırında).
  int? _utmEpsgDisplayZone;

  void _handleMapTap(LatLng point) {
    switch (_tapMode) {
      case _MapTapMode.waypoint1:
        setState(() {
          _waypoint1 = point;
          _status = 'İşaret 1 güncellendi.';
        });
        break;
      case _MapTapMode.waypoint2:
        setState(() {
          _waypoint2 = point;
          _status = 'İşaret 2 güncellendi.';
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
          _routeVertices.add(point);
          _status = 'Rota: ${_routeVertices.length} nokta.';
        });
        break;
      case _MapTapMode.polygonVertex:
        setState(() {
          _polygonVertices.add(point);
          _status = 'Alan: ${_polygonVertices.length} köşe.';
        });
        break;
    }
    _refreshMapDetailsSheetIfOpen();
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
  LatLng get debugMapHudCenter => _mapHudCenter;

  @visibleForTesting
  void debugSelectTapModeWaypoint1() => setState(() => _tapMode = _MapTapMode.waypoint1);

  @visibleForTesting
  void debugSelectTapModeWaypoint2() => setState(() => _tapMode = _MapTapMode.waypoint2);

  @visibleForTesting
  void debugSelectTapModeMapAnchor() => setState(() => _tapMode = _MapTapMode.mapAnchor);

  @visibleForTesting
  void debugSelectTapModeRouteVertex() => setState(() => _tapMode = _MapTapMode.routeVertex);

  @visibleForTesting
  void debugSelectTapModePolygonVertex() => setState(() => _tapMode = _MapTapMode.polygonVertex);

  @visibleForTesting
  void debugUndoLastRouteVertex() {
    if (_routeVertices.isEmpty) return;
    _setStateAndRefreshSheet(() => _routeVertices.removeLast());
  }

  @visibleForTesting
  void debugClearRouteVertices() {
    if (_routeVertices.isEmpty) return;
    _setStateAndRefreshSheet(() {
      _routeVertices.clear();
      _status = 'Rota temizlendi.';
    });
  }

  @visibleForTesting
  _MapBaseLayer get debugMapBase => _mapBase;

  @override
  void initState() {
    super.initState();
    RealtimePttServiceProvider.configure(
      RealtimePttConfig(
        backend: widget.pttBackend,
        currentUserId: _currentUserId,
        websocketUri: widget.pttWebsocketUrl == null
            ? null
            : Uri.tryParse(widget.pttWebsocketUrl!),
      ),
    );
    _pttService = RealtimePttServiceProvider.instance;
    _pttUxSub = _pttService.uxNoticeStream.listen(_onPttUxNotice);
    _initConnectivityAndPosition();
    unawaited(_restoreOfflineBasemapIfAny());
  }

  void _onPttUxNotice(PttServiceNotice n) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_mapsPttServerNoticeTurkish(n))),
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _positionSub?.cancel();
    _pttUxSub?.cancel();
    _mbTilesProvider?.dispose();
    super.dispose();
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen((pos) {
      if (!mounted || !_followGps) return;
      _setStateAndRefreshSheet(() {
        _myPosition = LatLng(pos.latitude, pos.longitude);
        _gpsAltDeviceMeters = pos.altitude;
        final t = TimeOfDay.now();
        _status =
            'GPS ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} · canlı (≈8 m)';
        if (_recordingTrack) {
          _recordedTrack.add(LatLng(pos.latitude, pos.longitude));
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
    final p1 = _waypoint1;
    if (p1 != null) {
      futures.add(() async {
        final e = await ElevationService.fetchMeters(p1.latitude, p1.longitude);
        if (!mounted) return;
        _setStateAndRefreshSheet(() => _demWp1 = e);
      }());
    }
    final p2 = _waypoint2;
    if (p2 != null) {
      futures.add(() async {
        final e = await ElevationService.fetchMeters(p2.latitude, p2.longitude);
        if (!mounted) return;
        _setStateAndRefreshSheet(() => _demWp2 = e);
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

  Future<void> _restoreOfflineBasemapIfAny() async {
    if (kIsWeb) return;
    final path = await MbtilesStorage.getSavedPath();
    if (path == null) return;
    if (!await File(path).exists()) {
      await MbtilesStorage.clearPath();
      return;
    }
    final check = await MbtilesRasterCheck.validateFile(path);
    if (!check.ok || check.meta == null) return;
    if (!mounted) return;
    final meta = check.meta!;
    final view = MbtilesRasterCheck.viewForMetadata(
      meta,
      _myPosition ?? _waypoint1 ?? const LatLng(39.925533, 32.866287),
    );
    setState(() {
      _mbTilesProvider?.dispose();
      _mbTilesProvider = MbTilesTileProvider.fromPath(path: path, silenceTileNotFound: true);
      _rasterSource = _MapRasterSource.mbtiles;
      _offlinePackLabel = path.split(RegExp(r'[\\/]')).last;
      _mbtilesMinNativeZoom = (meta.minZoom ?? 0).floor().clamp(0, 22);
      _mbtilesMaxNativeZoom = (meta.maxZoom ?? 19).ceil().clamp(0, 22);
      _status = 'Offline harita: ${meta.name}';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(view.$1, view.$2);
    });
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
    final pick = await FilePicker.platform.pickFiles(
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
    final check = await MbtilesRasterCheck.validateFile(destPath);
    if (!check.ok) {
      try {
        await File(destPath).delete();
      } catch (_) {}
      if (mounted) {
        setState(() => _status = check.message ?? 'Paket geçersiz');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(check.message ?? 'MBTiles açılamadı')),
        );
      }
      return;
    }
    final meta = check.meta!;
    await MbtilesStorage.savePath(destPath);
    if (!mounted) return;
    final centerGuess = _myPosition ?? _waypoint1 ?? const LatLng(39.925533, 32.866287);
    final view = MbtilesRasterCheck.viewForMetadata(meta, centerGuess);
    setState(() {
      _mbTilesProvider?.dispose();
      _mbTilesProvider = MbTilesTileProvider.fromPath(path: destPath, silenceTileNotFound: true);
      _rasterSource = _MapRasterSource.mbtiles;
      _offlinePackLabel = 'offline_basemap.mbtiles · ${meta.name}';
      _mbtilesMinNativeZoom = (meta.minZoom ?? 0).floor().clamp(0, 22);
      _mbtilesMaxNativeZoom = (meta.maxZoom ?? 19).ceil().clamp(0, 22);
      _status = 'Offline harita aktif (${meta.format}).';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(view.$1, view.$2);
    });
  }

  void _switchToOnlineRaster() {
    setState(() {
      _rasterSource = _MapRasterSource.online;
      _status = 'Çevrimiçi karolar.';
    });
  }

  Future<void> _clearOfflinePackFile() async {
    if (kIsWeb) return;
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
        _status = 'Offline paket kaldırıldı.';
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
        _myPosition = me;
        _gpsAltDeviceMeters = pos.altitude;
        _status = 'Konum alındı.';
      });
      _mapController.move(me, 14);
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

  String? _pairSummary(String label, LatLng? a, LatLng? b) {
    if (a == null || b == null) return null;
    final d = Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    final az = Geolocator.bearingBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    final mil = az * (6400.0 / 360.0);
    return '$label: ${d.toStringAsFixed(1)} m · azimut ${az.toStringAsFixed(2)}° · ${mil.toStringAsFixed(2)} mil';
  }

  void _onMapPositionChanged(MapCamera camera, bool _) {
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
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                    if (_mbTilesProvider == null) {
                      unawaited(_pickAndInstallMbtiles());
                    } else {
                      setState(() => _rasterSource = _MapRasterSource.mbtiles);
                    }
                  } else {
                    _switchToOnlineRaster();
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<_MapBaseLayer>(
                initialValue: _mapBase,
                decoration: const InputDecoration(labelText: 'Çevrimiçi karo'),
                onChanged: _rasterSource == _MapRasterSource.mbtiles
                    ? null
                    : (v) {
                        if (v != null) setState(() => _mapBase = v);
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
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMapDetailsSheet() async {
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
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
              final polygon =
                  _polygonVertices.length >= 3 ? sphericalPolygonAreaM2(_polygonVertices) : null;
              final hasAnyPoint = gps != null || w1 != null || w2 != null;
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.75,
                minChildSize: 0.38,
                maxChildSize: 0.94,
                builder: (context, scrollController) {
                  return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                      onPressed: gps == null ? null : () => _mapController.move(gps, 14),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Konuma git'),
                    ),
                    OutlinedButton.icon(
                      onPressed: w1 == null ? null : () => _mapController.move(w1, 14),
                      icon: const Icon(Icons.place_outlined),
                      label: const Text("İşaret 1'e git"),
                    ),
                    OutlinedButton.icon(
                      onPressed: w2 == null ? null : () => _mapController.move(w2, 14),
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
                  segments: const [
                    ButtonSegment<_MapTapMode>(
                      value: _MapTapMode.waypoint1,
                      label: Text('İş.1'),
                      tooltip: 'İşaret 1',
                      icon: Icon(Icons.adjust, size: 16),
                    ),
                    ButtonSegment<_MapTapMode>(
                      value: _MapTapMode.waypoint2,
                      label: Text('İş.2'),
                      tooltip: 'İşaret 2',
                      icon: Icon(Icons.flag_outlined, size: 16),
                    ),
                    ButtonSegment<_MapTapMode>(
                      value: _MapTapMode.mapAnchor,
                      label: Text('Konum'),
                      tooltip: 'Konumu haritadan işaretle',
                      icon: Icon(Icons.location_searching, size: 16),
                    ),
                    ButtonSegment<_MapTapMode>(
                      value: _MapTapMode.routeVertex,
                      label: Text('Rota'),
                      icon: Icon(Icons.route, size: 16),
                    ),
                    ButtonSegment<_MapTapMode>(
                      value: _MapTapMode.polygonVertex,
                      label: Text('Alan'),
                      icon: Icon(Icons.polyline, size: 16),
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
                        updateState(() => _followGps = true);
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
                              _waypoint1 = p;
                              _status = 'Koordinat girdisi → İşaret 1 güncellendi.';
                            });
                          },
                        );
                      },
                      icon: const Icon(Icons.grid_on, size: 18),
                      label: const Text('Koordinat gir'),
                    ),
                    TextButton.icon(
                      onPressed: w2 == null
                          ? null
                          : () => updateState(() {
                                _waypoint2 = null;
                                _demWp2 = null;
                              }),
                      icon: const Icon(Icons.clear),
                      label: const Text('İşaret 2 sil'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('maps_details_route_clear_button'),
                      onPressed: _routeVertices.isEmpty
                          ? null
                          : () => updateState(() {
                                _routeVertices.clear();
                                _status = 'Rota temizlendi.';
                              }),
                      icon: const Icon(Icons.clear_all),
                      label: Text('Rota (${_routeVertices.length})'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('maps_details_route_undo_button'),
                      onPressed:
                          _routeVertices.isEmpty ? null : () => updateState(() => _routeVertices.removeLast()),
                      icon: const Icon(Icons.undo),
                      label: const Text('Rota geri'),
                    ),
                    TextButton.icon(
                      onPressed: _polygonVertices.isEmpty ? null : () => updateState(() => _polygonVertices.clear()),
                      icon: const Icon(Icons.layers_clear),
                      label: Text('Alan (${_polygonVertices.length})'),
                    ),
                    TextButton.icon(
                      onPressed: _polygonVertices.isEmpty ? null : () => updateState(() => _polygonVertices.removeLast()),
                      icon: const Icon(Icons.undo_outlined),
                      label: const Text('Alan geri'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exportGpx,
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('GPX dışa'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importGeoFile,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('GPX/KML/KMZ'),
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
                if (w1 != null) ...[
                  const SizedBox(height: 10),
                  _coordBlock('İşaret 1', w1, demM: _demWp1),
                ],
                if (w2 != null) ...[
                  const SizedBox(height: 10),
                  _coordBlock('İşaret 2', w2, demM: _demWp2),
                ],
                if (gps != null && (w1 != null || w2 != null)) ...[
                  const SizedBox(height: 10),
                  Text('Mesafe / azimut', style: Theme.of(context).textTheme.titleSmall),
                  if (_pairSummary('Konum → İşaret 1', gps, w1) != null)
                    Text(_pairSummary('Konum → İşaret 1', gps, w1)!),
                  if (_pairSummary('Konum → İşaret 2', gps, w2) != null)
                    Text(_pairSummary('Konum → İşaret 2', gps, w2)!),
                  if (_pairSummary('İşaret 1 → İşaret 2', w1, w2) != null)
                    Text(_pairSummary('İşaret 1 → İşaret 2', w1, w2)!),
                ],
                if (_routeVertices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Rota: ${_routeVertices.length} köşe · ${_polylineLengthMeters(_routeVertices).toStringAsFixed(0)} m',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
                if (_polygonVertices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Alan: ${_polygonVertices.length} köşe'
                    '${polygon != null ? ' · ${polygon.toStringAsFixed(0)} m²' : ''}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
                if (_recordedTrack.length >= 2) ...[
                  const SizedBox(height: 12),
                  Text(
                    'İz: ${_recordedTrack.length} nokta · ${_polylineLengthMeters(_recordedTrack).toStringAsFixed(0)} m',
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

  Future<void> _exportGpx() async {
    final wpts = <(String, LatLng)>[];
    final g = _myPosition;
    final a = _waypoint1;
    final b = _waypoint2;
    if (g != null) wpts.add(('GPS / konum', g));
    if (a != null) wpts.add(('İşaret 1', a));
    if (b != null) wpts.add(('İşaret 2', b));
    for (var i = 0; i < _routeVertices.length; i++) {
      wpts.add(('Rota ${i + 1}', _routeVertices[i]));
    }
    for (var i = 0; i < _polygonVertices.length; i++) {
      wpts.add(('Alan ${i + 1}', _polygonVertices[i]));
    }
    final gpx = buildGpxDocument(
      name: 'Blue Viper Harita',
      waypoints: wpts,
      routePoints: _routeVertices.length >= 2 ? List<LatLng>.from(_routeVertices) : null,
      trackPoints: _recordedTrack.length >= 2 ? List<LatLng>.from(_recordedTrack) : null,
      trackName: 'GPS izi',
    );
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/blue_viper_harita_${DateTime.now().millisecondsSinceEpoch}.gpx');
    await f.writeAsString(gpx);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)], subject: 'Blue Viper Harita GPX'),
    );
  }

  Future<void> _importGeoFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gpx', 'kml', 'kmz'],
    );
    if (r == null || r.files.single.path == null) return;
    final path = r.files.single.path!;
    List<int> bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosya okunamadı')));
      }
      return;
    }
    String? text;
    final lower = path.toLowerCase();
    if (lower.endsWith('.kmz')) {
      text = decodeKmzToKmlString(bytes);
    } else {
      text = utf8.decode(bytes, allowMalformed: true);
    }
    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KMZ içinde KML bulunamadı')));
      }
      return;
    }
    final docText = text;
    _setStateAndRefreshSheet(() {
      if (lower.endsWith('.gpx') || docText.contains('<gpx')) {
        final p = parseGpx(docText);
        _routeVertices.clear();
        for (final e in p.wpts) {
          _routeVertices.add(e.$2);
        }
        if (p.routes.isNotEmpty) {
          _routeVertices.addAll(p.routes.first);
        } else if (p.tracks.isNotEmpty) {
          _routeVertices.addAll(p.tracks.first);
        }
        _status = 'GPX: ${_routeVertices.length} nokta yüklendi (rota).';
      } else {
        final k = parseKmlPlacemarks(docText);
        _routeVertices.clear();
        for (final e in k.points) {
          _routeVertices.add(e.$2);
        }
        if (k.lines.isNotEmpty) {
          _routeVertices.addAll(k.lines.first);
        }
        _status = 'KML/KMZ: ${_routeVertices.length} nokta yüklendi (rota).';
      }
    });
  }

  void _toggleTrackRecording() {
    _setStateAndRefreshSheet(() {
      _recordingTrack = !_recordingTrack;
      if (_recordingTrack) {
        _recordedTrack.clear();
        _status = 'İz kaydı: GPS açıkken nokta eklenir (≈8 m).';
      } else {
        _status = 'İz durdu (${_recordedTrack.length} nokta).';
      }
    });
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

  Widget _coordBlock(String title, LatLng p, {double? demM}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(GeoFormatters.decimalDegrees(p)),
        Text(GeoFormatters.dmsHuman(p)),
        Text(GeoFormatters.utmWgs84(p)),
        Text(GeoFormatters.utmWgs84EpsgLine(p, zoneOverride: _utmEpsgDisplayZone)),
        Text('MGRS: ${GeoFormatters.mgrs(p)}'),
        Text(GeoFormatters.sk42GridLine(p)),
        if (demM != null) Text('DEM rakım: ${demM.toStringAsFixed(1)} m'),
      ],
    );
  }

  Widget _buildTacticalHudBar(
    BuildContext context,
    LatLng hudCenter,
    double? measM,
    double? azDeg,
    int? milNato,
  ) {
    final mgrs = GeoFormatters.mgrsSpaced(hudCenter);
    final utm = GeoFormatters.utmCompactEastingNorthing(
      hudCenter,
      zoneOverride: _utmEpsgDisplayZone,
    );
    final measStr = measM == null
        ? '—'
        : measM < 0.5
            ? '~0 m'
            : '~${measM.toStringAsFixed(measM >= 100 ? 0 : 1)} m';
    final azStr = azDeg == null ? '—' : '∡${azDeg.toStringAsFixed(0)}°';
    final milStr = milNato == null ? '—' : '$milNato mil';

    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.25,
              shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
            ),
            child: Row(
              children: [
                Text(mgrs),
                const Text('  ·  '),
                Text(utm),
                const Text('  ·  '),
                Text(milStr),
                const Text('  ·  '),
                Text(measStr),
                const Text('  ·  '),
                Text(azStr),
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
                    _waypoint1 = p;
                    _status = 'İşaret 1 güncellendi.';
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
                  final cam = _mapController.camera;
                  _mapController.move(cam.center, cam.zoom + 1);
                },
                icon: const Icon(Icons.add, color: Colors.white),
              ),
              IconButton(
                key: const ValueKey('maps_zoom_out_button'),
                tooltip: 'Uzaklaştır',
                onPressed: () {
                  final cam = _mapController.camera;
                  _mapController.move(cam.center, cam.zoom - 1);
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
            IconButton(
              tooltip: 'GPX dışa aktar',
              onPressed: _exportGpx,
              icon: const Icon(Icons.ios_share, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Konuma git (GPS)',
              onPressed: () {
                final g = _myPosition;
                if (g != null) {
                  _mapController.move(g, 15);
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
              tooltip: 'İşaret 1',
              onPressed: () => setState(() => _tapMode = _MapTapMode.waypoint1),
              icon: Icon(Icons.adjust, color: iconColor(_MapTapMode.waypoint1)),
            ),
            IconButton(
              key: const ValueKey('maps_bottom_tapmode_waypoint2_button'),
              tooltip: 'İşaret 2',
              onPressed: () => setState(() => _tapMode = _MapTapMode.waypoint2),
              icon: Icon(Icons.place, color: iconColor(_MapTapMode.waypoint2)),
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
    final isLeader = st.members[_currentUserId]?.role == GroupRole.owner;
    final speakerName = st.currentSpeakerId == null
        ? 'Kanal boş'
        : (st.members[st.currentSpeakerId!]?.displayName ?? st.currentSpeakerId!);
    final queuedText = st.queuedUserIds.isEmpty ? '—' : st.queuedUserIds.join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                targetUserId: _currentUserId,
                currentName: st.members[_currentUserId]?.displayName ?? 'Ben',
                isSelf: true,
                updateState: updateState,
              ),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Adımı değiştir'),
            ),
            FilledButton.icon(
              onPressed: () {
                updateState(() {
                  final r = _pttService.requestTalk(_currentUserId);
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
              },
              icon: const Icon(Icons.mic, size: 18),
              label: const Text('Konuş (PTT)'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                updateState(() {
                  final ok = _pttService.releaseTalk(_currentUserId);
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
                    final ok = _pttService.forceNextSpeaker(actorId: _currentUserId);
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
        ...st.members.values.where((m) => m.userId != _currentUserId).map((m) {
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
                              actorId: _currentUserId,
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
                              actorId: _currentUserId,
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
        actorId: _currentUserId,
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
    final w2 = _waypoint2;

    final center = gps ?? w1 ?? const LatLng(39.925533, 32.866287);
    final refPoint = w1 ?? gps;
    final hud = _mapHudCenter;

    double? measM;
    double? azDeg;
    int? milNato;
    if (refPoint != null) {
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

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 6,
                onPositionChanged: _onMapPositionChanged,
                backgroundColor: const Color(0xFF1A1A1A),
                onTap: (_, point) => _handleMapTap(point),
              ),
              children: [
                if (_rasterSource == _MapRasterSource.online || kIsWeb)
                  TileLayer(
                    urlTemplate: _tileUrlForBase(_mapBase),
                    userAgentPackageName: 'com.blueviperpro.app',
                    subdomains: _subdomainsForMapBase(_mapBase),
                    tileProvider: _onlineTileProvider(),
                  )
                else if (_mbTilesProvider != null)
                  TileLayer(
                    key: ValueKey(_offlinePackLabel ?? 'mbtiles'),
                    tileProvider: _mbTilesProvider!,
                    userAgentPackageName: 'com.blueviperpro.app',
                    minNativeZoom: _mbtilesMinNativeZoom,
                    maxNativeZoom: _mbtilesMaxNativeZoom,
                  ),
                if (refPoint != null && measM != null && measM >= 0.5)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [refPoint, hud],
                        strokeWidth: 3.5,
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                if (_polygonVertices.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: List<LatLng>.from(_polygonVertices),
                        color: Colors.teal.withValues(alpha: 0.22),
                        borderColor: Colors.teal.shade800,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  )
                else if (_polygonVertices.length == 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: List<LatLng>.from(_polygonVertices),
                        strokeWidth: 3,
                        color: Colors.teal.shade600,
                      ),
                    ],
                  ),
                if (_routeVertices.length >= 2)
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
                    for (var i = 0; i < _routeVertices.length; i++)
                      Marker(
                        point: _routeVertices[i],
                        width: 34,
                        height: 34,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.deepPurple,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    if (gps != null)
                      Marker(
                        point: gps,
                        width: 44,
                        height: 44,
                        child: Icon(Icons.navigation, color: Colors.blue.shade700, size: 40),
                      ),
                    if (w1 != null)
                      Marker(
                        point: w1,
                        width: 42,
                        height: 42,
                        child: const Icon(Icons.adjust, color: Colors.redAccent, size: 34),
                      ),
                    if (w2 != null)
                      Marker(
                        point: w2,
                        width: 42,
                        height: 42,
                        child: Icon(Icons.place, color: Colors.green.shade700, size: 36),
                      ),
                  ],
                ),
                if (gps != null && w1 != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: [gps, w1], strokeWidth: 3, color: Colors.orange.shade700),
                    ],
                  ),
                if (gps != null && w2 != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: [gps, w2], strokeWidth: 2, color: Colors.cyan.shade700),
                    ],
                  ),
                if (w1 != null && w2 != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [w1, w2],
                        strokeWidth: 2,
                        color: Colors.amber.shade800,
                        pattern: StrokePattern.dashed(segments: const [10, 6]),
                      ),
                    ],
                  ),
                Scalebar(
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.only(left: 10, bottom: 10),
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                  ),
                  lineColor: Colors.white,
                  strokeWidth: 1.5,
                  lineHeight: 4,
                ),
              ],
            ),
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
        Positioned(
          left: 0,
          right: 0,
          top: topInset,
          child: _buildTacticalHudBar(context, hud, measM, azDeg, milNato),
        ),
        Positioned(
          left: 8,
          top: topInset + 50,
          child: IgnorePointer(child: _buildCompassRose()),
        ),
        Positioned(
          right: 6,
          top: topInset + 4,
          child: _buildTopRightTools(context, gps, w1),
        ),
        Positioned(
          right: 6,
          bottom: _kMapBottomToolsHeight + MediaQuery.paddingOf(context).bottom + 8,
          child: _buildZoomAndLocationColumn(),
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
      ..color = Colors.lightBlueAccent
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

enum _MapTapMode { waypoint1, waypoint2, mapAnchor, routeVertex, polygonVertex }

enum _MapBaseLayer {
  osm,
  humanitarian,
  cartoLight,
  cartoDark,
  openTopo,
  esriImagery,
}
