import 'dart:convert';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// NTv2 `.gsb` grid (deneysel): `GS_TYPE` SECOND, alt ızgara sonundaki float32 çiftleri (lat/lon saniye).
class Ntv2GsbShift {
  Ntv2GsbShift._({
    required this.latCount,
    required this.lonCount,
    required this.southDeg,
    required this.westDeg,
    required this.latStepDeg,
    required this.lonStepDeg,
    required this.latShiftSec,
    required this.lonShiftSec,
  });

  final int latCount;
  final int lonCount;
  final double southDeg;
  final double westDeg;
  final double latStepDeg;
  final double lonStepDeg;
  final Float32List latShiftSec;
  final Float32List lonShiftSec;

  /// WGS84 enlem/boylamına kayma (saniye → derece eklenir; proj4 NTv2 eşleniği).
  LatLng shiftWgs84(LatLng wgs) {
    if (latCount < 2 || lonCount < 2) return wgs;
    final gx = (wgs.longitude - westDeg) / lonStepDeg;
    final gy = (wgs.latitude - southDeg) / latStepDeg;
    if (gx < 0 || gy < 0 || gx > lonCount - 1 || gy > latCount - 1) {
      return wgs;
    }
    final x0 = gx.floor();
    final y0 = gy.floor();
    final tx = gx - x0;
    final ty = gy - y0;
    double sample(Float32List g, int x, int y) => g[y * lonCount + x];
    final la = sample(latShiftSec, x0, y0) * (1 - tx) * (1 - ty) +
        sample(latShiftSec, (x0 + 1).clamp(0, lonCount - 1), y0) * tx * (1 - ty) +
        sample(latShiftSec, x0, (y0 + 1).clamp(0, latCount - 1)) * (1 - tx) * ty +
        sample(latShiftSec, (x0 + 1).clamp(0, lonCount - 1), (y0 + 1).clamp(0, latCount - 1)) *
            tx *
            ty;
    final lo = sample(lonShiftSec, x0, y0) * (1 - tx) * (1 - ty) +
        sample(lonShiftSec, (x0 + 1).clamp(0, lonCount - 1), y0) * tx * (1 - ty) +
        sample(lonShiftSec, x0, (y0 + 1).clamp(0, latCount - 1)) * (1 - tx) * ty +
        sample(lonShiftSec, (x0 + 1).clamp(0, lonCount - 1), (y0 + 1).clamp(0, latCount - 1)) *
            tx *
            ty;
    return LatLng(
      wgs.latitude + la / 3600.0,
      wgs.longitude + lo / 3600.0,
    );
  }

  static Ntv2GsbShift? tryParse(List<int> bytes) {
    if (bytes.length < 256) return null;
    final s = latin1.decode(bytes, allowInvalid: true);
    if (!s.contains('NTv2') && !s.contains('VERSION')) return null;
    final latCount = _intField(s, RegExp(r'LAT_COUNT\s+(\d+)')) ?? 0;
    final lonCount = _intField(s, RegExp(r'LONG_COUNT\s+(\d+)')) ?? 0;
    if (latCount < 2 || lonCount < 2) return null;
    final expected = latCount * lonCount * 8;
    if (bytes.length < expected) return null;
    final gridOff = bytes.length - expected;
    final sLatSec = _doubleField(s, RegExp(r'S_LAT\s+([+-]?[\d.]+(?:[eE][+-]?\d+)?)'));
    final nLatSec = _doubleField(s, RegExp(r'N_LAT\s+([+-]?[\d.]+(?:[eE][+-]?\d+)?)'));
    final wLongSec = _doubleField(s, RegExp(r'W_LONG\s+([+-]?[\d.]+(?:[eE][+-]?\d+)?)'));
    final eLongSec = _doubleField(s, RegExp(r'E_LONG\s+([+-]?[\d.]+(?:[eE][+-]?\d+)?)'));
    final latIncSec = _doubleField(s, RegExp(r'LAT_INC\s+([+-]?[\d.]+(?:[eE][+-]?\d+)?)'));
    final longIncSec = _doubleField(s, RegExp(r'LONG_INC\s+([+-]?[\d.]+(?:[eE][+-]?\d+)?)'));
    if (sLatSec == null ||
        nLatSec == null ||
        wLongSec == null ||
        eLongSec == null ||
        latIncSec == null ||
        longIncSec == null) {
      return null;
    }
    final southDeg = sLatSec / 3600.0;
    final westDeg = wLongSec / 3600.0;
    final latStepDeg = latIncSec / 3600.0;
    final lonStepDeg = longIncSec / 3600.0;
    final buf = Uint8List.fromList(bytes);
    final bd = ByteData.view(buf.buffer, buf.offsetInBytes + gridOff, expected);
    final n = latCount * lonCount;
    final latShift = Float32List(n);
    final lonShift = Float32List(n);
    for (var i = 0; i < n; i++) {
      latShift[i] = bd.getFloat32(i * 8, Endian.big);
      lonShift[i] = bd.getFloat32(i * 8 + 4, Endian.big);
    }
    return Ntv2GsbShift._(
      latCount: latCount,
      lonCount: lonCount,
      southDeg: southDeg,
      westDeg: westDeg,
      latStepDeg: latStepDeg,
      lonStepDeg: lonStepDeg,
      latShiftSec: latShift,
      lonShiftSec: lonShift,
    );
  }
}

int? _intField(String s, RegExp pattern) {
  final m = pattern.firstMatch(s);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

double? _doubleField(String s, RegExp pattern) {
  final m = pattern.firstMatch(s);
  if (m == null) return null;
  return double.tryParse(m.group(1)!);
}
