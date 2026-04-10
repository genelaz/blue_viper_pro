import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'ballistics_engine.dart';
import 'ballistics_range_xlsx.dart';

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
  row('elev_moa', refOut.dropMoa, curOut.dropMoa);
  row('wind_mil', refOut.windMil, curOut.windMil);
  row('wind_moa', refOut.windMoa, curOut.windMoa);
  row('lat_sum_mil', refOut.combinedLateralMil, curOut.combinedLateralMil);
  row('lat_sum_moa', refOut.combinedLateralMoa, curOut.combinedLateralMoa);
  row('lead_mil', refOut.leadMil, curOut.leadMil);
  row('lead_moa', refOut.leadMoa, curOut.leadMoa);
  row('tof_ms', refOut.timeOfFlightMs, curOut.timeOfFlightMs, decimals: 0);
  row('mv_mps', refOut.adjustedMuzzleVelocityMps, curOut.adjustedMuzzleVelocityMps, decimals: 1);
  row('elev_clicks', refOut.clicks, curOut.clicks);
  row('wind_clicks', refOut.windClicks, curOut.windClicks);
  row('lead_clicks', refOut.leadClicks, curOut.leadClicks);
  row('lat_clicks', refOut.combinedLateralClicks, curOut.combinedLateralClicks);
  row('drop_cm', refOut.verticalHoldDeltaMeters * 100, curOut.verticalHoldDeltaMeters * 100, decimals: 1);
  row('wind_cm', refOut.windLateralDeltaMeters * 100, curOut.windLateralDeltaMeters * 100, decimals: 1);
  row(
    'lead_cm',
    refOut.leadLateralDeltaMeters * 100,
    curOut.leadLateralDeltaMeters * 100,
    decimals: 1,
  );
  row(
    'lat_cm',
    refOut.combinedLateralDeltaMeters * 100,
    curOut.combinedLateralDeltaMeters * 100,
    decimals: 1,
  );
  return b.toString();
}

String _csvEscapeName(String name) {
  if (name.contains(',') || name.contains('"') || name.contains('\n')) {
    return '"${name.replaceAll('"', '""')}"';
  }
  return name;
}

/// [rangeTableToCsv] ile aynı çözüm alanları (V/J hariç): mil, MOA, klik, hedef cm.
void _writeSolveRow(StringBuffer b, BallisticsSolveOutput o) {
  b.writeln(
    '${o.dropMil.toStringAsFixed(2)},${o.dropMoa.toStringAsFixed(2)},'
    '${o.windMil.toStringAsFixed(2)},${o.windMoa.toStringAsFixed(2)},'
    '${o.leadMil.toStringAsFixed(2)},${o.leadMoa.toStringAsFixed(2)},'
    '${o.combinedLateralMil.toStringAsFixed(2)},${o.combinedLateralMoa.toStringAsFixed(2)},'
    '${o.timeOfFlightMs.toStringAsFixed(0)},${o.clicks.toStringAsFixed(2)},'
    '${o.windClicks.toStringAsFixed(2)},${o.leadClicks.toStringAsFixed(2)},'
    '${o.combinedLateralClicks.toStringAsFixed(2)},'
    '${(o.verticalHoldDeltaMeters * 100).toStringAsFixed(1)},'
    '${(o.windLateralDeltaMeters * 100).toStringAsFixed(1)},'
    '${(o.leadLateralDeltaMeters * 100).toStringAsFixed(1)},'
    '${(o.combinedLateralDeltaMeters * 100).toStringAsFixed(1)}',
  );
}

const _multiRangeCsvHeader =
    'range_m,drop_mil,drop_moa,wind_mil,wind_moa,lead_mil,lead_moa,lat_total_mil,lat_total_moa,'
    'tof_ms,elev_clicks,wind_clicks,lead_clicks,lat_total_clicks,drop_cm,wind_cm,lead_cm,lat_total_cm';

/// «Menzil listesi (toplu)» çıktıları — tek form Δh’si sabit.
String multiRangeSolveToCsv(List<(int rangeMeters, BallisticsSolveOutput o)> rows) {
  final b = StringBuffer()..writeln(_multiRangeCsvHeader);
  for (final (r, o) in rows) {
    b.write('$r,');
    _writeSolveRow(b, o);
  }
  return b.toString();
}

