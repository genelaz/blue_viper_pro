import 'dart:math' as math;

/// Kullanıcı tabanlı G1 biçiminde i(Mach) eğrisi (doğrusal ara değer).
double customIDragAtMach(
  double mach,
  List<double> machNodes,
  List<double> iNodes,
) {
  assert(machNodes.length == iNodes.length && machNodes.length >= 2);
  final m = mach.clamp(machNodes.first, machNodes.last);
  var lo = 0;
  var hi = machNodes.length - 1;
  while (lo < hi - 1) {
    final mid = (lo + hi) >> 1;
    if (machNodes[mid] <= m) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final m0 = machNodes[lo];
  final m1 = machNodes[hi];
  if (m1 <= m0) return iNodes[lo];
  final t = (m - m0) / (m1 - m0);
  return iNodes[lo] + t * (iNodes[hi] - iNodes[lo]);
}

/// Satır başına: Mach ve i(M). En az 2 satır.
({List<double> machs, List<double> iNodes})? parseCustomDragTable(String text) {
  final machs = <double>[];
  final iNodes = <double>[];
  for (final raw in text.split(RegExp(r'[\n;]+'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'[,\s\t]+')).where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) continue;
    final m = double.tryParse(parts[0].replaceAll(',', '.'));
    final v = double.tryParse(parts[1].replaceAll(',', '.'));
    if (m == null || v == null) continue;
    machs.add(m);
    iNodes.add(math.max(v, 1e-6));
  }
  if (machs.length < 2) return null;
  final order = List<int>.generate(machs.length, (i) => i);
  order.sort((a, b) => machs[a].compareTo(machs[b]));
  return (
    machs: [for (final i in order) machs[i]],
    iNodes: [for (final i in order) iNodes[i]],
  );
}
