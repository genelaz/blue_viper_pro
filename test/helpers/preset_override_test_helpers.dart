import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder byKeyName(String key) => find.byKey(ValueKey<String>(key));

Future<void> selectDropdownText(
  WidgetTester tester, {
  required Finder dropdownFinder,
  required String itemText,
}) async {
  await tester.tap(dropdownFinder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(itemText).last);
  await tester.pumpAndSettle();
}

Future<void> tapSegmentText(
  WidgetTester tester, {
  required Finder segmentedFinder,
  required String text,
}) async {
  await tester.tap(find.descendant(of: segmentedFinder, matching: find.text(text)));
  await tester.pumpAndSettle();
}

String textFieldValue(WidgetTester tester, Finder fieldFinder) {
  final field = tester.widget<TextFormField>(fieldFinder);
  return field.controller?.text ?? '';
}
