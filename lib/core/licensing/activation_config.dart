/// Derleme: `--dart-define=ACTIVATION_API_URL=https://senin-worker.workers.dev`
///
/// Worker kök adresi (path eklemeden). Boş bırakılırsa kodlar APK içi hash ile
/// doğrulanır ve her cihazda kullanılabilir.
class ActivationConfig {
  static const String apiActivateUrl = String.fromEnvironment(
    'ACTIVATION_API_URL',
    defaultValue: '',
  );

  /// Uzak sunucu ile tek cihaza bağlı aktivasyon.
  static bool get useRemoteBinding => apiActivateUrl.trim().isNotEmpty;
}
