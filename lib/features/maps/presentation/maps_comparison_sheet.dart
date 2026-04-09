import 'package:flutter/material.dart';

/// Ürün yol haritası — sabit **8 paket** (Eksikler özeti ve numaralı maddeler bununla uyumludur).
class MapRoadmapPackage {
  const MapRoadmapPackage({
    required this.id,
    required this.sectionTitle,
    required this.headline,
    required this.description,
  });

  final int id;
  final String sectionTitle;
  final String headline;
  final String description;

  String get compareLine => '$headline — $description';
}

const List<MapRoadmapPackage> kMapRoadmapPackages = [
  MapRoadmapPackage(
    id: 1,
    sectionTitle: 'MGRS & UTM Harita (mobil)',
    headline: 'KML tam Google Earth uyumu (kalan)',
    description:
        'Çizgi / alan + nokta: `Style` / `StyleMap` (dokununca highlight ikon), `IconStyle`, '
        '`hotSpot`, KMZ / yerel / `http`·`https` raster ikon, HTML balon → düz metin ipucu, '
        r'`BalloonStyle` $[name] / $[description]. '
        'Eksik: Google Earth gömülü sembol kütüphanesi ve zengin HTML balon (CSS, gömülü içerik); '
        'Android’de `http` ikon için cleartext ağı gerekebilir.',
  ),
  MapRoadmapPackage(
    id: 2,
    sectionTitle: 'MGRS & UTM Harita (mobil)',
    headline: 'NTv2 ve kurumsal datum',
    description:
        'Kurumsal EPSG kayıt tabanından otomatik `.gsb` indirme / eşleme yok; kullanıcı dosyayı '
        'sağlar. Izgara WGS84 kapsamı HUD ve ayrıntılarda özetlenir; konum kapsam dışındayken '
        'kayma uygulanmaz (uyarı gösterilir).',
  ),
  MapRoadmapPackage(
    id: 3,
    sectionTitle: 'MGRS & UTM Harita (mobil)',
    headline: 'Vektör MBTiles (MapLibre / Style Spec)',
    description:
        'İsteğe bağlı MapLibre motoru (vektör MBTiles ayrıntıları): iOS/Android’de yerel '
        'MapLibre SDK; çevrimiçi OpenFreeMap Liberty stil JSON’u alınır, `openmaptiles` kaynağı '
        'yerel `.mbtiles` ile değiştirilir — sprite, glif, yerleşimli etiketler ve Style Spec native '
        'motor tarafından işlenir. macOS/Windows’ta deneysel WebView (`maplibre-gl-js`); '
        '`mbtiles://` ve tam özellik eşlemesi mobil native ile birebir olmayabilir. '
        'MapLibre açıkken GeoPDF JPEG üst katman, hillshade ve bazı `flutter_map` özel katmanları '
        'hâlâ kısmi veya yok; tam görünüm için klasik önizleme motoruna geçilebilir.',
  ),
  MapRoadmapPackage(
    id: 4,
    sectionTitle: 'CAS — Coğrafi Analiz Sistemi (HGK)',
    headline: 'Tehdit ve 3B görüş modeli',
    description:
        'Tehdit tüpü, 3B küre ve tam tehdit/görüş modellemesi yok. «Basit LOS»: gözlem/hedef yüksekliği, '
        'ayarlanabilir DEM örnek sayısı (profil/harita çözünürlüğü vs ağ), «Haritada göster» ile yeşil/kırmızı '
        'segment ve engel noktası; ayrıca MVP tehdit tüpü koridoru (pim 1–2 hattı etrafında) ve JSON tabanlı '
        'CAS 3B paket yükleme (threat tube footprint). '
        'Tam 3B tehdit modeli ve kurumsal CAS analitiği henüz yok.',
  ),
  MapRoadmapPackage(
    id: 5,
    sectionTitle: 'CAS — Coğrafi Analiz Sistemi (HGK)',
    headline: 'Kurumsal CAS veri bağlantısı',
    description:
        'Kurumsal Coğrafi Analiz Sistemi ile doğrudan veri / servis entegrasyonu yok.',
  ),
  MapRoadmapPackage(
    id: 6,
    sectionTitle: 'AlpinQuest',
    headline: 'GeoPDF, vektör mağaza ve egzotik CRS',
    description:
        'Her GeoPDF tam raster altlık değildir; vektör mağaza veya API entegrasyonu yok; egzotik '
        'CRS’ler .prj / EPSG / WKT ile sınırlı kalabilir.',
  ),
  MapRoadmapPackage(
    id: 7,
    sectionTitle: 'Harita işbirliği (oda + PTT)',
    headline: 'Üretim WebSocket sunucusu',
    description:
        'Çoklu cihazda aynı oda için çalışır `wss://` uç noktası üretimde sizin '
        'tarafınızda yapılandırılır (`PTT_WS_URL` vb.).',
  ),
  MapRoadmapPackage(
    id: 8,
    sectionTitle: 'Harita işbirliği (oda + PTT)',
    headline: 'Ses hattı (codec, VAD, mikrofon)',
    description:
        'Gerçek ses taşıması (codec), ses etkinlik algılama (VAD) ve sürekli mikrofon akışı henüz '
        'iskelet düzeyindedir.',
  ),
];

