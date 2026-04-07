import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'ballistics_engine.dart';

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
