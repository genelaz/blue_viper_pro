import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'activation_config.dart';

class ActivationApiResult {
  const ActivationApiResult({
    required this.ok,
    this.errorCode,
    this.statusCode = 0,
  });

  final bool ok;
  /// Sunucudan gelen `error` alanı (örn. `unknown_code`, `code_used_other_device`)
  final String? errorCode;
  final int statusCode;
}

Future<ActivationApiResult> postRemoteActivation({
  required String code12,
  required String deviceId,
}) =>
    postRemoteActivationWithUri(
      code12: code12,
      deviceId: deviceId,
      uri: Uri.tryParse(ActivationConfig.apiActivateUrl.trim()),
      client: null,
    );

/// Test ve özel ortamlar için; üretimde [postRemoteActivation] kullanın.
@visibleForTesting
Future<ActivationApiResult> postRemoteActivationWithUri({
  required String code12,
  required String deviceId,
  required Uri? uri,
  http.Client? client,
}) async {
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
    return const ActivationApiResult(ok: false, errorCode: 'bad_config', statusCode: 0);
  }

  final httpClient = client ?? http.Client();
  try {
    final res = await httpClient
        .post(
          uri,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'code': code12, 'deviceId': deviceId}),
        )
        .timeout(const Duration(seconds: 25));

    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      return ActivationApiResult(
        ok: false,
        errorCode: 'bad_response',
        statusCode: res.statusCode,
      );
    }

    if (data is Map && data['ok'] == true) {
      return ActivationApiResult(ok: true, statusCode: res.statusCode);
    }

    final err = data is Map ? data['error']?.toString() : null;
    return ActivationApiResult(
      ok: false,
      errorCode: err ?? 'rejected',
      statusCode: res.statusCode,
    );
  } catch (_) {
    return const ActivationApiResult(ok: false, errorCode: 'network', statusCode: 0);
  } finally {
    if (client == null) {
      httpClient.close();
    }
  }
}
