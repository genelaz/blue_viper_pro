import 'package:flutter/material.dart';

import '../../../core/ballistics/click_units.dart';
import 'strelock_ballistics_ui.dart';

class ManualScopeFormValues {
  const ManualScopeFormValues({
    required this.name,
    required this.clickUnit,
    required this.clickValueText,
    required this.minMag,
    required this.maxMag,
    required this.refMag,
    required this.notes,
  });

  final String name;
  final ClickUnit clickUnit;
  final String clickValueText;
  final String minMag;
  final String maxMag;
  final String refMag;
  final String notes;
}

class ManualScopeEntryPage extends StatefulWidget {
  const ManualScopeEntryPage({super.key});

  @override
  State<ManualScopeEntryPage> createState() => _ManualScopeEntryPageState();
}

class _ManualScopeEntryPageState extends State<ManualScopeEntryPage> {
  late final TextEditingController _name;
  late final TextEditingController _clickVal;
  late final TextEditingController _minMag;
  late final TextEditingController _maxMag;
  late final TextEditingController _refMag;
  late final TextEditingController _notes;
  ClickUnit _unit = ClickUnit.mil;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _clickVal = TextEditingController(text: '0.1');
    _minMag = TextEditingController();
    _maxMag = TextEditingController();
    _refMag = TextEditingController();
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _clickVal.dispose();
    _minMag.dispose();
    _maxMag.dispose();
    _refMag.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final val = double.tryParse(_clickVal.text.replaceAll(',', '.'));
    if (name.isEmpty || val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dürbün adı ve pozitif klik değeri gerekli.')),
      );
      return;
    }
    Navigator.of(context).pop(ManualScopeFormValues(
      name: name,
      clickUnit: _unit,
      clickValueText: _clickVal.text.trim(),
      minMag: _minMag.text.trim(),
      maxMag: _maxMag.text.trim(),
      refMag: _refMag.text.trim(),
      notes: _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StreLockBalColors.scaffold,
      appBar: AppBar(
        backgroundColor: StreLockBalColors.scaffold,
        foregroundColor: StreLockBalColors.label,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Yeni dürbün ekle',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: StreLockBalColors.headerOrange,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Text(
                  'Klik birimi ve değeri retikül / tambur hesaplarında kullanılır.',
                  style: streLockLabelStyle(context).copyWith(fontSize: 12),
                ),
                const StreLockSectionHeader('Dürbün'),
                StreLockLabeledField(label: 'Dürbün adı *', controller: _name, fieldWidth: 180),
                StreLockDropdown<ClickUnit>(
                  label: 'Klik birimi',
                  value: _unit,
                  items: [
                    for (final u in ClickUnit.values)
                      DropdownMenuItem(value: u, child: Text(u.label)),
                  ],
                  onChanged: (v) => setState(() => _unit = v ?? _unit),
                ),
                StreLockLabeledField(
                  label: 'Klik değeri *',
                  controller: _clickVal,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const StreLockSectionHeader('Büyütme (opsiyonel)'),
                StreLockLabeledField(
                  label: 'Min zoom ×',
                  controller: _minMag,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                StreLockLabeledField(
                  label: 'Max zoom ×',
                  controller: _maxMag,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                StreLockLabeledField(
                  label: 'Retikül referans × (SFP)',
                  controller: _refMag,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                StreLockLabeledField(
                  label: 'Notlar (objektif, tüp Ø, paralaks…)',
                  controller: _notes,
                  maxLines: 3,
                  fieldWidth: 200,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          StreLockFooterBar(
            onLeft: _save,
            onRight: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
