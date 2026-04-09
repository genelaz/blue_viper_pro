import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibEncoder;
import 'package:blue_viper_pro/core/geo/geopdf_extent.dart';
import 'package:blue_viper_pro/core/geo/geopdf_streams.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tryParseGeoPdfGpts finds GPTS lon/lat pairs', () {
    // Minimal Adobe-style measure snippet (PDF metinde düz metin olarak bulunur).
    final fake = StringBuffer()
      ..writeln('%PDF-1.4 fake')
      ..writeln('<< /Type /Measure /Subtype /RL')
      ..writeln('/GPTS [ 32.0 39.92 32.08 39.92 32.08 39.99 32.0 39.99 ]')
      ..writeln('/LPTS [ 0 0 1 0 1 1 0 1 ]')
      ..writeln('>>');
    final bytes = latin1.encode(fake.toString());
    final r = tryParseGeoPdfGpts(bytes);
    expect(r.found, isTrue);
    expect(r.cornersWgs84.length, 4);
    expect(r.cornersWgs84.first.latitude, closeTo(39.92, 1e-6));
    expect(r.cornersWgs84.first.longitude, closeTo(32.0, 1e-6));
  });

  test('tryParseGeoPdfGpts swaps when lon/lat order would exceed latitude range', () {
    // Yanlış sıra (önce enlem gibi): (10,100) boylam/enlem olarak geçersiz; doğru çift (100,10).
    final fake = '/GPTS [ 10 100 11 101 ]';
    final r = tryParseGeoPdfGpts(latin1.encode(fake));
    expect(r.found, isTrue);
    expect(r.cornersWgs84.length, 2);
    expect(r.cornersWgs84.first.longitude, closeTo(100, 1e-6));
    expect(r.cornersWgs84.first.latitude, closeTo(10, 1e-6));
  });

  test('tryParseGeoPdfGpts empty file', () {
    final r = tryParseGeoPdfGpts(<int>[]);
    expect(r.found, isFalse);
  });

  test('tryParseGeoPdfGpts reads GPTS from flate stream', () {
    final gpts = latin1.encode('/GPTS [ 32.0 39.9 32.1 39.9 32.1 40.0 32.0 40.0 ]');
    final compressed = const ZLibEncoder().encodeBytes(gpts);
    final prefix = latin1.encode('%PDF FlateDecode << /Length ${compressed.length} >> stream\n');
    final suffix = latin1.encode('\nendstream');
    final totalLen = prefix.length + compressed.length + suffix.length;
    final pdf = Uint8List(totalLen);
    pdf.setAll(0, prefix);
    pdf.setAll(prefix.length, compressed);
    pdf.setAll(prefix.length + compressed.length, suffix);
    expect(totalLen, pdf.length);
    final r = tryParseGeoPdfGpts(pdf);
    expect(r.found, isTrue);
    expect(r.detail, contains('Flate'));
  });

  test('tryConcatenateDecodedFlateText finds GPTS payload', () {
    final gpts = '/GPTS [ 1 2 3 4 ]';
    final z = const ZLibEncoder().encodeBytes(latin1.encode(gpts));
    final a = latin1.encode('<< /Filter /FlateDecode >> stream\n');
    final c = latin1.encode('\nendstream');
    final pdf = Uint8List(a.length + z.length + c.length);
    pdf.setAll(0, a);
    pdf.setAll(a.length, z);
    pdf.setAll(a.length + z.length, c);
    final t = tryConcatenateDecodedFlateText(pdf);
    expect(t, contains('GPTS'));
  });
}
