/// Uzun menzil (≈2–3 km ve üzeri) odaklı varsayılanlar ve menzil tablosu güvenlik sınırları.
/// Motor üst sınırı [BallisticsEngine] içindeki `distanceMeters.clamp` ile uyumlu tutulur.
abstract final class BallisticsRangeUi {
  /// Ana «Menzil» alanı — uzun menzil çözümü için başlangıç önerisi (m).
  static const int defaultPrimaryDistanceM = 1000;

  /// Menzil tablosu (Retikül sekmesi alanları): başlangıç / bitiş / adım (m).
  static const int defaultTableStartM = 100;
  static const int defaultTableEndM = 3000;
  static const int defaultTableStepM = 50;

  /// Parse başarısız olursa tablo bitişi (m).
  static const int fallbackTableEndM = 3000;

  /// Toplu menzil listesi diyaloğu varsayılan metni.
  static const String defaultBatchRangesCsv =
      '200,400,600,800,1000,1200,1400,1600,1800,2000,2200,2400,2600,2800,3000';

  /// Tablo satır sayısı üst sınırı (UI + çözüm süresi).
  static const int maxRangeTableRows = 400;

  static int rangeTableRowCount(int startM, int endM, int stepM) {
    if (stepM <= 0 || endM < startM) return 0;
    return ((endM - startM) ~/ stepM) + 1;
  }
}
