import 'package:shared_preferences/shared_preferences.dart';

/// İlk açılışta konum / izin tanıtım ekranının gösterilip gösterilmeyeceği.
class AppBootstrapPrefs {
  static const _key = 'app_permissions_intro_done_v1';

  static Future<bool> isIntroDone() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key) ?? false;
  }

  static Future<void> setIntroDone() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
  }
}