List<String> _gapsForSection(String sectionTitle) => [
      for (final p in kMapRoadmapPackages)
        if (p.sectionTitle == sectionTitle) p.compareLine,
    ];

typedef _MapCompareSection = ({
  String title,
  List<String> theyHave,
  List<String> weHave,
  List<String> gaps,
});

final List<_MapCompareSection> _kMapCompareSections = [
  (
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
      'GPS; çoklu renkli işaret (pim), sıralı rota (mor), alan poligonu (teal) ve m²',
      'GPX, KML ve KMZ (`doc.kml`) dışa aktarma; KML/KMZ’de delikli poligon; kapalı alanlar GPX’te ayrı trk; GPX/KML/KMZ içe aktarma',
      'KML `NetworkLink`: HTTPS hedefleri (yinelemesiz), süre/boyut sınırı, KMZ yanıtı; sınırlı iç içe derinlik; dışa / içe `Style` ve `StyleMap` (çizgi, alan; nokta `IconStyle` + KMZ/yerel/`http`·`https` ikon, `hotSpot`, dokununca highlight, HTML→düz balon)',
      'Raster MBTiles (png/jpg/webp): dosya seç, tam çevrimdışı altlık',
      'Shapefile rota (.shp/.shx, .prj ile CRS)',
      'GeoPDF: GPTS ile kapsama odak + turuncu çerçeve; varsa ilk DCT/JPEG raster üst katman',
      'NTv2: kullanıcı .gsb seçimi; kapsam özeti ve konum dışı uyarısı; koordinat çubuğunda kaymalı gösterim',
      'Vektör MBTiles: `format=pbf` / MVT; `metadata.json` / `vector_layers` veya gzip karo ile erken tespit; çevrimdışı paket üzerinde çevrimiçi raster altlık (isteğe bağlı)',
      r'MVT → harita: (A) Varsayılan önizleme motoru — gzip veya ham `tile_data` → `vector_tile`; çizgi, poligon (delikli) ve nokta; katman + `class` ile sezgisel renk ve çizgi kalınlığı; sınırlı `name`/`ref` etiketi; dokunuş «Özellik» ile 3×3 karo özeti. (B) İsteğe bağlı MapLibre motoru — iOS/Android native Liberty + yerel MVT; sprite/glif/tam stil; macOS/Windows deneysel WebView; bkz. Paket 3',
    ],
    gaps: _gapsForSection('MGRS & UTM Harita (mobil)'),
  ),
  (
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
      'İki işaret arası basit LOS (DEM; gözlem/hedef yüksekliği, örnek sayısı, profil, haritada yeşil/kırmızı segment + engel noktası) ve JSON tabanlı CAS 3B threat tube footprint katmanı; saha hızlı kontrolü, profesyonel CAS değil',
    ],
    gaps: _gapsForSection('CAS — Coğrafi Analiz Sistemi (HGK)'),
  ),
  (
    title: 'AlpinQuest',
    theyHave: [
      'İz kaydı, sınırsız waypoint / rota / alan',
      'GPX, KML, KMZ, GeoPDF ve çoklu offline format',
      'Katman opaklığı, DEM gölgelendirme, yakınlık uyarıları',
    ],
    weHave: [
      'GPS, çoklu işaret (pim), sıralı rota çizgisi',
      'GPS iz kaydı, yeşil iz çizgisi, GPX trk',
      'Kapalı poligon ile alan (m²), DEM profili',
      'Balistik sekmesi ile entegre hedef aktarımı',
      'Altlık saydamlığı (çevrimiçi + MBTiles), ayar kayıtlı — Adım 1 (AQ hizalama)',
      'İki raster katman: ana altlık + isteğe bağlı yarı saydam üst çevrimiçi katman (MBTiles + uydu vb.), opaklık ve seçim kayıtlı — Adım 2',
      'Koordinat ızgarası: WGS enlem/boylam veya WGS 84 / UTM kuzey (metre; MGRS ile uyumlu aralıklar), tercih kayıtlı — Adım 3',
      'GPS iz kaydı: gerçek GNSS noktaları (harita sabitliyken de), süre + mesafe (REC şeridi, menü), Android ön planda konum bildirimi, iOS arka plan modu — Adım 4',
      'İçe aktarma: GPX (çoklu iz/rota), KML, çoklu-KML KMZ, ESRI shapefile (.shp/.shx, .prj ile WGS84); harita veri kaynakları sayfası — Adım 5',
      'İsteğe bağlı DEM hillshade: Esri World Hillshade üst karo katmanı (ağ), saydamlık ve tercih kayıtlı',
      'GeoPDF (.pdf): GPTS odak + çerçeve; uygun PDF’lerde DCT/JPEG raster üst katman',
    ],
    gaps: _gapsForSection('AlpinQuest'),
  ),
  (
    title: 'Harita işbirliği (oda + PTT)',
    theyHave: [
      'Çoğu harita uygulamasında canlı ekip sesi veya konum paylaşımı ayrı kanallarda',
    ],
    weHave: [
      'Oda kodu / şifre, davet metni; baloncukta üyeler ve metin sohbet',
      'Konum paylaşımı (kurucu / üye); haritada isim bandı, konuşanda dalga animasyonu',
      'PTT kuyruğu ve moderasyon; ses tercihleri (giriş modu, öz-sessiz, odayı dinle) UI + wire',
      'Uzak modda yeniden bağlanınca join + durum snapshot isteği (istemci)',
    ],
    gaps: _gapsForSection('Harita işbirliği (oda + PTT)'),
  ),
];

