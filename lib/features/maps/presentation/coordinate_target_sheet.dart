import 'dart:math' as math;

import 'package:coordinate_converter/coordinate_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo/geo_formatters.dart';
import '../../../core/geo/sk42_turkey_grid.dart';
import '../../../core/geo/wgs84_utm_epsg.dart';

const Distance _earthDistance = Distance();

/// Tam ekran sayfa: harita + DD / MGRS / UTM / SK-42 / mesafe–azimut ile hedef seçimi.
Future<void> showCoordinateTargetPickerSheet(
  BuildContext context, {
  required LatLng initialCenter,
  required void Function(LatLng p) onApply,
  TileProvider? tileProvider,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (ctx) => CoordinateTargetPage(
        initialCenter: initialCenter,
        onApply: onApply,
        tileProvider: tileProvider,
      ),
    ),
  );
}

class CoordinateTargetPage extends StatefulWidget {
  const CoordinateTargetPage({
    super.key,
    required this.initialCenter,
    required this.onApply,
    this.tileProvider,
  });

  final LatLng initialCenter;
  final void Function(LatLng p) onApply;
  final TileProvider? tileProvider;

  @override
  State<CoordinateTargetPage> createState() => _CoordinateTargetPageState();
}

class _CoordinateTargetPageState extends State<CoordinateTargetPage>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late LatLng _picked;
  late TabController _tabs;

  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _mgrsCtrl = TextEditingController();
  final _utmZoneCtrl = TextEditingController();
  final _utmEastCtrl = TextEditingController();
  final _utmNorthCtrl = TextEditingController();
  bool _utmSouth = false;

  final _skEastCtrl = TextEditingController();
  final _skNorthCtrl = TextEditingController();
  int _skMeridian = 33;

  final _polarDistCtrl = TextEditingController();
  final _polarAzimuthCtrl = TextEditingController();
  final _polarMilCtrl = TextEditingController();

  String? _error;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _picked = widget.initialCenter;
    _tabs = TabController(length: 5, vsync: this);
    _syncFieldsFromPoint();
    _polarDistCtrl.text = '100';
  }

  void _syncFieldsFromPoint() {
    _latCtrl.text = _picked.latitude.toStringAsFixed(6);
    _lonCtrl.text = _picked.longitude.toStringAsFixed(6);
    _mgrsCtrl.text = GeoFormatters.mgrs(_picked);
    try {
      if (!_utmSouth) {
        final z = Wgs84UtmNorth.autoZoneFromLongitude(_picked.longitude);
        _utmZoneCtrl.text = z.toString();
        final xy = Wgs84UtmNorth.toUtm(_picked, z);
        _utmEastCtrl.text = xy.$1.toStringAsFixed(1);
        _utmNorthCtrl.text = xy.$2.toStringAsFixed(1);
      } else {
        final u = UTMCoordinates.fromDD(
          DDCoordinates(latitude: _picked.latitude, longitude: _picked.longitude),
        );
        _utmZoneCtrl.text = u.zoneNumber.toString();
        _utmEastCtrl.text = u.x.toStringAsFixed(1);
        _utmNorthCtrl.text = u.y.toStringAsFixed(1);
        _utmSouth = u.isSouthernHemisphere;
      }
    } catch (_) {
      _utmZoneCtrl.text = '37';
      _utmEastCtrl.text = '';
      _utmNorthCtrl.text = '';
    }
    _skMeridian = Sk42TurkeyGrid.pickMeridian(_picked.longitude);
    final sk = Sk42TurkeyGrid.wgs84ToGrid(_picked, _skMeridian);
    _skEastCtrl.text = sk.$1.toStringAsFixed(1);
    _skNorthCtrl.text = sk.$2.toStringAsFixed(1);
  }

  double _natoMilFromAzimuthDeg(double azimuthDeg) => azimuthDeg * (6400.0 / 360.0);

  double _azimuthDegFromNatoMil(double mil) => (mil % 6400.0) * (360.0 / 6400.0);

  void _onAzimuthChanged(String s) {
    final v = double.tryParse(s.replaceAll(',', '.'));
    if (v == null) return;
    var az = v % 360.0;
    if (az < 0) az += 360.0;
    _polarMilCtrl.text = _natoMilFromAzimuthDeg(az).toStringAsFixed(2);
  }

  void _onMilChanged(String s) {
    final v = double.tryParse(s.replaceAll(',', '.'));
    if (v == null) return;
    var az = _azimuthDegFromNatoMil(v);
    _polarAzimuthCtrl.text = az.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _mgrsCtrl.dispose();
    _utmZoneCtrl.dispose();
    _utmEastCtrl.dispose();
    _utmNorthCtrl.dispose();
    _skEastCtrl.dispose();
    _skNorthCtrl.dispose();
    _polarDistCtrl.dispose();
    _polarAzimuthCtrl.dispose();
    _polarMilCtrl.dispose();
    super.dispose();
  }

  void _applyDd() {
    final lat = double.tryParse(_latCtrl.text.replaceAll(',', '.'));
    final lon = double.tryParse(_lonCtrl.text.replaceAll(',', '.'));
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      setState(() => _error = 'Enlem/boylam geçersiz.');
      return;
    }
    setState(() {
      _picked = LatLng(lat, lon);
      _error = null;
    });
    _mapController.move(_picked, 14);
    setState(_syncFieldsFromPoint);
  }

  void _applyMgrs() {
    final p = GeoFormatters.tryParseMgrs(_mgrsCtrl.text);
    if (p == null) {
      setState(() => _error = 'MGRS okunamadı.');
      return;
    }
    setState(() {
      _picked = p;
      _error = null;
    });
    _mapController.move(_picked, 14);
    _syncFieldsFromPoint();
  }

  void _applyUtm() {
    final z = int.tryParse(_utmZoneCtrl.text.trim());
    final e = double.tryParse(_utmEastCtrl.text.replaceAll(',', '.'));
    final n = double.tryParse(_utmNorthCtrl.text.replaceAll(',', '.'));
    if (z == null || z < 1 || z > 60 || e == null || n == null) {
      setState(() => _error = 'UTM zon / doğu / kuzey geçersiz.');
      return;
    }
    try {
      late final LatLng ll;
      if (!_utmSouth) {
        ll = Wgs84UtmNorth.fromUtm(easting: e, northing: n, zone: z);
      } else {
        final dd = DDCoordinates.fromUTM(
          UTMCoordinates(
            x: e,
            y: n,
            zoneNumber: z,
            isSouthernHemisphere: true,
          ),
        );
        ll = LatLng(dd.latitude, dd.longitude);
      }
      setState(() {
        _picked = ll;
        _error = null;
      });
      _mapController.move(_picked, 14);
      setState(_syncFieldsFromPoint);
    } catch (err) {
      setState(() => _error = 'UTM → enlem/boylam hatası: $err');
    }
  }

  void _applySk42() {
    final e = double.tryParse(_skEastCtrl.text.replaceAll(',', '.'));
    final n = double.tryParse(_skNorthCtrl.text.replaceAll(',', '.'));
    if (e == null || n == null || !Sk42TurkeyGrid.meridians.contains(_skMeridian)) {
      setState(() => _error = 'SK-42 E / N veya orta meridyen geçersiz.');
      return;
    }
    try {
      final ll = Sk42TurkeyGrid.gridToWgs84(easting: e, northing: n, centralMeridian: _skMeridian);
      setState(() {
        _picked = ll;
        _error = null;
      });
      _mapController.move(_picked, 14);
      setState(_syncFieldsFromPoint);
    } catch (err) {
      setState(() => _error = 'SK-42 → WGS84 hatası: $err');
    }
  }

  /// Turuncu pim = başlangıç; girilen mesafe ve azimut (veya mil) ile büyük daire üzerinde yeni konum.
  void _applyPolar() {
    final d = double.tryParse(_polarDistCtrl.text.replaceAll(',', '.'));
    if (d == null || !d.isFinite || d <= 0 || d > 2e6) {
      setState(() => _error = 'Mesafe (m) 0–2 000 000 aralığında olmalı.');
      return;
    }
    final milStr = _polarMilCtrl.text.trim();
    final azStr = _polarAzimuthCtrl.text.trim();
    double? azDeg;
    if (milStr.isNotEmpty) {
      final mil = double.tryParse(milStr.replaceAll(',', '.'));
      if (mil == null || !mil.isFinite) {
        setState(() => _error = 'Milyem geçersiz.');
        return;
      }
      azDeg = _azimuthDegFromNatoMil(mil);
    } else if (azStr.isNotEmpty) {
      final az = double.tryParse(azStr.replaceAll(',', '.'));
      if (az == null || !az.isFinite) {
        setState(() => _error = 'Azimut (°) geçersiz.');
        return;
      }
      azDeg = az % 360.0;
      if (azDeg < 0) azDeg += 360.0;
    } else {
      setState(() => _error = 'Azimut (°) veya NATO milyem girin.');
      return;
    }
    try {
      final dest = _earthDistance.offset(_picked, d, azDeg);
      setState(() {
        _picked = dest;
        _error = null;
      });
      _mapController.move(_picked, math.max(12.0, _mapController.camera.zoom));
      _syncFieldsFromPoint();
      _polarMilCtrl.text = _natoMilFromAzimuthDeg(azDeg).toStringAsFixed(2);
      _polarAzimuthCtrl.text = azDeg.toStringAsFixed(2);
    } catch (err) {
      setState(() => _error = 'Konum hesabı başarısız: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Koordinat ile işaret'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Text(
                'Haritaya dokunun veya sekmeden DD / MGRS / UTM / SK-42 girin. '
                '«Metre · ° · mil» sekmesinde turuncu pimi başlangıç alıp ileri konumu hesaplayın.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _picked,
                      initialZoom: 13,
                      onTap: (_, p) {
                        setState(() {
                          _picked = p;
                          _error = null;
                        });
                        _syncFieldsFromPoint();
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.blueviperpro.app',
                        tileProvider: widget.tileProvider ?? NetworkTileProvider(),
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _picked,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.place, color: Colors.deepOrange, size: 36),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'DD'),
                  Tab(text: 'MGRS'),
                  Tab(text: 'UTM'),
                  Tab(text: 'SK-42'),
                  Tab(text: 'm · ° · mil'),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: TabBarView(
                controller: _tabs,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      TextField(
                        controller: _latCtrl,
                        decoration: const InputDecoration(labelText: 'Enlem (°)', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _lonCtrl,
                        decoration: const InputDecoration(labelText: 'Boylam (°)', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: _applyDd, child: const Text('Haritaya uygula')),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      TextField(
                        controller: _mgrsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'MGRS',
                          hintText: 'Örn: 37TCG1234567890',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: _applyMgrs, child: const Text('Haritaya uygula')),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      TextField(
                        controller: _utmZoneCtrl,
                        decoration: const InputDecoration(labelText: 'Zon (1–60)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Güney yarıküre'),
                        value: _utmSouth,
                        onChanged: (v) {
                          setState(() => _utmSouth = v);
                          _syncFieldsFromPoint();
                        },
                      ),
                      if (!_utmSouth)
                        Text(
                          'Kuzey: EPSG = 32600 + zon — Orta Doğu tipik 32635 (35N) … 32641 (41N).',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      if (!_utmSouth) const SizedBox(height: 8),
                      if (!_utmSouth)
                        DropdownButton<int>(
                          isExpanded: true,
                          hint: const Text('Orta Doğu hızlı UTM zon'),
                          items: [
                            for (final mz in Wgs84UtmNorth.middleEastZones)
                              DropdownMenuItem(
                                value: mz,
                                child: Text('EPSG:${Wgs84UtmNorth.epsgCode(mz)} · UTM ${mz}N'),
                              ),
                          ],
                          onChanged: (mz) {
                            if (mz == null) return;
                            setState(() {
                              _utmZoneCtrl.text = mz.toString();
                              final xy = Wgs84UtmNorth.toUtm(_picked, mz);
                              _utmEastCtrl.text = xy.$1.toStringAsFixed(1);
                              _utmNorthCtrl.text = xy.$2.toStringAsFixed(1);
                            });
                          },
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _utmEastCtrl,
                        decoration: const InputDecoration(labelText: 'Doğu (E, m)', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _utmNorthCtrl,
                        decoration: const InputDecoration(labelText: 'Kuzey (N, m)', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: _applyUtm, child: const Text('Haritaya uygula')),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      DropdownButtonFormField<int>(
                        key: ValueKey(_skMeridian),
                        initialValue: _skMeridian,
                        decoration: const InputDecoration(
                          labelText: 'Orta meridyen λ₀ (°)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final m in Sk42TurkeyGrid.meridians)
                            DropdownMenuItem(value: m, child: Text('$m°')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _skMeridian = v);
                          try {
                            final sk = Sk42TurkeyGrid.wgs84ToGrid(_picked, v);
                            _skEastCtrl.text = sk.$1.toStringAsFixed(1);
                            _skNorthCtrl.text = sk.$2.toStringAsFixed(1);
                          } catch (_) {}
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _skEastCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Doğu (E, m)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _skNorthCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kuzey (N, m)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pulkovo 1942 · 3° GK · FE 500 km. Resmi ölçüm için kurum parametrelerini kullanın.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: _applySk42, child: const Text('Haritaya uygula')),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text(
                        'Başlangıç: haritadaki turuncu pim (dokunun veya üstteki sekmeden girin).',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _polarDistCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mesafe (m)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _polarAzimuthCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Azimut — 360° (Kuzey=0°, Doğu=90°, saat yönü)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: _onAzimuthChanged,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _polarMilCtrl,
                        decoration: const InputDecoration(
                          labelText: 'NATO milyem (6400 = tam tur) — isteğe bağlı',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: _onMilChanged,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Önce azimut, sonra mil doldurursanız mil baskın sayılır. '
                        'Her iki alan da doluysa milyem kullanılır.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: _applyPolar, child: const Text('İleri konumu hesapla')),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        widget.onApply(_picked);
                        Navigator.pop(context);
                      },
                      child: const Text('Ana haritaya İşaret 1 olarak aktar'),
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
}
