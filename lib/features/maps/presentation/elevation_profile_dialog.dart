import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo/elevation_service.dart';
import '../../../core/geo/geo_measure.dart';

/// Rota boyunca DEM örnekleri — basit CAS/AlpinQuest benzeri profil (çevrimiçi DEM).
Future<void> showElevationProfileDialog(
  BuildContext context,
  List<LatLng> pathVertices,
) async {
  if (pathVertices.length < 2) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _ElevationProfileDialog(pathVertices: pathVertices),
  );
}

class _ElevationProfileDialog extends StatefulWidget {
  const _ElevationProfileDialog({required this.pathVertices});

  final List<LatLng> pathVertices;

  @override
  State<_ElevationProfileDialog> createState() => _ElevationProfileDialogState();
}

class _ElevationProfileDialogState extends State<_ElevationProfileDialog> {
  bool _loading = true;
  String? _error;
  final List<(double distM, double? elevM)> _samples = [];

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final pts = samplePolyline(widget.pathVertices, stepMeters: 135);
    var dist = 0.0;
    LatLng? prev;
    for (final p in pts) {
      if (prev != null) {
        dist += Geolocator.distanceBetween(
          prev.latitude,
          prev.longitude,
          p.latitude,
          p.longitude,
        );
      }
      prev = p;
      final el = await ElevationService.fetchMeters(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() => _samples.add((dist, el)));
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yükseklik profili (DEM)'),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: _loading && _samples.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Text(_error!)
                : ListView.builder(
                    itemCount: _samples.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _samples.length) {
                        return const ListTile(
                          leading: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          title: Text('Örnekleniyor…'),
                        );
                      }
                      final (d, e) = _samples[i];
                      return ListTile(
                        dense: true,
                        title: Text('${d.toStringAsFixed(0)} m'),
                        trailing: Text(
                          e == null ? '— m' : '${e.toStringAsFixed(0)} m',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
      ],
    );
  }
}
