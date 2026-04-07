import 'package:flutter_test/flutter_test.dart';

import 'package:blue_viper_pro/main.dart';

void main() {
  testWidgets('Uygulama ayağa kalkar', (WidgetTester tester) async {
    await tester.pumpWidget(const BlueViperProApp());
    await tester.pump();
  });
}
