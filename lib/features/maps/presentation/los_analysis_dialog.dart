import 'dart:math' as math;

import 'package:blue_viper_pro/core/geo/elevation_service.dart';
import 'package:blue_viper_pro/core/geo/simple_los.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

Future<void> showLosAnalysisDialog(
  BuildContext context, {
  required LatLng observer,
  required LatLng target,
  void Function(SimpleLosResult result, LatLng observer, LatLng target)? onApplyToMap,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Basit LOS (DEM)'),
      content: SizedBox(
        width: 340,
        child: _LosAnalysisBody(
          observer: observer,
          target: target,
          onApplyToMap: onApplyToMap,
          dialogContext: dialogCtx,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Kapat')),
      ],
    ),
  );
}

class _LosAnalysisBody extends StatefulWidget {
  const _LosAnalysisBody({
    required this.observer,
    required this.target,
    required this.dialogContext,
    this.onApplyToMap,
  });

  final LatLng observer;
  final LatLng target;
  final BuildContext dialogContext;
  final void Function(SimpleLosResult result, LatLng observer, LatLng target)? onApplyToMap;

  @override
  State<_LosAnalysisBody> createState() => _LosAnalysisBodyState();
}

class _LosAnalysisBodyState extends State<_LosAnalysisBody> {
  double _observerAntennaM = 1.8;
  double _targetHeightM = 0;
  /// DEM ara örnek sayısı ([analyzeSimpleLos] `segments`; düşük = hızlı/az istek, yüksek = daha ince profil).
  double _demSegments = 14;
  late Future<SimpleLosResult> _future;
  SimpleLosResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _future = _analyze();
    _attachFutureResult();
  }

  void _attachFutureResult() {
    _future.then((r) {
      if (mounted) setState(() => _lastResult = r);
    });
  }

  Future<SimpleLosResult> _analyze() {
    return analyzeSimpleLos(
      observer: widget.observer,
      target: widget.target,
      observerAntennaM: _observerAntennaM,
      targetHeightM: _targetHeightM,
      segments: _demSegments
          .round()
          .clamp(kLosDemSegmentsMin, kLosDemSegmentsMax),
      dem: (p) => ElevationService.fetchMeters(p.latitude, p.longitude),
    );
  }

  void _recompute() {
    setState(() {
      _future = _analyze();
      _lastResult = null;
    });
    _attachFutureResult();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paket 4 — yükseklikler, DEM çözünürlüğü, profil; «Haritada göster» ile yeşil/kırmızı LOS.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'DEM örnek sayısı (interval; $kLosDemSegmentsMin–$kLosDemSegmentsMax)',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        Slider(
          value: _demSegments.clamp(
            kLosDemSegmentsMin.toDouble(),
            kLosDemSegmentsMax.toDouble(),
          ),
          min: kLosDemSegmentsMin.toDouble(),
          max: kLosDemSegmentsMax.toDouble(),
          divisions: kLosDemSegmentsMax - kLosDemSegmentsMin,
          label: '${_demSegments.round()}',
          onChanged: (v) => setState(() => _demSegments = v),
          onChangeEnd: (_) => _recompute(),
        ),
        Text(
          'Yüksek değer: daha fazla Open-Meteo isteği ve süre; düşük: kaba profil.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Text('Gözlem yüksekliği (m)', style: Theme.of(context).textTheme.labelMedium),
        Slider(
          value: _observerAntennaM.clamp(0.5, 15.0),
          min: 0.5,
          max: 15.0,
          divisions: 29,
          label: '${_observerAntennaM.toStringAsFixed(1)} m',
          onChanged: (v) => setState(() => _observerAntennaM = v),
          onChangeEnd: (_) => _recompute(),
        ),
        Text('Hedef yüksekliği (yerden, m)', style: Theme.of(context).textTheme.labelMedium),
        Slider(
          value: _targetHeightM.clamp(0.0, 50.0),
          min: 0,
          max: 50.0,
          divisions: 50,
          label: '${_targetHeightM.toStringAsFixed(0)} m',
          onChanged: (v) => setState(() => _targetHeightM = v),
          onChangeEnd: (_) => _recompute(),
        ),
        const SizedBox(height: 4),
        FutureBuilder<SimpleLosResult>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
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
                      : 'Görüş hattına yakın yükseklik profili engel oluşturabilir (~${r.blockedNearM?.round() ?? '?'} m).',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Yer eğrisi / Dünya eğriliği yok; Open-Meteo DEM (~90 m); ara noktalarda >2 m fazla yükselti «engel» sayılır.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Text('Profil (mesafe → rakım)', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 4),
                SizedBox(
                  height: 140,
                  child: CustomPaint(
                    painter: _LosProfilePainter(
                      samples: r.samples,
                      clearLine: r.clearLineOfSight,
                      terrainColor: scheme.tertiary.withValues(alpha: 0.35),
                      losColor: scheme.primary,
                      blockedColor: scheme.error.withValues(alpha: 0.25),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Örnek noktalar (${r.samples.length})',
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                  ],
                ),
                if (widget.onApplyToMap != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _lastResult == null || _lastResult!.samples.length < 2
                          ? null
                          : () {
                              widget.onApplyToMap!(
                                _lastResult!,
                                widget.observer,
                                widget.target,
                              );
                              Navigator.pop(widget.dialogContext);
                            },
                      icon: const Icon(Icons.route_outlined, size: 18),
                      label: const Text('Haritada göster'),
                    ),
                  ),
                  Text(
                    'Yeşil: segment DEM’e göre engelsiz; kırmızı: olası engel. '
                    'Kırmızı daire yaklaşık ilk kesişim (≈ blockedNearM).',
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    ),
    );
  }
}

