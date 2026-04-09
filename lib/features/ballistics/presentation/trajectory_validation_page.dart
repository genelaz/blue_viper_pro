import 'package:flutter/material.dart';

import '../../../core/ballistics/ballistics_engine.dart';
import '../../../core/ballistics/click_units.dart';
import 'strelock_ballistics_ui.dart';

class TrajectoryValidationResult {
  const TrajectoryValidationResult({this.mv, this.bc});

  final double? mv;
  final double? bc;
}

/// StreLok «Atış yolu doğrulama» — Hız/BC sekmeleri, klik / mil / MOA.
class TrajectoryValidationPage extends StatefulWidget {
  const TrajectoryValidationPage({
    super.key,
    required this.ammoSummary,
    required this.initialMvMode,
    required this.distanceController,
    required this.currentMvText,
    required this.validateParentForm,
    required this.collectInput,
    required this.clickUnit,
    required this.clickValueText,
  });

  final String ammoSummary;
  final bool initialMvMode;
  final TextEditingController distanceController;
  final String currentMvText;
  final bool Function() validateParentForm;
  final BallisticsSolveInput Function() collectInput;
  final ClickUnit clickUnit;
  final String clickValueText;

  @override
  State<TrajectoryValidationPage> createState() => _TrajectoryValidationPageState();
}

class _TrajectoryValidationPageState extends State<TrajectoryValidationPage> {
  late bool _tuneMv;
  String _obsUnit = 'click';
  final _obsCtrl = TextEditingController();
  String _resultLine = '—';
  Color _resultColor = StreLockBalColors.label;

  @override
  void initState() {
    super.initState();
    _tuneMv = widget.initialMvMode;
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  double _parseClick() => double.tryParse(widget.clickValueText.replaceAll(',', '.')) ?? 0.1;

  double _obsToMil(double obs) {
    return switch (_obsUnit) {
      'moa' => obs / 3.438,
      'click' => switch (widget.clickUnit) {
          ClickUnit.mil => obs * _parseClick(),
          ClickUnit.moa => obs * (_parseClick() / 3.438),
          ClickUnit.cmPer100m => obs * (_parseClick() / 10.0),
          ClickUnit.inPer100yd => obs * (_parseClick() / 3.6),
        },
      _ => obs,
    };
  }

  void _compute() {
    if (!widget.validateParentForm()) {
      setState(() {
        _resultLine = 'Ana form doğrulanamadı.';
        _resultColor = StreLockBalColors.resultRed;
      });
      return;
    }
    final obs = double.tryParse(_obsCtrl.text.replaceAll(',', '.'));
    if (obs == null) {
      setState(() {
        _resultLine = 'Gözlem değeri girin.';
        _resultColor = StreLockBalColors.resultRed;
      });
      return;
    }
    final template = widget.collectInput();
    final obsMil = _obsToMil(obs);

    if (_tuneMv) {
      final mvNew = BallisticsEngine.trueMuzzleVelocityForObservedDrop(
        template: template,
        observedDropMil: obsMil,
      );
      if (mvNew == null) {
        setState(() {
          _resultLine = 'Vo uydurulamıyor (işaret yönü / menzil kontrol).';
          _resultColor = StreLockBalColors.resultRed;
        });
        return;
      }
      setState(() {
        _resultLine = '${mvNew.toStringAsFixed(1)} m/s';
        _resultColor = StreLockBalColors.resultGreen;
      });
      Navigator.of(context).pop(TrajectoryValidationResult(mv: mvNew));
      return;
    }

    final bcNew = BallisticsEngine.trueBallisticCoefficientForObservedDrop(
      template: template,
      observedDropMil: obsMil,
    );
    if (bcNew == null) {
      setState(() {
        _resultLine = 'BC uydurulamıyor (işaret yönü / menzil kontrol).';
        _resultColor = StreLockBalColors.resultRed;
      });
      return;
    }
    setState(() {
      _resultLine = bcNew.toStringAsFixed(4);
      _resultColor = StreLockBalColors.resultGreen;
    });
    Navigator.of(context).pop(TrajectoryValidationResult(bc: bcNew));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StreLockBalColors.scaffold,
      appBar: AppBar(
        backgroundColor: StreLockBalColors.scaffold,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Atış yolu doğrulama',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: StreLockBalColors.titleBlue,
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
                Row(
                  children: [
                    Expanded(
                      child: _modeChip(
                        label: 'Hız (Vo)',
                        selected: _tuneMv,
                        onTap: () => setState(() => _tuneMv = true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _modeChip(
                        label: 'BC',
                        selected: !_tuneMv,
                        onTap: () => setState(() => _tuneMv = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.ammoSummary.isNotEmpty)
                  Text(
                    widget.ammoSummary,
                    style: streLockSectionStyle(context).copyWith(fontSize: 14),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Doğrulama mesafesi mümkün olduğunca sıfırlama menzilinden uzak olmalı. '
                  'Tambur testinden sonra dikey düzeltmeyi girin. Klik: «Silah» sekmesindeki klik birimi/değeri kullanılır.',
                  style: streLockLabelStyle(context).copyWith(fontSize: 12),
                ),
                const SizedBox(height: 12),
                StreLockLabeledField(
                  label: 'Mesafe, m',
                  controller: widget.distanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Geçerli Vo, m/s',
                        style: streLockLabelStyle(context),
                      ),
                    ),
                    Text(
                      widget.currentMvText,
                      style: const TextStyle(
                        color: StreLockBalColors.titleBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const StreLockSectionHeader('Düzeltme birimi'),
                StreLockDropdown<String>(
                  label: 'Gözlem',
                  value: _obsUnit,
                  items: const [
                    DropdownMenuItem(value: 'click', child: Text('Klik')),
                    DropdownMenuItem(value: 'mil', child: Text('MRAD')),
                    DropdownMenuItem(value: 'moa', child: Text('MOA')),
                  ],
                  onChanged: (v) => setState(() => _obsUnit = v ?? _obsUnit),
                ),
                StreLockLabeledField(
                  label: _obsUnit == 'moa'
                      ? 'Dikey, MOA'
                      : _obsUnit == 'click'
                          ? 'Dikey, klik'
                          : 'Dikey, MRAD',
                  controller: _obsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
                const SizedBox(height: 16),
                StreLockFullButton(
                  label: 'Hesapla',
                  onPressed: _compute,
                  foregroundColor: StreLockBalColors.resultRed,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tuneMv ? 'Hesaplanan hız, m/s' : 'Hesaplanan BC',
                        style: streLockLabelStyle(context),
                      ),
                    ),
                    Text(
                      _resultLine,
                      style: TextStyle(
                        color: _resultColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: StreLockBalColors.footerBar,
            elevation: 6,
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? StreLockBalColors.fieldFill : Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? StreLockBalColors.fieldText : StreLockBalColors.label,
                fontWeight: FontWeight.w800;
              ),
            ),
          ),
        ),
      ),
    );
  }
}

```

I have a syntax error - semicolon instead of comma in TextStyle
</think>


<｜tool▁calls▁begin｜><｜tool▁call▁begin｜>
StrReplace