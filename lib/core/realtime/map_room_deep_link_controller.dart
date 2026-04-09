import 'package:flutter/foundation.dart';

import 'map_room_invite_link.dart';

/// Uygulama genelinden gelen harita oda davetini [MapsPage] tüketene kadar tutar.
class MapRoomDeepLinkController extends ChangeNotifier {
  MapRoomDeepLinkController._();
  static final instance = MapRoomDeepLinkController._();

  MapRoomInviteParse? _pending;

  /// Tüketilmemiş davet var mı (UI bilgi satırı için).
  bool get hasPending => _pending != null;

  void offer(MapRoomInviteParse invite) {
    _pending = invite;
    notifyListeners();
  }

  /// Bekleyen daveti al ve sıfırla; yoksa null.
  MapRoomInviteParse? takePending() {
    final x = _pending;
    _pending = null;
    if (x != null) notifyListeners();
    return x;
  }
}
