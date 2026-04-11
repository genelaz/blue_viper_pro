import 'package:blue_viper_pro/core/geo/open_meteo_ballistics_weather.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseOpenMeteoCurrentFromForecastJson ok', () {
    final w = parseOpenMeteoCurrentFromForecastJson({
      'current': {
        'temperature_2m': 12.5,
        'relative_humidity_2m': 60,
        'surface_pressure': 1013.2,
      },
    });
    expect(w, isNotNull);
    expect(w!.temperatureC, 12.5);
    expect(w.relativeHumidityPercent, 60);
    expect(w.pressureHpa, 1013.2);
  });

  test('parseOpenMeteoCurrentFromForecastJson null when missing current', () {
    expect(parseOpenMeteoCurrentFromForecastJson({}), isNull);
  });

  test('parseOpenMeteoCurrentFromForecastJson null when field missing', () {
    expect(
      parseOpenMeteoCurrentFromForecastJson({
        'current': {
          'temperature_2m': 1.0,
          'relative_humidity_2m': 50,
        },
      }),
      isNull,
    );
  });
}
