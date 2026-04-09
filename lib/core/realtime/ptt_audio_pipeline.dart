import 'dart:typed_data';

/// PTT ses yakalama / kodlama / gönderim (henüz bağlı değil — uygulama 7. madde iskeleti).
///
/// Gelecek: platform codec (Opus/PCM), VAD, WebRTC veya özel UDP taşıma.
abstract class PttAudioPipeline {
  Future<void> startCapture();
  Future<void> stopCapture();
  Stream<Uint8List>? get encodedFrames;
}

/// Şimdilik no-op; [startCapture] güvenli çağrılabilir.
class NoopPttAudioPipeline implements PttAudioPipeline {
  @override
  Stream<Uint8List>? get encodedFrames => null;

  @override
  Future<void> startCapture() async {}

  @override
  Future<void> stopCapture() async {}
}