const _savedTargetsCsvHeader =
    'name,distance_m,delta_h_m,drop_mil,drop_moa,wind_mil,wind_moa,lead_mil,lead_moa,lat_total_mil,lat_total_moa,'
    'tof_ms,elev_clicks,wind_clicks,lead_clicks,lat_total_clicks,drop_cm,wind_cm,lead_cm,lat_total_cm';

/// Kayıtlı hedef adı + menzil + Δh ile çözülen satırlar.
String savedTargetSolvesToCsv(
  List<(String name, double distanceMeters, double elevationDeltaMeters, BallisticsSolveOutput o)> rows,
) {
  final b = StringBuffer()..writeln(_savedTargetsCsvHeader);
  for (final (name, dm, dh, o) in rows) {
    b.write('${_csvEscapeName(name)},$dm,${dh.toStringAsFixed(1)},');
    _writeSolveRow(b, o);
  }
  return b.toString();
}

String rangeTableToCsv(List<RangeTableRow> rows) {
  final b = StringBuffer()
    ..writeln(
      'range_m,drop_mil,drop_moa,wind_mil,wind_moa,lead_mil,lead_moa,lat_total_mil,lat_total_moa,tof_ms,'
      'elev_clicks,wind_clicks,lead_clicks,lat_total_clicks,v_impact_mps,energy_j,'
      'drop_cm,wind_cm,lead_cm,lat_total_cm',
    );
  for (final r in rows) {
    b.writeln(
      '${r.rangeMeters},${r.dropMil.toStringAsFixed(2)},${r.dropMoa.toStringAsFixed(2)},'
      '${r.windMil.toStringAsFixed(2)},${r.windMoa.toStringAsFixed(2)},'
      '${r.leadMil.toStringAsFixed(2)},${r.leadMoa.toStringAsFixed(2)},'
      '${r.combinedLateralMil.toStringAsFixed(2)},${r.combinedLateralMoa.toStringAsFixed(2)},'
      '${r.tofMs.toStringAsFixed(0)},${r.elevClicks.toStringAsFixed(2)},${r.windClicks.toStringAsFixed(2)},'
      '${r.leadClicks.toStringAsFixed(2)},${r.combinedLateralClicks.toStringAsFixed(2)},'
      '${r.impactVelocityMps.toStringAsFixed(1)},'
      '${r.impactEnergyJoules?.toStringAsFixed(0) ?? ''},'
      '${r.dropCmApprox.toStringAsFixed(1)},'
      '${r.windCmApprox.toStringAsFixed(1)},'
      '${r.combinedLateralCmApprox.toStringAsFixed(1)}',
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
            'Ld.k',
            'Lat.k',
            'V',
            'J',
            'dcm',
            'wcm',
            'ldcm',
            'Lcm',
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
                r.leadClicks.toStringAsFixed(1),
                r.combinedLateralClicks.toStringAsFixed(1),
                r.impactVelocityMps.toStringAsFixed(0),
                r.impactEnergyJoules != null ? r.impactEnergyJoules!.toStringAsFixed(0) : '—',
                r.dropCmApprox.toStringAsFixed(0),
                r.windCmApprox.toStringAsFixed(0),
                r.leadCmApprox.toStringAsFixed(0),
                r.combinedLateralCmApprox.toStringAsFixed(0),
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

/// Menzil tablosunu Excel’de açılabilir `.xlsx` (OOXML) olarak paylaşır.
Future<void> shareRangeTableXlsx({
  required List<RangeTableRow> rows,
  required String filename,
  List<String>? nameColumn,
  List<double>? deltaHmColumn,
}) async {
  final bytes = encodeRangeTableXlsxBytes(
    rows,
    nameColumn: nameColumn,
    deltaHmColumn: deltaHmColumn,
  );
  if (bytes.isEmpty) return;
  if (kIsWeb) {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: filename),
        ],
        subject: filename,
      ),
    );
    return;
  }
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$filename');
  await f.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(f.path)], subject: filename),
  );
}

/// Profil kıyası (referans vs güncel) Excel’de açılabilir `.xlsx` olarak paylaşır.
Future<void> shareProfileCompareXlsx({
  required BallisticsSolveOutput refOut,
  required BallisticsSolveOutput curOut,
  required String filename,
}) async {
  final bytes = encodeProfileCompareXlsxBytes(refOut: refOut, curOut: curOut);
  if (bytes.isEmpty) return;
  if (kIsWeb) {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: filename,
          ),
        ],
        subject: filename,
      ),
    );
    return;
  }
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$filename');
  await f.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(f.path)], subject: filename),
  );
}
