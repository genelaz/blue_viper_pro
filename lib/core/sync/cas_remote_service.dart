import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../geo/cas_3d_package.dart';

enum CasRemoteParamStyle { camelCase, snakeCase }
enum CasRemoteCursorParamStyle { cursor, pageCursor, pageSnakeCursor }

/// Kurumsal CAS uç noktası için temel ayarlar (Paket 5).
class CasRemotePrefs {
  static const _urlKey = 'cas_remote_url_v1';
  static const _authKey = 'cas_remote_auth_v1';
  static const _tenantKey = 'cas_remote_tenant_v1';
  static const _limitKey = 'cas_remote_limit_v1';
  static const _maxPagesKey = 'cas_remote_max_pages_v1';
  static const _minAltKey = 'cas_remote_min_alt_v1';
  static const _maxAltKey = 'cas_remote_max_alt_v1';
  static const _bboxKey = 'cas_remote_bbox_v1';
  static const _tenantAsHeaderKey = 'cas_remote_tenant_as_header_v1';
  static const _paramStyleKey = 'cas_remote_param_style_v1';
  static const _cursorParamStyleKey = 'cas_remote_cursor_param_style_v1';
  static const _strictNextCursorKey = 'cas_remote_strict_next_cursor_v1';
  static const _lastSyncEpochMsKey = 'cas_remote_last_sync_epoch_ms_v1';

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
    if (a.toLowerCase().startsWith('basic ') || a.toLowerCase().startsWith('bearer ')) {
      return a;
    }
    return 'Bearer $a';
  }

  static Future<String?> getTenant() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString(_tenantKey);
    if (t == null || t.trim().isEmpty) return null;
    return t.trim();
  }

  static Future<int?> getLimit() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_limitKey);
    if (v == null) return null;
    return v.clamp(1, 500);
  }

  static Future<int> getMaxPages() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_maxPagesKey);
    if (v == null) return 8;
    return v.clamp(1, 50);
  }

  static Future<double?> getMinAlt() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getDouble(_minAltKey);
    if (v == null || v.isNaN) return null;
    return v;
  }

  static Future<double?> getMaxAlt() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getDouble(_maxAltKey);
    if (v == null || v.isNaN) return null;
    return v;
  }

  static Future<String?> getBbox() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_bboxKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static Future<bool> getTenantAsHeader() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_tenantAsHeaderKey) ?? false;
  }

  static Future<CasRemoteParamStyle> getParamStyle() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_paramStyleKey);
    for (final v in CasRemoteParamStyle.values) {
      if (v.name == raw) return v;
    }
    return CasRemoteParamStyle.camelCase;
  }

  static Future<CasRemoteCursorParamStyle> getCursorParamStyle() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cursorParamStyleKey);
    for (final v in CasRemoteCursorParamStyle.values) {
      if (v.name == raw) return v;
    }
    return CasRemoteCursorParamStyle.cursor;
  }

  static Future<bool> getStrictNextCursor() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_strictNextCursorKey) ?? false;
  }

  static Future<DateTime?> getLastSyncAt() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getInt(_lastSyncEpochMsKey);
    if (raw == null || raw <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }

  static Future<void> setLastSyncAt(DateTime? value) async {
    final p = await SharedPreferences.getInstance();
    if (value == null) {
      await p.remove(_lastSyncEpochMsKey);
    } else {
      await p.setInt(_lastSyncEpochMsKey, value.millisecondsSinceEpoch);
    }
  }

  static Future<void> save({
    required String? url,
    required String? auth,
    String? tenant,
    int? limit,
    int? maxPages,
    double? minAlt,
    double? maxAlt,
    String? bbox,
    bool? tenantAsHeader,
    CasRemoteParamStyle? paramStyle,
    CasRemoteCursorParamStyle? cursorParamStyle,
    bool? strictNextCursor,
  }) async {
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
    if (tenant == null || tenant.trim().isEmpty) {
      await p.remove(_tenantKey);
    } else {
      await p.setString(_tenantKey, tenant.trim());
    }
    if (limit == null) {
      await p.remove(_limitKey);
    } else {
      await p.setInt(_limitKey, limit.clamp(1, 500));
    }
    if (maxPages == null) {
      await p.remove(_maxPagesKey);
    } else {
      await p.setInt(_maxPagesKey, maxPages.clamp(1, 50));
    }
    if (minAlt == null || minAlt.isNaN) {
      await p.remove(_minAltKey);
    } else {
      await p.setDouble(_minAltKey, minAlt);
    }
    if (maxAlt == null || maxAlt.isNaN) {
      await p.remove(_maxAltKey);
    } else {
      await p.setDouble(_maxAltKey, maxAlt);
    }
    if (bbox == null || bbox.trim().isEmpty) {
      await p.remove(_bboxKey);
    } else {
      await p.setString(_bboxKey, bbox.trim());
    }
    if (tenantAsHeader == null) {
      await p.remove(_tenantAsHeaderKey);
    } else {
      await p.setBool(_tenantAsHeaderKey, tenantAsHeader);
    }
    if (paramStyle == null) {
      await p.remove(_paramStyleKey);
    } else {
      await p.setString(_paramStyleKey, paramStyle.name);
    }
    if (cursorParamStyle == null) {
      await p.remove(_cursorParamStyleKey);
    } else {
      await p.setString(_cursorParamStyleKey, cursorParamStyle.name);
    }
    if (strictNextCursor == null) {
      await p.remove(_strictNextCursorKey);
    } else {
      await p.setBool(_strictNextCursorKey, strictNextCursor);
    }
  }
}

