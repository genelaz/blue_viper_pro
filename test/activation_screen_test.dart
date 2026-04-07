import 'package:blue_viper_pro/core/licensing/activation_api_client.dart';
import 'package:blue_viper_pro/core/licensing/activation_store.dart';
import 'package:blue_viper_pro/features/licensing/presentation/activation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('remote flow: successful inject calls markActivatedRemote and onActivated', (tester) async {
    var activated = false;
    ActivationApiResult? seen;

    await tester.pumpWidget(
      MaterialApp(
        home: ActivationScreen(
          onActivated: () => activated = true,
          deviceIdForTest: () async => 'test-device-stable',
          remoteActivation: ({required code12, required deviceId}) async {
            expect(code12, '123456789012');
            expect(deviceId, 'test-device-stable');
            seen = const ActivationApiResult(ok: true, statusCode: 200);
            return seen!;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '123456789012');
    await tester.pump();
    await tester.tap(find.text('Aktifleştir'));
    await tester.pumpAndSettle();

    expect(activated, isTrue);
    expect(seen!.ok, isTrue);
    expect(await ActivationStore.isActivated(), isTrue);
    expect(await ActivationStore.usedRemoteBinding(), isTrue);
    expect(await ActivationStore.storedDeviceId(), 'test-device-stable');
  });

  testWidgets('remote flow: server error shows Turkish message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivationScreen(
          onActivated: () {},
          deviceIdForTest: () async => 'test-device-stable',
          remoteActivation: ({required code12, required deviceId}) async {
            return const ActivationApiResult(ok: false, errorCode: 'unknown_code');
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '123456789012');
    await tester.pump();
    await tester.tap(find.text('Aktifleştir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('geçersiz'), findsOneWidget);
    expect(await ActivationStore.isActivated(), isFalse);
  });

  testWidgets('offline flow: invalid code shows error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivationScreen(
          onActivated: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '000000000000');
    await tester.pump();
    await tester.tap(find.text('Aktifleştir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Geçersiz kod'), findsOneWidget);
    expect(await ActivationStore.isActivated(), isFalse);
  });
}
