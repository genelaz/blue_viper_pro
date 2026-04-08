import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Mağaza olmadan dağıtım: uzak bir JSON manifest ile sürüm karşılaştırması.
///
/// Derleme:
/// `--dart-define=UPDATE_MANIFEST_URL=https://sizin-alan.com/bv/update.json`
///
/// Manifest örneği [exampleUpdateManifestJson].
class SimpleUpdateOffer {
  const SimpleUpdateOffer({
    required this.latestBuild,
    required this.latestVersionLabel,
    required this.apkUrl,
    this.message,
    required this.forceUpdate,
  });

  final int latestBuild;
  final String latestVersionLabel;
  final String apkUrl;
  final String? message;
  final bool forceUpdate;
}

const String exampleUpdateManifestJson = '''
{
  "latest_build": 5,
  "latest_version": "1.0.2",
  "apk_url": "https://example.com/releases/blue_viper_pro.apk",
  "message": "Hata düzeltmeleri.",
  "min_supported_build": 3
}
''';

/// [manifestUrl] boş veya hatalıysa, güncelleme yoksa veya ağ hatasında `null`.
Future<SimpleUpdateOffer?> checkSimpleAppUpdate({
  required String manifestUrl,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final trimmed = manifestUrl.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !uri.hasScheme ||
      uri.scheme != 'https' ||
      !uri.hasAuthority) {
    if (kDebugMode) {
      debugPrint('SimpleUpdate: geçersiz UPDATE_MANIFEST_URL');
    }
    return null;
  }

  try {
    final res = await http.get(uri).timeout(timeout);
    if (res.statusCode != 200 || res.body.isEmpty) return null;
    final map = jsonDecode(res.body);
    if (map is! Map<String, dynamic>) return null;

    final latestBuild = (map['latest_build'] as num?)?.toInt();
    final apkUrl = map['apk_url'] as String?;
    if (latestBuild == null || apkUrl == null || apkUrl.isEmpty) return null;

    final apkUri = Uri.tryParse(apkUrl);
    if (apkUri == null || apkUri.scheme != 'https') return null;

    final pkg = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;
    if (latestBuild <= currentBuild) return null;

    final minSupported = (map['min_supported_build'] as num?)?.toInt();
    final force =
        minSupported != null && currentBuild > 0 && currentBuild < minSupported;

    final ver = (map['latest_version'] as String?)?.trim();
    final label =
        ver != null && ver.isNotEmpty ? ver : 'build $latestBuild';

    return SimpleUpdateOffer(
      latestBuild: latestBuild,
      latestVersionLabel: label,
      apkUrl: apkUrl,
      message: map['message'] as String?,
      forceUpdate: force,
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('SimpleUpdate: $e\n$st');
    }
    return null;
  }
}
