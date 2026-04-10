import 'dart:math' as math;

import 'package:flutter/material.dart';

/// StreLok-benzeri koyu ayar ekranları — ortak renk ve satır bileşenleri.
abstract final class StreLockBalColors {
  static const Color scaffold = Color(0xFF2B2B2D);
  static const Color headerOrange = Color(0xFFFF9800);
  static const Color headerYellow = Color(0xFFFFEB3B);
  static const Color titleBlue = Color(0xFF7EC8E3);
  static const Color label = Color(0xFFE8E8E8);
  static const Color fieldFill = Color(0xFFFFFFFF);
  static const Color fieldText = Color(0xFF1565C0);
  static const Color accentBlue = Color(0xFF1976D2);
  static const Color resultRed = Color(0xFFE53935);
  static const Color resultGreen = Color(0xFF69F0AE);
  static const Color footerBar = Color(0xFFE0E0E0);
  static const Color switchOn = Color(0xFFFF9800);
}

/// [BallisticsPage] gövdesi — koyu StreLok paleti + okunaklı formlar.
ThemeData streLockBallisticsTheme(BuildContext context) {
  const scaffold = StreLockBalColors.scaffold;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: scaffold,
    colorScheme: ColorScheme.dark(
      primary: StreLockBalColors.headerOrange,
      onPrimary: Colors.black,
      secondary: StreLockBalColors.titleBlue,
      onSecondary: Colors.black,
      surface: const Color(0xFF323234),
      onSurface: StreLockBalColors.label,
      surfaceContainerHighest: const Color(0xFF3C3C3F),
      outline: Colors.white24,
      outlineVariant: Colors.white10,
    ),
    dividerColor: Colors.white12,
    tabBarTheme: TabBarThemeData(
      indicatorColor: StreLockBalColors.titleBlue,
      labelColor: StreLockBalColors.titleBlue,
      unselectedLabelColor: StreLockBalColors.label.withValues(alpha: 0.65),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      labelStyle: const TextStyle(color: StreLockBalColors.label),
      hintStyle: TextStyle(color: StreLockBalColors.label.withValues(alpha: 0.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: StreLockBalColors.titleBlue, width: 2),
      ),
    ),
    textTheme: Theme.of(context).textTheme.apply(
          bodyColor: StreLockBalColors.label,
          displayColor: StreLockBalColors.label,
        ),
  );
}

/// Kestrel tarzı: dış halka = meteorolojik **rüzgâr kaynağı yönü** (kuzeyden °), dokun/sürükle.
/// Sıcaklık / basınç / nem / DA metinleri halkanın içinde köşelerde; merkezde derece.
class StreLockKestrelMetWindDial extends StatefulWidget {
  const StreLockKestrelMetWindDial({
    super.key,
    required this.windFromDegrees,
    required this.onWindFromChanged,
    required this.windSpeedMps,
    required this.temperatureLine,
    required this.pressureLine,
    required this.humidityLine,
    this.densityAltitudeLine,
    this.useMetWindVector = true,
  });

  /// Kuzeyden saat yönünde, 0–360° (meteorolojik «rüzgâr kaynağı»).
  final double windFromDegrees;
  final ValueChanged<double> onWindFromChanged;
  final String windSpeedMps;
  final String temperatureLine;
  final String pressureLine;
  final String humidityLine;
  final String? densityAltitudeLine;
  final bool useMetWindVector;

  @override
  State<StreLockKestrelMetWindDial> createState() => _StreLockKestrelMetWindDialState();
}

class _StreLockKestrelMetWindDialState extends State<StreLockKestrelMetWindDial> {
  late double _deg;

  @override
  void initState() {
    super.initState();
    _deg = _normDeg(widget.windFromDegrees);
  }

