// Hassas kod listesini diske şifreli yazar / çözer.
//
// Kullanım (proje kökünde):
//   set BVP_VAULT_PASS=guclu-bir-parola
//   dart run tool/private_vault.dart seal
//   dart run tool/private_vault.dart unseal
//
// seal: activation_codes_PRIVATE.txt → activation_codes_PRIVATE.sealed
// unseal: tersi (KV seed / Worker için düz metin gerekince)

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

const _magic = [0x42, 0x56, 0x50, 0x31]; // BVP1
const _plain = 'activation_codes_PRIVATE.txt';
const _sealed = 'activation_codes_PRIVATE.sealed';

void main(List<String> args) async {
  if (args.isEmpty) {
    // ignore: avoid_print
    print('Kullanim: dart run tool/private_vault.dart seal|unseal');
    // ignore: avoid_print
    print('Parola: ortam degiskeni BVP_VAULT_PASS (onerilir, ozellikle Windows)');
    exit(1);
  }
  final pass = Platform.environment['BVP_VAULT_PASS']?.trim();
  if (pass == null || pass.isEmpty) {
    // ignore: avoid_print
    print('BVP_VAULT_PASS tanimli degil.');
    exit(1);
  }
  if (pass.length < 10) {
    // ignore: avoid_print
    print('En az 10 karakter parola kullanin.');
    exit(1);
  }

  final keyBytes = sha256.convert(utf8.encode(pass)).bytes;
  final key = Key(Uint8List.fromList(keyBytes));

  switch (args[0]) {
    case 'seal':
      _sealFile(key);
      break;
    case 'unseal':
      _unsealFile(key);
      break;
    default:
      // ignore: avoid_print
      print('Bilinmeyen komut: ${args[0]}');
      exit(1);
  }
}

void _sealFile(Key key) {
  final f = File(_plain);
  if (!f.existsSync()) {
    // ignore: avoid_print
    print('$_plain bulunamadi.');
    exit(1);
  }
  final plain = f.readAsBytesSync();
  final iv = IV.fromSecureRandom(16);
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  final encrypted = encrypter.encryptBytes(plain, iv: iv);

  final out = BytesBuilder()
    ..add(_magic)
    ..add(iv.bytes)
    ..add(encrypted.bytes);
  File(_sealed).writeAsBytesSync(out.toBytes());
  // ignore: avoid_print
  print('Yazildi: $_sealed');
  // ignore: avoid_print
  print('Guvenlik: $_plain dosyasini sadece siz gorebilecek sekilde silin veya baska bir yere tasiyin.');
}

void _unsealFile(Key key) {
  final f = File(_sealed);
  if (!f.existsSync()) {
    // ignore: avoid_print
    print('$_sealed bulunamadi.');
    exit(1);
  }
  final all = f.readAsBytesSync();
  if (all.length < 4 + 16 + 16) {
    // ignore: avoid_print
    print('Bozuk veya eski format.');
    exit(1);
  }
  for (var i = 0; i < 4; i++) {
    if (all[i] != _magic[i]) {
      // ignore: avoid_print
      print('Gecersiz dosya (BVP1 degil).');
      exit(1);
    }
  }
  final iv = IV(Uint8List.fromList(all.sublist(4, 20)));
  final ct = Encrypted(Uint8List.fromList(all.sublist(20)));
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  try {
    final plain = encrypter.decryptBytes(ct, iv: iv);
    File(_plain).writeAsBytesSync(plain);
    // ignore: avoid_print
    print('Yazildi: $_plain');
  } catch (_) {
    // ignore: avoid_print
    print('Parola yanlis veya dosya bozuk.');
    exit(1);
  }
}
