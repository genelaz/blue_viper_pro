import 'package:blue_viper_pro/core/geo/elevation_service.dart';
import 'package:blue_viper_pro/core/geo/simple_los.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

Future<void> showLosAnalysisDialog(
  BuildContext context, {
  required LatLng observer,
  required LatLng target,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Basit LOS (DEM)'),
      content: SizedBox(
        width: 320,
        child: FutureBuilder<SimpleLosResult>(
          future: analyzeSimpleLos(
            observer: observer,
            target: target,
            dem: (p) => ElevationService.fetchMeters(p.latitude, p.longitude),
          ),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final r = snap.data!;
            if (r.samples.isEmpty) {
              return const Text('DEM verisi alınamadı veya mesafe çok kısa.');
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  r.clearLineOfSight
                      ? 'Görüş hattı (DEM örneklemesine göre) engelsiz görünüyor.'
                      : 'Görüş hattına yakın yükseklik profili engel oluşturabilir (~${r.blockedNearM?.round()} m).',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Yer eğrisi / Dünya eğriliği yok; Open-Meteo DEM (~90 m).',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: r.samples.length,
                    itemBuilder: (c, i) {
                      final s = r.samples[i];
                      return ListTile(
                        dense: true,
                        title: Text('${s.distanceFromObserverM.toStringAsFixed(0)} m'),
                        subtitle: Text(
                          'DEM ${s.elevationM.toStringAsFixed(0)} m · LOS ${s.lineOfSightHeightM.toStringAsFixed(0)} m',
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
      ],
    ),
  );
}
