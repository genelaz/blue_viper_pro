import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/reticles/reticle_definition.dart';
import 'reticle_canvas_painter.dart';

/// Katalogdan seçilen parametrik retikül + tutma (mil veya MOA, retikül birimine göre).
class ReticleHoldView extends StatelessWidget {
  final ReticleDefinition? reticle;
  final double holdUpMil;
  final double holdLeftMil;
  final double holdUpMoa;
  final double holdLeftMoa;
  final bool firstFocalPlane;
  final double scopeMagnification;
  final double referenceMag;

  const ReticleHoldView({
    super.key,
    this.reticle,
    required this.holdUpMil,
    required this.holdLeftMil,
    required this.holdUpMoa,
    required this.holdLeftMoa,
    this.firstFocalPlane = true,
    this.scopeMagnification = 10,
    this.referenceMag = 10,
  });

  double get _scale {
    if (firstFocalPlane) return 1.0;
    final r = referenceMag <= 0 ? 10.0 : referenceMag;
    final m = scopeMagnification <= 0 ? r : scopeMagnification;
    return r / m;
  }

  double get _holdUp {
    final u = reticle?.unit ?? 'mil';
    final base = u == 'moa' ? holdUpMoa : holdUpMil;
    return base * _scale;
  }

  double get _holdLeft {
    final u = reticle?.unit ?? 'mil';
    final base = u == 'moa' ? holdLeftMoa : holdLeftMil;
    return base * _scale;
  }

  @override
  Widget build(BuildContext context) {
    final def = reticle ??
        const ReticleDefinition(
          id: 'fallback',
          name: 'Genel MIL ızgara',
          manufacturer: '',
          unit: 'mil',
          pattern: 'hash',
        );

    return LayoutBuilder(
      builder: (context, c) {
        final s = math.min(c.maxWidth, 320.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              def.name,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (def.manufacturer.isNotEmpty)
              Text(
                def.manufacturer,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: s,
              height: s,
              child: CustomPaint(
                painter: ReticleCanvasPainter(
                  def: def,
                  holdUpUnits: _holdUp,
                  holdLeftUnits: _holdLeft,
                  unitIsMoa: def.unit == 'moa',
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      'Tutma (${def.unit}): ↑ ${_holdUp.toStringAsFixed(2)}  '
                      '← ${_holdLeft.toStringAsFixed(2)}  '
                      '(${firstFocalPlane ? 'FFP' : 'SFP ×${_scale.toStringAsFixed(2)}'})',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
