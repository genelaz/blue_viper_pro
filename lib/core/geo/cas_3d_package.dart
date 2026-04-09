import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class Cas3dThreatTube {
  const Cas3dThreatTube({
    required this.id,
    required this.observer,
    required this.target,
    required this.startHalfWidthM,
    required this.endHalfWidthM,
    this.minAltM,
    this.maxAltM,
  });

  final String id;
  final LatLng observer;
  final LatLng target;
  final double startHalfWidthM;
  final double endHalfWidthM;
  final double? minAltM;
  final double? maxAltM;
}

class Cas3dPackage {
  const Cas3dPackage({
    required this.name,
    required this.version,
    required this.threatTubes,
  });

  final String name;
  final String version;
  final List<Cas3dThreatTube> threatTubes;
}

Cas3dPackage parseCas3dPackageJson(String source) {
  final root = jsonDecode(source);
  if (root is! Map<String, dynamic>) {
    throw const FormatException('CAS 3B paket kökü JSON nesnesi olmalı.');
  }
  final name = (root['name'] as String?)?.trim();
  if (name == null || name.isEmpty) {
    throw const FormatException('CAS 3B paketinde "name" zorunlu.');
  }
  final version = ((root['version'] as String?)?.trim().isNotEmpty ?? false)
      ? (root['version'] as String).trim()
      : '1';
  final tubesRaw = root['threatTubes'];
  if (tubesRaw is! List) {
    throw const FormatException('CAS 3B paketinde "threatTubes" dizi olmalı.');
  }
  final tubes = <Cas3dThreatTube>[];
  for (var i = 0; i < tubesRaw.length; i++) {
    final e = tubesRaw[i];
    if (e is! Map<String, dynamic>) {
      throw FormatException('threatTubes[$i] nesne olmalı.');
    }
    final id = (e['id'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw FormatException('threatTubes[$i].id zorunlu.');
    }
    final observer = _latLngFromAny(e['observer'], path: 'threatTubes[$i].observer');
    final target = _latLngFromAny(e['target'], path: 'threatTubes[$i].target');
    final startHalfWidthM = _numRequired(e['startHalfWidthM'], 'threatTubes[$i].startHalfWidthM')
        .clamp(5.0, 1000.0);
    final endHalfWidthM =
        _numRequired(e['endHalfWidthM'], 'threatTubes[$i].endHalfWidthM').clamp(5.0, 1000.0);
    final minAltM = _numOptional(e['minAltM']);
    final maxAltM = _numOptional(e['maxAltM']);
    tubes.add(
      Cas3dThreatTube(
        id: id,
        observer: observer,
        target: target,
        startHalfWidthM: startHalfWidthM,
        endHalfWidthM: endHalfWidthM,
        minAltM: minAltM,
        maxAltM: maxAltM,
      ),
    );
  }
  return Cas3dPackage(name: name, version: version, threatTubes: tubes);
}

Future<Cas3dPackage> loadCas3dPackageFromPath(String path) async {
  final text = await File(path).readAsString();
  return parseCas3dPackageJson(text);
}

List<LatLng> casThreatTubeFootprint(Cas3dThreatTube tube) {
  final meanLat = (tube.observer.latitude + tube.target.latitude) * 0.5;
  final cosLat = math.cos(meanLat * math.pi / 180).abs().clamp(0.1, 1.0);
  const metersPerDegLat = 111320.0;
  final north = (tube.target.latitude - tube.observer.latitude) * metersPerDegLat;
  final east = (tube.target.longitude - tube.observer.longitude) * metersPerDegLat * cosLat;
  final len = math.sqrt(east * east + north * north);
  if (len < 1) return const [];
  final dirEast = east / len;
  final dirNorth = north / len;
  final nLeftEast = -dirNorth;
  final nLeftNorth = dirEast;
  final nRightEast = -nLeftEast;
  final nRightNorth = -nLeftNorth;
  final aLeft = _offsetByMeters(
    tube.observer,
    eastM: nLeftEast * tube.startHalfWidthM,
    northM: nLeftNorth * tube.startHalfWidthM,
  );
  final bLeft = _offsetByMeters(
    tube.target,
    eastM: nLeftEast * tube.endHalfWidthM,
    northM: nLeftNorth * tube.endHalfWidthM,
  );
  final bRight = _offsetByMeters(
    tube.target,
    eastM: nRightEast * tube.endHalfWidthM,
    northM: nRightNorth * tube.endHalfWidthM,
  );
  final aRight = _offsetByMeters(
    tube.observer,
    eastM: nRightEast * tube.startHalfWidthM,
    northM: nRightNorth * tube.startHalfWidthM,
  );
  return [aLeft, bLeft, bRight, aRight];
}

LatLng _offsetByMeters(LatLng origin, {required double eastM, required double northM}) {
  const metersPerDegLat = 111320.0;
  final dLat = northM / metersPerDegLat;
  final cosLat = math.cos(origin.latitude * math.pi / 180).abs().clamp(0.1, 1.0);
  final dLon = eastM / (metersPerDegLat * cosLat);
  return LatLng(origin.latitude + dLat, origin.longitude + dLon);
}

LatLng _latLngFromAny(Object? raw, {required String path}) {
  if (raw is! Map<String, dynamic>) {
    throw FormatException('$path nesne olmalı.');
  }
  final lat = _numRequired(raw['lat'], '$path.lat');
  final lon = _numRequired(raw['lon'], '$path.lon');
  return LatLng(lat, lon);
}

double _numRequired(Object? raw, String path) {
  if (raw is num) return raw.toDouble();
  throw FormatException('$path sayı olmalı.');
}

double? _numOptional(Object? raw) => raw is num ? raw.toDouble() : null;
