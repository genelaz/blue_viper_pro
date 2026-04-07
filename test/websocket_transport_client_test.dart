import 'dart:async';

import 'package:blue_viper_pro/core/realtime/websocket_transport_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeWebSocketSink implements WebSocketSink {
  final List<Object?> sent = <Object?>[];
  bool closed = false;
  final _done = Completer<void>();

  @override
  void add(message) => sent.add(message);

  @override
  void addError(error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {
    await for (final event in stream) {
      add(event);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {
    closed = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future get done => _done.future;
}

class _FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWebSocketChannel(StreamController<dynamic> controller, this.fakeSink)
      : stream = controller.stream;

  @override
  final Stream<dynamic> stream;

  final _FakeWebSocketSink fakeSink;

  @override
  WebSocketSink get sink => fakeSink;

  @override
  String? get closeReason => null;

  @override
  int? get closeCode => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future<void>.value();
}

void main() {
  test('parses valid json map and ignores malformed payload', () async {
    final inCtrl = StreamController<dynamic>();
    final sink = _FakeWebSocketSink();
    final c = WebSocketTransportClient(
      uri: Uri.parse('ws://example.test'),
      channelConnector: (_) => _FakeWebSocketChannel(inCtrl, sink),
    );
    await c.connect();

    final received = <Map<String, dynamic>>[];
    final sub = c.messages.listen(received.add);

    inCtrl.add('{bad json');
    inCtrl.add('{"type":"ok","value":1}');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(received.length, 1);
    expect(received.first['type'], 'ok');
    await sub.cancel();
    await c.dispose();
    await inCtrl.close();
  });

  test('reconnect scheduling uses exponential backoff up to cap', () async {
    final delays = <Duration>[];
    final c = WebSocketTransportClient(
      uri: Uri.parse('ws://example.test'),
      reconnectBaseDelay: const Duration(milliseconds: 10),
      reconnectMaxDelay: const Duration(milliseconds: 40),
      channelConnector: (_) => throw Exception('connect fail'),
      onReconnectScheduled: delays.add,
    );

    await c.connect();
    await Future<void>.delayed(const Duration(milliseconds: 95));
    await c.dispose();

    expect(delays.length, greaterThanOrEqualTo(3));
    expect(delays[0], const Duration(milliseconds: 10));
    expect(delays[1], const Duration(milliseconds: 20));
    expect(delays[2], const Duration(milliseconds: 40));
  });

  test('dispose stops pending reconnect loop', () async {
    var scheduledCount = 0;
    final c = WebSocketTransportClient(
      uri: Uri.parse('ws://example.test'),
      reconnectBaseDelay: const Duration(milliseconds: 10),
      reconnectMaxDelay: const Duration(milliseconds: 20),
      channelConnector: (_) => throw Exception('connect fail'),
      onReconnectScheduled: (_) => scheduledCount++,
    );
    await c.connect();
    await Future<void>.delayed(const Duration(milliseconds: 12));
    await c.dispose();
    final countAtDispose = scheduledCount;
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(scheduledCount, countAtDispose);
  });
}