int _totalGapCount() => kMapRoadmapPackages.length;

int _gapPackageStartIndex(int sectionIndex) {
  final secTitle = _kMapCompareSections[sectionIndex].title;
  final first = kMapRoadmapPackages.indexWhere((p) => p.sectionTitle == secTitle);
  return first < 0 ? 1 : kMapRoadmapPackages[first].id;
}

/// Tüm «Eksik / yol haritası» maddeleri sırayla Paket 1…8 (tek liste).
List<({int pkg, String sectionTitle, String headline, String body})> _numberedGapPackages() => [
      for (final p in kMapRoadmapPackages)
        (pkg: p.id, sectionTitle: p.sectionTitle, headline: p.headline, body: p.description),
    ];

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
        final scheme = Theme.of(ctx).colorScheme;
        return ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            24 + MediaQuery.paddingOf(ctx).bottom,
          ),
          children: [
            Text('Referans uygulamalar vs Blue Viper', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: const Text('Eksikler / yol haritası — 8 paket'),
                subtitle: Text(
                  '${_totalGapCount()} paket; ayrıntı aşağıda her blokta tekrarlanır',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in _numberedGapPackages()) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Paket ${e.pkg} · ${e.sectionTitle}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: scheme.error, fontSize: 12),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Text(
                              e.headline,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: Text(e.body, style: const TextStyle(fontSize: 12, height: 1.35)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (var si = 0; si < _kMapCompareSections.length; si++) ...[
              _CompareBlock(
                title: _kMapCompareSections[si].title,
                theyHave: _kMapCompareSections[si].theyHave,
                weHave: _kMapCompareSections[si].weHave,
                gaps: _kMapCompareSections[si].gaps,
                gapPackageStart: _gapPackageStartIndex(si),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Bu liste eğitim ve plan içindir. «Eksik» satırları kısa vadeli iş ile çok yıllık ürün hedefini bir arada tutar; tamamının tek seferde kapanması hedef değildir. '
              'Tamamlananlar sürümlerle «Bizde» tarafına taşınır.',
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
    required this.gapPackageStart,
  });

  final String title;
  final List<String> theyHave;
  final List<String> weHave;
  final List<String> gaps;
  /// Bu bloktaki ilk eksik satırının global paket numarası (1 tabanlı).
  final int gapPackageStart;

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
          _numberedGapBullets(context),
        ],
      ),
    );
  }

  Widget _numberedGapBullets(BuildContext context) {
    final tint = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eksik / yol haritası',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tint),
          ),
          for (var i = 0; i < gaps.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('· ', style: TextStyle(color: tint)),
                  Expanded(
                    child: Text(
                      'Paket ${gapPackageStart + i}: ${gaps[i]}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
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
