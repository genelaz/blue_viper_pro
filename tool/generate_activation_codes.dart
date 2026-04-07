// Tek seferlik: 100 adet 12 haneli kod üretir, hash dosyasını yazar, düz metin listesini kaydeder.
// Çalıştırma: dart run tool/generate_activation_codes.dart
//
// UYARI: activation_codes_PRIVATE.txt dosyasını asla public repoya koymayın.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

const _salt = 'bvp_act_v1|';
const _count = 100;
const _digits = 12;

void main() {
  final rnd = Random.secure();
  final codes = <String>{};

  while (codes.length < _count) {
    final digits = StringBuffer();
    for (var i = 0; i < _digits; i++) {
      digits.write(rnd.nextInt(10));
    }
    codes.add(digits.toString());
  }

  final sorted = codes.toList()..sort();

  final hashes = sorted
      .map((c) => sha256.convert(utf8.encode('$_salt$c')).toString())
      .toList();

  final root = Directory.current.path;
  final privatePath = '$root/activation_codes_PRIVATE.txt';
  File(privatePath).writeAsStringSync(
    '${sorted.join('\n')}\n',
    mode: FileMode.writeOnly,
  );

  final dartDir = Directory('$root/lib/core/licensing');
  if (!dartDir.existsSync()) {
    dartDir.createSync(recursive: true);
  }
  final dartPath = '${dartDir.path}/activation_code_hashes.g.dart';
  final buf = StringBuffer()
    ..writeln('// GENERATED — tool/generate_activation_codes.dart')
    ..writeln('// Bu dosyayı elle düzenlemeyin. Yeni kod seti için aracı yeniden çalıştırın.')
    ..writeln('// ignore_for_file: constant_identifier_names')
    ..writeln()
    ..writeln('const Set<String> kActivationCodeSha256Hex = {');
  for (final h in hashes) {
    buf.writeln("  '$h',");
  }
  buf.writeln('};');
  File(dartPath).writeAsStringSync(buf.toString());

  // Cloudflare KV bulk: wrangler kv bulk put ... (bkz. server/cloudflare-activation/README.md)
  final kvPath = '$root/activation_kv_seed.json';
  final kvList = hashes
      .map((h) => {'key': h, 'value': '__free__'})
      .toList();
  File(kvPath).writeAsStringSync('${jsonEncode(kvList)}\n');

  // ignore: avoid_print
  print('Yazıldı: $privatePath (${sorted.length} kod)');
  // ignore: avoid_print
  print('Yazıldı: $dartPath (${hashes.length} hash)');
  // ignore: avoid_print
  print('Yazıldı: $kvPath (KV seed, ${hashes.length} anahtar)');
}
