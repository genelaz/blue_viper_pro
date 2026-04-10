import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'ballistics_engine.dart';

String _xmlEsc(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// Excel sütun adı (0 = A).
String _colLetters(int index) {
  var n = index + 1;
  final codes = <int>[];
  while (n > 0) {
    n--;
    codes.add(65 + (n % 26));
    n ~/= 26;
  }
  return String.fromCharCodes(codes.reversed);
}

/// Menzil tablosu veya toplu çözüm satırları için minimal OOXML (.xlsx) zip.
///
/// [nameColumn] / [deltaHmColumn] verilirse (kayıtlı hedefler gibi) başa eklenir;
/// [deltaHmColumn] kullanımı için [nameColumn] da aynı uzunlukta olmalıdır.
Uint8List encodeRangeTableXlsxBytes(
  List<RangeTableRow> rows, {
  List<String>? nameColumn,
  List<double>? deltaHmColumn,
}) {
  if (nameColumn != null && nameColumn.length != rows.length) {
    throw ArgumentError('nameColumn length must match rows');
  }
  if (deltaHmColumn != null) {
    if (nameColumn == null) {
      throw ArgumentError('deltaHmColumn requires nameColumn');
    }
    if (deltaHmColumn.length != rows.length) {
      throw ArgumentError('deltaHmColumn length must match rows');
    }
  }

  final headers = <String>[
    if (nameColumn != null) 'name',
    if (deltaHmColumn != null) 'delta_h_m',
    'range_m',
    'drop_mil',
    'drop_moa',
    'wind_mil',
    'wind_moa',
    'lead_mil',
    'lead_moa',
    'lat_total_mil',
    'lat_total_moa',
    'tof_ms',
    'elev_clicks',
    'wind_clicks',
    'lead_clicks',
    'lat_total_clicks',
    'v_impact_mps',
    'energy_j',
    'drop_cm',
    'wind_cm',
    'lead_cm',
    'lat_total_cm',
  ];

  final sheet = StringBuffer();
  sheet.write(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<sheetData>',
  );

  var rowIx = 1;
  void openRow() {
    sheet.write('<row r="$rowIx">');
  }

  void closeRow() {
    sheet.write('</row>');
    rowIx++;
  }

  void cellStr(int col, String text) {
    final ref = '${_colLetters(col)}$rowIx';
    sheet.write(
      '<c r="$ref" t="inlineStr">'
      '<is><t>${_xmlEsc(text)}</t></is>'
      '</c>',
    );
  }

  void cellNum(int col, double v, int decimals) {
    final ref = '${_colLetters(col)}$rowIx';
    sheet.write('<c r="$ref"><v>${v.toStringAsFixed(decimals)}</v></c>');
  }

  void cellNumOrEmpty(int col, double? v, int decimals) {
    final ref = '${_colLetters(col)}$rowIx';
    if (v == null) {
      cellStr(col, '');
    } else {
      sheet.write('<c r="$ref"><v>${v.toStringAsFixed(decimals)}</v></c>');
    }
  }

  openRow();
  for (var c = 0; c < headers.length; c++) {
    cellStr(c, headers[c]);
  }
  closeRow();

  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    openRow();
    var c = 0;
    if (nameColumn != null) {
      cellStr(c, nameColumn[i]);
      c++;
    }
    if (deltaHmColumn != null) {
      cellNum(c, deltaHmColumn[i], 1);
      c++;
    }
    cellNum(c, r.rangeMeters.toDouble(), 0);
    c++;
    cellNum(c, r.dropMil, 2);
    c++;
    cellNum(c, r.dropMoa, 2);
    c++;
    cellNum(c, r.windMil, 2);
    c++;
    cellNum(c, r.windMoa, 2);
    c++;
    cellNum(c, r.leadMil, 2);
    c++;
    cellNum(c, r.leadMoa, 2);
    c++;
    cellNum(c, r.combinedLateralMil, 2);
    c++;
    cellNum(c, r.combinedLateralMoa, 2);
    c++;
    cellNum(c, r.tofMs, 0);
    c++;
    cellNum(c, r.elevClicks, 2);
    c++;
    cellNum(c, r.windClicks, 2);
    c++;
    cellNum(c, r.leadClicks, 2);
    c++;
    cellNum(c, r.combinedLateralClicks, 2);
    c++;
    cellNum(c, r.impactVelocityMps, 1);
    c++;
    cellNumOrEmpty(c, r.impactEnergyJoules, 0);
    c++;
    cellNum(c, r.dropCmApprox, 1);
    c++;
    cellNum(c, r.windCmApprox, 1);
    c++;
    cellNum(c, r.leadCmApprox, 1);
    c++;
    cellNum(c, r.combinedLateralCmApprox, 1);
    closeRow();
  }

  sheet.write('</sheetData></worksheet>');

  return _xlsxZipFromWorksheetXml(sheet.toString(), sheetTabName: 'Menzil');
}

