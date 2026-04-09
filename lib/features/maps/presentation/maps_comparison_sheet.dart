import 'package:flutter/material.dart';

typedef _MapCompareSection = ({
  String title,
  List<String> theyHave,
  List<String> weHave,
  List<String> gaps,
});

const List<_MapCompareSection> _kMapCompareSections = [
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
      'GPS / iki işaret noktası, sıralı rota (mor), alan poligonu (teal) ve m²',
      'GPX, KML ve KMZ (`doc.kml`) dışa aktarma; KML/KMZ’de delikli poligon; kapalı alanlar GPX’te ayrı trk; GPX/KML/KMZ içe aktarma',
      'KML `NetworkLink`: HTTPS hedefleri (yinelemesiz), süre/boyut sınırı, KMZ yanıtı; sınırlı iç içe derinlik; dışa / içe `Style` ve `StyleMap` (normal) ile çizgi rengi',
      'Raster MBTiles (png/jpg/webp): dosya seç, tam çevrimdışı altlık',
      'Shapefile rota (.shp/.shx, .prj ile CRS)',
      'GeoPDF: GPTS ile kapsama odak + turuncu çerçeve; varsa ilk DCT/JPEG raster üst katman',
      'NTv2: kullanıcı .gsb ızgarası seçerek isteğe bağlı datum kaydırma (MVP)',
      'Vektör MBTiles: `format=pbf` / MVT; `metadata.json` / `vector_layers` veya gzip karo ile erken tespit; çevrimdışı paket üzerinde çevrimiçi raster altlık (isteğe bağlı)',
      'MVT → harita: gzip veya ham `tile_data` → `vector_tile`; çizgi, poligon (delikli) ve nokta önizlemesi; dolgu / çizgi opaklığı, eşzamanlı karo sınırı, önizleme zoom tavanı; sınırlı `name`/`ref` etiketi — katman önceliği + yakın tekrar birleştirme, isteğe bağlı zoom ile etiket kotası; dokunuş modu «Özellik» ile 3×3 karo alanında özellik özeti; OpenMapTiles / MapLibre tarzı stil ve glif yok',
    ],
    gaps: [
      'KML’de çoklu StyleMap senaryoları, `highlight` ve ikon/hotspot; içe aktarmada yalnızca çizgi rengi (`Style` / `StyleMap` normal); dolgu/alan rengi ve gelişmiş semboloji sınırlı',
      'Kurumsal datum ile otomatik NTv2 eşlemesi yok; sadece seçilen .gsb',
      'Vektör MBTiles — Paket 3 (kalan): MapLibre / Style Spec ile gerçek harita (glif, sprite, katman stilleri, yerleşime duyarlı etiket motoru); şu an tek palet + sınırlı düz metin; tam ürün için ikinci harita motoru veya kapsamlı özel renderer + mimari karar',
    ],
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
      'İki işaret arası basit LOS (DEM örnekleme; sahadan hızlı kontrol, profesyonel görüş analizi değil)',
    ],
    gaps: [
      'Tehdit tüpü, 3B küre, tam tehdit/görüş modellemesi yok',
      'Kurumsal CAS ile doğrudan veri bağlantısı yok',
    ],
  ),
  (
    title: 'AlpinQuest',
    theyHave: [
      'İz kaydı, sınırsız waypoint / rota / alan',
      'GPX, KML, KMZ, GeoPDF ve çoklu offline format',
      'Katman opaklığı, DEM gölgelendirme, yakınlık uyarıları',
    ],
    weHave: [
      'GPS, iki işaret noktası, sıralı rota çizgisi',
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
    gaps: [
      'Her GeoPDF tam raster altlık değildir; vektör mağaza/API entegrasyonu yok; egzotik CRS’ler .prj/EPSG/WKT ile sınırlı kalabilir',
    ],
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
    gaps: [
      'Üretimde çalışır WebSocket uç noktası / sunucu sizin tarafınızda yapılandırılır',
      'Gerçek ses taşıması (codec), VAD ve sürekli mikrofon — ses hattı henüz iskelet',
    ],
  ),
];

int _totalGapCount() {
  var n = 0;
  for (final s in _kMapCompareSections) {
    n += s.gaps.length;
  }
  return n;
}

int _gapPackageStartIndex(int sectionIndex) {
  var p = 1;
  for (var i = 0; i < sectionIndex; i++) {
    p += _kMapCompareSections[i].gaps.length;
  }
  return p;
}

/// Tüm «Eksik / yol haritası» maddeleri sırayla Paket 1…N (tek liste).
List<({int pkg, String sectionTitle, String gap})> _numberedGapPackages() {
  final out = <({int pkg, String sectionTitle, String gap})>[];
  var p = 1;
  for (final sec in _kMapCompareSections) {
    for (final g in sec.gaps) {
      out.add((pkg: p, sectionTitle: sec.title, gap: g));
      p++;
    }
  }
  return out;
}

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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('Referans uygulamalar vs Blue Viper', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: const Text('Eksikler / yol haritası — özet'),
                subtitle: Text(
                  '${_totalGapCount()} madde; ayrıntı aşağıda her blokta tekrarlanır',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in _numberedGapPackages()) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Paket ${e.pkg} · ${e.sectionTitle}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: scheme.error, fontSize: 12),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Text(e.gap, style: const TextStyle(fontSize: 12)),
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
