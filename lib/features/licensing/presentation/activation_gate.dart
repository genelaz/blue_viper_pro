import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/licensing/activation_config.dart';
import '../../../core/licensing/activation_store.dart';
import '../../../core/licensing/device_identity.dart';
import 'activation_screen.dart';

/// Aktivasyon tamamlanmadan ana uygulamayı göstermez.
/// Uzak modda: kayıtlı cihaz kimliği değişirse oturumu sıfırlar.
class ActivationGate extends StatefulWidget {
  const ActivationGate({super.key, required this.child});

  final Widget child;

  @override
  State<ActivationGate> createState() => _ActivationGateState();
}

class _ActivationGateState extends State<ActivationGate> {
  bool _loading = true;
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await ActivationStore.isActivated();
    if (!ok) {
      if (mounted) {
        setState(() {
          _activated = false;
          _loading = false;
        });
      }
      return;
    }

    if (ActivationConfig.useRemoteBinding) {
      final usedRemote = await ActivationStore.usedRemoteBinding();
      if (!usedRemote) {
        await ActivationStore.clearAll();
        if (mounted) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tek cihaz kilidi: sunucu ile yeniden aktivasyon gerekir.'),
              ),
            );
          });
        }
        if (mounted) {
          setState(() {
            _activated = false;
            _loading = false;
          });
        }
        return;
      }

      final stored = await ActivationStore.storedDeviceId();
      final current = await getDeviceActivationId();
      if (stored != null &&
          stored.isNotEmpty &&
          current.isNotEmpty &&
          current != 'unknown' &&
          current != 'unsupported' &&
          current != stored) {
        await ActivationStore.clearAll();
        if (mounted) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Lisans bu telefonla eşleşmiyor (kod başka cihaza bağlı olabilir).',
                ),
              ),
            );
          });
        }
        if (mounted) {
          setState(() {
            _activated = false;
            _loading = false;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _activated = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_activated) {
      return ActivationScreen(
        onActivated: () => setState(() => _activated = true),
      );
    }
    return widget.child;
  }
}
