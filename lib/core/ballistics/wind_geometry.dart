import 'dart:math' as math;

/// [windFromNorthDeg]: meteorolojik “nereden esiyor” (0=kuzey, saat yönü).
/// [shotAzimuthFromNorthDeg]: atış yönü.
/// Dönüş: yan bileşen (+ = mermiyi sağa iter).
double crossWindMpsFromMetWind({
  required double windSpeedMps,
  required double windFromNorthDeg,
  required double shotAzimuthFromNorthDeg,
}) {
  final rad = (windFromNorthDeg - shotAzimuthFromNorthDeg) * math.pi / 180.0;
  return windSpeedMps * math.sin(rad);
}
