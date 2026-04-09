import 'package:flutter/material.dart';

import '../../../core/ui/field_ui_widgets.dart';

/// Atış giriş: balistik ve saha araçları; hedef kitle: saha avcısı, dağcı, taktik konum kullanıcısı.
class ShootingHubPage extends StatelessWidget {
  const ShootingHubPage({
    super.key,
    required this.onBalistik,
    required this.onBluetooth,
    required this.onYedek,
    required this.onHarita,
  });

  final VoidCallback onBalistik;
  final VoidCallback onBluetooth;
  final VoidCallback onYedek;
  final VoidCallback onHarita;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const FieldPageHeader(
          title: 'Saha merkezi',
          badge: 'AV · DAĞ · TAKTİK',
          subtitle:
              'Balistik hesap, çevresel veri ve yedek. Canlı koordinat, rota ve grup konumu için '
              'alttaki Harita sekmesini kullanın — tek elde okunur, düşük ışıkta kontrastlı arayüz.',
        ),
        const SizedBox(height: 22),
        FieldActionCard(
          icon: Icons.calculate_rounded,
          title: 'Balistik hesap',
          subtitle: 'Menzil, ortam ve nişangah — sekmeli saha hesaplayıcı',
          onTap: onBalistik,
          emphasized: true,
        ),
        const SizedBox(height: 12),
        FieldActionCard(
          icon: Icons.bluetooth_searching_rounded,
          title: 'Bluetooth ölçüm',
          subtitle: 'Kestrel ve uyumlu BLE ortam sensörleri',
          onTap: onBluetooth,
        ),
        const SizedBox(height: 12),
        FieldActionCard(
          icon: Icons.cloud_sync_outlined,
          title: 'Yedek ve geri yükle',
          subtitle: 'Profiller ve ayarlar — dosya veya uzak uç',
          onTap: onYedek,
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: onHarita,
          icon: const Icon(Icons.map_outlined, size: 22),
          label: const Text('Harita ve koordinat'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ],
    );
  }
}
