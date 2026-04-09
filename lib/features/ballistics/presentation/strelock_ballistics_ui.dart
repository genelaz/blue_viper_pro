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
