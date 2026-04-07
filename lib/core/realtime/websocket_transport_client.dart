import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketChannelConnector = WebSocketChannel Function(Uri uri);

class WebSocketTransportClient {
  final Uri uri;
  final Duration reconnectBaseDelay;
  final Duration reconnectMaxDelay;
  final WebSocketChannelConnector _channelConnector;
  final void Function(Duration delay)? onReconnectScheduled;
  final void Function()? onConnected;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _manuallyClosed = false;
  Duration _currentDelay;
  Timer? _reconnectTimer;

  final _messagesCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messagesCtrl.stream;

  WebSocketTransportClient({
    required this.uri,
    this.reconnectBaseDelay = const Duration(seconds: 1),
    this.reconnectMaxDelay = const Duration(seconds: 20),
    WebSocketChannelConnector? channelConnector,
    this.onReconnectScheduled,
    this.onConnected,
  })  : _channelConnector = channelConnector ?? WebSocketChannel.connect,
        _currentDelay = reconnectBaseDelay;

  Future<void> connect() async {
    _manuallyClosed = false;
    _connectInternal();
  }

  void _connectInternal() {
    _reconnectTimer?.cancel();
    try {
      _channel = _channelConnector(uri);
      _sub = _channel!.stream.listen(
        (data) {
          try {
            final m = jsonDecode(data as String);
            if (m is Map<String, dynamic>) {
              _messagesCtrl.add(m);
            } else if (m is Map) {
              _messagesCtrl.add(Map<String, dynamic>.from(m));
            }
          } catch (_) {
            // Ignore malformed payloads to keep stream alive.
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
      );
      _currentDelay = reconnectBaseDelay;
      onConnected?.call();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manuallyClosed) return;
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_currentDelay, _connectInternal);
    onReconnectScheduled?.call(_currentDelay);
    final doubled = _currentDelay * 2;
    _currentDelay = doubled > reconnectMaxDelay ? reconnectMaxDelay : doubled;
  }

  void send(Map<String, dynamic> message) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode(message));
  }

  Future<void> dispose() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    await _messagesCtrl.close();
  }
}
