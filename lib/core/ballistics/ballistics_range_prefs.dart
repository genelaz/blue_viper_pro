import 'package:shared_preferences/shared_preferences.dart';

import 'ballistics_range_ui.dart';

/// [SharedPreferences] ile ana menzil, menzil tablosu aralığı ve son toplu menzil CSV metni.
class BallisticsRangePrefsSnapshot {
  const BallisticsRangePrefsSnapshot({
    required this.primaryDistanceM,
    required this.tableStartM,
    required this.tableEndM,
    required this.tableStepM,
    required this.lastBatchRangesCsv,
  });

  final double primaryDistanceM;
  final int tableStartM;
  final int tableEndM;
  final int tableStepM;
  final String lastBatchRangesCsv;
}

abstract final class BallisticsRangePrefs {
  BallisticsRangePrefs._();

  static const _kPrimary = 'ballistics_range_primary_m_v1';
  static const _kTableStart = 'ballistics_range_table_start_v1';
  static const _kTableEnd = 'ballistics_range_table_end_v1';
  static const _kTableStep = 'ballistics_range_table_step_v1';
  static const _kBatchCsv = 'ballistics_range_batch_csv_v1';

  static const int _maxBatchCsvChars = 2000;

  static String formatPrimaryField(double meters) {
    final r = meters.roundToDouble();
    if ((meters - r).abs() < 1e-6) {
      return r.toInt().toString();
    }
    return meters.toStringAsFixed(1);
  }

  static Future<BallisticsRangePrefsSnapshot> load() async {
    final p = await SharedPreferences.getInstance();
    var primary = BallisticsRangeUi.defaultPrimaryDistanceM.toDouble();
    final ps = p.getString(_kPrimary);
    if (ps != null && ps.trim().isNotEmpty) {
      final d = double.tryParse(ps.replaceAll(',', '.'));
      if (d != null && d >= 1 && d <= 100000) primary = d;
    }

    var start = BallisticsRangeUi.defaultTableStartM;
    var end = BallisticsRangeUi.defaultTableEndM;
    var step = BallisticsRangeUi.defaultTableStepM;
    final si = p.getInt(_kTableStart);
    final ei = p.getInt(_kTableEnd);
    final sti = p.getInt(_kTableStep);
    if (si != null && ei != null && sti != null) {
      final s = si;
      final e = ei;
      final st = sti;
      if (st > 0 && e >= s && s >= 0 && e <= 100000 && st <= 5000) {
        final rows = BallisticsRangeUi.rangeTableRowCount(s, e, st);
        if (rows > 0 && rows <= BallisticsRangeUi.maxRangeTableRows) {
          start = s;
          end = e;
          step = st;
        }
      }
    }

    var batch = BallisticsRangeUi.defaultBatchRangesCsv;
    final bs = p.getString(_kBatchCsv);
    if (bs != null && bs.trim().isNotEmpty) {
      final t = bs.trim();
      if (t.length <= _maxBatchCsvChars) batch = t;
    }

    return BallisticsRangePrefsSnapshot(
      primaryDistanceM: primary,
      tableStartM: start,
      tableEndM: end,
      tableStepM: step,
      lastBatchRangesCsv: batch,
    );
  }

  static Future<void> save({
    required String primaryText,
    required String tableStartText,
    required String tableEndText,
    required String tableStepText,
    required String batchCsv,
  }) async {
    final p = await SharedPreferences.getInstance();

    final pd = double.tryParse(primaryText.replaceAll(',', '.'));
    if (pd != null) {
      final c = pd.clamp(1.0, 100000.0);
      await p.setString(_kPrimary, c.toString());
    }

    final s = int.tryParse(tableStartText.trim());
    final e = int.tryParse(tableEndText.trim());
    final st = int.tryParse(tableStepText.trim());
    if (s != null && e != null && st != null) {
      if (st > 0 && e >= s && s >= 0 && e <= 100000 && st <= 5000) {
        final rows = BallisticsRangeUi.rangeTableRowCount(s, e, st);
        if (rows > 0 && rows <= BallisticsRangeUi.maxRangeTableRows) {
          await p.setInt(_kTableStart, s);
          await p.setInt(_kTableEnd, e);
          await p.setInt(_kTableStep, st);
        }
      }
    }

    final bc = batchCsv.trim();
    if (bc.isEmpty) {
      await p.remove(_kBatchCsv);
    } else {
      await p.setString(
        _kBatchCsv,
        bc.length > _maxBatchCsvChars ? bc.substring(0, _maxBatchCsvChars) : bc,
      );
    }
  }
}
