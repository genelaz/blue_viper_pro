import 'package:blue_viper_pro/features/licensing/presentation/activation_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows child when already activated (offline)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'activation_ok_v1': true,
      'activation_remote_v1': false,
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ActivationGate(
          child: Scaffold(body: Text('INSIDE_APP')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('INSIDE_APP'), findsOneWidget);
    expect(find.text('Aktifleştir'), findsNothing);
  });

  testWidgets('shows activation screen when not activated', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: ActivationGate(
          child: Scaffold(body: Text('INSIDE_APP')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('INSIDE_APP'), findsNothing);
    expect(find.text('Aktifleştir'), findsOneWidget);
  });
}
