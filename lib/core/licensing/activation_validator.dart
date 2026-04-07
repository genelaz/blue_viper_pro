import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'activation_code_hashes.g.dart';

const String kActivationSalt = 'bvp_act_v1|';

String normalizeActivationInput(String input) =>
    input.replaceAll(RegExp(r'\s'), '').trim();

/// [allowedHashes] içinde üretilen SHA-256 ile eşleşme (test ve özel setler için).
@visibleForTesting
bool activationCodeMatchesHashes(String raw, Set<String> allowedHashes) {
  final c = normalizeActivationInput(raw);
  if (!RegExp(r'^\d{12}$').hasMatch(c)) return false;
  final h = sha256.convert(utf8.encode('$kActivationSalt$c')).toString();
  return allowedHashes.contains(h);
}

/// Geçerli biçim: tam 12 rakam (boşluklar yok sayılır).
bool isValidActivationCode(String raw) =>
    activationCodeMatchesHashes(raw, kActivationCodeSha256Hex);
