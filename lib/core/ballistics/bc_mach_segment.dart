/// Mach eşiklerine göre parçalı BC (yüksek Mach’tan düşüğe eşleşir).
class BcMachSegment {
  /// Bu Mach ve üzeri için [bc] kullanılır (parça tablosu azalan Mach sıralı olmalı).
  final double machMin;
  final double bc;

  const BcMachSegment({required this.machMin, required this.bc});
}

/// [segments] azalan [machMin] sırasında olmalı (örn. 3.0 → 1.2 → 0.0).
double bcForMachFromSegments(
  double mach,
  List<BcMachSegment> segments,
  double fallbackBc,
) {
  if (segments.isEmpty) return fallbackBc;
  for (final s in segments) {
    if (mach >= s.machMin) {
      return s.bc.clamp(0.02, 2.5);
    }
  }
  return fallbackBc.clamp(0.02, 2.5);
}

List<BcMachSegment>? parseBcMachSegments(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final out = <BcMachSegment>[];
  for (final raw in t.split(RegExp(r'[\n;]+'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'[,\s\t]+')).where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) continue;
    final m = double.tryParse(parts[0].replaceAll(',', '.'));
    final b = double.tryParse(parts[1].replaceAll(',', '.'));
    if (m == null || b == null) continue;
    out.add(BcMachSegment(machMin: m, bc: b));
  }
  if (out.length < 2) return null;
  out.sort((a, b) => b.machMin.compareTo(a.machMin));
  return out;
}
