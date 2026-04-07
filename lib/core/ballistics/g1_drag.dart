/// G1 standart mermi sürüklenme eğrisi (Mach → i(M)) ve ideal gaz yoğunluğu.
library;

/// ISO benzeri: kuru havada ses hızı (m/s), yaklaşık.
double speedOfSoundDryAirMps(double tempC) =>
    331.3 + 0.606 * tempC.clamp(-50.0, 60.0);

/// Ideal gaz: hava yoğunluğu kg/m³. P: Pa, T: K
double airDensityKgPerM3({required double pressurePa, required double tempK}) {
  const rDryAir = 287.05;
  return pressurePa / (rDryAir * tempK);
}

/// ICAO deniz seviyesi referans yoğunluğu (~15 °C, 101325 Pa).
const double icaoSeaLevelDensity = 1.225;

/// McCoy / JBM biçiminde skaler sürüklenme ivmesi (m/s²):
/// \(\lVert \mathbf{a}_d \rVert = k\,(\rho/\rho_0)\, i(M)\, v^2 / C\) — C lb/in² G1 BC.
const double kG1DragSi = 1.12e-4;

double g1IDragAtMach(double mach) {
  final m = mach.clamp(_g1Machs.first, _g1Machs.last);
  var lo = 0;
  var hi = _g1Machs.length - 1;
  while (lo < hi - 1) {
    final mid = (lo + hi) >> 1;
    if (_g1Machs[mid] <= m) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final m0 = _g1Machs[lo];
  final m1 = _g1Machs[hi];
  if (m1 <= m0) return _g1I[lo];
  final t = (m - m0) / (m1 - m0);
  return _g1I[lo] + t * (_g1I[hi] - _g1I[lo]);
}

double g1DragAccelerationMagnitude({
  required double velocityMps,
  required double mach,
  required double bcG1LbPerSqIn,
  required double densityRatio,
}) {
  if (velocityMps < 1e-6 || bcG1LbPerSqIn < 1e-9) return 0;
  return kG1DragSi *
      densityRatio *
      velocityMps * velocityMps *
      g1IDragAtMach(mach) /
      bcG1LbPerSqIn;
}

// Mach düğümleri ve G1 i(M); çiftler eşleştirilmiş (doğrusal ara değerleme).
const List<double> _g1Machs = [
  0.00, 0.20, 0.40, 0.60, 0.80, 0.90, 0.95, 1.00, 1.10, 1.20, 1.40, 1.60,
  1.80, 2.00, 2.20, 2.50, 2.80, 3.00, 3.50, 4.00,
];

const List<double> _g1I = [
  0.2629, 0.2378, 0.2217, 0.2034, 0.2199, 0.2411, 0.2701, 0.3038, 0.3529,
  0.3792, 0.4147, 0.4277, 0.4294, 0.4233, 0.4134, 0.3935, 0.3722, 0.3464,
  0.3004, 0.2872,
];
