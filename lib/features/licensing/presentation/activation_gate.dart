import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/licensing/activation_config.dart';
import '../../../core/licensing/activation_store.dart';
import '../../../core/licensing/device_identity.dart';
import '../../../core/realtime/map_room_deep_link_controller.dart';
import '../../../core/realtime/map_room_invite_link.dart';
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
  StreamSubscription<Uri>? _haritaOdaLinkSub;

  @override
  void initState() {
    super.initState();
    unawaited(_initHaritaOdaDeepLinks());
    _haritaOdaLinkSub =
        AppLinks().uriLinkStream.listen(_onHaritaOdaUri, onError: (_) {});
    _check();
  }

  @override
  void dispose() {
    _haritaOdaLinkSub?.cancel();
    super.dispose();
  }

  Future<void> _initHaritaOdaDeepLinks() async {
    try {
      final initial = await AppLinks().getInitialLink();
      if (initial != null) _onHaritaOdaUri(initial);
    } catch (_) {}
  }

  void _onHaritaOdaUri(Uri uri) {
    final invite = MapRoomInviteLink.tryParse(uri);
    if (invite == null) return;
    MapRoomDeepLinkController.instance.offer(invite);
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
