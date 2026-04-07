// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Katalog üretimi: flutter pub run yok; `dart run tool/gen_reticles.dart`
void main() {
  final out = <Map<String, dynamic>>[];
  final manufacturers = [
    'Vortex', 'Nightforce', 'Trijicon', 'Schmidt & Bender', 'Kahles', 'Steiner',
    'Zeiss', 'Leupold', 'Burris', 'Athlon', 'Primary Arms', 'Sig Sauer',
    'EOTech', 'Delta Optical', 'Meopta', 'Bushnell', 'US Optics', 'Zero Compromise',
    'Sightron', 'Hawke', 'IOR', 'Swarovski', 'Minox', 'Tangent Theta', 'March',
    'TTI', 'Riton', 'Monstrum', 'Arken', 'Maven', 'Element Optics', 'Vector',
  ];
  final patterns = ['hash', 'tree', 'mil_dot', 'duplex', 'german_4'];
  var n = 0;
  for (final mfr in manufacturers) {
    for (final pat in patterns) {
      for (var k = 0; k < 2; k++) {
        n++;
        final unit = (n % 3 == 0) ? 'moa' : 'mil';
        final major = unit == 'moa' ? 1.0 : 1.0;
        final minor = unit == 'moa' ? 0.25 : 0.2;
        out.add({
          'id': 'ret_${mfr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${pat}_$n',
          'name': '$mfr tarzı ${pat == 'tree' ? 'ağaç' : pat == 'mil_dot' ? 'mil-dot' : pat == 'duplex' ? 'duplex' : pat == 'german_4' ? 'German 4A' : 'MIL/MOA hash'} ($unit)',
          'manufacturer': mfr,
          'unit': unit,
          'defaultFfp': n % 5 != 0,
          'pattern': pat,
          'majorStep': major,
          'minorStep': minor,
          'visibleRadiusUnits': pat == 'tree' ? 10.0 : 8.0,
          if (pat == 'tree') 'treeLevels': 10 + (n % 4),
          if (pat == 'tree') 'windDotsPerSide': 4 + (n % 3),
          if (pat == 'mil_dot') 'milDotCount': 8 + (n % 5),
        });
      }
    }
  }
  // Ek: genel indeksler
  for (var i = 0; i < 40; i++) {
    n++;
    out.add({
      'id': 'ret_generic_extra_$i',
      'name': 'Genel indeks #$i (${i % 2 == 0 ? 'MRAD' : 'MOA'} ızgara)',
      'manufacturer': 'Genel / özel yapım',
      'unit': i % 2 == 0 ? 'mil' : 'moa',
      'defaultFfp': true,
      'pattern': ['hash', 'tree', 'mil_dot'][i % 3],
      'majorStep': i % 2 == 0 ? 1.0 : 1.0,
      'minorStep': i % 2 == 0 ? 0.2 : 0.25,
      'visibleRadiusUnits': 6.0 + (i % 5),
      if (i % 3 == 1) 'treeLevels': 8,
      if (i % 3 == 1) 'windDotsPerSide': 5,
      if (i % 3 == 2) 'milDotCount': 10,
    });
  }

  final file = File('assets/reticles/reticle_catalog.json');
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert(out));
  print('Wrote ${out.length} reticles to ${file.path}');
}
