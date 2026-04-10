import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fotoğraf yokken «açık dürbün» hissi: koyu çerçeve, yuvarlak görüş alanı, gökyüzü / saha ufku.
/// Raster görüntü gerekmez; vektör ile StreLok tarzı önizleme.
class ReticlePreviewBackdrop extends StatelessWidget {
  const ReticlePreviewBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScopeFieldBackdropPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _ScopeFieldBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, Paint()..color = const Color(0xFF232325));

    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 * 0.93;

    final clipPath = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    canvas.save();
    canvas.clipPath(clipPath);

    final field = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(0, -1),
        end: Alignment(0, 1),
        colors: [
          Color(0xFF7BA3C8),
          Color(0xFF9EBDD4),
          Color(0xFFC5D5E2),
          Color(0xFFAAB89A),
          Color(0xFF8FA67E),
        ],
        stops: [0.0, 0.28, 0.46, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, field);

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.02,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.08),
          Colors.black.withValues(alpha: 0.28),
        ],
        stops: const [0.62, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, vignette);

    canvas.restore();

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..color = const Color(0xFF080809),
    );
    canvas.drawCircle(
      c,
      r - 1.2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
