import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Nordic UART Service (LiNK / bazı çevre cihazlarında metin dökümü).
Future<String?> sniffNordicUartText(
  BluetoothDevice device, {
  Duration listenFor = const Duration(seconds: 2),
}) async {
  BluetoothCharacteristic? tx;
  final services = await device.discoverServices();
  for (final s in services) {
    final su = s.uuid.toString().toLowerCase().replaceAll('-', '');
    if (!su.contains('6e400001')) continue;
    for (final c in s.characteristics) {
      final cu = c.uuid.toString().toLowerCase().replaceAll('-', '');
      if (cu.contains('6e400003') && c.properties.notify) {
        tx = c;
        break;
      }
    }
    if (tx != null) break;
  }
  if (tx == null) return null;

  final buf = StringBuffer();
  late StreamSubscription<List<int>> sub;
  sub = tx.onValueReceived.listen((v) {
    if (v.isEmpty) return;
    try {
      buf.write(String.fromCharCodes(v));
    } catch (_) {}
  });
  try {
    await tx.setNotifyValue(true);
    await Future<void>.delayed(listenFor);
    await tx.setNotifyValue(false);
  } finally {
    await sub.cancel();
  }
  final out = buf.toString().trim();
  return out.isEmpty ? null : out;
}
