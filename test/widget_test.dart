import 'package:blue_viper_pro/core/realtime/map_collab_identity.dart';
import 'package:blue_viper_pro/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'activation_ok_v1': true,
      'activation_remote_v1': false,
      'app_permissions_intro_done_v1': true,
      'map_collab_user_id': 'test-widget-user',
    });
    await MapCollabIdentity.load();
  });

  testWidgets('Uygulama ayağa kalkar ve atış göbeği görünür', (WidgetTester tester) async {
    await tester.pumpWidget(
      const BlueViperProApp(showDeveloperCreditOverlay: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Balistik hesap'), findsOneWidget);
    expect(find.text('Harita ve koordinat'), findsOneWidget);
  });
}