/// Kurumsal CAS’dan 3B threat tube paketi çeker.
class CasRemoteService {
  static Future<Cas3dPackage> pullCas3dPackage({http.Client? httpClient}) async {
    final url = await CasRemotePrefs.getUrl();
    if (url == null) {
      throw StateError('CAS URL ayarlı değil');
    }
    final baseUri = Uri.parse(url);
    final auth = await CasRemotePrefs.getAuthHeader();
    final tenant = await CasRemotePrefs.getTenant();
    final limit = await CasRemotePrefs.getLimit();
    final maxPages = await CasRemotePrefs.getMaxPages();
    final minAlt = await CasRemotePrefs.getMinAlt();
    final maxAlt = await CasRemotePrefs.getMaxAlt();
    final bbox = await CasRemotePrefs.getBbox();
    final tenantAsHeader = await CasRemotePrefs.getTenantAsHeader();
    final paramStyle = await CasRemotePrefs.getParamStyle();
    final cursorParamStyle = await CasRemotePrefs.getCursorParamStyle();
    final strictNextCursor = await CasRemotePrefs.getStrictNextCursor();
    final headers = <String, String>{
      'Authorization': ?auth,
      'Accept': 'application/json',
      if (tenantAsHeader && tenant != null) 'X-Tenant-Id': tenant,
    };
    final ownsClient = httpClient == null;
    final client = httpClient ?? http.Client();
    try {
      String? cursor;
      var page = 0;
      String? mergedName;
      String? mergedVersion;
      final mergedTubes = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      while (true) {
        page++;
        final qp = Map<String, String>.from(baseUri.queryParameters);
        final kTenant = paramStyle == CasRemoteParamStyle.snakeCase ? 'tenant_id' : 'tenant';
        final kMinAlt = paramStyle == CasRemoteParamStyle.snakeCase ? 'min_alt' : 'minAlt';
        final kMaxAlt = paramStyle == CasRemoteParamStyle.snakeCase ? 'max_alt' : 'maxAlt';
        final kCursor = switch (cursorParamStyle) {
          CasRemoteCursorParamStyle.cursor => 'cursor',
          CasRemoteCursorParamStyle.pageCursor => 'pageCursor',
          CasRemoteCursorParamStyle.pageSnakeCursor => 'page_cursor',
        };
        if (!tenantAsHeader && tenant != null) qp[kTenant] = tenant;
        if (limit != null) qp['limit'] = '$limit';
        if (minAlt != null) qp[kMinAlt] = minAlt.toStringAsFixed(1);
        if (maxAlt != null) qp[kMaxAlt] = maxAlt.toStringAsFixed(1);
        if (bbox != null) qp['bbox'] = bbox;
        if (cursor != null && cursor.isNotEmpty) qp[kCursor] = cursor;
        final uri = baseUri.replace(queryParameters: qp.isEmpty ? null : qp);

        final r = await client.get(uri, headers: headers).timeout(const Duration(seconds: 45));
        if (r.statusCode < 200 || r.statusCode >= 300) {
          throw Exception('CAS GET ${r.statusCode}');
        }
        final body = r.body.trim();
        if (body.isEmpty) throw Exception('CAS boş yanıt');
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('CAS JSON nesne olmalı');
        }

        final pageThreatTubes = decoded['threatTubes'];
        if (page == 1 && pageThreatTubes is List && !_hasPagingHints(decoded)) {
          return parseCas3dPackageJson(body);
        }

        final rawItems = decoded['items'] is List
            ? decoded['items'] as List
            : (pageThreatTubes is List ? pageThreatTubes : null);
        if (rawItems == null) {
          throw const FormatException('CAS items veya threatTubes listesi yok');
        }
        mergedName ??= (decoded['name']?.toString().trim().isNotEmpty ?? false)
            ? decoded['name'].toString().trim()
            : 'Remote CAS';
        mergedVersion ??= (decoded['version']?.toString().trim().isNotEmpty ?? false)
            ? decoded['version'].toString().trim()
            : 'paged';

        for (final item in rawItems) {
          if (item is! Map) continue;
          final entry = Map<String, dynamic>.from(item);
          final id = entry['id']?.toString().trim();
          if (id == null || id.isEmpty) continue;
          if (seenIds.add(id)) mergedTubes.add(entry);
        }

        final nextCursor = _readNextCursor(
          decoded,
          cursorParamStyle: cursorParamStyle,
          strict: strictNextCursor,
        );
        if (nextCursor == null || nextCursor.isEmpty) break;
        if (page >= maxPages) break;
        cursor = nextCursor;
      }
      if (mergedTubes.isEmpty) {
        throw const FormatException('CAS sayfalı yanıtta tube bulunamadı');
      }
      final merged = <String, Object?>{
        'name': mergedName,
        'version': mergedVersion,
        'threatTubes': mergedTubes,
      };
      return parseCas3dPackageJson(jsonEncode(merged));
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}

bool _hasPagingHints(Map<String, dynamic> json) {
  return json.containsKey('items') ||
      json.containsKey('nextCursor') ||
      json.containsKey('next_cursor') ||
      json.containsKey('cursor');
}

String? _readNextCursor(
  Map<String, dynamic> json, {
  required CasRemoteCursorParamStyle cursorParamStyle,
  required bool strict,
}) {
  if (strict) {
    switch (cursorParamStyle) {
      case CasRemoteCursorParamStyle.cursor:
        final c = json['cursor'];
        if (c is String && c.trim().isNotEmpty) return c.trim();
        return null;
      case CasRemoteCursorParamStyle.pageCursor:
        final c = json['pageCursor']?.toString();
        if (c != null && c.trim().isNotEmpty) return c.trim();
        return null;
      case CasRemoteCursorParamStyle.pageSnakeCursor:
        final c = json['page_cursor']?.toString();
        if (c != null && c.trim().isNotEmpty) return c.trim();
        return null;
    }
  }
  final a = json['nextCursor']?.toString();
  if (a != null && a.trim().isNotEmpty) return a.trim();
  final b = json['next_cursor']?.toString();
  if (b != null && b.trim().isNotEmpty) return b.trim();
  final c = json['cursor'];
  if (c is Map) {
    final nc = c['next']?.toString();
    if (nc != null && nc.trim().isNotEmpty) return nc.trim();
  }
  return null;
}
