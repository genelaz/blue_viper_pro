import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/licensing/activation_api_client.dart';
import '../../../core/licensing/activation_config.dart';
import '../../../core/licensing/activation_store.dart';
import '../../../core/licensing/activation_validator.dart';
import '../../../core/licensing/device_identity.dart';

/// Uzak aktivasyon isteğini özelleştirmek için (widget testleri).
typedef ActivationRemoteRequest = Future<ActivationApiResult> Function({
  required String code12,
  required String deviceId,
});

/// İlk kurulumda 12 haneli kod ile açılış.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({
    super.key,
    required this.onActivated,
    this.remoteActivation,
    @visibleForTesting this.deviceIdForTest,
  });

  final VoidCallback onActivated;

  /// Boş değilse [ActivationConfig.useRemoteBinding] kapalı olsa bile uzak akış
  /// (cihaz kimliği + sunucu doğrulaması) kullanılır; üretimde verilmez.
  final ActivationRemoteRequest? remoteActivation;

  /// Testlerde [getDeviceActivationId] yerine sabit kimlik.
  @visibleForTesting
  final Future<String> Function()? deviceIdForTest;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _apiErrorTurkish(String? code) {
    switch (code) {
      case 'unknown_code':
        return 'Bu kod geçersiz veya sunucuda tanımlı değil.';
      case 'code_used_other_device':
        return 'Bu kod başka bir telefonda zaten kullanıldı; başka cihazda çalışmaz.';
      case 'bad_code':
        return 'Kod tam 12 rakam olmalıdır.';
      case 'bad_device':
        return 'Cihaz kimliği reddedildi. Uygulamayı yeniden başlatın.';
      case 'network':
        return 'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.';
      case 'bad_response':
      case 'rejected':
        return 'Sunucu yanıtı beklenenden farklı. Yöneticinize bildirin.';
      case 'bad_config':
        return 'Uygulama API adresiyle derlenmemiş (yapılandırma hatası).';
      default:
        return 'Aktivasyon başarısız (${code ?? 'bilinmeyen hata'}).';
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });

    final raw = _ctrl.text;
    final code = normalizeActivationInput(raw);
    if (!RegExp(r'^\d{12}$').hasMatch(code)) {
      setState(() {
        _busy = false;
        _error = 'Tam 12 rakam girin.';
      });
      return;
    }

    final useRemoteFlow =
        ActivationConfig.useRemoteBinding || widget.remoteActivation != null;

    if (useRemoteFlow) {
      final deviceId = widget.deviceIdForTest != null
          ? await widget.deviceIdForTest!()
          : await getDeviceActivationId();
      if (deviceId.isEmpty ||
          deviceId == 'unknown' ||
          deviceId == 'unsupported' ||
          deviceId == 'ios_unknown') {
        setState(() {
          _busy = false;
          _error = 'Bu cihaz için güvenli kimlik üretilemedi.';
        });
        return;
      }

      final result = widget.remoteActivation != null
          ? await widget.remoteActivation!(code12: code, deviceId: deviceId)
          : await postRemoteActivation(code12: code, deviceId: deviceId);
      if (!result.ok) {
        setState(() {
          _busy = false;
          _error = _apiErrorTurkish(result.errorCode);
        });
        return;
      }

      await ActivationStore.markActivatedRemote(deviceId: deviceId);
    } else {
      if (!isValidActivationCode(raw)) {
        setState(() {
          _busy = false;
          _error = 'Geçersiz kod. Size verilen listeden olmalıdır.';
        });
        return;
      }
      final deviceId = await getDeviceActivationId();
      await ActivationStore.markActivatedOffline(
        deviceId: deviceId.isEmpty ? null : deviceId,
      );
    }

    if (!mounted) return;
    setState(() => _busy = false);
    widget.onActivated();
  }

  @override
  Widget build(BuildContext context) {
    final remote = ActivationConfig.useRemoteBinding || widget.remoteActivation != null;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(Icons.lock_outline, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Blue Viper Pro',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                remote
                    ? 'Size verilen 12 haneli kodu girin. Her kod yalnızca bu telefonda bir kez '
                        'onaylanır; başka cihazda aynı kod çalışmaz. İnternet gerekir.'
                    : 'Uygulamayı kullanmak için size iletilen 12 haneli aktivasyon kodunu girin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              ),
              if (remote)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Yönetici modu: uzaktan tek cihaz kilidi açık.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.teal.shade800),
                  ),
                ),
              const SizedBox(height: 32),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                maxLength: 19,
                inputFormatters: [
                  _TwelveDigitGroupingFormatter(),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Aktivasyon kodu',
                  hintText: '0000 0000 0000',
                  counterText: '',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_busy) _submit();
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Aktifleştir'),
              ),
              const Spacer(),
              Text(
                remote
                    ? 'Kodu paylaşmadan önce kimin kullanacağını kontrol edin. Sunucu, kodu ilk doğrulayan '
                        'cihaza kilitler.'
                    : 'Bu sürüm çevrimdışı doğrulama kullanıyor: aynı kod birden fazla telefonda çalışabilir. '
                        'Tek cihaz için APK’yı ACTIVATION_API_URL ile derleyin (bkz. server/cloudflare-activation).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Görüntü: 0000 0000 0000 — değerlendirilen: 12 rakam.
class _TwelveDigitGroupingFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 12 ? digits.substring(0, 12) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i == 4 || i == 8) buf.write(' ');
      buf.write(trimmed[i]);
    }
    final t = buf.toString();
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}
