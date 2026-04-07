import 'package:blue_viper_pro/core/sync/remote_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('push PUTs body with Bearer and succeeds on 204', () async {
    await RemoteBackupPrefs.save(url: 'https://api.test/yedek.json', auth: 'secret');

    http.BaseRequest? seen;
    final mock = MockClient((request) async {
      seen = request;
      expect(request.method, 'PUT');
      expect(
        request.headers['Content-Type'],
        'application/json; charset=utf-8',
      );
      expect(request.headers['Authorization'], 'Bearer secret');
      expect(request.body, '{"a":1}');
      return http.Response('', 204);
    });

    await RemoteBackupService.push('{"a":1}', httpClient: mock);
    expect(seen, isNotNull);
    expect(seen!.url.toString(), 'https://api.test/yedek.json');
  });

  test('push omits Authorization header when auth not set', () async {
    await RemoteBackupPrefs.save(url: 'https://api.test/x', auth: null);

    final mock = MockClient((request) async {
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response('', 204);
    });

    await RemoteBackupService.push('{}', httpClient: mock);
  });

  test('push throws on non-2xx', () async {
    await RemoteBackupPrefs.save(url: 'https://nope.test/', auth: null);
    final mock = MockClient((request) async => http.Response('bad', 500));
    await expectLater(
      RemoteBackupService.push('{}', httpClient: mock),
      throwsA(isA<Exception>().having((e) => '$e', 'msg', contains('PUT 500'))),
    );
  });

  test('pull returns body on 200', () async {
    await RemoteBackupPrefs.save(url: 'https://pull.test/data', auth: 't');
    const payload = '{"backupSchemaVersion":1,"prefs":{}}';
    http.BaseRequest? seen;
    final mock = MockClient((request) async {
      seen = request;
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer t');
      return http.Response(payload, 200);
    });

    final out = await RemoteBackupService.pull(httpClient: mock);
    expect(out, payload);
    expect(seen!.url.toString(), 'https://pull.test/data');
  });

  test('pull throws on empty body', () async {
    await RemoteBackupPrefs.save(url: 'https://e.test/', auth: null);
    final mock = MockClient((request) async => http.Response('  ', 200));
    await expectLater(
      RemoteBackupService.pull(httpClient: mock),
      throwsA(isA<Exception>().having((e) => '$e', 'msg', contains('Boş'))),
    );
  });

  test('pull throws on invalid JSON', () async {
    await RemoteBackupPrefs.save(url: 'https://e.test/', auth: null);
    final mock = MockClient((request) async => http.Response('not json', 200));
    await expectLater(
      RemoteBackupService.pull(httpClient: mock),
      throwsA(isA<FormatException>()),
    );
  });

  test('push and pull require URL', () async {
    await expectLater(
      RemoteBackupService.push('{}', httpClient: MockClient((_) async => http.Response('', 200))),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      RemoteBackupService.pull(httpClient: MockClient((_) async => http.Response('{}', 200))),
      throwsA(isA<StateError>()),
    );
  });
}
