import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'strelock_ballistics_ui.dart';

/// StreLok tarzı: hedef hızı ve yönünden çapraz bileşeni hesaplayıp forma yazdırma.
class MovingTargetLeadPage extends StatefulWidget {
  const MovingTargetLeadPage({super.key, required this.onApplyCrossTrackMps});

  final void Function(double crossTrackMps) onApplyCrossTrackMps;

  @override
  State<MovingTargetLeadPage> createState() => _MovingTargetLeadPageState();
}

class _MovingTargetLeadPageState extends State<MovingTargetLeadPage> {
  final _speedCtrl = TextEditingController(text: '3');
  final _angleCtrl = TextEditingController(text: '90');
  bool _kmH = false;

  @override
  void dispose() {
    _speedCtrl.dispose();
    _angleCtrl.dispose();
    super.dispose();
  }

  double _crossTrackMps() {
    final s = double.tryParse(_speedCtrl.text.replaceAll(',', '.')) ?? 0;
    final deg = double.tryParse(_angleCtrl.text.replaceAll(',', '.')) ?? 90;
    final v = _kmH ? s / 3.6 : s;
    final rad = deg * math.pi / 180.0;
    return v * math.sin(rad);
  }

  @override
  Widget build(BuildContext context) {
    final ct = _crossTrackMps();
    return Scaffold(
      backgroundColor: StreLockBalColors.scaffold,
      appBar: AppBar(
        backgroundColor: StreLockBalColors.scaffold,
        foregroundColor: StreLockBalColors.label,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Hareketli hedef öncüsü',
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
            'Hedefin yatay düzlemdeki hızı ve çizgiye göre açısından çapraz (line-of-sight’e dik) '
            'bileşen hesaplanır; bu değer «Ek» sekmesindeki «Hedef çapraz hız» alanına yazılır.',
            style: streLockLabelStyle(context).copyWith(height: 1.35),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hız birimi km/h'),
            subtitle: Text(_kmH ? 'Girilen değer km/h' : 'Girilen değer m/s'),
            value: _kmH,
            onChanged: (v) => setState(() => _kmH = v),
          ),
          TextFormField(
            controller: _speedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _kmH ? 'Hedef hızı (km/h)' : 'Hedef hızı (m/s)',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _angleCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Hareket yönü — nişan çizgisine göre açı (°)',
              helperText: '0°: nişan hattı boyunca · 90°: tam çapraz (maks. öncü)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Material(
            color: StreLockBalColors.fieldFill,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Çapraz bileşen',
                    style: streLockSectionStyle(context),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${ct.toStringAsFixed(2)} m/s',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: StreLockBalColors.fieldText,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Formül: v × sin(açı). İşaret: sahada hedef sağa gidiyorsa öncü yönünü forma göre doğrulayın.',
                    style: streLockLabelStyle(context).copyWith(fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              widget.onApplyCrossTrackMps(ct);
              Navigator.of(context).pop(true);
            },
            icon: const Icon(Icons.playlist_add),
            label: const Text('Çapraz hızı forma yaz'),
          ),
        ],
      ),
    );
  }
}
