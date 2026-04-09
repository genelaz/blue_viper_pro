import 'package:latlong2/latlong.dart';

/// `.prj` / CRS durumu (kullanıcı mesajı için).
enum ShapefilePrjStatus {
  /// Yan klasörde `.prj` yok; x/y WGS84 enlem-boylam sayıldı.
  absent,

  /// `.prj` proj4 ile okundu, WGS84’e dönüştürüldü.
  applied,

  /// `.prj` vardı ama çözülemedi; ham x/y WGS84 varsayıldı.
  failed,
}

/// Shapefile → rota köşeleri.
class ShapefileRouteImportResult {
  const ShapefileRouteImportResult({
    this.points,
    this.prjStatus = ShapefilePrjStatus.absent,
  });

  final List<LatLng>? points;
  final ShapefilePrjStatus prjStatus;
}
