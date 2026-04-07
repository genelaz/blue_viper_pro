import 'package:blue_viper_pro/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'activation_ok_v1': true,
      'activation_remote_v1': false,
      'app_permissions_intro_done_v1': true,
    });
  });

  testWidgets('Uygulama ayağa kalkar ve atış göbeği görünür', (WidgetTester tester) async {
    await tester.pumpWidget(const BlueViperProApp());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 6));

    expect(find.text('Balistik hesap'), findsOneWidget);
    expect(find.text('Harita programına geç (Maps)'), findsOneWidget);
  });
}
