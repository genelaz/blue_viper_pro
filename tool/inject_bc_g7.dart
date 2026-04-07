// dart run tool/inject_bc_g7.dart
// Katalogdaki her bcG1 varyantına tahmini bcG7 ekler (mühimmat id eşlemesi + G1→G7 kabaca ölçek).
// bcG1 yoksa ama mühimmat id tabloda ise yalnızca bcG7 yazar.

import 'dart:convert';
import 'dart:io';

import 'package:blue_viper_pro/core/ballistics/bc_g7_estimate.dart';

/// Lapua / Hornady / yaygın NATO yükleri için G7 (lb/in²) — tüm namlu varyantları aynı mermi için ortak.
const Map<String, double> _g7ByAmmoId = {
  'bund_556_m855': 0.141,
  'bund_556_m193': 0.179,
  'bund_556_mk262': 0.200,
  'bund_508_nereli': 0.195,
  'bund_762_m118lr': 0.268,
  'bund_300nm_230': 0.355,
  'bund_127_bmg': 0.230,
  'bund_tr_mpt_standard': 0.210,
  'mke_762_m80': 0.206,
  'mke_762_m118': 0.255,
  'mke_762_m62': 0.210,
  'mke_762_subsonic': 0.315,
  'mke_859_ball': 0.340,
  'mke_859_solid': 0.292,
  'mke_127_m33': 0.230,
  'mke_127_m8': 0.218,
  'mke_127_m17': 0.218,
  'mke_127_m2ap': 0.205,
  'mke_127_solid_sniper': 0.360,
  'lapua_308_155_scenar': 0.236,
  'lapua_308_167_scenarl': 0.265,
  'lapua_308_175_scenar': 0.262,
  'lapua_65_123_scenar': 0.259,
  'lapua_65_136_scenar': 0.290,
  'lapua_338_250_scenar': 0.328,
  'lapua_338_300_gr': 0.382,
  'hornady_308_168_eldm': 0.245,
  'hornady_308_178_eldm': 0.255,
  'hornady_65_140_eldm': 0.283,
  'sierra_308_168_mk': 0.242,
  'sierra_308_175_tmk': 0.255,
  'berger_308_168_hybrid': 0.247,
  'berger_65_140_hybrid': 0.284,
  '308_168_smk': 0.242,
  '308_175_smk': 0.255,
  '338_250_scenar': 0.328,
  '338_300_smk': 0.382,
  '300wm_190_smk': 0.308,
  '300wm_220_smk': 0.339,
  '762_175_otm': 0.255,
  '762x39_123': 0.188,
  '762x54r_174': 0.235,
  '556_77_otm': 0.200,
  '65_140_eldm': 0.283,
  'lapua_408_390': 0.445,
};

void main() {
  final root = Directory.current;
  final path = '${root.path}${Platform.pathSeparator}assets${Platform.pathSeparator}catalog${Platform.pathSeparator}turkey_nato.json';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Bulunamadı: $path');
    exit(1);
  }
  final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final ammos = map['ammos'] as List<dynamic>;
  var n = 0;
  for (final raw in ammos) {
    final a = raw as Map<String, dynamic>;
    final aid = a['id'] as String;
    final variants = a['variants'] as List<dynamic>;
    final g7Base = _g7ByAmmoId[aid];
    for (final rv in variants) {
      final v = rv as Map<String, dynamic>;
      if (v.containsKey('bcG7')) continue;
      final g1 = (v['bcG1'] as num?)?.toDouble();
      final g7 = g1 != null
          ? (g7Base ?? estimateG7FromG1(g1))
          : g7Base;
      if (g7 == null) continue;
      v['bcG7'] = double.parse(g7.toStringAsFixed(3));
      n++;
    }
  }
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(map));
  stdout.writeln('bcG7 eklendi: $n varyant. Dosya: $path');
}
