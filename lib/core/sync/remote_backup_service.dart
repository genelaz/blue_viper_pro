import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// İsteğe bağlı uzak yedek: kendi sunucunuz, WebDAV proxy veya otomasyon uç noktası.
class RemoteBackupPrefs {
  static const _urlKey = 'remote_backup_url_v1';
  static const _authKey = 'remote_backup_auth_v1';

  static Future<String?> getUrl() async {
    final p = await SharedPreferences.getInstance();
    final u = p.getString(_urlKey);
    return (u != null && u.trim().isNotEmpty) ? u.trim() : null;
  }

  static Future<String?> getAuthRaw() async {
    final p = await SharedPreferences.getInstance();
    final a = p.getString(_authKey);
    if (a == null || a.trim().isEmpty) return null;
    return a.trim();
  }

  static Future<String?> getAuthHeader() async {
    final a = await getAuthRaw();
    if (a == null) return null;
    final t = a;
    if (t.toLowerCase().startsWith('basic ') || t.toLowerCase().startsWith('bearer ')) {
      return t;
    }
    return 'Bearer $t';
  }

  static Future<void> save({required String? url, required String? auth}) async {
    final p = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await p.remove(_urlKey);
    } else {
      await p.setString(_urlKey, url.trim());
    }
    if (auth == null || auth.trim().isEmpty) {
      await p.remove(_authKey);
    } else {
      await p.setString(_authKey, auth.trim());
    }
  }
}

class RemoteBackupService {
  /// [body] tam yedek JSON (AppBackupService.payloadToJson).
  ///
  /// [httpClient] verilirse kullanılır ve kapatılmaz (test mock).
  static Future<void> push(
    String body, {
    http.Client? httpClient,
  }) async {
    final url = await RemoteBackupPrefs.getUrl();
    if (url == null) throw StateError('Uzak URL ayarlı değil');
    final uri = Uri.parse(url);
    final auth = await RemoteBackupPrefs.getAuthHeader();
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': ?auth,
    };

    final ownsClient = httpClient == null;
    final client = httpClient ?? http.Client();
    try {
      final r =
          await client.put(uri, headers: headers, body: body).timeout(const Duration(seconds: 45));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw Exception('PUT ${r.statusCode}: ${r.body.length > 200 ? r.body.substring(0, 200) : r.body}');
      }
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  /// GET ile ham JSON döner (restoreFromJson ile birleştirilebilir).
  static Future<String> pull({http.Client? httpClient}) async {
    final url = await RemoteBackupPrefs.getUrl();
    if (url == null) throw StateError('Uzak URL ayarlı değil');
    final uri = Uri.parse(url);
    final auth = await RemoteBackupPrefs.getAuthHeader();
    final headers = <String, String>{
      'Authorization': ?auth,
    };

    final ownsClient = httpClient == null;
    final client = httpClient ?? http.Client();
    try {
      final r = await client.get(uri, headers: headers).timeout(const Duration(seconds: 45));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw Exception('GET ${r.statusCode}');
      }
      final t = r.body.trim();
      if (t.isEmpty) throw Exception('Boş yanıt');
      jsonDecode(t);
      return t;
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}
