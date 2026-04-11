import 'package:flutter/material.dart';

import '../../../core/bluetooth/ble_device_prefs.dart';
import 'bluetooth_page.dart';

/// StreLok tarzı BLE cihaz kayıtları + tarama sayfasına geçiş.
class BleHubPage extends StatefulWidget {
  const BleHubPage({super.key});

  @override
  State<BleHubPage> createState() => _BleHubPageState();
}

class _BleHubPageState extends State<BleHubPage> {
  String _weatherKind = BleDevicePrefs.weatherKinds.first;
  String _windKind = BleDevicePrefs.windKinds.first;
  final _weatherIdCtrl = TextEditingController();
  final _windIdCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final wk = await BleDevicePrefs.weatherKind();
    final wid = await BleDevicePrefs.weatherDeviceId();
    final nk = await BleDevicePrefs.windKind();
    final nid = await BleDevicePrefs.windDeviceId();
    if (!mounted) return;
    setState(() {
      _weatherKind = wk;
      _windKind = nk;
      _weatherIdCtrl.text = wid ?? '';
      _windIdCtrl.text = nid ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _weatherIdCtrl.dispose();
    _windIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveWeather() async {
    await BleDevicePrefs.setWeatherKind(_weatherKind);
    await BleDevicePrefs.setWeatherDeviceId(_weatherIdCtrl.text.trim().isEmpty ? null : _weatherIdCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hava istasyonu kaydı güncellendi.')));
    await _reload();
  }

  Future<void> _saveWind() async {
    await BleDevicePrefs.setWindKind(_windKind);
    await BleDevicePrefs.setWindDeviceId(_windIdCtrl.text.trim().isEmpty ? null : _windIdCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rüzgarölçer kaydı güncellendi.')));
    await _reload();
  }

  Future<void> _clearWeather() async {
    _weatherIdCtrl.clear();
    await BleDevicePrefs.setWeatherDeviceId(null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kayıtlı hava cihazı kimliği silindi.')));
  }

  Future<void> _clearWind() async {
    _windIdCtrl.clear();
    await BleDevicePrefs.setWindDeviceId(null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kayıtlı rüzgar cihazı kimliği silindi.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth cihazları')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Cihaz türünü seçin; uzak kimliği taramadan kopyalayın veya elle girin. '
            'Bağlantı için «BLE tarama» ile cihazı bulun.',
            style: TextStyle(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 20),
          Text('Hava istasyonları', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Cihaz türü'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _weatherKind,
                isExpanded: true,
                items: [
                  for (final k in BleDevicePrefs.weatherKinds)
                    DropdownMenuItem(value: k, child: Text(BleDevicePrefs.weatherKindLabel(k))),
                ],
                onChanged: (v) => setState(() => _weatherKind = v ?? _weatherKind),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weatherIdCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Kaydedilmiş cihaz kimliği (ör. MAC / remote id)',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(onPressed: _saveWeather, child: const Text('Kaydet')),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _clearWeather,
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Silmek'),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Rüzgarölçer cihazları', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Cihaz türü'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _windKind,
                isExpanded: true,
                items: [
                  for (final k in BleDevicePrefs.windKinds)
                    DropdownMenuItem(value: k, child: Text(BleDevicePrefs.windKindLabel(k))),
                ],
                onChanged: (v) => setState(() => _windKind = v ?? _windKind),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _windIdCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Kaydedilmiş cihaz kimliği',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(onPressed: _saveWind, child: const Text('Kaydet')),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _clearWind,
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Silmek'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('BLE tarama')),
                    body: const BluetoothPage(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.radar),
            label: const Text('BLE tarama (cihaz bul)'),
          ),
        ],
      ),
    );
  }
}
