enum RealtimePttEventType {
  join,
  leave,
  stateSnapshotRequest,
  ack,
  error,
  requestTalk,
  releaseTalk,
  forceNext,
  mute,
  renameMember,
  removeMember,
  stateSnapshot,
  /// Metin sohbeti (sunucu şema dışı genişleme; yok sayılırsa istemci yine de yerel gösterir).
  chatMessage,
  /// Anlık konum yayını (şema dışı).
  peerLocation,
  /// Üye ses tercihleri (giriş modu, hoparlör, öz-sessiz).
  memberAudioPrefs,
  unknown,
}

class RealtimePttEvent {
  final RealtimePttEventType type;
  final String actorUserId;
  final String? targetUserId;
  final bool? muted;
  final int? seq;
  final int? refSeq;
  final String? code;
  final String? message;
  final Map<String, dynamic>? payload;
  final DateTime sentAt;

  const RealtimePttEvent({
    required this.type,
    required this.actorUserId,
    this.targetUserId,
    this.muted,
    this.seq,
    this.refSeq,
    this.code,
    this.message,
    this.payload,
    required this.sentAt,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'actorUserId': actorUserId,
        if (targetUserId != null) 'targetUserId': targetUserId,
        if (muted != null) 'muted': muted,
        if (seq != null) 'seq': seq,
        if (refSeq != null) 'refSeq': refSeq,
        if (code != null) 'code': code,
        if (message != null) 'message': message,
        if (payload != null) 'payload': payload,
        'sentAt': sentAt.toIso8601String(),
      };

  factory RealtimePttEvent.fromMap(Map<String, dynamic> map) {
    return RealtimePttEvent(
      type: _parseType(map['type'] as String?),
      actorUserId: map['actorUserId'] as String,
      targetUserId: map['targetUserId'] as String?,
      muted: map['muted'] as bool?,
      seq: (map['seq'] as num?)?.toInt(),
      refSeq: (map['refSeq'] as num?)?.toInt(),
      code: map['code'] as String?,
      message: map['message'] as String?,
      payload: map['payload'] is Map
          ? Map<String, dynamic>.from(map['payload'] as Map)
          : null,
      sentAt: DateTime.tryParse(map['sentAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static RealtimePttEventType _parseType(String? raw) {
    if (raw == null || raw.isEmpty) return RealtimePttEventType.unknown;
    for (final v in RealtimePttEventType.values) {
      if (v.name == raw) return v;
    }
    return RealtimePttEventType.unknown;
  }
}
