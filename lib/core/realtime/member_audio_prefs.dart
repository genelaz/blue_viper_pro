/// PTT giriş modu (gerçek ses işleme sonrası bağlanır; şimdilik tercih + paylaşım).
enum PttInputMode {
  /// Ses eşiği algılandığında konuş (VAD) — tercih kaydı.
  voiceActivated,

  /// Bas-konuş.
  pushToTalk,

  /// Sürekli mikrofon açık (uygulama desteği geldiğinde).
  alwaysOn,
}

/// Üyenin ses dinleme / mikrofon tercihleri (odadaki diğerlerine `memberAudioPrefs` ile gider).
class MemberAudioPrefs {
  final PttInputMode inputMode;

  /// `false` → hoparlör/kulaklık kapalı (dinlemiyor); listede gösterilir.
  final bool speakerOn;

  /// Kendi mikrofonunu sessize alma (moderatör susturmasından ayrı).
  final bool micSelfMuted;

  const MemberAudioPrefs({
    this.inputMode = PttInputMode.pushToTalk,
    this.speakerOn = true,
    this.micSelfMuted = false,
  });

  Map<String, dynamic> toPayload() => {
        'inputMode': inputMode.name,
        'speakerOn': speakerOn,
        'micSelfMuted': micSelfMuted,
      };

  factory MemberAudioPrefs.fromPayload(Map<String, dynamic>? p) {
    if (p == null) return const MemberAudioPrefs();
    final raw = p['inputMode'] as String?;
    final mode = PttInputMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => PttInputMode.pushToTalk,
    );
    return MemberAudioPrefs(
      inputMode: mode,
      speakerOn: p['speakerOn'] as bool? ?? true,
      micSelfMuted: p['micSelfMuted'] as bool? ?? false,
    );
  }

  MemberAudioPrefs copyWith({
    PttInputMode? inputMode,
    bool? speakerOn,
    bool? micSelfMuted,
  }) {
    return MemberAudioPrefs(
      inputMode: inputMode ?? this.inputMode,
      speakerOn: speakerOn ?? this.speakerOn,
      micSelfMuted: micSelfMuted ?? this.micSelfMuted,
    );
  }
}
