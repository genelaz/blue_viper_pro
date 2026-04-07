import 'dart:convert';

import 'package:blue_viper_pro/core/geo/elevation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses first elevation from Open-Meteo-shaped JSON', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.open-meteo.com');
      expect(request.url.path, '/v1/elevation');
      expect(request.url.queryParameters['latitude'], '39.9');
      expect(request.url.queryParameters['longitude'], '32.8');
      return http.Response(jsonEncode({'elevation': [1250.5, 99]}), 200);
    });
    final m = await ElevationService.fetchMeters(39.9, 32.8, client: client);
    expect(m, 1250.5);
  });

  test('non-200 returns null', () async {
    final client = MockClient((_) async => http.Response('', 503));
    expect(await ElevationService.fetchMeters(1, 2, client: client), isNull);
  });

  test('invalid JSON returns null', () async {
    final client = MockClient((_) async => http.Response('x', 200));
    expect(await ElevationService.fetchMeters(1, 2, client: client), isNull);
  });

  test('empty elevation list returns null', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'elevation': []}), 200),
    );
    expect(await ElevationService.fetchMeters(1, 2, client: client), isNull);
  });
}
