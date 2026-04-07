/// StreLok tarzı katalog girdisi: vektör/parametrik çizim (PNG kopyası değil).
class ReticleDefinition {
  final String id;
  final String name;
  final String manufacturer;
  /// `mil` veya `moa`
  final String unit;
  final bool defaultFfp;
  /// `mil_dot` | `hash` | `tree` | `duplex` | `german_4`
  final String pattern;
  final double majorStep;
  final double minorStep;
  /// Ağaç / mil-dot için yarıçap (birim cinsinden).
  final double visibleRadiusUnits;
  final int? treeLevels;
  final int? windDotsPerSide;
  final int? milDotCount;

  const ReticleDefinition({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.unit,
    this.defaultFfp = true,
    required this.pattern,
    this.majorStep = 1.0,
    this.minorStep = 0.2,
    this.visibleRadiusUnits = 6.0,
    this.treeLevels,
    this.windDotsPerSide,
    this.milDotCount,
  });

  factory ReticleDefinition.fromMap(Map<String, dynamic> m) {
    return ReticleDefinition(
      id: m['id'] as String,
      name: m['name'] as String,
      manufacturer: m['manufacturer'] as String? ?? '',
      unit: m['unit'] as String? ?? 'mil',
      defaultFfp: m['defaultFfp'] as bool? ?? true,
      pattern: m['pattern'] as String? ?? 'hash',
      majorStep: (m['majorStep'] as num?)?.toDouble() ?? 1.0,
      minorStep: (m['minorStep'] as num?)?.toDouble() ?? 0.2,
      visibleRadiusUnits: (m['visibleRadiusUnits'] as num?)?.toDouble() ?? 6.0,
      treeLevels: (m['treeLevels'] as num?)?.toInt(),
      windDotsPerSide: (m['windDotsPerSide'] as num?)?.toInt(),
      milDotCount: (m['milDotCount'] as num?)?.toInt(),
    );
  }
}
