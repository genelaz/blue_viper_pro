import 'package:shared_preferences/shared_preferences.dart';

/// Cihazda kalıcı aktivasyon. Uzak modda [storedDeviceId] bu telefonla eşleşmeli.
class ActivationStore {
  static const _keyOk = 'activation_ok_v1';
  static const _keyDeviceId = 'activation_device_id_v1';
  static const _keyRemote = 'activation_remote_v1';

  static Future<bool> isActivated() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyOk) ?? false;
  }

  static Future<String?> storedDeviceId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyDeviceId);
  }

  static Future<bool> usedRemoteBinding() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyRemote) ?? false;
  }

  /// Eski: yalnızca yerel hash doğrulaması.
  static Future<void> markActivatedOffline({String? deviceId}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyOk, true);
    await p.setBool(_keyRemote, false);
    if (deviceId != null && deviceId.isNotEmpty) {
      await p.setString(_keyDeviceId, deviceId);
    }
  }

  /// Uzak sunucu onayı sonrası.
  static Future<void> markActivatedRemote({required String deviceId}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyOk, true);
    await p.setBool(_keyRemote, true);
    await p.setString(_keyDeviceId, deviceId);
  }

  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyOk);
    await p.remove(_keyDeviceId);
    await p.remove(_keyRemote);
  }
}
