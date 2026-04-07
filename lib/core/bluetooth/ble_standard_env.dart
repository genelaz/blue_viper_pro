import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Standart BLE Çevresel / özel ölçü UUID’leri (16-bit kısa biçim eşleşmesi).
class BleEnvReading {
  final double? temperatureC;
  final double? humidityPercent;
  final double? pressureHpa;

  const BleEnvReading({
    this.temperatureC,
    this.humidityPercent,
    this.pressureHpa,
  });

  bool get isEmpty =>
      temperatureC == null && humidityPercent == null && pressureHpa == null;
}

class _Acc {
  double? t;
  double? h;
  double? p;

  void takeT(double v) => t ??= v;
  void takeH(double v) => h ??= v;
  void takeP(double v) => p ??= v;

  BleEnvReading get reading =>
      BleEnvReading(temperatureC: t, humidityPercent: h, pressureHpa: p);
}

bool _uuidHas(String u, String short16) {
  final s = u.toLowerCase().replaceAll('-', '');
  final tail = short16.toLowerCase().replaceAll('-', '');
  return s.endsWith(tail.padLeft(8, '0')) || s.contains(short16.toLowerCase());
}

double? _readFloatLe(Uint8List bytes, [int offset = 0]) {
  if (bytes.length < offset + 4) return null;
  final bd = ByteData.sublistView(bytes, offset, offset + 4);
  return bd.getFloat32(0, Endian.little);
}

double? _readInt16Centideg(Uint8List bytes) {
  if (bytes.length < 2) return null;
  final bd = ByteData.sublistView(bytes, 0, 2);
  return bd.getInt16(0, Endian.little) / 100.0;
}

double? _readUint16Centi(Uint8List bytes) {
  if (bytes.length < 2) return null;
  final bd = ByteData.sublistView(bytes, 0, 2);
  return bd.getUint16(0, Endian.little) / 100.0;
}

void _heuristicBytes(Uint8List bytes, _Acc acc) {
  if (bytes.length >= 2) {
    final cT = _readInt16Centideg(bytes);
    if (cT != null && cT > -55 && cT < 70) acc.takeT(cT);
    final cH = _readUint16Centi(bytes);
    if (cH != null && cH >= 0 && cH <= 100) acc.takeH(cH);
  }
  if (bytes.length >= 4) {
    final f = _readFloatLe(bytes);
    if (f != null) {
      if (f > -50 && f < 65) acc.takeT(f);
      if (f >= 0 && f <= 100) acc.takeH(f);
      if (f > 800 && f < 1100) acc.takeP(f);
      if (f > 80000 && f < 110000) acc.takeP(f / 100);
    }
  }
}

/// GATT okuma: BLE-SIG çevresel UUID + bilinmeyen karakteristiklerde sezgisel ayrıştırma (Kestrel vb.).
Future<BleEnvReading> readStandardEnvironmental(BluetoothDevice device) async {
  final acc = _Acc();

  final services = await device.discoverServices();
  for (final s in services) {
    for (final c in s.characteristics) {
      final u = c.uuid.toString();
      try {
        if (!c.properties.read) continue;
        final bytes = Uint8List.fromList(await c.read());
        if (bytes.isEmpty) continue;

        if (_uuidHas(u, '2a6e')) {
          final v = _readInt16Centideg(bytes);
          if (v != null) acc.takeT(v);
        } else if (_uuidHas(u, '2a6f')) {
          final v = _readUint16Centi(bytes);
          if (v != null) acc.takeH(v);
        } else if (_uuidHas(u, '2a6d')) {
          if (bytes.length >= 4) {
            var pv = _readFloatLe(bytes);
            if (pv != null && pv < 500) pv = pv * 100;
            if (pv != null) acc.takeP(pv);
          }
        } else {
          _heuristicBytes(bytes, acc);
        }
      } catch (_) {}
    }
  }
  return acc.reading;
}
