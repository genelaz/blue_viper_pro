import 'package:blue_viper_pro/core/licensing/activation_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('isActivated false by default', () async {
    expect(await ActivationStore.isActivated(), isFalse);
  });

  test('markActivatedOffline then isActivated true; usedRemoteBinding false', () async {
    await ActivationStore.markActivatedOffline(deviceId: 'dev-a');
    expect(await ActivationStore.isActivated(), isTrue);
    expect(await ActivationStore.usedRemoteBinding(), isFalse);
    expect(await ActivationStore.storedDeviceId(), 'dev-a');
  });

  test('markActivatedRemote sets remote flag and device id', () async {
    await ActivationStore.markActivatedRemote(deviceId: 'dev-b');
    expect(await ActivationStore.isActivated(), isTrue);
    expect(await ActivationStore.usedRemoteBinding(), isTrue);
    expect(await ActivationStore.storedDeviceId(), 'dev-b');
  });

  test('clearAll removes keys', () async {
    await ActivationStore.markActivatedRemote(deviceId: 'x');
    await ActivationStore.clearAll();
    expect(await ActivationStore.isActivated(), isFalse);
    expect(await ActivationStore.usedRemoteBinding(), isFalse);
    expect(await ActivationStore.storedDeviceId(), isNull);
  });
}
