import 'package:flutter/foundation.dart';

class TargetSolution {
  final double distanceMeters;
  final double elevationDeltaMeters;
  final double slopeDegrees;
  /// Atış yönü (kuzeyden derece), Coriolis / vektörel rüzgâr için.
  final double? shotAzimuthFromNorthDeg;
  /// Rüzgar hızı (m/s).
  final double? windSpeedMps;
  /// Rüzgarın estiği yön (kuzeyden derece, meteorolojik “nereden”).
  final double? windFromNorthDeg;
  /// Sağdan/soldan basit mod: +1 sağdan, −1 soldan; [windFromNorthDeg] yoksa kullanılır.
  final int? windCrossSignFromRight;

  const TargetSolution({
    required this.distanceMeters,
    required this.elevationDeltaMeters,
    required this.slopeDegrees,
    this.shotAzimuthFromNorthDeg,
    this.windSpeedMps,
    this.windFromNorthDeg,
    this.windCrossSignFromRight,
  });
}

class TargetSolutionStore {
  static final ValueNotifier<TargetSolution?> current =
      ValueNotifier<TargetSolution?>(null);

  static void save(TargetSolution solution) {
    current.value = solution;
  }
}
