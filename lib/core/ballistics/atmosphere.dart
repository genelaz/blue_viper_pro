import 'dart:math' as math;

import 'g1_drag.dart' show speedOfSoundDryAirMps, icaoSeaLevelDensity;

/// Buck (1981) doygun su buharı basıncı (Pa), T °C.
double _saturationVaporPressurePa(double tempC) {
  final t = tempC.clamp(-80.0, 60.0);
  return 611.21 * math.exp((18.678 - t / 234.5) * (t / (257.14 + t)));
}

/// RH % ve sıcaklıkta buhar basıncı (Pa).
double vaporPressurePa(double tempC, double relativeHumidityPercent) {
  final rh = relativeHumidityPercent.clamp(0.0, 100.0) / 100.0;
  return rh * _saturationVaporPressurePa(tempC);
}

/// Nemli hava yoğunluğu (kg/m³). Basınç Pa, sıcaklık K.
double humidAirDensityKgPerM3({
  required double pressurePa,
  required double tempK,
  required double relativeHumidityPercent,
}) {
  const rd = 287.05;
  const rv = 461.495;
  final tC = tempK - 273.15;
  final e = vaporPressurePa(tC, relativeHumidityPercent);
  final pd = (pressurePa - e).clamp(100.0, pressurePa);
  return pd / (rd * tempK) + e / (rv * tempK);
}

/// ICAO standart atmosfer: rakıma göre basınç (Pa), 0–11 km.
double isaPressureAtAltitudeMeters(double altitudeM) {
  const p0 = 101325.0;
  const t0 = 288.15;
  const l = 0.0065;
  const g = 9.80665;
  const r = 287.05;
  final h = altitudeM.clamp(-500.0, 11000.0);
  final t = t0 - l * h;
  if (t <= 0) return p0 * 0.01;
  return p0 * math.pow(t / t0, g / (r * l));
}

/// ICAO standart sıcaklık (K) verilen rakımda (deniz seviyesi referans).
double isaTemperatureKAtAltitudeMeters(double altitudeM) {
  const t0 = 288.15;
  const l = 0.0065;
  return (t0 - l * altitudeM.clamp(-500.0, 11000.0)).clamp(200.0, 320.0);
}

/// Atmosfer girdilerinden yoğunluk oranı ρ/ρ₀ (ρ₀ = 1.225 ICAO deniz seviyesi).
double densityRatioFromAtmosphere({
  required double temperatureC,
  required double pressureHpa,
  required double relativeHumidityPercent,
  double? densityAltitudeMeters,
}) {
  final tempK = temperatureC + 273.15;
  double pPa = pressureHpa * 100.0;
  if (densityAltitudeMeters != null && densityAltitudeMeters.abs() > 1e-3) {
    pPa = isaPressureAtAltitudeMeters(densityAltitudeMeters);
  }
  final rho = humidAirDensityKgPerM3(
    pressurePa: pPa,
    tempK: tempK,
    relativeHumidityPercent: relativeHumidityPercent,
  );
  return (rho / icaoSeaLevelDensity).clamp(0.25, 1.55);
}

double soundSpeedForSolve(double temperatureC) => speedOfSoundDryAirMps(temperatureC);
