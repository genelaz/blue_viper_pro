import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ücretsiz / açık harita verisi ve offline paket üretimi için kısa rehber (mağaza değil, bağlantı listesi).
Future<void> showMapDataPackagesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      Future<void> open(String url) async {
        final u = Uri.parse(url);
        if (await canLaunchUrl(u)) {
          await launchUrl(u, mode: LaunchMode.externalApplication);
        }
      }

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        builder: (_, scroll) {
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text('Harita veri kaynakları', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Mağaza entegrasyonu yok; aşağıdaki sitelerden veya masaüstü araçlarla MBTiles üretip uygulamada «.mbtiles» veya GPX/KML/KMZ ile açabilirsiniz. Raster paketler tam çevrimdışı altlık; vektör (`pbf`) paketlerde üstte çevrimiçi raster katman + MVT geometri önizlemesi (stil/etiket yok).',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Geofabrik — OSM çıkarımları'),
                subtitle: const Text('Ülke/bölge .osm.pbf; tippecanoe ile MBTiles'),
                onTap: () => open('https://download.geofabrik.de/'),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('OpenTopoMap'),
                subtitle: const Text('Topo stili karolar (kullanım koşullarına dikkat)'),
                onTap: () => open('https://opentopomap.org/'),
              ),
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('OpenMapTiles schema (belge)'),
                subtitle: const Text('Vector tile / raster pipeline örnekleri'),
                onTap: () => open('https://openmaptiles.org/'),
              ),
              ListTile(
                leading: const Icon(Icons.build_outlined),
                title: const Text('Tippecanoe (Mapbox)'),
                subtitle: const Text('GeoJSON → MBTiles komut satırı'),
                onTap: () => open('https://github.com/felt/tippecanoe'),
              ),
              const Divider(height: 28),
              Text('Yol haritası (vektör)', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Vektör MBTiles (`format=pbf`): MVT çözülür; çizgi, alan ve nokta önizlemesi haritada çizilir (MapLibre / Style Spec / yazılı etiket yok). Tam ürün haritası için «Referans uygulamalar» sayfasındaki Paket 3 (kalan iş).',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
              Text('Biçim notları', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                '• Shapefile: `.shp` seçin; aynı klasörde `.shx` ve mümkünse `.prj` (CRS / WGS84 dönüşümü).\n'
                '• GeoPDF: `/GPTS` (WGS84 köşe) varsa kapsama odaklanır ve turuncu çerçeve çizilir; bazı PDF’lerde ilk sıkıştırılmış JPEG üst katman olarak eklenir.\n'
                '• KML/KMZ: `Polygon` / `MultiPolygon` — tüm kapalı parçalar teal alanda çizilir; birincil parça köşe numaraları ve geri al ile düzenlenir.\n'
                '• `NetworkLink`: yalnızca HTTPS hedefleri, tekrarlayan adres tek istek; yanıt KML veya KMZ olabilir; süre ve boyut sınırlı (web’de CORS kısıtı olabilir).\n'
                '• KML çizgi rengi: `Style` / `StyleMap` (`normal` çifti) içindeki `LineStyle` / `color` (aabbggrr); haritada çoklu renkli çizgiler; rota noktası eklendiğinde veya rota temizlendiğinde bu katman sıfırlanır.\n'
                '• KMZ: zip içindeki tüm `.kml` dosyaları birleştirilerek okunur.\n'
                '• NTv2: haritada `.gsb` seçerek (isteğe bağlı) datum kaydırması uygulanır; dosyayı siz sağlarsınız.\n'
                '• MBTiles: raster (`png`/`jpg`/`webp`) tam çevrimdışı karolar; vektör (`format=pbf` / gzip MVT) raster karosu değil — geometri önizlemesi ve isteğe bağlı çevrimiçi üst katman.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ],
          );
        },
      );
    },
  );
}
