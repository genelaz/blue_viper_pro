import 'package:flutter/material.dart';

/// AlpinQuest benzeri atış giriş ekranı: balistik ve yardımcı araçlara kartlarla geçiş.
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
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Atış',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Balistik hesap ve saha donanımı. Harita için alttan «Maps» sekmesini kullanın.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        _HubCard(
          icon: Icons.calculate,
          title: 'Balistik hesap',
          subtitle: 'Menzil, ortam, retikül — Strelok tarzı sekmeli çözüm',
          onTap: onBalistik,
          emphasized: true,
        ),
        const SizedBox(height: 12),
        _HubCard(
          icon: Icons.bluetooth_searching,
          title: 'Bluetooth',
          subtitle: 'Kestrel / BLE ortam değerleri',
          onTap: onBluetooth,
        ),
        const SizedBox(height: 12),
        _HubCard(
          icon: Icons.cloud_sync_outlined,
          title: 'Yedek',
          subtitle: 'Profil ve veri senkronu',
          onTap: onYedek,
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onHarita,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Harita programına geç (Maps)'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: emphasized ? cs.primaryContainer.withValues(alpha: 0.35) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 36, color: cs.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
