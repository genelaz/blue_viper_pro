import 'helpers/preset_override_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PresetSpec {
  final String id;
  final String label;
  final Map<int, (String mv, String bc)> byInch;

  const _PresetSpec(this.id, this.label, this.byInch);
}

const _presetA = _PresetSpec('a', 'Preset A', {
  16: ('760', '0.44'),
  22: ('810', '0.47'),
  24: ('830', '0.48'),
});
const _presetB = _PresetSpec('b', 'Preset B', {
  16: ('720', '0.39'),
  22: ('770', '0.42'),
  24: ('795', '0.43'),
});

class _PresetOverrideDemo extends StatefulWidget {
  const _PresetOverrideDemo();

  @override
  State<_PresetOverrideDemo> createState() => _PresetOverrideDemoState();
}

class _PresetOverrideDemoState extends State<_PresetOverrideDemo> {
  _PresetSpec _selected = _presetA;
  int _selectedInch = 22;
  final _mvCtrl = TextEditingController();
  final _bcCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyPreset(_selected, _selectedInch);
  }

  void _applyPreset(_PresetSpec preset, int inch) {
    final tuple = preset.byInch[inch] ?? preset.byInch[22]!;
    _mvCtrl.text = tuple.$1;
    _bcCtrl.text = tuple.$2;
  }

  @override
  void dispose() {
    _mvCtrl.dispose();
    _bcCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<_PresetSpec>(
                key: const ValueKey<String>('preset_dropdown'),
                initialValue: _selected,
                items: const [
                  DropdownMenuItem(value: _presetA, child: Text('Preset A')),
                  DropdownMenuItem(value: _presetB, child: Text('Preset B')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selected = v;
                    _applyPreset(v, _selectedInch);
                  });
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                key: const ValueKey<String>('variant_segmented'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<int>(value: 16, label: Text('16"')),
                  ButtonSegment<int>(value: 22, label: Text('22"')),
                  ButtonSegment<int>(value: 24, label: Text('24"')),
                ],
                selected: {_selectedInch},
                onSelectionChanged: (s) {
                  setState(() {
                    _selectedInch = s.first;
                    _applyPreset(_selected, _selectedInch);
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('field_mv'),
                controller: _mvCtrl,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('field_bc'),
                controller: _bcCtrl,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('preset secimi alanlari otomatik doldurur', (tester) async {
    await tester.pumpWidget(const _PresetOverrideDemo());
    await tester.pumpAndSettle();

    expect(textFieldValue(tester, byKeyName('field_mv')), '810');
    expect(textFieldValue(tester, byKeyName('field_bc')), '0.47');

    await selectDropdownText(
      tester,
      dropdownFinder: byKeyName('preset_dropdown'),
      itemText: 'Preset B',
    );

    expect(textFieldValue(tester, byKeyName('field_mv')), '770');
    expect(textFieldValue(tester, byKeyName('field_bc')), '0.42');
  });

  testWidgets('16-22-24 secimi degerleri override eder', (tester) async {
    await tester.pumpWidget(const _PresetOverrideDemo());
    await tester.pumpAndSettle();

    await tapSegmentText(
      tester,
      segmentedFinder: byKeyName('variant_segmented'),
      text: '16"',
    );
    expect(textFieldValue(tester, byKeyName('field_mv')), '760');

    await tapSegmentText(
      tester,
      segmentedFinder: byKeyName('variant_segmented'),
      text: '24"',
    );
    expect(textFieldValue(tester, byKeyName('field_mv')), '830');
    expect(textFieldValue(tester, byKeyName('field_bc')), '0.48');
  });
}
