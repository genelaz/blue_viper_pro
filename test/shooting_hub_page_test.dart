import 'package:blue_viper_pro/features/shooting/presentation/shooting_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hub cards and map button invoke callbacks', (tester) async {
    var balistik = 0;
    var bluetooth = 0;
    var yedek = 0;
    var harita = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShootingHubPage(
            onBalistik: () => balistik++,
            onBluetooth: () => bluetooth++,
            onYedek: () => yedek++,
            onHarita: () => harita++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Balistik hesap'));
    await tester.pump();
    expect(balistik, 1);

    await tester.tap(find.text('Bluetooth'));
    await tester.pump();
    expect(bluetooth, 1);

    await tester.tap(find.text('Yedek'));
    await tester.pump();
    expect(yedek, 1);

    await tester.tap(find.text('Harita programına geç (Maps)'));
    await tester.pump();
    expect(harita, 1);
  });
}