/// Yatay eksen: gözleyiciden mesafe (m). Dikey: WGS yaklaşık rakım + LOS çizgisinin kesişimi.
class _LosProfilePainter extends CustomPainter {
  _LosProfilePainter({
    required this.samples,
    required this.clearLine,
    required this.terrainColor,
    required this.losColor,
    required this.blockedColor,
  });

  final List<SimpleLosSample> samples;
  final bool clearLine;
  final Color terrainColor;
  final Color losColor;
  final Color blockedColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    final padL = 36.0;
    final padR = 8.0;
    final padT = 8.0;
    final padB = 22.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    if (w <= 0 || h <= 0) return;

    final maxD = samples.last.distanceFromObserverM;
    var yMin = double.infinity;
    var yMax = double.negativeInfinity;
    for (final s in samples) {
      yMin = math.min(yMin, s.elevationM);
      yMin = math.min(yMin, s.lineOfSightHeightM);
      yMax = math.max(yMax, s.elevationM);
      yMax = math.max(yMax, s.lineOfSightHeightM);
    }
    if (yMax <= yMin) {
      yMax = yMin + 1;
    }
    const margin = 8.0;
    yMin -= margin;
    yMax += margin;

    double xPix(double d) => padL + (d / maxD) * w;
    double yPix(double elevM) => padT + h * (1 - (elevM - yMin) / (yMax - yMin));

    // Engel dolgusu: ara örnekte arazi LOS’un >2 m üstündeyse, o segmentte LOS ile zemin arası
    if (!clearLine) {
      for (var i = 1; i < samples.length - 1; i++) {
        final p0 = samples[i - 1];
        final p1 = samples[i];
        if (p1.elevationM > p1.lineOfSightHeightM + 2.0) {
          final quad = Path()
            ..moveTo(xPix(p0.distanceFromObserverM), yPix(p0.lineOfSightHeightM))
            ..lineTo(xPix(p1.distanceFromObserverM), yPix(p1.lineOfSightHeightM))
            ..lineTo(xPix(p1.distanceFromObserverM), yPix(p1.elevationM))
            ..lineTo(xPix(p0.distanceFromObserverM), yPix(p0.elevationM))
            ..close();
          canvas.drawPath(quad, Paint()..color = blockedColor);
        }
      }
    }

    final terrain = Path()..moveTo(xPix(samples.first.distanceFromObserverM), yPix(samples.first.elevationM));
    for (var i = 1; i < samples.length; i++) {
      terrain.lineTo(xPix(samples[i].distanceFromObserverM), yPix(samples[i].elevationM));
    }
    canvas.drawPath(
      terrain,
      Paint()
        ..color = terrainColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final los = Path()..moveTo(xPix(samples.first.distanceFromObserverM), yPix(samples.first.lineOfSightHeightM));
    for (var i = 1; i < samples.length; i++) {
      los.lineTo(xPix(samples[i].distanceFromObserverM), yPix(samples[i].lineOfSightHeightM));
    }
    canvas.drawPath(
      los,
      Paint()
        ..color = losColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final axisPaint = Paint()
      ..color = Colors.black38
      ..strokeWidth = 1;
    canvas.drawLine(Offset(padL, padT + h), Offset(padL + w, padT + h), axisPaint);

    final tp = TextPainter(
      text: TextSpan(
        style: const TextStyle(fontSize: 10, color: Colors.black54),
        children: [
          TextSpan(text: '0'),
          TextSpan(text: ' — ${maxD.toStringAsFixed(0)} m', style: const TextStyle(fontSize: 9)),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(padL, padT + h + 2));

    final tpL = TextPainter(
      text: TextSpan(
        text: '${yMin.toStringAsFixed(0)}…${yMax.toStringAsFixed(0)} m',
        style: const TextStyle(fontSize: 9, color: Colors.black45),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpL.paint(canvas, Offset(2, padT + h / 2 - 6));
  }

  @override
  bool shouldRepaint(covariant _LosProfilePainter oldDelegate) {
    if (oldDelegate.clearLine != clearLine) return true;
    if (oldDelegate.samples.length != samples.length) return true;
    for (var i = 0; i < samples.length; i++) {
      final a = oldDelegate.samples[i];
      final b = samples[i];
      if (a.distanceFromObserverM != b.distanceFromObserverM ||
          a.elevationM != b.elevationM ||
          a.lineOfSightHeightM != b.lineOfSightHeightM) {
        return true;
      }
    }
    return false;
  }
}
