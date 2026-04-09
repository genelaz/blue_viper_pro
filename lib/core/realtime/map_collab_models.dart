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

/// Odadaki bir üyenin bildirdiği hedef nokta (gerçek zamanlı işaret).
class MapCollabTargetReport {
  final String userId;
  final String displayName;
  final double latitude;
  final double longitude;
  final double? bearingFromReporterDeg;
  final double? distanceFromReporterM;
  final DateTime sentAt;

  const MapCollabTargetReport({
    required this.userId,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.bearingFromReporterDeg,
    this.distanceFromReporterM,
    required this.sentAt,
  });

  Map<String, dynamic> toWirePayload() => {
        'displayName': displayName,
        'latitude': latitude,
        'longitude': longitude,
        if (bearingFromReporterDeg != null)
          'bearingFromReporterDeg': bearingFromReporterDeg,
        if (distanceFromReporterM != null)
          'distanceFromReporterM': distanceFromReporterM,
      };
}
