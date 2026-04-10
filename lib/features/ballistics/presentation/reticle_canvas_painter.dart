import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/reticles/reticle_definition.dart';

/// Parametrik retikül çizimi (vektör). Telifli raster görüntü değildir.
class ReticleCanvasPainter extends CustomPainter {
  final ReticleDefinition def;
  final double holdUpUnits;
  final double holdLeftUnits;
  final bool unitIsMoa;

  /// Açık dürbün / beyaz alan önizlemesi (StreLok benzeri); yeşil gece görüş modu için false.
  final bool lightScopeField;

  ReticleCanvasPainter({
    required this.def,
    required this.holdUpUnits,
    required this.holdLeftUnits,
    required this.unitIsMoa,
    this.lightScopeField = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 8;
    final vr = def.visibleRadiusUnits.clamp(3.0, 20.0);
    final pxPerUnit = r / vr;

    final grid = Paint()
      ..color = lightScopeField
          ? const Color(0xFF141414).withValues(alpha: 0.48)
          : Colors.green.shade800
      ..strokeWidth = lightScopeField ? 0.85 : 1.0;
    final major = Paint()
      ..color = lightScopeField
          ? const Color(0xFF050505).withValues(alpha: 0.9)
          : Colors.lightGreenAccent.shade700
      ..strokeWidth = lightScopeField ? 1.15 : 1.4;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey.shade700
      ..strokeWidth = 1.0;

    if (!lightScopeField) {
      canvas.drawCircle(c, r, rim);
    }

    switch (def.pattern) {
      case 'mil_dot':
        _milDot(canvas, c, r, pxPerUnit, grid, major);
        break;
      case 'tree':
        _tree(canvas, c, r, pxPerUnit, grid, major);
        break;
      case 'duplex':
        _duplex(canvas, c, r, grid, major);
        break;
      case 'german_4':
        _german4(canvas, c, r, grid, major);
        break;
      case 'hash':
      default:
        _hash(canvas, c, r, pxPerUnit, grid, major);
        break;
    }

    final hu = holdUpUnits;
    final hl = holdLeftUnits;
    final hp = Offset(c.dx - hl * pxPerUnit, c.dy - hu * pxPerUnit);
    final lineToHold = Paint()
      ..color = lightScopeField ? const Color(0xFFC62828) : Colors.redAccent
      ..strokeWidth = lightScopeField ? 1.4 : 1.6;
    canvas.drawLine(c, hp, lineToHold);
    if (lightScopeField) {
      canvas.drawCircle(hp, 8, Paint()..color = const Color(0xFFF9A825));
      canvas.drawCircle(hp, 5, Paint()..color = const Color(0xFFFFFDE7));
      canvas.drawCircle(hp, 2.2, Paint()..color = const Color(0xFF4E342E));
    } else {
      canvas.drawCircle(hp, 5, Paint()..color = Colors.redAccent);
      canvas.drawCircle(hp, 2, Paint()..color = Colors.white);
    }
  }

  void _hash(Canvas canvas, Offset c, double r, double px, Paint g, Paint mj) {
    final maj = def.majorStep;
    final min = def.minorStep;
    if (min <= 0) return;
    final steps = (r / px / min).ceil();
    final majorEvery = (maj / min).round().clamp(1, 10000);
    final crossW = lightScopeField ? 2.0 : 1.8;
    final crossH = Paint()
      ..color = mj.color
      ..strokeWidth = crossW;
    final crossV = Paint()
      ..color = mj.color
      ..strokeWidth = crossW;
    for (var i = -steps; i <= steps; i++) {
      if (i == 0) continue;
      final u = i * min;
      final o = u * px;
      if (o.abs() > r) continue;
      final isMajor = i % majorEvery == 0;
      final p = isMajor ? mj : g;
      canvas.drawLine(Offset(c.dx + o, c.dy - r), Offset(c.dx + o, c.dy + r), p);
      canvas.drawLine(Offset(c.dx - r, c.dy + o), Offset(c.dx + r, c.dy + o), p);
    }
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), crossH);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), crossV);
  }

  void _milDot(Canvas canvas, Offset c, double r, double px, Paint g, Paint mj) {
    final min = def.minorStep;
    final count = def.milDotCount ?? 8;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), mj);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), mj);
    for (var i = 1; i <= count; i++) {
      final d = i * min * px;
      if (d > r) break;
      canvas.drawCircle(Offset(c.dx + d, c.dy), 2, g);
      canvas.drawCircle(Offset(c.dx - d, c.dy), 2, g);
      canvas.drawCircle(Offset(c.dx, c.dy + d), 2, g);
      canvas.drawCircle(Offset(c.dx, c.dy - d), 2, g);
    }
  }

  void _tree(Canvas canvas, Offset c, double r, double px, Paint g, Paint mj) {
    final maj = def.majorStep;
    final levels = def.treeLevels ?? 10;
    final wdots = def.windDotsPerSide ?? 4;
    canvas.drawLine(Offset(c.dx, c.dy), Offset(c.dx, c.dy + r), mj);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), g);
    for (var i = 1; i <= levels; i++) {
      final y = c.dy + i * maj * px;
      if (y > c.dy + r) break;
      final halfW = math.min(r, i * maj * px * 0.45);
      canvas.drawLine(Offset(c.dx - halfW, y), Offset(c.dx + halfW, y), g);
      final step = halfW / (wdots + 1);
      for (var d = 1; d <= wdots; d++) {
        canvas.drawCircle(Offset(c.dx - halfW + step * d, y), 1.8, g);
      }
    }
  }

  void _duplex(Canvas canvas, Offset c, double r, Paint g, Paint mj) {
    final thick = r * 0.15;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx - thick, c.dy), mj..strokeWidth = 3);
    canvas.drawLine(Offset(c.dx + thick, c.dy), Offset(c.dx + r, c.dy), mj..strokeWidth = 3);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy - thick), mj..strokeWidth = 3);
    canvas.drawLine(Offset(c.dx, c.dy + thick), Offset(c.dx, c.dy + r), mj..strokeWidth = 3);
    canvas.drawLine(Offset(c.dx - thick, c.dy), Offset(c.dx + thick, c.dy), g);
    canvas.drawLine(Offset(c.dx, c.dy - thick), Offset(c.dx, c.dy + thick), g);
  }

  void _german4(Canvas canvas, Offset c, double r, Paint g, Paint mj) {
    final thick = r * 0.35;
    canvas.drawLine(Offset(c.dx, c.dy), Offset(c.dx, c.dy + r), mj..strokeWidth = 3.5);
    canvas.drawLine(Offset(c.dx - r * 0.9, c.dy), Offset(c.dx + r * 0.9, c.dy), g);
    canvas.drawLine(Offset(c.dx - thick, c.dy), Offset(c.dx - r * 0.9, c.dy), g);
    canvas.drawLine(Offset(c.dx + thick, c.dy), Offset(c.dx + r * 0.9, c.dy), g);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy - thick), g);
  }

  @override
  bool shouldRepaint(covariant ReticleCanvasPainter old) =>
      old.holdUpUnits != holdUpUnits ||
      old.holdLeftUnits != holdLeftUnits ||
      old.def.id != def.id ||
      old.def.pattern != def.pattern ||
      old.lightScopeField != lightScopeField;
}
