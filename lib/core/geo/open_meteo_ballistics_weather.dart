import 'dart:convert';

import 'package:http/http.dart' as http;

/// Open-Meteo «current» — balistik forma sıcaklık / nem / basınç (hPa).
class OpenMeteoCurrentWeather {
  const OpenMeteoCurrentWeather({
    required this.temperatureC,
    required this.relativeHumidityPercent,
    required this.pressureHpa,
  });

  final double temperatureC;
  final double relativeHumidityPercent;
  final double pressureHpa;
}

/// Ağ yokken test için: Open-Meteo `v1/forecast` JSON gövdesinden [current] alanını okur.
OpenMeteoCurrentWeather? parseOpenMeteoCurrentFromForecastJson(
  Map<String, dynamic> map,
) {
  final cur = map['current'] as Map<String, dynamic>?;
  if (cur == null) return null;
  final t = (cur['temperature_2m'] as num?)?.toDouble();
  final rh = (cur['relative_humidity_2m'] as num?)?.toDouble();
  final p = (cur['surface_pressure'] as num?)?.toDouble();
  if (t == null || rh == null || p == null) return null;
  return OpenMeteoCurrentWeather(
    temperatureC: t,
    relativeHumidityPercent: rh,
    pressureHpa: p,
  );
}

/// [latitudeDeg] / [longitudeDeg] WGS84.
Future<OpenMeteoCurrentWeather?> fetchOpenMeteoCurrent({
  required double latitudeDeg,
  required double longitudeDeg,
}) async {
  final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': latitudeDeg.toString(),
    'longitude': longitudeDeg.toString(),
    'current': 'temperature_2m,relative_humidity_2m,surface_pressure',
    'timezone': 'auto',
  });
  final res = await http.get(uri).timeout(const Duration(seconds: 12));
  if (res.statusCode < 200 || res.statusCode >= 300) return null;
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return parseOpenMeteoCurrentFromForecastJson(map);
}
