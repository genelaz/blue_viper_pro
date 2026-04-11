import 'package:flutter/material.dart';

import '../../../core/ballistics/ballistics_engine.dart';
import '../../../core/ballistics/ballistics_output_convention.dart';
import '../../../core/ballistics/click_units.dart';
import 'strelock_ballistics_ui.dart';

/// StreLok «Ek veriler»: ikincil düzeltmeler, ses hızı, yörünge tepesi, tık başına cm (mil için).
class BallisticsExtraDataPage extends StatelessWidget {
  const BallisticsExtraDataPage({
    super.key,
    required this.input,
    required this.output,
    this.zeroElevCompClicks = 0,
    this.zeroWindCompClicks = 0,
    this.showEnergyFtLbf = false,
  });

  final BallisticsSolveInput input;
  final BallisticsSolveOutput output;
  final double zeroElevCompClicks;
  final double zeroWindCompClicks;
  final bool showEnergyFtLbf;

  @override
  Widget build(BuildContext context) {
    final d = input.distanceMeters;
    final sec = output.secondaryCorrections;
    final milC = input.angularMilConvention;
    final moaC = input.moaDisplayConvention;

    double milOf(double deltaM) => milFromLateralMeters(deltaM: deltaM, rangeM: d, convention: milC);
    double moaOfMil(double mil, double deltaM) =>
        moaFromMilAndGeometry(mil: mil, deltaM: deltaM, rangeM: d, convention: moaC);

    double clicksOfMil(double mil) => clicksForCorrectionMil(
          correctionMil: mil,
          clickUnit: input.clickUnit,
          clickValue: input.clickValue,
          moaClickConvention: moaC,
          angularMilConvention: milC,
        );

    final cLatMil = milOf(sec.coriolisLateralM);
    final cLatMoa = moaOfMil(cLatMil, sec.coriolisLateralM);
    final cLatClk = clicksOfMil(cLatMil);

    final cVertMil = milOf(sec.coriolisVerticalM);
    final cVertMoa = moaOfMil(cVertMil, sec.coriolisVerticalM);
    final cVertClk = clicksOfMil(cVertMil);

    final spinMil = milOf(sec.spinDriftM);
    final spinMoa = moaOfMil(spinMil, sec.spinDriftM);
    final spinClk = clicksOfMil(spinMil);

    final jumpMil = milOf(sec.aeroJumpVerticalM);
    final jumpMoa = moaOfMil(jumpMil, sec.aeroJumpVerticalM);
    final jumpClk = clicksOfMil(jumpMil);

    final energy = output.impactEnergyJoules;
    final energyStr = energy == null
        ? '—'
        : showEnergyFtLbf
            ? '${(energy * 0.737562149).toStringAsFixed(0)} ft·lbf'
            : '${energy.toStringAsFixed(0)} J';

    double? cmPerClickMil;
    if (input.clickUnit == ClickUnit.mil) {
      cmPerClickMil = d * input.clickValue * 0.1;
    }

    final tofS = output.timeOfFlightMs / 1000.0;

    final valStyle = streLockLabelStyle(context).copyWith(
      color: StreLockBalColors.accentBlue,
      fontWeight: FontWeight.w700,
    );
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: Text(k, style: streLockLabelStyle(context))),
              Expanded(
                flex: 4,
                child: Text(v, textAlign: TextAlign.end, style: valStyle),
              ),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: StreLockBalColors.scaffold,
      appBar: AppBar(
        backgroundColor: StreLockBalColors.scaffold,
        foregroundColor: StreLockBalColors.label,
        title: Text(
          'Ek veriler',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: StreLockBalColors.headerOrange,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Mevcut mesafe: ${d.toStringAsFixed(0)} m', style: streLockSectionStyle(context)),
          const SizedBox(height: 12),
          row('Vo (barut düzeltmeli)', '${output.adjustedMuzzleVelocityMps.toStringAsFixed(1)} m/s'),
          row('Hedef hızı', '${output.impactVelocityMps.toStringAsFixed(0)} m/s'),
          row('Enerji (hedef)', energyStr),
          row('Ses hızı (çözüm T)', '${output.speedOfSoundMps.toStringAsFixed(0)} m/s'),
          row('Uçuş süresi', '${tofS.toStringAsFixed(3)} s (${output.timeOfFlightMs.toStringAsFixed(0)} ms)'),
          row('Yörünge tepesi (y, kabaca)', '${output.apexHeightAlongPathM.toStringAsFixed(2)} m'),
          row('Dikey tutma (toplam)', '${(output.verticalHoldDeltaMeters * 100).toStringAsFixed(1)} cm'),
          if (cmPerClickMil != null)
            row('1 klik ≈ (bu mesafede, mil)', '${cmPerClickMil.toStringAsFixed(2)} cm')
          else
            row('1 klik ≈ cm @ mesafe', 'Mil dışı tık: dürbün kılavuzuna bakın.'),
          row('Düşüş tık (+ sıfır telafisi)', (output.clicks + zeroElevCompClicks).toStringAsFixed(2)),
          row('Yan (saf rüzgâr) tık (+ telafi)', (output.windClicks + zeroWindCompClicks).toStringAsFixed(2)),
          const Divider(height: 28),
          Text('İkincil düzeltmeler', style: streLockSectionStyle(context)),
          row('Coriolis yatay', '${cLatMil.toStringAsFixed(2)} mil · ${cLatMoa.toStringAsFixed(2)} MOA · ${cLatClk.toStringAsFixed(1)} klik'),
          row('Coriolis dikey', '${cVertMil.toStringAsFixed(2)} mil · ${cVertMoa.toStringAsFixed(2)} MOA · ${cVertClk.toStringAsFixed(1)} klik'),
          row('Spin sapması', '${spinMil.toStringAsFixed(2)} mil · ${spinMoa.toStringAsFixed(2)} MOA · ${spinClk.toStringAsFixed(1)} klik'),
          row('Aero jump (yan rüzgâr)', '${jumpMil.toStringAsFixed(2)} mil · ${jumpMoa.toStringAsFixed(2)} MOA · ${jumpClk.toStringAsFixed(1)} klik'),
          const SizedBox(height: 8),
          Text(
            'İkincil bileşenler küçük açı yaklaşımıyla çözüm çizgisinden türetilir; ana «HESAPLA» ile aynı motor.',
            style: streLockLabelStyle(context).copyWith(fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }
}
