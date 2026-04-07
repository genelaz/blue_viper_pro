import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Açık yükseltme verisi (Open-Meteo, anahtarsız; web/mobil uyumlu).
///
/// DTM tabanlı yaklaşık rakım (m); GNSS’ten daha tutarlı arazi kullanımı için.
class ElevationService {
  static const _base = 'https://api.open-meteo.com/v1/elevation';

  /// Tek nokta için deniz seviyesinden yükseklik (m). Hata durumunda null.
  ///
  /// [client] verilirse istek bu istemciyle yapılır ve kapatılmaz (test mock’ları için).
  static Future<double?> fetchMeters(
    double latitude,
    double longitude, {
    @visibleForTesting http.Client? client,
  }) async {
    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    );

    final ownsClient = client == null;
    final c = client ?? http.Client();
    try {
      final res = await c.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = data['elevation'] as List<dynamic>?;
      if (list == null || list.isEmpty) return null;
      return (list[0] as num).toDouble();
    } catch (_) {
      return null;
    } finally {
      if (ownsClient) {
        c.close();
      }
    }
  }
}
