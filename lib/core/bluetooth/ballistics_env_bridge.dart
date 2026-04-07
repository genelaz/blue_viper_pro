import 'package:flutter/foundation.dart';

import 'ble_standard_env.dart';

/// Kestrel / BLE ortam okuması → Balistik sekmesi forma aktarımı.
class BallisticsEnvBridge {
  BallisticsEnvBridge._();

  static final ValueNotifier<BleEnvReading?> pending = ValueNotifier<BleEnvReading?>(null);

  /// Boş okuma gönderilmez.
  static void offer(BleEnvReading r) {
    if (r.isEmpty) return;
    pending.value = r;
  }
}
