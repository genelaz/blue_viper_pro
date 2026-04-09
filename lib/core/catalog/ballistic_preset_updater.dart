import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'ballistic_preset_repository.dart';

class BallisticPresetUpdateResult {
  const BallisticPresetUpdateResult({
    required this.success,
    required this.message,
    this.dataVersion,
    this.skipped = false,
  });

  final bool success;
  final String message;
  final String? dataVersion;
  final bool skipped;
}

class BallisticPresetUpdater {
  static const _remoteUrlKey = 'ballistic_preset_remote_url_v1';

  static Future<String?> getRemoteUrl() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_remoteUrlKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  static Future<void> setRemoteUrl(String? url) async {
    final p = await SharedPreferences.getInstance();
    final t = url?.trim();
    if (t == null || t.isEmpty) {
      await p.remove(_remoteUrlKey);
    } else {
      await p.setString(_remoteUrlKey, t);
    }
  }

  static Future<BallisticPresetUpdateResult> updateFromUrl(
    String url, {
    http.Client? httpClient,
    bool force = false,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return const BallisticPresetUpdateResult(
        success: false,
        message: 'Preset URL geçersiz (http/https olmalı).',
      );
    }

    final client = httpClient ?? http.Client();
    final ownsClient = httpClient == null;
    try {
      final r = await client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        return BallisticPresetUpdateResult(
          success: false,
          message: 'Preset indirme hatası: HTTP ${r.statusCode}',
        );
      }
      final body = r.body.trim();
      if (body.isEmpty) {
        return const BallisticPresetUpdateResult(
          success: false,
          message: 'Preset yanıtı boş.',
        );
      }

      try {
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          return const BallisticPresetUpdateResult(
            success: false,
            message: 'Preset payload formatı geçersiz.',
          );
        }
        final manifestRaw = decoded['manifest'];
        if (manifestRaw is! Map) {
          return const BallisticPresetUpdateResult(
            success: false,
            message: 'Preset payload manifest içermiyor.',
          );
        }
        final incomingManifest = BallisticPresetManifest.fromMap(
          Map<String, dynamic>.from(manifestRaw),
        );
        final current = await BallisticPresetRepository.loadActiveOrBuiltIn();
        if (!force &&
            incomingManifest.dataVersion == current.manifest.dataVersion) {
          await setRemoteUrl(url);
          return BallisticPresetUpdateResult(
            success: true,
            skipped: true,
            message: 'Preset sürümü güncel: ${incomingManifest.dataVersion}',
            dataVersion: incomingManifest.dataVersion,
          );
        }

        await BallisticPresetRepository.applyRemotePayloadJson(body);
        final active = await BallisticPresetRepository.loadActiveOrBuiltIn();
        await setRemoteUrl(url);
        return BallisticPresetUpdateResult(
          success: true,
          message: 'Preset güncellendi: ${active.manifest.dataVersion}',
          dataVersion: active.manifest.dataVersion,
        );
      } catch (e) {
        await BallisticPresetRepository.rollbackToPrevious();
        return BallisticPresetUpdateResult(
          success: false,
          message: 'Preset apply/verify hatası: $e',
        );
      }
    } catch (e) {
      return BallisticPresetUpdateResult(
        success: false,
        message: 'Preset güncelleme hatası: $e',
      );
    } finally {
      if (ownsClient) client.close();
    }
  }
}

