import 'package:blue_viper_pro/core/geo/simple_los.dart'
    show
        analyzeSimpleLos,
        kLosDemSegmentsMax,
        kLosDemSegmentsMin,
        losFirstBlockApproxPosition,
        losSegmentsForMap;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('analyzeSimpleLos flat terrain remains clear', () async {
    Future<double?> flat(LatLng p) async => 50.0;
    final r = await analyzeSimpleLos(
      observer: const LatLng(0, 0),
      target: const LatLng(0, 0.02),
      observerAntennaM: 2,
      targetHeightM: 0,
      segments: 8,
      dem: flat,
    );
    expect(r.clearLineOfSight, isTrue);
    expect(r.blockedNearM, isNull);
    expect(r.samples.length, 9);
  });

  test('analyzeSimpleLos ridge above LOS triggers block', () async {
    const obs = LatLng(0, 0);
    const tgt = LatLng(0, 0.02);
    Future<double?> dem(LatLng p) async {
      final onObs = (p.latitude - obs.latitude).abs() < 1e-9 && (p.longitude - obs.longitude).abs() < 1e-9;
      final onTgt = (p.latitude - tgt.latitude).abs() < 1e-9 && (p.longitude - tgt.longitude).abs() < 1e-9;
      if (onObs || onTgt) return 100;
      return 400;
    }
    final r = await analyzeSimpleLos(
      observer: obs,
      target: tgt,
      observerAntennaM: 2,
      targetHeightM: 0,
      segments: 20,
      dem: dem,
    );
    expect(r.clearLineOfSight, isFalse);
    expect(r.blockedNearM, isNotNull);
  });

  test('analyzeSimpleLos higher target clears shallow ridge', () async {
    const obs = LatLng(0, 0);
    const tgt = LatLng(0, 0.02);
    Future<double?> dem(LatLng p) async {
      final onObs = (p.latitude - obs.latitude).abs() < 1e-9 && (p.longitude - obs.longitude).abs() < 1e-9;
      final onTgt = (p.latitude - tgt.latitude).abs() < 1e-9 && (p.longitude - tgt.longitude).abs() < 1e-9;
      if (onObs || onTgt) return 100;
      final t = (p.longitude - obs.longitude) / (tgt.longitude - obs.longitude);
      if (t > 0.38 && t < 0.62) return 126;
      return 100;
    }
    final low = await analyzeSimpleLos(
      observer: obs,
      target: tgt,
      observerAntennaM: 2,
      targetHeightM: 0,
      segments: 16,
      dem: dem,
    );
    final high = await analyzeSimpleLos(
      observer: obs,
      target: tgt,
      observerAntennaM: 2,
      targetHeightM: 80,
      segments: 16,
      dem: dem,
    );
    expect(low.clearLineOfSight, isFalse);
    expect(high.clearLineOfSight, isTrue);
  });

  test('losSegmentsForMap splits colors along ridge', () async {
    const obs = LatLng(0, 0);
    const tgt = LatLng(0, 0.02);
    Future<double?> dem(LatLng p) async {
      final onObs = (p.latitude - obs.latitude).abs() < 1e-9 && (p.longitude - obs.longitude).abs() < 1e-9;
      final onTgt = (p.latitude - tgt.latitude).abs() < 1e-9 && (p.longitude - tgt.longitude).abs() < 1e-9;
      if (onObs || onTgt) return 100;
      return 400;
    }
    final r = await analyzeSimpleLos(
      observer: obs,
      target: tgt,
      observerAntennaM: 2,
      targetHeightM: 0,
      segments: 10,
      dem: dem,
    );
    final segs = losSegmentsForMap(obs, tgt, r);
    expect(segs.length, r.samples.length - 1);
    expect(segs.any((s) => s.blocked), isTrue);
    final blk = losFirstBlockApproxPosition(obs, tgt, r);
    expect(blk, isNotNull);
  });

  test('analyzeSimpleLos clamps extreme segment count', () async {
    Future<double?> flat(LatLng p) async => 10.0;
    final huge = await analyzeSimpleLos(
      observer: const LatLng(0, 0),
      target: const LatLng(0, 0.02),
      segments: 999,
      dem: flat,
    );
    expect(huge.samples.length, kLosDemSegmentsMax + 1);
    final tiny = await analyzeSimpleLos(
      observer: const LatLng(0, 0),
      target: const LatLng(0, 0.02),
      segments: 1,
      dem: flat,
    );
    expect(tiny.samples.length, kLosDemSegmentsMin + 1);
  });
}
