import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Ara DEM örneklemesi için alt/üst sınır (`analyzeSimpleLos` içinde [segments] buna sıkıştırılır).
const int kLosDemSegmentsMin = 6;
const int kLosDemSegmentsMax = 56;

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
  final seg = segments.clamp(kLosDemSegmentsMin, kLosDemSegmentsMax);
  final h0 = obsElev + observerAntennaM;
  final h1 = tgtElev + targetHeightM;
  final samples = <SimpleLosSample>[];
  double? blocked;
  for (var i = 0; i <= seg; i++) {
    final t = i / seg;
    final lat = observer.latitude + (target.latitude - observer.latitude) * t;
    final lon = observer.longitude + (target.longitude - observer.longitude) * t;
    final p = LatLng(lat, lon);
    final d = totalM * t;
    final el = i == 0 ? obsElev : i == segments ? tgtElev : await dem(p);
    if (el == null) continue;
    final losH = h0 + (h1 - h0) * t;
    samples.add(SimpleLosSample(distanceFromObserverM: d, elevationM: el, lineOfSightHeightM: losH));
    if (i > 0 && i < seg && el > losH + 2.0) {
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

/// [samples] üzerinde segment [segmentStartIndex] → [segmentStartIndex+1]; engel kuralı `analyzeSimpleLos` ile aynı (+2 m, uç örnekler hariç).
bool losSegmentBlocked(List<SimpleLosSample> samples, int segmentStartIndex) {
  if (samples.length < 2) return false;
  bool interiorObstructs(int k) =>
      k > 0 &&
      k < samples.length - 1 &&
      samples[k].elevationM > samples[k].lineOfSightHeightM + 2.0;

  final i = segmentStartIndex;
  if (i < 0 || i >= samples.length - 1) return false;
  return interiorObstructs(i) || interiorObstructs(i + 1);
}

/// Örneklerin [distanceFromObserverM] değerlerine göre gözlem–hedef doğrusunda konum (WGS84 doğrusal enterpolasyon).
List<LatLng> losSamplePositions(LatLng observer, LatLng target, List<SimpleLosSample> samples) {
  if (samples.isEmpty) return [observer, target];
  final total = samples.last.distanceFromObserverM;
  if (total < 1) return [observer, target];
  return [
    for (final s in samples)
      LatLng(
        observer.latitude + (target.latitude - observer.latitude) * (s.distanceFromObserverM / total),
        observer.longitude + (target.longitude - observer.longitude) * (s.distanceFromObserverM / total),
      ),
  ];
}

/// Haritada ayrı renkli çizgiler: her öğe iki noktalı bir segment ve engel durumu.
List<({List<LatLng> points, bool blocked})> losSegmentsForMap(
  LatLng observer,
  LatLng target,
  SimpleLosResult result,
) {
  if (result.samples.length < 2) return const [];
  final pts = losSamplePositions(observer, target, result.samples);
  final out = <({List<LatLng> points, bool blocked})>[];
  for (var i = 0; i < pts.length - 1; i++) {
    out.add((
      points: [pts[i], pts[i + 1]],
      blocked: losSegmentBlocked(result.samples, i),
    ));
  }
  return out;
}

/// İlk DEM engeline yaklaşık konum (gözlem–hedef doğrusunda); [result.blockedNearM] ile.
LatLng? losFirstBlockApproxPosition(LatLng observer, LatLng target, SimpleLosResult result) {
  final dBlk = result.blockedNearM;
  if (dBlk == null || result.samples.length < 2) return null;
  final total = result.samples.last.distanceFromObserverM;
  if (total < 1) return null;
  final t = (dBlk.clamp(0.0, total)) / total;
  return LatLng(
    observer.latitude + (target.latitude - observer.latitude) * t,
    observer.longitude + (target.longitude - observer.longitude) * t,
  );
}
