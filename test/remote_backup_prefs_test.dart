import 'package:blue_viper_pro/core/sync/remote_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('getUrl returns null when empty or unset', () async {
    expect(await RemoteBackupPrefs.getUrl(), isNull);
    final p = await SharedPreferences.getInstance();
    await p.setString('remote_backup_url_v1', '   ');
    expect(await RemoteBackupPrefs.getUrl(), isNull);
  });

  test('save persists url and auth; empty clears', () async {
    await RemoteBackupPrefs.save(
      url: ' https://x.example/back ',
      auth: ' tok ',
    );
    expect(await RemoteBackupPrefs.getUrl(), 'https://x.example/back');
    expect(await RemoteBackupPrefs.getAuthRaw(), 'tok');
    expect(await RemoteBackupPrefs.getAuthHeader(), 'Bearer tok');

    await RemoteBackupPrefs.save(url: '', auth: '');
    expect(await RemoteBackupPrefs.getUrl(), isNull);
    expect(await RemoteBackupPrefs.getAuthRaw(), isNull);
    expect(await RemoteBackupPrefs.getAuthHeader(), isNull);
  });

  test('getAuthHeader passes through Bearer and Basic', () async {
    await RemoteBackupPrefs.save(url: 'https://a', auth: 'Bearer abc');
    expect(await RemoteBackupPrefs.getAuthHeader(), 'Bearer abc');
    await RemoteBackupPrefs.save(url: 'https://a', auth: 'basic xyz');
    expect(await RemoteBackupPrefs.getAuthHeader(), 'basic xyz');
  });
}
