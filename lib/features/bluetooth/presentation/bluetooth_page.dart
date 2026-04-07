import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/bluetooth/ballistics_env_bridge.dart';
import '../../../core/bluetooth/ble_nordic_probe.dart';
import '../../../core/bluetooth/ble_standard_env.dart';

/// Kestrel / çevresel BLE cihazları için tarama. Ortam ölçümü servisleri cihaza göre değişir.
class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  StreamSubscription<List<ScanResult>>? _scanSub;
  final List<ScanResult> _results = [];
  String _status = 'Hazır';
  bool _scanning = false;

  @override
  void dispose() {
    unawaited(_scanSub?.cancel());
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    await _scanSub?.cancel();
    _scanSub = null;
    setState(() {
      _results.clear();
      _scanning = true;
      _status = 'Taranıyor… (8 sn)';
    });
    try {
      if (await FlutterBluePlus.isSupported == false) {
        setState(() => _status = 'Bu cihaz BLE desteklemiyor.');
        return;
      }
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        setState(() => _status = 'Bluetooth kapalı. Sistem ayarlarından açın.');
        return;
      }
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
      _scanSub = FlutterBluePlus.scanResults.listen((list) {
        setState(() {
          _results
            ..clear()
            ..addAll(list);
        });
      });
      await Future<void>.delayed(const Duration(seconds: 8));
      await FlutterBluePlus.stopScan();
      setState(() {
        _scanning = false;
        _status = 'Tarama bitti. ${_results.length} sonuç.';
      });
    } catch (e) {
      setState(() {
        _scanning = false;
        _status = 'Hata: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _status,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: _scanning ? null : _startScan,
              icon: const Icon(Icons.radar),
              label: Text(_scanning ? 'Taranıyor…' : 'BLE taraması başlat'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Ortam okuma: BLE-SIG çevresel UUID + bilinmeyen karakteristiklerde sezgisel ayrıştırma. '
              'Kestrel LiNK bazen Nordic UART kullanır — «Nordic UART dinle» ile ham metin deneyin.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (ctx, i) {
                final r = _results[i];
                final name = r.device.platformName.isEmpty
                    ? '(isimsiz)'
                    : r.device.platformName;
                return ListTile(
                  title: Text(name),
                  subtitle: Text('${r.device.remoteId}  RSSI ${r.rssi}'),
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await r.device.connect(timeout: const Duration(seconds: 10));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Bağlandı: $name')),
                        );
                        final ss = await r.device.discoverServices();
                        if (!context.mounted) return;
                        await showDialog<void>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text('GATT — $name'),
                            content: SizedBox(
                              width: double.maxFinite,
                              height: 360,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () async {
                                      final env = await readStandardEnvironmental(r.device);
                                      if (!c.mounted) return;
                                      Navigator.pop(c);
                                      if (!mounted) return;
                                      await showDialog<void>(
                                        context: context,
                                        builder: (ctx2) => AlertDialog(
                                          title: const Text('BLE ortam ölçümü'),
                                          content: Text(
                                            env.isEmpty
                                                ? 'Değer çıkmadı. Nordic UART veya üretici uygulamasını deneyin.'
                                                : 'Sıcaklık: ${env.temperatureC?.toStringAsFixed(1) ?? "—"} °C\n'
                                                    'Nem: ${env.humidityPercent?.toStringAsFixed(0) ?? "—"} %\n'
                                                    'Basınç: ${env.pressureHpa?.toStringAsFixed(0) ?? "—"} hPa',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: env.isEmpty
                                                  ? null
                                                  : () {
                                                      BallisticsEnvBridge.offer(env);
                                                      Navigator.pop(ctx2);
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Balistik sekmesine gönderildi — sıcaklık / basınç / nem alanları güncellenir.',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                              child: const Text('Balistiğe uygula'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx2),
                                              child: const Text('Kapat'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.thermostat),
                                    label: const Text('Ortam oku (2A6E/6F/6D + sezgisel)'),
                                  ),
                                  const SizedBox(height: 6),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final txt = await sniffNordicUartText(r.device);
                                      if (!c.mounted) return;
                                      Navigator.pop(c);
                                      if (!mounted) return;
                                      await showDialog<void>(
                                        context: context,
                                        builder: (ctx2) => AlertDialog(
                                          title: const Text('Nordic UART (2 sn)'),
                                          content: SingleChildScrollView(
                                            child: Text(
                                              txt ?? 'Bildirim alınamadı veya servis yok (LiNK protokolü cihaza göre değişir).',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx2),
                                              child: const Text('Kapat'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.cable),
                                    label: const Text('Nordic UART dinle'),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: ListView(
                                      children: [
                                        for (final s in ss)
                                          ListTile(
                                            dense: true,
                                            title: Text(s.uuid.toString()),
                                            subtitle: Text('${s.characteristics.length} karakteristik'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(c);
                                  r.device.disconnect();
                                },
                                child: const Text('Kapat / kop'),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Bağlantı hatası: $e')),
                        );
                      }
                    },
                    child: const Text('Bağlan'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
