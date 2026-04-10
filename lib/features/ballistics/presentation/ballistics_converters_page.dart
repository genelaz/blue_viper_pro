import 'package:flutter/material.dart';

import 'strelock_ballistics_ui.dart';

/// Balistik alt araçları — StreLok «Dönüştürücüler» tarzı liste.
enum BallisticsConverterAction {
  truingVo,
  truingBc,
  truingAdvanced,
  rangeTable,
  batchMultiRange,
  movingTarget,
  zeroWizard,
  captureCompareRef,
  runCompare,
}

class BallisticsConvertersPage extends StatelessWidget {
  const BallisticsConvertersPage({
    super.key,
    required this.compareRefReady,
    required this.onPick,
  });

  final bool compareRefReady;
  final void Function(BallisticsConverterAction action) onPick;

  @override
  Widget build(BuildContext context) {
    Widget tile(
      String label,
      BallisticsConverterAction a, {
      bool enabled = true,
      String? subtitle,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: enabled ? StreLockBalColors.fieldFill : Colors.white24,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: enabled ? () => onPick(a) : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: enabled ? StreLockBalColors.fieldText : StreLockBalColors.label,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: (enabled ? StreLockBalColors.label : StreLockBalColors.label)
                              .withValues(alpha: enabled ? 0.72 : 0.45),
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: StreLockBalColors.scaffold,
      appBar: AppBar(
        backgroundColor: StreLockBalColors.scaffold,
        foregroundColor: StreLockBalColors.label,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Dönüştürücüler',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: StreLockBalColors.headerOrange,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Vo / BC doğrulama ve tablolar',
            style: streLockSectionStyle(context),
          ),
          tile(
            'Atış yolu: Vo (MV) uydurma',
            BallisticsConverterAction.truingVo,
            subtitle: 'Gözlenen düşüşe göre başlangıç hızını ayarlar.',
          ),
          tile(
            'Atış yolu: BC uydurma',
            BallisticsConverterAction.truingBc,
            subtitle: 'Gözlenen isabete göre balistik katsayıyı ayarlar.',
          ),
          tile(
            'Atış yolu: birim seçimi (tam ekran)',
            BallisticsConverterAction.truingAdvanced,
            subtitle: 'Trajektori doğrulama: mil, MOA, tık ve gelişmiş seçenekler.',
          ),
          tile(
            'Menzil tablosu',
            BallisticsConverterAction.rangeTable,
            subtitle: 'Mil / MOA / klik / cm sütunları; CSV, XLSX veya PDF paylaşım.',
          ),
          tile(
            'Menzil listesi (toplu)',
            BallisticsConverterAction.batchMultiRange,
            subtitle: 'Birden çok menzil: mil, MOA, klik, cm özeti; CSV ve Excel çıktısı.',
          ),
          tile(
            'Hareketli hedef (çapraz hız)',
            BallisticsConverterAction.movingTarget,
            subtitle: 'Çapraz hız için öncü (lead) ve entegre balistik çözüm.',
          ),
          tile(
            'Sıfır / nişan sihirbazı (sapma → tık)',
            BallisticsConverterAction.zeroWizard,
            subtitle: 'Kağıt veya retikülde ölçülen sapmadan tık düzeltmesi.',
          ),
          const StreLockSectionHeader('Karşılaştırma'),
          tile(
            'Referansı yakala (mevcut çözüm)',
            BallisticsConverterAction.captureCompareRef,
            subtitle: 'Formdaki Vo, BC ve nişan ayarlarını referans olarak saklar.',
          ),
          tile(
            'Profilleri karşılaştır',
            BallisticsConverterAction.runCompare,
            enabled: compareRefReady,
            subtitle: 'Referans ile güncel çözümü tabloda ve CSV / Excel’de yan yana.',
          ),
          if (!compareRefReady)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Karşılaştırma için önce referans yakalanır.',
                style: streLockLabelStyle(context).copyWith(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
