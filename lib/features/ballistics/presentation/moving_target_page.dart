import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ballistics/ballistics_engine.dart';
import '../../../core/ballistics/ballistics_export.dart';
import 'strelock_ballistics_ui.dart';

/// StreLok tarzı: hız + açı → çapraz hız; isteğe bağlı tam çözümle önleme ve retikül önizlemesi.
class MovingTargetLeadPage extends StatefulWidget {
  const MovingTargetLeadPage({
    super.key,
    required this.onApplyCrossTrackMps,
    this.baselineInput,
  });

  final void Function(double crossTrackMps) onApplyCrossTrackMps;

  /// Doluysa önleme mil/MOA ve daire önizleme hesaplanır.
  final BallisticsSolveInput? baselineInput;

  @override
  State<MovingTargetLeadPage> createState() => _MovingTargetLeadPageState();
}

class _MovingTargetLeadPageState extends State<MovingTargetLeadPage> {
  final _speedCtrl = TextEditingController(text: '3');
  final _angleCtrl = TextEditingController(text: '90');
  bool _kmH = false;
  bool _showMoa = false;

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

  BallisticsSolveOutput? _previewOut() {
    final b = widget.baselineInput;
    if (b == null) return null;
    try {
      return BallisticsEngine.solve(b.withTargetCrossTrackMps(_crossTrackMps()));
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareCsv() async {
    final b = widget.baselineInput;
    final o = _previewOut();
    if (b == null || o == null) return;
    final csv = multiRangeSolveToCsv([(b.distanceMeters.round(), o)]);
    await shareCsvText(csv, filename: 'blue_viper_moving_target.csv');
  }

  @override
  Widget build(BuildContext context) {
    final ct = _crossTrackMps();
    final out = _previewOut();
    final leadCm = out == null ? null : out.leadLateralDeltaMeters * 100.0;
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
          'Hareketli hedef',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: StreLockBalColors.headerOrange,
                fontWeight: FontWeight.w800,
              ),
        ),
        actions: [
          if (widget.baselineInput != null)
            TextButton(
              onPressed: () => unawaited(_shareCsv()),
              child: const Text('CSV'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (widget.baselineInput != null)
            Text(
              'Hedef mesafesi ≈ ${widget.baselineInput!.distanceMeters.toStringAsFixed(0)} m (formdan)',
              style: streLockLabelStyle(context).copyWith(color: StreLockBalColors.accentBlue),
            ),
          const SizedBox(height: 8),
          Text(
            'Hedefin yatay düzlemdeki hızı ve çizgiye göre açısından çapraz bileşen hesaplanır; '
            '«Çapraz hızı forma yaz» ile «Ek» sekmesindeki hedef çapraz hız alanına aktarılır.',
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
                  Text('Çapraz bileşen', style: streLockSectionStyle(context)),
                  const SizedBox(height: 6),
                  Text(
                    '${ct.toStringAsFixed(2)} m/s',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: StreLockBalColors.fieldText,
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (out != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Önleme mesafesi (yaklaşık): ${leadCm!.toStringAsFixed(1)} cm @ ${widget.baselineInput!.distanceMeters.toStringAsFixed(0)} m',
                    style: streLockLabelStyle(context),
                  ),
                ),
                Switch(
                  value: _showMoa,
                  onChanged: (v) => setState(() => _showMoa = v),
                ),
                Text(_showMoa ? 'MOA' : 'MRAD', style: streLockLabelStyle(context)),
              ],
            ),
            Text(
              _showMoa
                  ? 'Önleme: ${out.leadMoa.toStringAsFixed(2)} MOA'
                  : 'Önleme: ${out.leadMil.toStringAsFixed(2)} mil · ${out.leadClicks.toStringAsFixed(1)} klik',
              style: streLockSectionStyle(context),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _MovingReticlePainter(
                  leadMil: out.leadMil,
                  rangeM: widget.baselineInput!.distanceMeters,
                ),
                child: Center(
                  child: Text(
                    '∠ ${_angleCtrl.text}°',
                    style: streLockLabelStyle(context).copyWith(color: StreLockBalColors.accentBlue),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Alt şerit: kabaca menzil ölçeği (stadiametrik değil — görsel ipucu).',
              style: streLockLabelStyle(context).copyWith(fontSize: 11),
            ),
          ],
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

class _MovingReticlePainter extends CustomPainter {
  _MovingReticlePainter({required this.leadMil, required this.rangeM});

  final double leadMil;
  final double rangeM;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.48;
    final paint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r, paint);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), paint);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), paint);
    final pxPerMil = r * 0.08;
    final lx = leadMil * pxPerMil;
    canvas.drawCircle(Offset(c.dx + lx, c.dy), r * 0.06, Paint()..color = Colors.amberAccent);
    final stadia = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = -4; i <= 4; i++) {
      final x = c.dx + i * (r / 5);
      final h = (i.abs() + 1) * 3.0;
      canvas.drawLine(Offset(x, c.dy + r * 0.72), Offset(x, c.dy + r * 0.72 + h), stadia);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: '${rangeM.toStringAsFixed(0)} m',
        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy + r * 0.78));
  }

  @override
  bool shouldRepaint(covariant _MovingReticlePainter oldDelegate) =>
      oldDelegate.leadMil != leadMil || oldDelegate.rangeM != rangeM;
}
