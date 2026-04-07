import 'package:coordinate_converter/coordinate_converter.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

import 'sk42_turkey_grid.dart';
import 'wgs84_utm_epsg.dart';

/// WGS84: DD, DMS, UTM, MGRS metinleri.
class GeoFormatters {
  static String decimalDegrees(LatLng p) =>
      '${p.latitude.toStringAsFixed(6)}°, ${p.longitude.toStringAsFixed(6)}°';

  static String dmsHuman(LatLng p) {
    try {
      final d = DDCoordinates(latitude: p.latitude, longitude: p.longitude);
      final m = d.toDMS();
      final latH = m.latDirection.abbreviation;
      final lonH = m.longDirection.abbreviation;
      return '${m.latDegrees}° ${m.latMinutes}\' ${m.latSeconds.toStringAsFixed(2)}" $latH  ·  '
          '${m.longDegrees}° ${m.longMinutes}\' ${m.longSeconds.toStringAsFixed(2)}" $lonH';
    } catch (_) {
      return 'DMS —';
    }
  }

  static String utmWgs84(LatLng p) {
    try {
      final u = UTMCoordinates.fromDD(
        DDCoordinates(latitude: p.latitude, longitude: p.longitude),
      );
      final hemi = u.isSouthernHemisphere ? 'G' : 'K';
      return 'UTM Zon ${u.zoneNumber} ($hemi)  E${u.x.toStringAsFixed(1)}  N${u.y.toStringAsFixed(1)}';
    } catch (_) {
      return 'UTM —';
    }
  }

  /// WGS 84 / UTM **kuzey** + **EPSG** (proj4; ME tipik zonlar 35–41N).
  static String utmWgs84EpsgLine(LatLng p, {int? zoneOverride}) {
    try {
      final z = zoneOverride ?? Wgs84UtmNorth.autoZoneFromLongitude(p.longitude);
      if (z < 1 || z > 60) return 'UTM EPSG —';
      final epsg = Wgs84UtmNorth.epsgCode(z);
      final (e, n) = Wgs84UtmNorth.toUtm(p, z);
      final me = Wgs84UtmNorth.middleEastZones.contains(z) ? ' · Orta Doğu dilimi' : '';
      return 'EPSG:$epsg (WGS 84 / UTM ${z}N)$me · E ${e.toStringAsFixed(1)} · N ${n.toStringAsFixed(1)}';
    } catch (_) {
      return 'UTM EPSG —';
    }
  }

  static String mgrs(LatLng p) {
    try {
      return Mgrs.forward([p.longitude, p.latitude], 5);
    } catch (_) {
      return 'MGRS —';
    }
  }

  /// MGRS aralıklı (ör. `36STG 89641 81534`) — 5 m hassasiyet.
  static String mgrsSpaced(LatLng p) {
    try {
      final raw = Mgrs.forward([p.longitude, p.latitude], 5).replaceAll(RegExp(r'\s+'), '');
      if (raw.length >= 15) {
        return '${raw.substring(0, 5)} ${raw.substring(5, 10)} ${raw.substring(10, 15)}';
      }
      if (raw.length >= 10) {
        return '${raw.substring(0, 5)} ${raw.substring(5)}';
      }
      return raw;
    } catch (_) {
      return 'MGRS —';
    }
  }

  /// Tek satır: `36N 289641 4181534` (WGS84 / UTM kuzey; N = kuzey yarım).
  static String utmCompactEastingNorthing(LatLng p, {int? zoneOverride}) {
    try {
      final z = zoneOverride ?? Wgs84UtmNorth.autoZoneFromLongitude(p.longitude);
      final (e, n) = Wgs84UtmNorth.toUtm(p, z);
      final hemi = p.latitude >= 0 ? 'N' : 'S';
      return '$z$hemi ${e.round()} ${n.round()}';
    } catch (_) {
      return 'UTM —';
    }
  }

  /// SK-42 / Pulkovo TM (3° dilim, λ₀ seçilebilir; verilmezse otomatik).
  static String sk42GridLine(LatLng p, {int? centralMeridian}) {
    try {
      final cm = centralMeridian ?? Sk42TurkeyGrid.pickMeridian(p.longitude);
      final (e, n) = Sk42TurkeyGrid.wgs84ToGrid(p, cm);
      return 'SK-42 TM · λ₀=$cm° · E ${e.toStringAsFixed(1)} m · N ${n.toStringAsFixed(1)} m';
    } catch (_) {
      return 'SK-42 —';
    }
  }

  /// MGRS grid — bbox ortası.
  static LatLng? tryParseMgrs(String raw) {
    final s = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (s.length < 3) return null;
    try {
      final b = Mgrs.inverse(s);
      if (b.length >= 4) {
        final lon = (b[0] + b[2]) / 2;
        final lat = (b[1] + b[3]) / 2;
        return LatLng(lat, lon);
      }
    } catch (_) {}
    return null;
  }
}
