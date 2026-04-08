import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Konuşmacı üzerinde basit ses çubuğu animasyonu.
class MapSpeakingWave extends StatefulWidget {
  const MapSpeakingWave({super.key, this.color = Colors.lightGreenAccent});

  final Color color;

  @override
  State<MapSpeakingWave> createState() => _MapSpeakingWaveState();
}

class _MapSpeakingWaveState extends State<MapSpeakingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value * math.pi * 2;
        return SizedBox(
          width: 36,
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (i) {
              final h = 6.0 + 8.0 * (0.5 + 0.5 * math.sin(t + i * 0.7)).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  width: 4,
                  height: h,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, color: Colors.black54),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
