import 'shapefile_route_result.dart';

import 'shapefile_route_stub.dart' if (dart.library.io) 'shapefile_route_io.dart' as impl;

export 'shapefile_route_result.dart';

Future<ShapefileRouteImportResult> importShapefileRoute(String shpPath) => impl.importShapefileRoute(shpPath);
