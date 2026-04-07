import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Aktivasyon bağlamak için cihaza göre mümkün olduğunca sabit kimlik.
Future<String> getDeviceActivationId() async {
  final plugin = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final a = await plugin.androidInfo;
      return a.id;
    }
    if (Platform.isIOS) {
      final i = await plugin.iosInfo;
      return i.identifierForVendor ?? 'ios_unknown';
    }
  } catch (_) {
    return 'unknown';
  }
  return 'unsupported';
}
