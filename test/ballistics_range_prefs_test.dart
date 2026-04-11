import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blue_viper_pro/core/ballistics/ballistics_range_prefs.dart';
import 'package:blue_viper_pro/core/ballistics/ballistics_range_ui.dart';

void main() {
  test('save then load restores primary, table, batch CSV', () async {
    SharedPreferences.setMockInitialValues({});
    await BallisticsRangePrefs.save(
      primaryText: '1850',
      tableStartText: '150',
      tableEndText: '3000',
      tableStepText: '50',
      batchCsv: '1000,2000,3000',
    );
    final s = await BallisticsRangePrefs.load();
    expect(s.primaryDistanceM, 1850.0);
    expect(s.tableStartM, 150);
    expect(s.tableEndM, 3000);
    expect(s.tableStepM, 50);
    expect(s.lastBatchRangesCsv, '1000,2000,3000');
  });

  test('load rejects table when row count exceeds max', () async {
    SharedPreferences.setMockInitialValues({
      'ballistics_range_table_start_v1': 100,
      'ballistics_range_table_end_v1': 3000,
      'ballistics_range_table_step_v1': 1,
    });
    final s = await BallisticsRangePrefs.load();
    expect(s.tableStartM, BallisticsRangeUi.defaultTableStartM);
    expect(s.tableEndM, BallisticsRangeUi.defaultTableEndM);
    expect(s.tableStepM, BallisticsRangeUi.defaultTableStepM);
  });
}
