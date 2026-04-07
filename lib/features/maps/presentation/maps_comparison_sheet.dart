import 'package:flutter/material.dart';

/// MGRS & UTM Harita, CAS (HGK Coğrafi Analiz), AlpinQuest ile kaba karşılaştırma.
Future<void> showMapsReferenceComparisonSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (c, scroll) {
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('Referans uygulamalar vs Blue Viper', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            const _CompareBlock(
              title: 'MGRS & UTM Harita (mobil)',
              theyHave: [
                'Çoklu format: MGRS, UTM, DMS/DD',
                'Koordinat dönüşümü, işaretçiler',
                'Basit rota / mesafe (uygulamaya göre değişir)',
                'Bazı sürümlerde offline katman / dışa aktarım',
              ],
              weHave: [
                'WGS84, DMS, UTM, MGRS (GeoFormatters)',
                'SK-42 TM (3° GK, λ₀ 27–45°, FE 500 km) gösterim ve giriş',
                'WGS 84 / UTM kuzey + EPSG (32635–32641 ME hızlı seçim, proj4)',
                'Çevrimiçi katman seçenekleri (OSM, topo, uydu)',
                'GPS / iki işaret noktası, sıralı rota (mor), alan poligonu (teal) ve m²',
                'GPX dışa aktarma; GPX/KML/KMZ içe aktarma (rota yükleme)',
                'Raster MBTiles (png/jpg/webp): dosya seç, tam çevrimdışı altlık',
              ],
              gaps: [
                'NTv2 ızgarası / kurumsal datum dosyaları yok (towgs84 yaklaşık)',
                'KML tam modeli, GeoPDF, shapefile yok',
                'Vektör MBTiles (Mapbox pbf) raster paketi gibi açılmaz',
              ],
            ),
            const _CompareBlock(
              title: 'CAS — Coğrafi Analiz Sistemi (HGK)',
              theyHave: [
                'Profesyonel CBS: 3B küre, ortofoto, topografya',
                'Görüş analizi, arazi profili, tehdit/engel analizi',
                'MGRS/UTM ile askeri planlama entegrasyonu',
              ],
              weHave: [
                'Hafif saha haritası + DEM rakım (ağ)',
                'Menzil / azimut / eğim özetleri',
                'Rota veya iz için basit DEM yükseklik profili (çevrimiçi)',
              ],
              gaps: [
                'Gerçek görüş alanı / LOS, tehdit tüpü, 3B küre yok',
                'Kurumsal CAS ile doğrudan veri bağlantısı yok',
              ],
            ),
            const _CompareBlock(
              title: 'AlpinQuest',
              theyHave: [
                'İz kaydı, sınırsız waypoint / rota / alan',
                'GPX, KML, KMZ, GeoPDF ve çoklu offline format',
                'Katman opaklığı, DEM gölgelendirme, yakınlık uyarıları',
              ],
              weHave: [
                'GPS, iki işaret noktası, sıralı rota çizgisi',
                'GPS iz kaydı (ağ varken akış), yeşil iz çizgisi, GPX trk',
                'Kapalı poligon ile alan (m²), DEM profili',
                'Balistik sekmesi ile entegre hedef aktarımı',
              ],
              gaps: [
                'Arka plan sürekli kayıt (servis) ve ayrıntılı istatistik grafikleri yok',
                'Çoklu katman opaklığı / hazır mağaza paketleri yok (tek MBTiles)',
                'KMZ dışa aktarma, shapefile/GeoPDF dışa aktarma yok',
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Bu liste kabaca eğitim / ürün planlaması içindir; özellikler zamanla genişletilebilir.',
              style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
          ],
        );
      },
    ),
  );
}

class _CompareBlock extends StatelessWidget {
  const _CompareBlock({
    required this.title,
    required this.theyHave,
    required this.weHave,
    required this.gaps,
  });

  final String title;
  final List<String> theyHave;
  final List<String> weHave;
  final List<String> gaps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          _bullets('Onlarda (tipik)', theyHave, Theme.of(context).colorScheme.tertiary),
          _bullets('Bizde', weHave, Theme.of(context).colorScheme.primary),
          _bullets('Eksik / yol haritası', gaps, Theme.of(context).colorScheme.error),
        ],
      ),
    );
  }

  Widget _bullets(String h, List<String> items, Color tint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(h, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tint)),
          for (final s in items)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('· ', style: TextStyle(color: tint)),
                  Expanded(child: Text(s, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
