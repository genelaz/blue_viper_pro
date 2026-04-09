import 'package:flutter/material.dart';

import 'strelock_ballistics_ui.dart';

/// StreLok tarzı manuel silah formu — ham metinler; üst widget parse eder.
class ManualWeaponFormValues {
  const ManualWeaponFormValues({
    required this.name,
    required this.caliber,
    required this.role,
    required this.region,
    required this.notes,
    required this.barrelInches,
    required this.zeroRangeM,
    required this.sightHeightCm,
    required this.twistInchesPerTurn,
    required this.twistRh,
    required this.grain,
    required this.bulletCalIn,
  });

  final String name;
  final String caliber;
  final String role;
  final String region;
  final String notes;
  final String barrelInches;
  final String zeroRangeM;
  final String sightHeightCm;
  final String twistInchesPerTurn;
  final bool twistRh;
  final String grain;
  final String bulletCalIn;
}

class ManualWeaponEntryPage extends StatefulWidget {
  const ManualWeaponEntryPage({super.key});

  @override
  State<ManualWeaponEntryPage> createState() => _ManualWeaponEntryPageState();
}

class _ManualWeaponEntryPageState extends State<ManualWeaponEntryPage> {
  late final TextEditingController _name;
  late final TextEditingController _cal;
  late final TextEditingController _role;
  late final TextEditingController _region;
  late final TextEditingController _notes;
  late final TextEditingController _barrel;
  late final TextEditingController _zero;
  late final TextEditingController _sight;
  late final TextEditingController _twist;
  late final TextEditingController _grain;
  late final TextEditingController _calIn;
  bool _twistRh = true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _cal = TextEditingController();
    _role = TextEditingController();
    _region = TextEditingController();
    _notes = TextEditingController();
    _barrel = TextEditingController();
    _zero = TextEditingController();
    _sight = TextEditingController();
    _twist = TextEditingController();
    _grain = TextEditingController();
    _calIn = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _cal.dispose();
    _role.dispose();
    _region.dispose();
    _notes.dispose();
    _barrel.dispose();
    _zero.dispose();
    _sight.dispose();
    _twist.dispose();
    _grain.dispose();
    _calIn.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final cal = _cal.text.trim();
    if (name.isEmpty || cal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silah adı ve kalibre zorunlu.')),
      );
      return;
    }
    Navigator.of(context).pop(ManualWeaponFormValues(
      name: name,
      caliber: cal,
      role: _role.text.trim(),
      region: _region.text.trim(),
      notes: _notes.text.trim(),
      barrelInches: _barrel.text.trim(),
      zeroRangeM: _zero.text.trim(),
      sightHeightCm: _sight.text.trim(),
      twistInchesPerTurn: _twist.text.trim(),
      twistRh: _twistRh,
      grain: _grain.text.trim(),
      bulletCalIn: _calIn.text.trim(),
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
          'Yeni silah ekle',
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
                  'Zorunlu: ad ve kalibre. Diğer alanlar katalogda saklanır ve forma uygulanır.',
                  style: streLockLabelStyle(context).copyWith(fontSize: 12),
                ),
                const StreLockSectionHeader('Genel'),
                StreLockLabeledField(label: 'Silah adı *', controller: _name, fieldWidth: 160),
                StreLockLabeledField(label: 'Kalibre *', controller: _cal, fieldWidth: 160),
                StreLockLabeledField(label: 'Rol', controller: _role, fieldWidth: 160),
                StreLockLabeledField(label: 'Bölge / ülke', controller: _region, fieldWidth: 160),
                StreLockLabeledField(
                  label: 'Notlar (seri, üretici, dipçik…)',
                  controller: _notes,
                  maxLines: 3,
                  fieldWidth: 200,
                ),
                const StreLockSectionHeader('Nişan / namlu'),
                StreLockLabeledField(
                  label: 'Namlu uzunluğu, in',
                  controller: _barrel,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                StreLockLabeledField(
                  label: 'Varsayılan sıfır, m',
                  controller: _zero,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                StreLockLabeledField(
                  label: 'Nişangah yüksekliği, cm',
                  controller: _sight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const StreLockSectionHeader('Hatve / mermi'),
                StreLockToggleRow(
                  label: 'Sağ el hatve (RH)',
                  value: _twistRh,
                  onChanged: (v) => setState(() => _twistRh = v),
                ),
                StreLockLabeledField(
                  label: 'Hatve in/tur',
                  controller: _twist,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                StreLockLabeledField(
                  label: 'Mermi ağırlığı, gr',
                  controller: _grain,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                StreLockLabeledField(
                  label: 'Mermi çapı, in',
                  controller: _calIn,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 24),
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
