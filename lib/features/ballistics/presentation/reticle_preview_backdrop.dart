import 'package:flutter/material.dart';

/// Retikül önizlemesi için düz siyah yerine «açık dürbün» hissi veren yumuşak gradyan.
/// Fotoğraf yokken kullanılır; gerçek görüntü ile çakışmaz.
class ReticlePreviewBackdrop extends StatelessWidget {
  const ReticlePreviewBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF243848),
              Color(0xFF1B2830),
              Color(0xFF1A2520),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
      );
    }
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF9BCCE8),
            Color(0xFF7BAE8C),
            Color(0xFF6A9568),
          ],
          stops: [0.0, 0.42, 1.0],
        ),
      ),
    );
  }
}
