import 'package:flutter/material.dart';

void main() => runApp(const BlueViperProApp());

class BlueViperProApp extends StatelessWidget {
  const BlueViperProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blue Viper Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _RootScaffold(),
    );
  }
}

class _RootScaffold extends StatefulWidget {
  const _RootScaffold();

  @override
  State<_RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<_RootScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _BallisticsPage(),
      const _MapMgrsPageStub(),
      const _BluetoothPageStub(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blue Viper Pro'),
      ),
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            label: 'Ballistics',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: 'Map (MGRS)',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            label: 'Bluetooth',
          ),
        ],
      ),
    );
  }
}

/// ---------------------------
/// Faz 1: çalışan balistik akış
/// ---------------------------
class _BallisticsPage extends StatefulWidget {
  const _BallisticsPage();

  @override
  State<_BallisticsPage> createState() => _BallisticsPageState();
}

class _BallisticsPageState extends State<_BallisticsPage> {
  final _formKey = GlobalKey<FormState>();

  final _distanceCtrl = TextEditingController(text: '500'); // m
  final _mvCtrl = TextEditingController(text: '800'); // m/s
  final _bcCtrl = TextEditingController(text: '0.45'); // BC (G1)
  final _tempCtrl = TextEditingController(text: '15'); // °C
  final _pressureCtrl = TextEditingController(text: '1013'); // hPa
  final _elevDeltaCtrl = TextEditingController(text: '0'); // m
  final _slopeCtrl = TextEditingController(text: '0'); // deg

  // Optik / klik sistemi (Faz 1)
  _ClickUnit _clickUnit = _ClickUnit.mil;
  final _clickValueCtrl = TextEditingController(text: '0.1'); // 0.1 mil/click

  _BallisticResult? _result;

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _mvCtrl.dispose();
    _bcCtrl.dispose();
    _tempCtrl.dispose();
    _pressureCtrl.dispose();
    _elevDeltaCtrl.dispose();
    _slopeCtrl.dispose();
    _clickValueCtrl.dispose();
    super.dispose();
  }

  void _solve() {
    if (!_formKey.currentState!.validate()) return;

    double parse(String s) => double.parse(s.replaceAll(',', '.'));

    final distance = parse(_distanceCtrl.text);
    final mv = parse(_mvCtrl.text);
    final bc = parse(_bcCtrl.text);
    final temp = parse(_tempCtrl.text);
    final pressure = parse(_pressureCtrl.text);
    final elevDelta = parse(_elevDeltaCtrl.text);
    final slope = parse(_slopeCtrl.text);

    final clickValue = parse(_clickValueCtrl.text);

    final solution = _simpleBallisticSolve(
      distanceMeters: distance,
      muzzleVelocityMps: mv,
      ballisticCoefficient: bc,
      temperatureC: temp,
      pressureHpa: pressure,
      targetElevationDeltaMeters: elevDelta,
      slopeAngleDegrees: slope,
    );

    final clicks = _clicksForCorrection(
      correctionMil: solution.dropMil,
      clickValue: clickValue,
      clickUnit: _clickUnit,
    );

    setState(() {
      _result = _BallisticResult(
        dropMil: solution.dropMil,
        dropMoA: solution.dropMoA,
        tofMs: solution.tofMs,
        clicks: clicks,
        clickUnit: _clickUnit,
        clickValue: clickValue,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const spacing = SizedBox(height: 12);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Text(
              'Balistik (Faz 1)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu Faz 1 sürümünde hesap motoru basitleştirilmiş bir yaklaşıktır. '
              'Sonraki fazlarda gerçek G1/G7 drag modeli + rüzgar + sıfır ayarı + '
              'eğim/rakım entegrasyonu detaylandırılır.',
            ),
            const Divider(height: 24),

            _numField(_distanceCtrl, 'Menzil', suffix: 'm'),
            spacing,
            _numField(_mvCtrl, 'Çıkış hızı', suffix: 'm/s'),
            spacing,
            _numField(_bcCtrl, 'Balistik katsayı (G1 BC)'),
            spacing,
            _numField(_tempCtrl, 'Sıcaklık', suffix: '°C'),
            spacing,
            _numField(_pressureCtrl, 'Basınç', suffix: 'hPa'),
            spacing,
            _numField(_elevDeltaCtrl, 'Hedef rakım farkı (+yukarı / -aşağı)',
                suffix: 'm'),
            spacing,
            _numField(_slopeCtrl, 'Eğim açısı', suffix: '°'),
            const Divider(height: 24),

            const Text(
              'Optik / Klik',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<_ClickUnit>(
              value: _clickUnit,
              items: const [
                DropdownMenuItem(
                  value: _ClickUnit.mil,
                  child: Text('MIL (mrad)'),
                ),
                DropdownMenuItem(
                  value: _ClickUnit.moa,
                  child: Text('MOA'),
                ),
                DropdownMenuItem(
                  value: _ClickUnit.cmPer100m,
                  child: Text('cm / 100m'),
                ),
                DropdownMenuItem(
                  value: _ClickUnit.inPer100yd,
                  child: Text('in / 100yd'),
                ),
              ],
              onChanged: (v) => setState(() => _clickUnit = v ?? _clickUnit),
              decoration: const InputDecoration(
                labelText: 'Klik birimi',
                border: OutlineInputBorder(),
              ),
            ),
            spacing,
            _numField(_clickValueCtrl, 'Klik değeri (seçtiğin birime göre)'),
            spacing,

            ElevatedButton.icon(
              onPressed: _solve,
              icon: const Icon(Icons.calculate),
              label: const Text('Hesapla'),
            ),

            const SizedBox(height: 16),
            if (_result != null) _ResultCard(result: _result!),
          ],
        ),
      ),
    );
  }

  Widget _numField(
    TextEditingController c,
    String label, {
    String? suffix,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Boş olamaz';
        final v = double.tryParse(value.replaceAll(',', '.'));
        if (v == null) return 'Sayı gir';
        return null;
      },
    );
  }
}

