import 'package:blue_viper_pro/core/maps/mbtiles_vector_overlay_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_tile/vector_tile.dart';

void main() {
  test('MbtilesVectorMapLabel and overlay data carry labels list', () {
    final label = MbtilesVectorMapLabel(point: const LatLng(1, 2), text: 'X');
    final data = MbtilesVectorOverlayData(
      lineSegments: const <MbtilesVectorStyledLine>[],
      polygonPatches: const <MbtilesVectorStyledPolygonPatch>[],
      points: const [],
      labels: [label],
    );
    expect(data.labels, hasLength(1));
    expect(data.labels.first.text, 'X');
  });

  test('label layer priority: place > transportation_name > boundary', () {
    expect(
      MbtilesVectorOverlayBuilder.labelPriorityForLayerTest('place'),
      greaterThan(MbtilesVectorOverlayBuilder.labelPriorityForLayerTest('transportation_name')),
    );
    expect(
      MbtilesVectorOverlayBuilder.labelPriorityForLayerTest('transportation_name'),
      greaterThan(MbtilesVectorOverlayBuilder.labelPriorityForLayerTest('boundary')),
    );
  });

  test('effectiveLabelBudget scales with zoom when enabled', () {
    expect(
      MbtilesVectorOverlayBuilder.effectiveLabelBudgetTest(zoom: 8, userMax: 20, scaleByZoom: true),
      lessThan(20),
    );
    expect(
      MbtilesVectorOverlayBuilder.effectiveLabelBudgetTest(zoom: 20, userMax: 20, scaleByZoom: true),
      20,
    );
    expect(
      MbtilesVectorOverlayBuilder.effectiveLabelBudgetTest(zoom: 8, userMax: 20, scaleByZoom: false),
      20,
    );
  });

  test('label dedupe key stable for same cell and text', () {
    const p = LatLng(41.0082, 28.9784);
    final a = MbtilesVectorOverlayBuilder.labelDedupeKeyTest(p, 'Istanbul');
    final b = MbtilesVectorOverlayBuilder.labelDedupeKeyTest(p, 'Istanbul');
    expect(a, b);
    expect(a, isNot(MbtilesVectorOverlayBuilder.labelDedupeKeyTest(p, 'Izmir')));
  });

  test('preview line style: motorway thicker and distinct from path', () {
    final motorway = MbtilesVectorOverlayBuilder.previewLineStyleForTest(
      'transportation',
      {'class': VectorTileValue(stringValue: 'motorway')},
    );
    final path = MbtilesVectorOverlayBuilder.previewLineStyleForTest(
      'transportation',
      {'class': VectorTileValue(stringValue: 'path')},
    );
    expect(motorway.strokeWidth, greaterThan(path.strokeWidth));
    expect(motorway.strokeArgb, isNot(path.strokeArgb));
  });

  test('preview polygon style: water vs default fill', () {
    final water = MbtilesVectorOverlayBuilder.previewPolygonStyleForTest('water', null);
    final def = MbtilesVectorOverlayBuilder.previewPolygonStyleForTest('unknown_layer_xyz', null);
    expect(water.fillArgb, isNot(def.fillArgb));
  });
}
