import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/maps/mbtiles_vector_pick.dart';

/// Vektör MBTiles dokunuş sorgusu sonuçları (OpenMapTiles / MVT özellikleri; MapLibre değil).
Future<void> showVectorMbtilesPickSheet(
  BuildContext context, {
  required LatLng at,
  required List<MbtilesVectorPickResult> hits,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.88,
      minChildSize: 0.28,
      builder: (_, scroll) {
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text('MVT özellikleri', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '${at.latitude.toStringAsFixed(5)}, ${at.longitude.toStringAsFixed(5)}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (hits.isEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Bu konumda uygun geometri bulunamadı. Yakınlaştırın veya çizgi / alan üzerinde tekrar deneyin.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
            for (var i = 0; i < hits.length; i++) ...[
              const SizedBox(height: 14),
              Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                child: ExpansionTile(
                  initiallyExpanded: i == 0,
                  title: Text(
                    hits[i].layerName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${hits[i].matchKindLabel}'
                    '${hits[i].distanceMeters > 0.05 ? ' · ~${hits[i].distanceMeters.toStringAsFixed(0)} m' : ''}'
                    '${hits[i].featureId.isNotEmpty ? ' · id ${hits[i].featureId}' : ''}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  children: [
                    if (hits[i].properties.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'Özellik alanı yok veya boş.',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Column(
                          children: [
                            for (final e in hits[i].properties.entries)
                              ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                title: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                subtitle: Text(e.value, style: const TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}
