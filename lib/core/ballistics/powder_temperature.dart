/// Barut sıcaklığına göre çıkış hızı düzeltmesi.
/// En az iki [TempVelocityPair] verilirse doğrusal interpolasyon; aksi halde [fallbackMps] döner.
double muzzleVelocityFromPowderTable({
  required double fallbackMps,
  required double powderTempC,
  required List<TempVelocityPair> pairs,
}) {
  if (pairs.length < 2) return fallbackMps;
  final sorted = List<TempVelocityPair>.from(pairs)..sort((a, b) => a.tempC.compareTo(b.tempC));
  final p0 = sorted.first;
  final p1 = sorted.last;
  if ((p1.tempC - p0.tempC).abs() < 1.0) return fallbackMps;
  final t = powderTempC.clamp(p0.tempC, p1.tempC);
  final f = (t - p0.tempC) / (p1.tempC - p0.tempC);
  return p0.velocityMps + f * (p1.velocityMps - p0.velocityMps);
}

class TempVelocityPair {
  final double tempC;
  final double velocityMps;

  const TempVelocityPair({required this.tempC, required this.velocityMps});
}
