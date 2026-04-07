import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/geo/app_bootstrap_prefs.dart';

/// İlk açılış: konum (+ isteğe bağlı Bluetooth) izinleri; harita kullanımı için.
class StartupPermissionsPage extends StatefulWidget {
  const StartupPermissionsPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<StartupPermissionsPage> createState() => _StartupPermissionsPageState();
}

class _StartupPermissionsPageState extends State<StartupPermissionsPage> {
  String _msg = '';

  Future<void> _requestLocation() async {
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) {
      setState(() => _msg = 'Cihazda konum (GPS) kapalı; sistem ayarlarından açın.');
      await Geolocator.openLocationSettings();
      return;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      setState(() => _msg = 'Konum kalıcı kapalı; Uygulama ayarlarından izin verin.');
      await openAppSettings();
      return;
    }
    setState(() {
      _msg = p == LocationPermission.always || p == LocationPermission.whileInUse
          ? 'Konum izni verildi. Harita sekmesinde konumunuz güncellenir.'
          : 'Konum izni yok; «Konumumu al» ile tekrar deneyebilirsiniz.';
    });
  }

  Future<void> _requestBluetoothOptional() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    if (!mounted) return;
    setState(() => _msg = 'Bluetooth izinleri istendi (Kestrel / BLE).');
  }

  Future<void> _continue() async {
    await AppBootstrapPrefs.setIntroDone();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.map_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Blue Viper Pro',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Harita, menzil ve balistik aktarımı için konum kullanılır. '
                'İlk kurulumda izin vermeniz önerilir. Bluetooth isteğe bağlıdır (çevresel ölçüm).',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Not:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Yurtta Sulh, Cihanda Sulh Gazı Mustafa Kemal ATATÜRK',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_msg.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade800)),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: _requestLocation,
                icon: const Icon(Icons.location_searching),
                label: const Text('Konum iznini iste'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _requestBluetoothOptional,
                icon: const Icon(Icons.bluetooth),
                label: const Text('Bluetooth (isteğe bağlı)'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _continue,
                child: const Text('Uygulamaya geç'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
