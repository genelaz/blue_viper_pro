/// G1 BC (lb/in²) için kabaca G7 BC tahmini — katalogda ayrı G7 yoksa kullanılır.
double estimateG7FromG1(double g1) {
  if (g1 < 0.28) return (g1 * 0.58).clamp(0.12, 0.22);
  if (g1 < 0.42) return (g1 * 0.50).clamp(0.17, 0.24);
  if (g1 < 0.55) return (g1 * 0.52).clamp(0.20, 0.30);
  if (g1 < 0.72) return (g1 * 0.48).clamp(0.28, 0.38);
  return (g1 * 0.36).clamp(0.30, 0.45);
}

/// G7→G1 kabaca ters ölçek — profilde yalnızca G7 kaydı varken G1 yuvasını doldurmak için.
double estimateG1FromG7Rough(double g7) => (g7 / 0.50).clamp(0.22, 0.95);
