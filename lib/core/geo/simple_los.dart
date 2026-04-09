import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// DEM örnekleri ile basit yüzey görüşü (düz dünya, eğri yükseklik profili).
class SimpleLosSample {
  const SimpleLosSample({
    required this.distanceFromObserverM,
    required this.elevationM,
    required this.lineOfSightHeightM,
  });

  final double distanceFromObserverM;
  final double elevationM;
  final double lineOfSightHeightM;
}

class SimpleLosResult {
  const SimpleLosResult({
    required this.clearLineOfSight,
    required this.samples,
    this.blockedNearM,
  });

  final bool clearLineOfSight;
  final List<SimpleLosSample> samples;
  /// Görüşü kesen ilk örnek mesafesi (gözleyiciden).
  final double? blockedNearM;
}

/// [observer] ve [target] arasında [segments] parçaya bölünüp [dem] ile karşılaştırılır.
Future<SimpleLosResult> analyzeSimpleLos({
  required LatLng observer,
  required LatLng target,
  double observerAntennaM = 1.8,
  double targetHeightM = 0,
  int segments = 14,
  required Future<double?> Function(LatLng p) dem,
}) async {
  final totalM = Geolocator.distanceBetween(
    observer.latitude,
    observer.longitude,
    target.latitude,
    target.longitude,
  );
  if (totalM < 2) {
    return const SimpleLosResult(clearLineOfSight: true, samples: []);
  }
  final obsElev = await dem(observer);
  final tgtElev = await dem(target);
  if (obsElev == null || tgtElev == null) {
    return SimpleLosResult(
      clearLineOfSight: false,
      samples: const [],
      blockedNearM: null,
    );
  }
  final h0 = obsElev + observerAntennaM;
  final h1 = tgtElev + targetHeightM;
  final samples = <SimpleLosSample>[];
  double? blocked;
  for (var i = 0; i <= segments; i++) {
    final t = i / segments;
    final lat = observer.latitude + (target.latitude - observer.latitude) * t;
    final lon = observer.longitude + (target.longitude - observer.longitude) * t;
    final p = LatLng(lat, lon);
    final d = totalM * t;
    final el = i == 0 ? obsElev : i == segments ? tgtElev : await dem(p);
    if (el == null) continue;
    final losH = h0 + (h1 - h0) * t;
    samples.add(SimpleLosSample(distanceFromObserverM: d, elevationM: el, lineOfSightHeightM: losH));
    if (i > 0 && i < segments && el > losH + 2.0) {
      blocked ??= d;
    }
  }
  final clear = blocked == null;
  return SimpleLosResult(
    clearLineOfSight: clear,
    samples: samples,
    blockedNearM: blocked,
  );
}
