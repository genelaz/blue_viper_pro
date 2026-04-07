enum ClickUnit {
  mil,
  moa,
  cmPer100m,
  inPer100yd,
}

extension ClickUnitLabel on ClickUnit {
  String get label => switch (this) {
        ClickUnit.mil => 'MIL (mrad)',
        ClickUnit.moa => 'MOA',
        ClickUnit.cmPer100m => 'cm / 100m',
        ClickUnit.inPer100yd => 'in / 100yd',
      };
}

