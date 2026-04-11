import 'package:shared_preferences/shared_preferences.dart';

/// StreLok tarzı: hava istasyonu / rüzgarölçer cihaz türü + kayıtlı BLE uzak kimlik.
abstract final class BleDevicePrefs {
  BleDevicePrefs._();

  static const _kWeatherKind = 'ble_weather_device_kind_v1';
  static const _kWeatherId = 'ble_weather_device_id_v1';
  static const _kWindKind = 'ble_wind_device_kind_v1';
  static const _kWindId = 'ble_wind_device_id_v1';

  static const weatherKinds = <String>[
    'kestrel_5500_5700',
    'kestrel_drop',
    'weatherflow',
    'other',
  ];

  static const windKinds = <String>[
    'calypso_ultrasonic',
    'other',
  ];

  static Future<String> weatherKind() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kWeatherKind) ?? weatherKinds.first;
  }

  static Future<void> setWeatherKind(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kWeatherKind, v);
  }

  static Future<String?> weatherDeviceId() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kWeatherId);
    if (s == null || s.trim().isEmpty) return null;
    return s.trim();
  }

  static Future<void> setWeatherDeviceId(String? id) async {
    final p = await SharedPreferences.getInstance();
    if (id == null || id.trim().isEmpty) {
      await p.remove(_kWeatherId);
    } else {
      await p.setString(_kWeatherId, id.trim());
    }
  }

  static Future<String> windKind() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kWindKind) ?? windKinds.first;
  }

  static Future<void> setWindKind(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kWindKind, v);
  }

  static Future<String?> windDeviceId() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kWindId);
    if (s == null || s.trim().isEmpty) return null;
    return s.trim();
  }

  static Future<void> setWindDeviceId(String? id) async {
    final p = await SharedPreferences.getInstance();
    if (id == null || id.trim().isEmpty) {
      await p.remove(_kWindId);
    } else {
      await p.setString(_kWindId, id.trim());
    }
  }

  static String weatherKindLabel(String key) => switch (key) {
        'kestrel_5500_5700' => 'Kestrel 5500/5700',
        'kestrel_drop' => 'Kestrel Drop',
        'weatherflow' => 'Weatherflow WEATHERmeter',
        _ => 'Diğer',
      };

  static String windKindLabel(String key) => switch (key) {
        'calypso_ultrasonic' => 'Calypso Ultrasonic',
        _ => 'Diğer',
      };
}
