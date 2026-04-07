import 'dart:convert';

import 'package:blue_viper_pro/core/licensing/activation_validator.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

String _hashFor12(String digits) =>
    sha256.convert(utf8.encode('$kActivationSalt$digits')).toString();

void main() {
  group('normalizeActivationInput', () {
    test('strips whitespace', () {
      expect(normalizeActivationInput('  12 34 56 '), '123456');
    });
  });

  group('activationCodeMatchesHashes', () {
    test('accepts when hash is in set', () {
      const code = '987654321098';
      final h = _hashFor12(code);
      expect(activationCodeMatchesHashes(code, {h}), isTrue);
      expect(activationCodeMatchesHashes('9876 5432 1098', {h}), isTrue);
    });

    test('rejects wrong length', () {
      final h = _hashFor12('123456789012');
      expect(activationCodeMatchesHashes('12345', {h}), isFalse);
    });

    test('rejects when set empty', () {
      expect(activationCodeMatchesHashes('123456789012', {}), isFalse);
    });
  });
}