Uint8List _xlsxZipFromWorksheetXml(String worksheetXml, {required String sheetTabName}) {
  const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  const relsRoot = '<?xml version="1.0" encoding="UTF-8"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  final workbook = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="${_xmlEsc(sheetTabName)}" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';

  const workbookRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  const styles = '<?xml version="1.0" encoding="UTF-8"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="1"><font><sz val="11"/><color theme="1"/><name val="Calibri"/></font></fonts>'
      '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>'
      '</styleSheet>';

  final arch = Archive()
    ..add(ArchiveFile('[Content_Types].xml', contentTypes.length, utf8.encode(contentTypes)))
    ..add(ArchiveFile.string('_rels/.rels', relsRoot))
    ..add(ArchiveFile.string('xl/workbook.xml', workbook))
    ..add(ArchiveFile.string('xl/_rels/workbook.xml.rels', workbookRels))
    ..add(ArchiveFile.string('xl/styles.xml', styles))
    ..add(ArchiveFile('xl/worksheets/sheet1.xml', worksheetXml.length, utf8.encode(worksheetXml)));

  final bytes = ZipEncoder().encode(arch);
  return Uint8List.fromList(bytes);
}

/// Referans vs güncel profil çözümü — metrik / referans / güncel / delta.
Uint8List encodeProfileCompareXlsxBytes({
  required BallisticsSolveOutput refOut,
  required BallisticsSolveOutput curOut,
}) {
  void row4(
    StringBuffer b,
    int rowIx,
    String a,
    String bStr,
    String cStr,
    String dStr,
  ) {
    b.write('<row r="$rowIx">');
    for (var i = 0; i < 4; i++) {
      final ref = '${_colLetters(i)}$rowIx';
      final t = [a, bStr, cStr, dStr][i];
      b.write(
        '<c r="$ref" t="inlineStr"><is><t>${_xmlEsc(t)}</t></is></c>',
      );
    }
    b.write('</row>');
  }

  void row4n(StringBuffer b, int rowIx, String label, double br, double cr, int dec) {
    final d = cr - br;
    b.write('<row r="$rowIx">');
    b.write(
      '<c r="A$rowIx" t="inlineStr"><is><t>${_xmlEsc(label)}</t></is></c>',
    );
    b.write('<c r="B$rowIx"><v>${br.toStringAsFixed(dec)}</v></c>');
    b.write('<c r="C$rowIx"><v>${cr.toStringAsFixed(dec)}</v></c>');
    b.write('<c r="D$rowIx"><v>${d.toStringAsFixed(dec)}</v></c>');
    b.write('</row>');
  }

  final sheet = StringBuffer()
    ..write(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>',
    );

  var r = 1;
  row4(sheet, r++, 'metric', 'referans', 'guncel', 'delta');
  row4n(sheet, r++, 'elev_mil', refOut.dropMil, curOut.dropMil, 2);
  row4n(sheet, r++, 'elev_moa', refOut.dropMoa, curOut.dropMoa, 2);
  row4n(sheet, r++, 'wind_mil', refOut.windMil, curOut.windMil, 2);
  row4n(sheet, r++, 'wind_moa', refOut.windMoa, curOut.windMoa, 2);
  row4n(sheet, r++, 'lat_sum_mil', refOut.combinedLateralMil, curOut.combinedLateralMil, 2);
  row4n(sheet, r++, 'lat_sum_moa', refOut.combinedLateralMoa, curOut.combinedLateralMoa, 2);
  row4n(sheet, r++, 'lead_mil', refOut.leadMil, curOut.leadMil, 2);
  row4n(sheet, r++, 'lead_moa', refOut.leadMoa, curOut.leadMoa, 2);
  row4n(sheet, r++, 'tof_ms', refOut.timeOfFlightMs, curOut.timeOfFlightMs, 0);
  row4n(sheet, r++, 'mv_mps', refOut.adjustedMuzzleVelocityMps, curOut.adjustedMuzzleVelocityMps, 1);
  row4n(sheet, r++, 'elev_clicks', refOut.clicks, curOut.clicks, 2);
  row4n(sheet, r++, 'wind_clicks', refOut.windClicks, curOut.windClicks, 2);
  row4n(sheet, r++, 'lead_clicks', refOut.leadClicks, curOut.leadClicks, 2);
  row4n(sheet, r++, 'lat_clicks', refOut.combinedLateralClicks, curOut.combinedLateralClicks, 2);
  row4n(sheet, r++, 'drop_cm', refOut.verticalHoldDeltaMeters * 100, curOut.verticalHoldDeltaMeters * 100, 1);
  row4n(sheet, r++, 'wind_cm', refOut.windLateralDeltaMeters * 100, curOut.windLateralDeltaMeters * 100, 1);
  row4n(
    sheet,
    r++,
    'lead_cm',
    refOut.leadLateralDeltaMeters * 100,
    curOut.leadLateralDeltaMeters * 100,
    1,
  );
  row4n(
    sheet,
    r++,
    'lat_cm',
    refOut.combinedLateralDeltaMeters * 100,
    curOut.combinedLateralDeltaMeters * 100,
    1,
  );

  sheet.write('</sheetData></worksheet>');

  return _xlsxZipFromWorksheetXml(sheet.toString(), sheetTabName: 'Kiyas');
}
