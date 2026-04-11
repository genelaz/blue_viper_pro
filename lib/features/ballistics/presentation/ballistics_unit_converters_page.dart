import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'strelock_ballistics_ui.dart';

/// StreLok «Dönüştürücüler» listesindeki pratik araçlar (saf matematik).
class BallisticsUnitConvertersPage extends StatefulWidget {
  const BallisticsUnitConvertersPage({super.key});

  @override
  State<BallisticsUnitConvertersPage> createState() => _BallisticsUnitConvertersPageState();
}

class _BallisticsUnitConvertersPageState extends State<BallisticsUnitConvertersPage> {
  final _d1 = TextEditingController(text: '100');
  final _d2 = TextEditingController(text: '250');
  final _mil = TextEditingController(text: '1');
  final _rangeM = TextEditingController(text: '1000');
  final _grain = TextEditingController(text: '175');
  final _gram = TextEditingController(text: '11.3');
  final _hpa = TextEditingController(text: '1013');
  final _lbft = TextEditingController(text: '40');
  final _torqueNm = TextEditingController(text: '68');
  final _bcV1 = TextEditingController(text: '800');
  final _bcV2 = TextEditingController(text: '780');
  final _bcR = TextEditingController(text: '100');

  @override
  void dispose() {
    for (final c in [
      _d1,
      _d2,
      _mil,
      _rangeM,
      _grain,
      _gram,
      _hpa,
      _lbft,
      _torqueNm,
      _bcV1,
      _bcV2,
      _bcR,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _p(String s) => double.tryParse(s.replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final dA = _p(_d1.text) ?? 0;
    final dB = _p(_d2.text) ?? 0;
    final deltaM = (dB - dA).abs();
    final milVal = _p(_mil.text) ?? 0;
    final rM = _p(_rangeM.text) ?? 1000;
    final cmFromMil = rM * milVal * 0.1;
    final moaFromMil = milVal * 3.43774677;
    final gr = _p(_grain.text);
    final gm = _p(_gram.text);
    final gramFromGrain = gr != null ? gr * 0.06479891 : null;
    final grainFromGram = gm != null ? gm / 0.06479891 : null;
    final hpa = _p(_hpa.text) ?? 0;
    final inHg = hpa / 33.8638866667;
    final mmHg = hpa / 1.33322;
    final psi = hpa / 68.9475729328;
    final lbft = _p(_lbft.text) ?? 0;
    final tNm = _p(_torqueNm.text) ?? 0;
    final v1 = _p(_bcV1.text);
    final v2 = _p(_bcV2.text);
    final rr = _p(_bcR.text);
    double? bcHint;
    if (v1 != null && v2 != null && rr != null && rr > 1 && (v1 - v2).abs() > 0.5) {
      bcHint = v1 / (v2 + (v1 - v2) * (800.0 / rr).clamp(0.0, 1.0));
    }

    Widget sec(String title, List<Widget> kids) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Material(
            color: StreLockBalColors.fieldFill,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: streLockSectionStyle(context)),
                  const SizedBox(height: 8),
                  ...kids,
                ],
              ),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: StreLockBalColors.scaffold,
      appBar: AppBar(
        backgroundColor: StreLockBalColors.scaffold,
        foregroundColor: StreLockBalColors.label,
        title: Text(
          'Birim araçları',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: StreLockBalColors.headerOrange,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Sonuçlar yaklaşıktır; dürbün / üretici tanımlarına güvenin.',
            style: streLockLabelStyle(context).copyWith(height: 1.3),
          ),
          const SizedBox(height: 12),
          sec('Mesafe farkı', [
            TextField(
              controller: _d1,
              decoration: const InputDecoration(labelText: 'Nokta A (m)', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _d2,
              decoration: const InputDecoration(labelText: 'Nokta B (m)', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text('|A−B| = ${deltaM.toStringAsFixed(1)} m', style: streLockLabelStyle(context)),
          ]),
          sec('Mesafeye göre mil → MOA / cm', [
            TextField(
              controller: _rangeM,
              decoration: const InputDecoration(labelText: 'Menzil (m)', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mil,
              decoration: const InputDecoration(labelText: 'Açı (mil)', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text('≈ ${moaFromMil.toStringAsFixed(2)} MOA (lineer 3,4377×)', style: streLockLabelStyle(context)),
            Text('≈ ${cmFromMil.toStringAsFixed(1)} cm (yaklaşık subtension)', style: streLockLabelStyle(context)),
          ]),
          sec('Açı', [
            Text('90° = ${(math.pi / 2).toStringAsFixed(4)} rad', style: streLockLabelStyle(context)),
            Text('1 rad = ${(180 / math.pi).toStringAsFixed(3)}°', style: streLockLabelStyle(context)),
            Text('1 mil (NATO) ≈ ${(360 / 6400).toStringAsFixed(6)}°', style: streLockLabelStyle(context)),
          ]),
          sec('Hız', [
            Text('10 m/s = ${(10 * 3.6).toStringAsFixed(1)} km/h', style: streLockLabelStyle(context)),
            Text('100 km/h = ${(100 / 3.6).toStringAsFixed(2)} m/s', style: streLockLabelStyle(context)),
          ]),
          sec('Ağırlık', [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _grain,
                    decoration: const InputDecoration(labelText: 'Grain', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _gram,
                    decoration: const InputDecoration(labelText: 'Gram', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (gramFromGrain != null) Text('→ ${gramFromGrain.toStringAsFixed(2)} g', style: streLockLabelStyle(context)),
            if (grainFromGram != null) Text('→ ${grainFromGram.toStringAsFixed(1)} gr', style: streLockLabelStyle(context)),
          ]),
          sec('Basınç (hPa giriş)', [
            TextField(
              controller: _hpa,
              decoration: const InputDecoration(labelText: 'hPa', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            Text('inHg: ${inHg.toStringAsFixed(2)}', style: streLockLabelStyle(context)),
            Text('mmHg: ${mmHg.toStringAsFixed(1)}', style: streLockLabelStyle(context)),
            Text('psi: ${psi.toStringAsFixed(2)}', style: streLockLabelStyle(context)),
          ]),
          sec('Uzunluk', [
            Text('1 in = 25,4 mm', style: streLockLabelStyle(context)),
            Text('1 ft = 0,3048 m', style: streLockLabelStyle(context)),
          ]),
          sec('Tork', [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _torqueNm,
                    decoration: const InputDecoration(labelText: 'N·m', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lbft,
                    decoration: const InputDecoration(labelText: 'lb·ft', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            Text(
              'N·m→lb·ft: ${(tNm * 0.737562149).toStringAsFixed(1)} · lb·ft→N·m: ${(lbft / 0.737562149).toStringAsFixed(1)}',
              style: streLockLabelStyle(context),
            ),
          ]),
          sec('BC ipucu (iki Vo, kaba)', [
            TextField(controller: _bcV1, decoration: const InputDecoration(labelText: 'Vo₁ m/s', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            TextField(controller: _bcV2, decoration: const InputDecoration(labelText: 'Vo₂ m/s', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            TextField(controller: _bcR, decoration: const InputDecoration(labelText: 'Referans m', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            Text(
              bcHint == null ? 'Geçerli iki hız girin (yaklaşık oran).' : 'Oran ipucu ≈ ${bcHint.toStringAsFixed(3)} (Vo düşüşüne göre)',
              style: streLockLabelStyle(context),
            ),
          ]),
          sec('Tık doğrulama (mil → tık)', [
            Text(
              'Örnek: 1,25 mil düzeltme, 0,1 mil tık → ${(1.25 / 0.1).toStringAsFixed(1)} tık',
              style: streLockLabelStyle(context),
            ),
          ]),
        ],
      ),
    );
  }
}
