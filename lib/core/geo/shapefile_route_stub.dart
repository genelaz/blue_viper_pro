import 'shapefile_route_result.dart';

/// Web / IO olmayan platformlarda shapefile yok.
Future<ShapefileRouteImportResult> importShapefileRoute(String shpPath) async =>
    const ShapefileRouteImportResult(points: null, prjStatus: ShapefilePrjStatus.absent);
