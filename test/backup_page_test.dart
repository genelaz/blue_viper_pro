import 'dart:convert';

import 'package:blue_viper_pro/core/sync/remote_backup_service.dart';
import 'package:blue_viper_pro/features/sync/presentation/backup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpBackup(WidgetTester tester, {http.Client? remoteHttpClient}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Material(
            color: Colors.transparent,
            child: BackupPage(remoteHttpClient: remoteHttpClient),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('saving remote prefs writes SharedPreferences', (tester) async {
    await pumpBackup(tester);

    expect(find.text('Dışa aktar (paylaş)'), findsOneWidget);
    expect(find.text('Yedek ile birleştir'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.ensureVisible(fields.at(0));
    await tester.enterText(fields.at(0), 'https://store.test/backup');
    await tester.ensureVisible(fields.at(1));
    await tester.enterText(fields.at(1), 'mytoken');

    await tester.ensureVisible(find.byKey(const Key('backup_save_remote')));
    await tester.tap(find.byKey(const Key('backup_save_remote')));
    await tester.pumpAndSettle();

    expect(await RemoteBackupPrefs.getUrl(), 'https://store.test/backup');
    expect(await RemoteBackupPrefs.getAuthRaw(), 'mytoken');
    expect(
      find.textContaining('Uzak yedek ayarları kaydedildi.', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('PUT gönder uses injected http client', (tester) async {
    var putCalls = 0;
    final mock = MockClient((request) async {
      putCalls++;
      expect(request.method, 'PUT');
      return http.Response('', 204);
    });

    await RemoteBackupPrefs.save(url: 'https://put.test/backup.json', auth: null);
    await pumpBackup(tester, remoteHttpClient: mock);

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('backup_put_remote')));
    await tester.tap(find.byKey(const Key('backup_put_remote')));
    await tester.pumpAndSettle();

    expect(putCalls, 1);
    expect(
      find.textContaining('Uzak yedek tamam (PUT).', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('GET çek uses injected client and restores JSON', (tester) async {
    var getCalls = 0;
    final backupJson = jsonEncode({
      'backupSchemaVersion': 1,
      'prefs': {'from_remote_get': 'ok'},
    });
    final mock = MockClient((request) async {
      getCalls++;
      expect(request.method, 'GET');
      return http.Response(backupJson, 200);
    });

    await RemoteBackupPrefs.save(url: 'https://get.test/backup.json', auth: null);
    await pumpBackup(tester, remoteHttpClient: mock);

    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('backup_get_remote')));
    await tester.tap(find.byKey(const Key('backup_get_remote')));
    await tester.pumpAndSettle();

    expect(getCalls, 1);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('from_remote_get'), 'ok');
    expect(
      find.textContaining('Uzak JSON birleştirildi.', skipOffstage: false),
      findsOneWidget,
    );
  });
}
