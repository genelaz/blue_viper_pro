import 'dart:convert';

import 'package:blue_viper_pro/core/licensing/activation_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('bad_config when uri is null', () async {
    final r = await postRemoteActivationWithUri(
      code12: '123456789012',
      deviceId: 'd1',
      uri: null,
      client: null,
    );
    expect(r.ok, isFalse);
    expect(r.errorCode, 'bad_config');
  });

  test('bad_config when scheme invalid', () async {
    final r = await postRemoteActivationWithUri(
      code12: '123456789012',
      deviceId: 'd1',
      uri: Uri.parse('ftp://x.example/'),
      client: null,
    );
    expect(r.ok, isFalse);
    expect(r.errorCode, 'bad_config');
  });

  test('ok true when JSON ok', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['code'], '123456789012');
      expect(body['deviceId'], 'd1');
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final r = await postRemoteActivationWithUri(
      code12: '123456789012',
      deviceId: 'd1',
      uri: Uri.parse('https://example.test/activate'),
      client: client,
    );
    expect(r.ok, isTrue);
    expect(r.statusCode, 200);
  });

  test('maps server error field', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'ok': false, 'error': 'unknown_code'}),
        200,
      ),
    );
    final r = await postRemoteActivationWithUri(
      code12: '123456789012',
      deviceId: 'd1',
      uri: Uri.parse('https://example.test/activate'),
      client: client,
    );
    expect(r.ok, isFalse);
    expect(r.errorCode, 'unknown_code');
  });

  test('bad_response on invalid JSON body', () async {
    final client = MockClient((_) async => http.Response('not-json', 200));
    final r = await postRemoteActivationWithUri(
      code12: '123456789012',
      deviceId: 'd1',
      uri: Uri.parse('https://example.test/activate'),
      client: client,
    );
    expect(r.ok, isFalse);
    expect(r.errorCode, 'bad_response');
  });
}
