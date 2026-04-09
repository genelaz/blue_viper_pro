import 'package:blue_viper_pro/core/sync/cas_remote_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOkClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = '''
{
  "name":"Remote CAS",
  "version":"1",
  "threatTubes":[
    {
      "id":"a",
      "observer":{"lat":39.9,"lon":32.8},
      "target":{"lat":40.0,"lon":32.9},
      "startHalfWidthM":20,
      "endHalfWidthM":50
    }
  ]
}
''';
    final stream = Stream<List<int>>.fromIterable([body.codeUnits]);
    return http.StreamedResponse(stream, 200);
  }
}

class _FakePagedClient extends http.BaseClient {
  int _requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _requestCount++;
    final qp = request.url.queryParameters;
    final cursor = qp['cursor'];
    if (_requestCount == 1) {
      expect(qp['tenant'], 'acme');
      expect(qp['limit'], '1');
      expect(qp['minAlt'], '150.0');
      expect(qp['maxAlt'], '900.0');
      expect(qp['bbox'], '32.7,39.8,33.1,40.2');
      final body = '''
{
  "name":"Remote CAS",
  "version":"2",
  "items":[
    {
      "id":"a",
      "observer":{"lat":39.9,"lon":32.8},
      "target":{"lat":40.0,"lon":32.9},
      "startHalfWidthM":20,
      "endHalfWidthM":50
    }
  ],
  "nextCursor":"abc"
}
''';
      return http.StreamedResponse(Stream<List<int>>.fromIterable([body.codeUnits]), 200);
    }
    expect(cursor, 'abc');
    final body = '''
{
  "name":"Remote CAS",
  "version":"2",
  "items":[
    {
      "id":"b",
      "observer":{"lat":40.1,"lon":32.7},
      "target":{"lat":40.2,"lon":32.6},
      "startHalfWidthM":30,
      "endHalfWidthM":70
    }
  ]
}
''';
    return http.StreamedResponse(Stream<List<int>>.fromIterable([body.codeUnits]), 200);
  }
}

class _FakeTenantHeaderClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    expect(request.url.queryParameters.containsKey('tenant'), isFalse);
    expect(request.headers['X-Tenant-Id'], 'acme-header');
    final body = '''
{
  "name":"Remote CAS",
  "version":"3",
  "threatTubes":[
    {
      "id":"h1",
      "observer":{"lat":39.9,"lon":32.8},
      "target":{"lat":40.0,"lon":32.9},
      "startHalfWidthM":20,
      "endHalfWidthM":50
    }
  ]
}
''';
    return http.StreamedResponse(Stream<List<int>>.fromIterable([body.codeUnits]), 200);
  }
}

class _FakeSnakeCaseClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final qp = request.url.queryParameters;
    expect(qp['tenant_id'], 'acme-snake');
    expect(qp['min_alt'], '100.0');
    expect(qp['max_alt'], '700.0');
    expect(qp.containsKey('tenant'), isFalse);
    expect(qp.containsKey('minAlt'), isFalse);
    expect(qp.containsKey('maxAlt'), isFalse);
    final body = '''
{
  "name":"Remote CAS",
  "version":"4",
  "threatTubes":[
    {
      "id":"s1",
      "observer":{"lat":39.9,"lon":32.8},
      "target":{"lat":40.0,"lon":32.9},
      "startHalfWidthM":20,
      "endHalfWidthM":50
    }
  ]
}
''';
    return http.StreamedResponse(Stream<List<int>>.fromIterable([body.codeUnits]), 200);
  }
}

class _FakePageCursorClient extends http.BaseClient {
  int _requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _requestCount++;
    final qp = request.url.queryParameters;
    if (_requestCount == 1) {
      expect(qp.containsKey('cursor'), isFalse);
      expect(qp.containsKey('page_cursor'), isFalse);
      final body = '''
{
  "name":"Remote CAS",
  "version":"5",
  "items":[
    {
      "id":"pc1",
      "observer":{"lat":39.9,"lon":32.8},
      "target":{"lat":40.0,"lon":32.9},
      "startHalfWidthM":20,
      "endHalfWidthM":50
    }
  ],
  "nextCursor":"c2"
}
''';
      return http.StreamedResponse(Stream<List<int>>.fromIterable([body.codeUnits]), 200);
    }
    expect(qp['pageCursor'], 'c2');
    expect(qp.containsKey('cursor'), isFalse);
    final body = '''
{
  "name":"Remote CAS",
  "version":"5",
  "items":[
    {
      "id":"pc2",
      "observer":{"lat":40.1,"lon":32.7},
      "target":{"lat":40.2,"lon":32.6},
      "startHalfWidthM":30,
      "endHalfWidthM":70
    }
  ]
}
''';
    return http.StreamedResponse(Stream<List<int>>.fromIterable([body.codeUnits]), 200);
  }
}

class _FakeStrictCursorClient extends http.BaseClient {
  int _requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _requestCount++;
    if (_requestCount > 1) {
      throw StateError('strict mode should not request second page');
    }
    final body = '''
{
  "name":"Remote CAS",
  "version":"6",
  "items":[
    {
      "id":"st1",
      "observer":{"lat":39.9,"lon":32.8},
      "target":{"lat":40.0,"lon":32.9},
      "startHalfWidthM":20,
      "endHalfWidthM":50
    }
  ],
  "nextCursor":"should_be_ignored_in_strict_pageCursor"
}
''';
    return http.StreamedResponse(Stream<List<int>>.fromIterable([body.codeUnits]), 200);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('pullCas3dPackage parses remote json', () async {
    await CasRemotePrefs.save(url: 'https://example.com/cas', auth: null);
    final pack = await CasRemoteService.pullCas3dPackage(httpClient: _FakeOkClient());
    expect(pack.name, 'Remote CAS');
    expect(pack.threatTubes.length, 1);
    expect(pack.threatTubes.first.id, 'a');
  });

  test('pullCas3dPackage fails when url missing', () async {
    await CasRemotePrefs.save(url: null, auth: null);
    expect(
      () => CasRemoteService.pullCas3dPackage(httpClient: _FakeOkClient()),
      throwsA(isA<StateError>()),
    );
  });

  test('pullCas3dPackage merges paged response with tenant and limit', () async {
    await CasRemotePrefs.save(
      url: 'https://example.com/cas',
      auth: null,
      tenant: 'acme',
      limit: 1,
      maxPages: 4,
      minAlt: 150,
      maxAlt: 900,
      bbox: '32.7,39.8,33.1,40.2',
    );
    final pack = await CasRemoteService.pullCas3dPackage(httpClient: _FakePagedClient());
    expect(pack.name, 'Remote CAS');
    expect(pack.version, '2');
    expect(pack.threatTubes.length, 2);
    expect(pack.threatTubes.map((e) => e.id), containsAll(<String>['a', 'b']));
  });

  test('pullCas3dPackage sends tenant as header when enabled', () async {
    await CasRemotePrefs.save(
      url: 'https://example.com/cas',
      auth: null,
      tenant: 'acme-header',
      tenantAsHeader: true,
    );
    final pack = await CasRemoteService.pullCas3dPackage(httpClient: _FakeTenantHeaderClient());
    expect(pack.version, '3');
    expect(pack.threatTubes.length, 1);
    expect(pack.threatTubes.first.id, 'h1');
  });

  test('pullCas3dPackage supports snake_case query parameters', () async {
    await CasRemotePrefs.save(
      url: 'https://example.com/cas',
      auth: null,
      tenant: 'acme-snake',
      minAlt: 100,
      maxAlt: 700,
      paramStyle: CasRemoteParamStyle.snakeCase,
    );
    final pack = await CasRemoteService.pullCas3dPackage(httpClient: _FakeSnakeCaseClient());
    expect(pack.version, '4');
    expect(pack.threatTubes.length, 1);
    expect(pack.threatTubes.first.id, 's1');
  });

  test('pullCas3dPackage supports pageCursor cursor parameter style', () async {
    await CasRemotePrefs.save(
      url: 'https://example.com/cas',
      auth: null,
      cursorParamStyle: CasRemoteCursorParamStyle.pageCursor,
    );
    final pack = await CasRemoteService.pullCas3dPackage(httpClient: _FakePageCursorClient());
    expect(pack.version, '5');
    expect(pack.threatTubes.length, 2);
    expect(pack.threatTubes.map((e) => e.id), containsAll(<String>['pc1', 'pc2']));
  });

  test('pullCas3dPackage strict next cursor honors selected key only', () async {
    await CasRemotePrefs.save(
      url: 'https://example.com/cas',
      auth: null,
      cursorParamStyle: CasRemoteCursorParamStyle.pageCursor,
      strictNextCursor: true,
    );
    final pack = await CasRemoteService.pullCas3dPackage(httpClient: _FakeStrictCursorClient());
    expect(pack.version, '6');
    expect(pack.threatTubes.length, 1);
    expect(pack.threatTubes.first.id, 'st1');
  });

  test('CasRemotePrefs persists last sync timestamp', () async {
    final now = DateTime(2026, 4, 9, 14, 35, 10);
    await CasRemotePrefs.setLastSyncAt(now);
    final loaded = await CasRemotePrefs.getLastSyncAt();
    expect(loaded?.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    await CasRemotePrefs.setLastSyncAt(null);
    expect(await CasRemotePrefs.getLastSyncAt(), isNull);
  });
}
