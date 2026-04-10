import 'dart:async';

import 'package:flutter/widgets.dart';

/// Soğuk açılışta 8 sn; arka plandan [resumed] ile dönüşte 3 sn gösterilir.
class DeveloperCreditShell extends StatefulWidget {
  const DeveloperCreditShell({super.key, required this.child});

  final Widget child;

  @override
  State<DeveloperCreditShell> createState() => _DeveloperCreditShellState();
}

class _DeveloperCreditShellState extends State<DeveloperCreditShell>
    with WidgetsBindingObserver {
  static const _message = 'Hüsnü Aydın tarafından geliştirilmektedir.';
  static const _durationColdStart = Duration(seconds: 8);
  static const _durationResume = Duration(seconds: 3);

  Timer? _timer;
  bool _visible = false;
  AppLifecycleState? _lastLifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _armOverlay(_durationColdStart));
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final prev = _lastLifecycle;
      if (prev == AppLifecycleState.paused ||
          prev == AppLifecycleState.inactive ||
          prev == AppLifecycleState.hidden) {
        _armOverlay(_durationResume);
      }
    }
    _lastLifecycle = state;
  }

  void _armOverlay(Duration visibleFor) {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _visible = true);
    _timer = Timer(visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_visible)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ColoredBox(
                color: const Color(0xB8000000),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF5F5F5),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        shadows: [
                          Shadow(blurRadius: 12, color: Color(0xCC000000)),
                          Shadow(blurRadius: 4, offset: Offset(0, 1), color: Color(0x99000000)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