  @override
  void didUpdateWidget(covariant StreLockKestrelMetWindDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windFromDegrees != widget.windFromDegrees) {
      _deg = _normDeg(widget.windFromDegrees);
    }
  }

  static double _normDeg(double d) {
    var x = d % 360;
    if (x < 0) x += 360;
    return x;
  }

  void _setFromLocal(Offset local, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final dx = local.dx - c.dx;
    final dy = local.dy - c.dy;
    if (dx * dx + dy * dy < 16) return;
    var deg = math.atan2(dx, -dy) * 180 / math.pi;
    if (deg < 0) deg += 360;
    setState(() => _deg = deg);
    widget.onWindFromChanged(_deg);
  }

  @override
  Widget build(BuildContext context) {
    final small = streLockLabelStyle(context).copyWith(fontSize: 10, height: 1.15);
    final centerDeg = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: StreLockBalColors.fieldFill,
          fontWeight: FontWeight.w800,
        );

    return LayoutBuilder(
      builder: (context, c) {
        final side = math.min(c.maxWidth, 260.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: SizedBox(
                width: side,
                height: side,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (e) => _setFromLocal(e.localPosition, Size(side, side)),
                  onPanUpdate: (e) => _setFromLocal(e.localPosition, Size(side, side)),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: Size(side, side),
                        painter: _KestrelWindDialRingPainter(
                          tickColor: StreLockBalColors.titleBlue.withValues(alpha: 0.45),
                          ringColor: StreLockBalColors.headerOrange.withValues(alpha: 0.55),
                        ),
                      ),
                      CustomPaint(
                        size: Size(side, side),
                        painter: _KestrelWindArrowPainter(
                          windFromDegrees: _deg,
                          arrowColor: StreLockBalColors.resultRed,
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.temperatureLine,
                                style: small,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                widget.humidityLine,
                                textAlign: TextAlign.end,
                                style: small,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_deg.toStringAsFixed(0)}°', style: centerDeg),
                            Text(
                              'kuzeyden',
                              style: small.copyWith(fontSize: 9),
                            ),
                            if (widget.densityAltitudeLine != null &&
                                widget.densityAltitudeLine!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.densityAltitudeLine!,
                                textAlign: TextAlign.center,
                                style: small,
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              widget.pressureLine,
                              textAlign: TextAlign.center,
                              style: small,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: Text(
                          'Rüzgâr hızı, m/s: ${widget.windSpeedMps}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: StreLockBalColors.resultGreen,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!widget.useMetWindVector)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Yan rüzgâr modunda çözüm alanları aşağıda; tam vektör için «Met rüzgârı» seçeneğini açın.',
                  textAlign: TextAlign.center,
                  style: streLockLabelStyle(context).copyWith(fontSize: 11),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KestrelWindDialRingPainter extends CustomPainter {
  _KestrelWindDialRingPainter({required this.tickColor, required this.ringColor});

  final Color tickColor;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = ringColor;
    canvas.drawCircle(c, r - 4, ring);
    final tick = Paint()
      ..strokeWidth = 1.2
      ..color = tickColor;
    for (var i = 0; i < 36; i++) {
      final ang = i * math.pi * 2 / 36;
      final long = i % 3 == 0;
      final r0 = r - (long ? 18 : 12);
      final r1 = r - 7;
      canvas.drawLine(
        Offset(c.dx + r0 * math.sin(ang), c.dy - r0 * math.cos(ang)),
        Offset(c.dx + r1 * math.sin(ang), c.dy - r1 * math.cos(ang)),
        tick,
      );
    }
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    void drawCardinal(String label, double degFromNorth) {
      final ang = degFromNorth * math.pi / 180;
      final x = c.dx + (r - 26) * math.sin(ang);
      final y = c.dy - (r - 26) * math.cos(ang);
      tp.text = TextSpan(
        text: label,
        style: TextStyle(
          color: StreLockBalColors.label.withValues(alpha: 0.85),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    drawCardinal('12', 0);
    drawCardinal('3', 90);
    drawCardinal('6', 180);
    drawCardinal('9', 270);
  }

  @override
  bool shouldRepaint(covariant _KestrelWindDialRingPainter oldDelegate) =>
      oldDelegate.tickColor != tickColor || oldDelegate.ringColor != ringColor;
}

/// Ok, rüzgârın **geldiği** yöne doğru (meteorolojik kaynak).
class _KestrelWindArrowPainter extends CustomPainter {
  _KestrelWindArrowPainter({required this.windFromDegrees, required this.arrowColor});

  final double windFromDegrees;
  final Color arrowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 * 0.42;
    final rad = (windFromDegrees * math.pi / 180) - math.pi / 2;
    final tip = Offset(c.dx + r * math.cos(rad), c.dy + r * math.sin(rad));
    final perp = Offset(-math.sin(rad), math.cos(rad)) * 10.0;
    final base = c + Offset(math.cos(rad), math.sin(rad)) * (r * 0.35);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + perp.dx, base.dy + perp.dy)
      ..lineTo(base.dx - perp.dx, base.dy - perp.dy)
      ..close();
    final fill = Paint()..color = arrowColor;
    canvas.drawPath(path, fill);
    final stem = Paint()
      ..color = arrowColor.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(c, base, stem);
  }

  @override
  bool shouldRepaint(covariant _KestrelWindArrowPainter oldDelegate) =>
      oldDelegate.windFromDegrees != windFromDegrees || oldDelegate.arrowColor != arrowColor;
}

TextStyle streLockLabelStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(color: StreLockBalColors.label, height: 1.25) ??
    const TextStyle(color: StreLockBalColors.label, fontSize: 14);

TextStyle streLockSectionStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleSmall?.copyWith(
          color: StreLockBalColors.headerYellow,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ) ??
    const TextStyle(
      color: StreLockBalColors.headerYellow,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );

/// Sol etiket, sağda beyaz yuvarlak alan (StreLok satırı).
class StreLockLabeledField extends StatelessWidget {
  const StreLockLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.suffix,
    this.fieldWidth = 120,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final int maxLines;
  final String? suffix;
  final double fieldWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(label, style: streLockLabelStyle(context)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: fieldWidth,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: const TextStyle(
                color: StreLockBalColors.fieldText,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: StreLockBalColors.fieldFill,
                isDense: true,
                suffixText: suffix,
                suffixStyle: const TextStyle(color: StreLockBalColors.fieldText, fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StreLockSectionHeader extends StatelessWidget {
  const StreLockSectionHeader(this.text, {super.key, this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        text,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: streLockSectionStyle(context),
      ),
    );
  }
}

class StreLockToggleRow extends StatelessWidget {
  const StreLockToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: streLockLabelStyle(context))),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: StreLockBalColors.switchOn.withValues(alpha: 0.55),
            activeThumbColor: StreLockBalColors.switchOn,
          ),
        ],
      ),
    );
  }
}

class StreLockFooterBar extends StatelessWidget {
  const StreLockFooterBar({
    super.key,
    this.leftLabel = 'Kaydet',
    this.rightLabel = 'Vazgeç',
    required this.onLeft,
    required this.onRight,
  });

  final String leftLabel;
  final String rightLabel;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StreLockBalColors.footerBar,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              TextButton(
                onPressed: onLeft,
                child: Text(leftLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              TextButton(
                onPressed: onRight,
                child: Text(rightLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StreLockFullButton extends StatelessWidget {
  const StreLockFullButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.foregroundColor = StreLockBalColors.accentBlue,
  });

  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: StreLockBalColors.fieldFill,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kompakt dropdown — beyaz kutu.
class StreLockDropdown<T> extends StatelessWidget {
  const StreLockDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(label, style: streLockLabelStyle(context))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: StreLockBalColors.fieldFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                items: items,
                onChanged: onChanged,
                style: const TextStyle(
                  color: StreLockBalColors.fieldText,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                dropdownColor: StreLockBalColors.fieldFill,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
