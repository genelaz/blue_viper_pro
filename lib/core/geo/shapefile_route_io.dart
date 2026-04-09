import 'dart:io';

import 'package:dart_jts/dart_jts.dart';
import 'package:dart_shp/dart_shp.dart';
import 'package:latlong2/latlong.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;

import 'shapefile_crs_io.dart';
import 'shapefile_route_result.dart';

Future<ShapefileRouteImportResult> importShapefileRoute(String shpPath) async {
  final hadPrj = shapefilePrjExistsAtShpPath(shpPath);
  final srcProj = tryProjectionFromShapefilePrj(shpPath);
  final prjStatus = !hadPrj
      ? ShapefilePrjStatus.absent
      : (srcProj != null ? ShapefilePrjStatus.applied : ShapefilePrjStatus.failed);

  final wgs = proj4.Projection.get('EPSG:4326')!;
  ShapefileFeatureReader? reader;
  try {
    reader = ShapefileFeatureReader(File(shpPath));
    await reader.open();
    final out = <LatLng>[];
    while (await reader.hasNext()) {
      final f = await reader.next();
      final g = f.geometry;
      if (g != null) {
        out.addAll(_geometryToLatLngs(g, srcProj, wgs));
      }
    }
    reader.close();
    if (out.isEmpty) {
      return ShapefileRouteImportResult(points: null, prjStatus: prjStatus);
    }
    return ShapefileRouteImportResult(points: out, prjStatus: prjStatus);
  } catch (_) {
    try {
      reader?.close();
    } catch (_) {}
    return ShapefileRouteImportResult(points: null, prjStatus: prjStatus);
  }
}

List<LatLng> _geometryToLatLngs(Geometry g, proj4.Projection? srcProj, proj4.Projection wgs) {
  final out = <LatLng>[];
  void addCoords(Iterable<Coordinate> coords) {
    for (final c in coords) {
      if (!c.x.isNaN && !c.y.isNaN) {
        out.add(_projectedCoordToLatLng(c.x, c.y, srcProj, wgs));
      }
    }
  }

  if (g is Point) {
    final c = g.getCoordinate();
    if (c != null) addCoords([c]);
  } else if (g is LineString) {
    addCoords(g.getCoordinates());
  } else if (g is Polygon) {
    addCoords(g.getExteriorRing().getCoordinates());
  } else if (g is MultiPoint) {
    for (var i = 0; i < g.getNumGeometries(); i++) {
      out.addAll(_geometryToLatLngs(g.getGeometryN(i), srcProj, wgs));
    }
  } else if (g is MultiLineString) {
    for (var i = 0; i < g.getNumGeometries(); i++) {
      out.addAll(_geometryToLatLngs(g.getGeometryN(i), srcProj, wgs));
    }
  } else if (g is MultiPolygon) {
    for (var i = 0; i < g.getNumGeometries(); i++) {
      out.addAll(_geometryToLatLngs(g.getGeometryN(i), srcProj, wgs));
    }
  } else if (g is GeometryCollection) {
    for (var i = 0; i < g.getNumGeometries(); i++) {
      out.addAll(_geometryToLatLngs(g.getGeometryN(i), srcProj, wgs));
    }
  }
  return out;
}

LatLng _projectedCoordToLatLng(double x, double y, proj4.Projection? srcProj, proj4.Projection wgs) {
  if (srcProj == null) {
    return LatLng(y, x);
  }
  try {
    final r = srcProj.transform(wgs, proj4.Point(x: x, y: y));
    if (r.x.isNaN || r.y.isNaN || r.x.abs() > 180.0 || r.y.abs() > 90.0) {
      return LatLng(y, x);
    }
    return LatLng(r.y, r.x);
  } catch (_) {
    return LatLng(y, x);
  }
}
