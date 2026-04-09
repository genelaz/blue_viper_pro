import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show Inflate, ZLibDecoder;

/// PDF `stream` … `endstream` bloklarından ham bayt çıkarır (Length anahtarı yoksa `endstream`e kadar).
Uint8List? _pdfStreamBytesAfter(List<int> pdf, int dctIdx) {
  final streamMark = utf8.encode('stream');
  var i = dctIdx;
  for (; i < pdf.length - 6; i++) {
    var match = true;
    for (var k = 0; k < streamMark.length; k++) {
      if (pdf[i + k] != streamMark[k]) {
        match = false;
        break;
      }
    }
    if (!match) continue;
    var j = i + streamMark.length;
    if (j < pdf.length && pdf[j] == 0x0d) j++;
    if (j < pdf.length && pdf[j] == 0x0a) j++;
    final start = j;
    const endTok = [0x65, 0x6e, 0x64, 0x73, 0x74, 0x72, 0x65, 0x61, 0x6d];
    for (var e = start; e + endTok.length <= pdf.length; e++) {
      var ok = true;
      for (var t = 0; t < endTok.length; t++) {
        if (pdf[e + t] != endTok[t]) {
          ok = false;
          break;
        }
      }
      if (ok) {
        return Uint8List.fromList(pdf.sublist(start, e));
      }
    }
    return null;
  }
  return null;
}

/// İlk [DCTDecode] JPEG akışı (JFIF başlığı).
Uint8List? tryExtractFirstJpegFromPdf(List<int> pdf) {
  final scan = latin1.decode(pdf, allowInvalid: true);
  final re = RegExp('DCTDecode', caseSensitive: false);
  for (final m in re.allMatches(scan)) {
    final raw = _pdfStreamBytesAfter(pdf, m.start);
    if (raw != null && raw.length > 4 && raw[0] == 0xff && raw[1] == 0xd8) {
      return raw;
    }
  }
  return null;
}

/// Flate sıkıştırılmış streamleri açıp birleşik metin döndürür (`GPTS` araması için).
String tryConcatenateDecodedFlateText(List<int> pdf) {
  final scan = latin1.decode(pdf, allowInvalid: true);
  final out = StringBuffer();
  var from = 0;
  while (true) {
    final f = scan.indexOf('FlateDecode', from);
    if (f < 0) break;
    final raw = _pdfStreamBytesAfter(pdf, f);
    if (raw != null && raw.isNotEmpty) {
      try {
        out.write(latin1.decode(
          const ZLibDecoder().decodeBytes(raw),
          allowInvalid: true,
        ));
      } catch (_) {
        try {
          final inflated = Inflate(raw).getBytes();
          out.write(latin1.decode(inflated, allowInvalid: true));
        } catch (_) {}
      }
    }
    from = f + 1;
  }
  return out.toString();
}
