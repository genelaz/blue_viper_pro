import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'ballistics_engine.dart';

/// İki çözümün (referans vs güncel) kısa Kıyas CSV’si.
String profileCompareToCsv({
  required BallisticsSolveOutput refOut,
  required BallisticsSolveOutput curOut,
}) {
  final b = StringBuffer()..writeln('metric,referans,guncel,delta');
  void row(String metric, double a, double c, {int decimals = 2}) {
    final d = c - a;
    b.writeln(
      '$metric,${a.toStringAsFixed(decimals)},${c.toStringAsFixed(decimals)},${d.toStringAsFixed(decimals)}',
    );
  }

  row('elev_mil', refOut.dropMil, curOut.dropMil);
  row('wind_mil', refOut.windMil, curOut.windMil);
  row('lat_sum_mil', refOut.combinedLateralMil, curOut.combinedLateralMil);
  row('lead_mil', refOut.leadMil, curOut.leadMil);
  row('tof_ms', refOut.timeOfFlightMs, curOut.timeOfFlightMs, decimals: 0);
  row('mv_mps', refOut.adjustedMuzzleVelocityMps, curOut.adjustedMuzzleVelocityMps, decimals: 1);
  return b.toString();
}

String _csvEscapeName(String name) {
  if (name.contains(',') || name.contains('"') || name.contains('\n')) {
    return '"${name.replaceAll('"', '""')}"';
  }
  return name;
}

void _writeSolveRow(StringBuffer b, BallisticsSolveOutput o) {
  b.writeln(
    '${o.dropMil.toStringAsFixed(2)},${o.windMil.toStringAsFixed(2)},'
    '${o.leadMil.toStringAsFixed(2)},${o.combinedLateralMil.toStringAsFixed(2)},'
    '${o.timeOfFlightMs.toStringAsFixed(0)},${o.clicks.toStringAsFixed(2)},'
    '${o.windClicks.toStringAsFixed(2)},${o.combinedLateralClicks.toStringAsFixed(2)}',
  );
}

/// «Menzil listesi (toplu)» çıktıları — tek form Δh’si sabit.
String multiRangeSolveToCsv(List<(int rangeMeters, BallisticsSolveOutput o)> rows) {
  final b = StringBuffer()
    ..writeln(
      'range_m,drop_mil,wind_mil,lead_mil,lat_total_mil,tof_ms,elev_clicks,wind_clicks,lat_total_clicks',
    );
  for (final (r, o) in rows) {
    b.write('$r,');
    _writeSolveRow(b, o);
  }
  return b.toString();
}

/// Kayıtlı hedef adı + menzil + Δh ile çözülen satırlar.
String savedTargetSolvesToCsv(
  List<(String name, double distanceMeters, double elevationDeltaMeters, BallisticsSolveOutput o)> rows,
) {
  final b = StringBuffer()
    ..writeln(
      'name,distance_m,delta_h_m,drop_mil,wind_mil,lead_mil,lat_total_mil,tof_ms,elev_clicks,wind_clicks,lat_total_clicks',
    );
  for (final (name, dm, dh, o) in rows) {
    b.write('${_csvEscapeName(name)},$dm,${dh.toStringAsFixed(1)},');
    _writeSolveRow(b, o);
  }
  return b.toString();
}

String rangeTableToCsv(List<RangeTableRow> rows) {
  final b = StringBuffer()
    ..writeln(
      'range_m,drop_mil,wind_mil,lead_mil,lat_total_mil,tof_ms,elev_clicks,wind_clicks,lat_total_clicks',
    );
  for (final r in rows) {
    b.writeln(
      '${r.rangeMeters},${r.dropMil.toStringAsFixed(2)},${r.windMil.toStringAsFixed(2)},'
      '${r.leadMil.toStringAsFixed(2)},${r.combinedLateralMil.toStringAsFixed(2)},'
      '${r.tofMs.toStringAsFixed(0)},${r.elevClicks.toStringAsFixed(2)},${r.windClicks.toStringAsFixed(2)},'
      '${r.combinedLateralClicks.toStringAsFixed(2)}',
    );
  }
  return b.toString();
}

Future<void> shareCsvText(String csv, {required String filename}) async {
  if (kIsWeb) {
    await SharePlus.instance.share(
      ShareParams(text: csv, subject: filename),
    );
    return;
  }
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$filename');
  await f.writeAsString(csv, encoding: utf8);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(f.path)], subject: filename),
  );
}

Future<void> shareRangeTablePdf({
  required List<RangeTableRow> rows,
  required String title,
  required String filename,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(level: 0, child: pw.Text(title)),
        pw.TableHelper.fromTextArray(
          headers: const [
            'm',
            'Elev',
            'Wind',
            'Lead',
            'LatΣ',
            'TOF',
            'El.k',
            'Wnd.k',
            'Lat.k',
          ],
          data: [
            for (final r in rows)
              [
                r.rangeMeters.toString(),
                r.dropMil.toStringAsFixed(2),
                r.windMil.toStringAsFixed(2),
                r.leadMil.toStringAsFixed(2),
                r.combinedLateralMil.toStringAsFixed(2),
                r.tofMs.toStringAsFixed(0),
                r.elevClicks.toStringAsFixed(1),
                r.windClicks.toStringAsFixed(1),
                r.combinedLateralClicks.toStringAsFixed(1),
              ],
          ],
        ),
      ],
    ),
  );
  final bytes = await doc.save();
  if (kIsWeb) {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(Uint8List.fromList(bytes), mimeType: 'application/pdf', name: filename),
        ],
        subject: title,
      ),
    );
    return;
  }
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$filename');
  await f.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(f.path)], subject: title),
  );
}