enum _ClickUnit { mil, moa, cmPer100m, inPer100yd }

class _BallisticSolveOutput {
  final double dropMil;
  final double dropMoA;
  final double tofMs;

  const _BallisticSolveOutput({
    required this.dropMil,
    required this.dropMoA,
    required this.tofMs,
  });
}

class _BallisticResult {
  final double dropMil;
  final double dropMoA;
  final double tofMs;

  final double clicks;
  final _ClickUnit clickUnit;
  final double clickValue;

  const _BallisticResult({
    required this.dropMil,
    required this.dropMoA,
    required this.tofMs,
    required this.clicks,
    required this.clickUnit,
    required this.clickValue,
  });
}

class _ResultCard extends StatelessWidget {
  final _BallisticResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    String unitLabel(_ClickUnit u) => switch (u) {
          _ClickUnit.mil => 'mil/click',
          _ClickUnit.moa => 'MOA/click',
          _ClickUnit.cmPer100m => 'cm/100m per click',
          _ClickUnit.inPer100yd => 'in/100yd per click',
        };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sonuç',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _kv('Drop', '${result.dropMil.toStringAsFixed(2)} mil'),
            _kv('Drop', '${result.dropMoA.toStringAsFixed(2)} MOA'),
            _kv('TOF', '${result.tofMs.toStringAsFixed(0)} ms'),
            const Divider(height: 24),
            _kv(
              'Klik ayarı',
              '${result.clicks.toStringAsFixed(1)} clicks '
              '(klik=${result.clickValue} ${unitLabel(result.clickUnit)})',
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k),
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

double _clicksForCorrection({
  required double correctionMil,
  required double clickValue,
  required _ClickUnit clickUnit,
}) {
  // correctionMil: mil cinsinden düzeltme.
  // clickValue + clickUnit: kullanıcının optiği.
  // Burada hepsini "mil" karşılığına çevirip klik sayısını buluyoruz.

  double clickInMil() {
    // 1 mil ≈ 3.438 MOA
    // Linear clickler için:
    // - mil ≈ (linear / distance)*1000 ; burada 100m ve 100yd sabitine göre yaklaşıyoruz.
    switch (clickUnit) {
      case _ClickUnit.mil:
        return clickValue;
      case _ClickUnit.moa:
        return clickValue / 3.438;
      case _ClickUnit.cmPer100m:
        // 1 mil @100m = 10 cm
        return clickValue / 10.0;
      case _ClickUnit.inPer100yd:
        // 1 mil @100yd ≈ 3.6 inch
        return clickValue / 3.6;
    }
  }

  final perClickMil = clickInMil();
  if (perClickMil <= 0) return 0;
  return correctionMil / perClickMil;
}

_BallisticSolveOutput _simpleBallisticSolve({
  required double distanceMeters,
  required double muzzleVelocityMps,
  required double ballisticCoefficient,
  required double temperatureC,
  required double pressureHpa,
  required double targetElevationDeltaMeters,
  required double slopeAngleDegrees,
}) {
  final g = 9.81;

  // Basit uçuş süresi: t = s / v
  final t = distanceMeters / muzzleVelocityMps;

  // Serbest düşüş: d = 0.5*g*t^2
  var dropMeters = 0.5 * g * t * t;

  // BC etkisi (kaba): BC büyüdükçe düşüş azalır
  dropMeters *= (1.0 / (0.5 + ballisticCoefficient));

  // Ortam düzeltmesi (kaba)
  final tempFactor = 1 + (temperatureC - 15) * 0.003;
  final pressureFactor = 1 + (pressureHpa - 1013) * -0.0003;
  dropMeters *= tempFactor * pressureFactor;

  // Hedef yukarıdaysa (pozitif elev delta) biraz daha az drop varsayımı (kaba)
  dropMeters -= targetElevationDeltaMeters * 0.01;

  // Eğim büyüdükçe etkisi azalsın (kaba)
  dropMeters *= (1 - slopeAngleDegrees.abs() * 0.003);

  // mil dönüşümü (yaklaşık): mil ≈ (drop / distance) * 1000
  final dropMil = (dropMeters / distanceMeters) * 1000;

  // MOA dönüşümü: 1 mil ≈ 3.438 MOA
  final dropMoA = dropMil * 3.438;

  return _BallisticSolveOutput(
    dropMil: dropMil,
    dropMoA: dropMoA,
    tofMs: t * 1000,
  );
}

/// ---------------------------
/// Faz 1 stub: Harita + MGRS
/// ---------------------------
class _MapMgrsPageStub extends StatelessWidget {
  const _MapMgrsPageStub();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Map + MGRS (Faz 1 stub)\n\n'
          'Sonraki adım:\n'
          '- Online harita\n'
          '- Konum izni + anlık konum\n'
          '- Haritada hedef noktası seçimi\n'
          '- Mesafe / azimut / eğim / rakım farkı\n'
          '- MGRS gösterimi',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// ---------------------------
/// Faz 1 stub: Bluetooth
/// ---------------------------
class _BluetoothPageStub extends StatelessWidget {
  const _BluetoothPageStub();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Bluetooth (Faz 1 stub)\n\n'
          'Sonraki adım:\n'
          '- Cihaz tarama\n'
          '- Bağlanma\n'
          '- Mesafe ölçer / sensör verisi alma',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}