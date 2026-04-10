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
    required this.firstFocalPlane,
    required this.verticalClickCmPer100m,
    required this.horizontalClickCmPer100m,
    required this.reticleCode,
  });

  final String name;
  final ClickUnit clickUnit;
  final String clickValueText;
  final String minMag;
  final String maxMag;
  final String refMag;
  final String notes;
  final bool firstFocalPlane;
  final String verticalClickCmPer100m;
  final String horizontalClickCmPer100m;
  final String reticleCode;
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
  late final TextEditingController _vCm;
  late final TextEditingController _hCm;
  late final TextEditingController _reticle;
  ClickUnit _unit = ClickUnit.mil;
  bool _ffp = true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _clickVal = TextEditingController(text: '0.1');
    _minMag = TextEditingController();
    _maxMag = TextEditingController();
    _refMag = TextEditingController();
    _notes = TextEditingController();
    _vCm = TextEditingController();
    _hCm = TextEditingController();
    _reticle = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _clickVal.dispose();
    _minMag.dispose();
    _maxMag.dispose();
    _refMag.dispose();
    _notes.dispose();
    _vCm.dispose();
    _hCm.dispose();
    _reticle.dispose();
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
      firstFocalPlane: _ffp,
      verticalClickCmPer100m: _vCm.text.trim(),
      horizontalClickCmPer100m: _hCm.text.trim(),
      reticleCode: _reticle.text.trim(),
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
                StreLockToggleRow(
                  label: 'İlk odak düzlemi (FFP)',
                  value: _ffp,
                  onChanged: (v) => setState(() => _ffp = v),
                ),
                Text(
                  'SFP’de büyütme alanları ve retikül referansı anlamlıdır; FFP’de subtension büyütmeye bağlı değişmez.',
                  style: streLockLabelStyle(context).copyWith(fontSize: 11),
                ),
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
                StreLockLabeledField(
                  label: 'Dikey klik @100 m (cm)',
                  controller: _vCm,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                StreLockLabeledField(
                  label: 'Yatay klik @100 m (cm)',
                  controller: _hCm,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                StreLockLabeledField(
                  label: 'Retikül kodu / adı',
                  controller: _reticle,
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
                Text(
                  'Uyarı: Klik cm değerleri üretici tablosundan doğrulanmalı; yanlış cm retikül hesaplarını bozar.',
                  style: TextStyle(
                    color: StreLockBalColors.resultRed.withValues(alpha: 0.9),
                    fontSize: 11,
                    height: 1.35,
                  ),
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
