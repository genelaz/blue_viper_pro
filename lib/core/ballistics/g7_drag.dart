import 'g1_drag.dart' show kG1DragSi;

/// G7 sürüklenme eğrisi (Mach → i(M)); BC birimi lb/in² G7.
double g7IDragAtMach(double mach) {
  final m = mach.clamp(_g7Machs.first, _g7Machs.last);
  var lo = 0;
  var hi = _g7Machs.length - 1;
  while (lo < hi - 1) {
    final mid = (lo + hi) >> 1;
    if (_g7Machs[mid] <= m) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final m0 = _g7Machs[lo];
  final m1 = _g7Machs[hi];
  if (m1 <= m0) return _g7I[lo];
  final t = (m - m0) / (m1 - m0);
  return _g7I[lo] + t * (_g7I[hi] - _g7I[lo]);
}

double g7DragAccelerationMagnitude({
  required double velocityMps,
  required double mach,
  required double bcG7LbPerSqIn,
  required double densityRatio,
}) {
  if (velocityMps < 1e-6 || bcG7LbPerSqIn < 1e-9) return 0;
  return kG1DragSi *
      densityRatio *
      velocityMps * velocityMps *
      g7IDragAtMach(mach) /
      bcG7LbPerSqIn;
}

const List<double> _g7Machs = [
  0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.75, 0.80, 0.825, 0.85, 0.875, 0.90,
  0.925, 0.95, 0.975, 1.00, 1.025, 1.05, 1.075, 1.10, 1.125, 1.15, 1.175, 1.20,
  1.25, 1.30, 1.35, 1.40, 1.50, 1.60, 1.70, 1.80, 1.90, 2.00, 2.20, 2.40, 2.60,
  2.80, 3.00, 3.50, 4.00,
];

const List<double> _g7I = [
  0.0120, 0.0280, 0.0500, 0.0687, 0.0966, 0.1298, 0.1510, 0.1678, 0.1830,
  0.2020, 0.2230, 0.2480, 0.2770, 0.3080, 0.3410, 0.3780, 0.4050, 0.4300,
  0.4560, 0.4650, 0.4750, 0.4870, 0.5000, 0.5150, 0.5500, 0.6050, 0.6700,
  0.7400, 0.9000, 1.0500, 1.2100, 1.3800, 1.5400, 1.6900, 1.9500, 2.1500,
  2.3000, 2.4200, 2.5200, 2.6800, 2.9700,
];
