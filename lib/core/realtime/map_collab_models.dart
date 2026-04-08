/// Grup sohbet satırı (harita işbirliği).
class MapCollabChatMessage {
  final String userId;
  final String displayName;
  final String text;
  final DateTime sentAt;

  const MapCollabChatMessage({
    required this.userId,
    required this.displayName,
    required this.text,
    required this.sentAt,
  });
}

/// Akran cihazının paylaştığı anlık konum.
class MapCollabPeerLocation {
  final String userId;
  final double latitude;
  final double longitude;
  final double? altitudeM;
  final DateTime sentAt;

  const MapCollabPeerLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.altitudeM,
    required this.sentAt,
  });
}
