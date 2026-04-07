import 'dart:async';
import 'dart:convert';

import 'package:blue_viper_pro/core/realtime/group_session.dart';
import 'package:blue_viper_pro/core/realtime/ptt_queue.dart';
import 'package:blue_viper_pro/core/realtime/ptt_service_notice.dart';
import 'package:blue_viper_pro/core/realtime/realtime_ptt_events.dart';
import 'package:blue_viper_pro/core/realtime/websocket_transport_client.dart';
import 'package:blue_viper_pro/core/realtime/websocket_realtime_ptt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeWebSocketSink implements WebSocketSink {
  final List<Object?> sent = <Object?>[];
  final Completer<void> _done = Completer<void>();

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
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future get done => _done.future;
}

class _FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWebSocketChannel(this.stream, this.sink);

  @override
  final Stream<dynamic> stream;

  @override
  final WebSocketSink sink;

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
  WebSocketRealtimePttService makeService() {
    return WebSocketRealtimePttService(
      session: GroupSession(
        sessionId: 's1',
        name: 'Demo',
        ownerUserId: 'u1',
        maxMembers: 10,
        createdAt: DateTime.now(),
      ),
      owner: const GroupMember(
        userId: 'u1',
        displayName: 'Owner',
        role: GroupRole.owner,
      ),
    );
  }

  test('applies ordered remote events to queue state', () {
    final svc = makeService();
    svc.onRemoteEvent(
      RealtimePttEvent(
        type: RealtimePttEventType.join,
        actorUserId: 'u1',
        targetUserId: 'u2',
        sentAt: DateTime.parse('2026-01-01T10:00:00Z'),
      ),
    );
    svc.onRemoteEvent(
      RealtimePttEvent(
        type: RealtimePttEventType.join,
        actorUserId: 'u1',
        targetUserId: 'u3',
        sentAt: DateTime.parse('2026-01-01T10:00:01Z'),
      ),
    );
    svc.onRemoteEvent(
      RealtimePttEvent(
        type: RealtimePttEventType.requestTalk,
        actorUserId: 'u2',
        sentAt: DateTime.parse('2026-01-01T10:00:02Z'),
      ),
    );
    svc.onRemoteEvent(
      RealtimePttEvent(
        type: RealtimePttEventType.requestTalk,
        actorUserId: 'u3',
        sentAt: DateTime.parse('2026-01-01T10:00:03Z'),
      ),
    );

    expect(svc.state.currentSpeakerId, 'u2');
    expect(svc.state.queuedUserIds, ['u3']);

    svc.onRemoteEvent(
      RealtimePttEvent(
        type: RealtimePttEventType.releaseTalk,
        actorUserId: 'u2',
        sentAt: DateTime.parse('2026-01-01T10:00:04Z'),
      ),
    );
    expect(svc.state.currentSpeakerId, 'u3');
  });

  test('duplicate remote event is idempotent', () {
    final svc = makeService();
    final e = RealtimePttEvent(
      type: RealtimePttEventType.join,
      actorUserId: 'u1',
      targetUserId: 'u2',
      sentAt: DateTime.parse('2026-01-01T10:00:00Z'),
    );
    svc.onRemoteEvent(e);
    svc.onRemoteEvent(e);
    expect(svc.state.members.keys.where((id) => id == 'u2').length, 1);
  });

  test('state snapshot replaces local state', () {
    final svc = makeService();
    svc.onRemoteEvent(
      RealtimePttEvent(
        type: RealtimePttEventType.stateSnapshot,
        actorUserId: 'server',
        sentAt: DateTime.parse('2026-01-01T10:00:00Z'),
        payload: {
          'currentSpeakerId': 'u3',
          'queuedUserIds': ['u2'],
          'members': [
            {
              'userId': 'u1',
              'displayName': 'Owner',
              'role': 'owner',
              'muted': false,
            },
            {
              'userId': 'u2',
              'displayName': 'M2',
              'role': 'member',
              'muted': false,
            },
            {
              'userId': 'u3',
              'displayName': 'M3',
              'role': 'member',
              'muted': false,
            },
          ],
        },
      ),
    );
    expect(svc.state.currentSpeakerId, 'u3');
    expect(svc.state.queuedUserIds, ['u2']);
    expect(svc.state.members.length, 3);
  });

  test('renameMember event updates display name', () {
    final svc = makeService();
    svc.onRemoteEvent(
      RealtimePttEvent(
        type: RealtimePttEventType.join,
        actorUserId: 'u1',
        targetUserId: 'u2',
        sentAt: DateTime.parse('2026-01-01T10:00:00Z'),
      ),
    );
    svc.onRemoteEvent(
      RealtimePttEvent(
        type: RealtimePttEventType.renameMember,
        actorUserId: 'u1',
        targetUserId: 'u2',
        payload: const {'displayName': 'Takim-2'},
        sentAt: DateTime.parse('2026-01-01T10:00:01Z'),
      ),
    );
    expect(svc.state.members['u2']?.displayName, 'Takim-2');
  });

  test('connect sends join and snapshot request commands', () async {
    final sink = _FakeWebSocketSink();
    final transport = WebSocketTransportClient(
      uri: Uri.parse('ws://example.test'),
      channelConnector: (_) =>
          _FakeWebSocketChannel(const Stream<dynamic>.empty(), sink),
    );
    final svc = WebSocketRealtimePttService(
      session: GroupSession(
        sessionId: 's1',
        name: 'Demo',
        ownerUserId: 'u1',
        maxMembers: 10,
        createdAt: DateTime.now(),
      ),
      owner: const GroupMember(
        userId: 'u1',
        displayName: 'Owner',
        role: GroupRole.owner,
      ),
      transportClient: transport,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final payloads = sink.sent.whereType<String>().toList();
    expect(payloads.any((e) => e.contains('"type":"join"')), isTrue);
    expect(
      payloads.any((e) => e.contains('"type":"stateSnapshotRequest"')),
      isTrue,
    );
    await svc.dispose();
  });

  test('ack clears pending command and avoids extra retries', () async {
    final sink = _FakeWebSocketSink();
    final incoming = StreamController<dynamic>();
    final transport = WebSocketTransportClient(
      uri: Uri.parse('ws://example.test'),
      channelConnector: (_) => _FakeWebSocketChannel(incoming.stream, sink),
    );
    final svc = WebSocketRealtimePttService(
      session: GroupSession(
        sessionId: 's1',
        name: 'Demo',
        ownerUserId: 'u1',
        maxMembers: 10,
        createdAt: DateTime.now(),
      ),
      owner: const GroupMember(
        userId: 'u1',
        displayName: 'Owner',
        role: GroupRole.owner,
      ),
      transportClient: transport,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    sink.sent.clear();
    svc.requestTalk('u1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final request = sink.sent.whereType<String>().toList();
    final talkRaw = request.firstWhere((e) => e.contains('"type":"requestTalk"'));
    final seq = (jsonDecode(talkRaw) as Map<String, dynamic>)['seq'] as int;
    incoming.add(
      jsonEncode({
        'sessionId': 's1',
        'type': 'ack',
        'actorUserId': 'server',
        'refSeq': seq,
        'sentAt': '2026-01-01T10:00:00Z',
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final talkSendsBefore = sink.sent
        .whereType<String>()
        .where((e) => e.contains('"type":"requestTalk"'))
        .length;
    expect(talkSendsBefore, 1);
    await Future<void>.delayed(const Duration(seconds: 3));
    final talkSendsAfter = sink.sent
        .whereType<String>()
        .where((e) => e.contains('"type":"requestTalk"'))
        .length;
    expect(talkSendsAfter, 1);
    await svc.dispose();
    await incoming.close();
  });

  test('server error emits ux notice and requests state reconcile', () async {
    final sink = _FakeWebSocketSink();
    final incoming = StreamController<dynamic>();
    final transport = WebSocketTransportClient(
      uri: Uri.parse('ws://example.test'),
      channelConnector: (_) => _FakeWebSocketChannel(incoming.stream, sink),
    );
    final svc = WebSocketRealtimePttService(
      session: GroupSession(
        sessionId: 's1',
        name: 'Demo',
        ownerUserId: 'u1',
        maxMembers: 10,
        createdAt: DateTime.now(),
      ),
      owner: const GroupMember(
        userId: 'u1',
        displayName: 'Owner',
        role: GroupRole.owner,
      ),
      transportClient: transport,
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    sink.sent.clear();
    svc.requestTalk('u1');
    await Future<void>.delayed(const Duration(milliseconds: 25));
    final talkJson = sink.sent.whereType<String>().firstWhere((e) => e.contains('"type":"requestTalk"'));
    final seq = (jsonDecode(talkJson) as Map<String, dynamic>)['seq'] as int;
    final notices = <PttServiceNotice>[];
    final sub = svc.uxNoticeStream.listen(notices.add);
    incoming.add(
      jsonEncode({
        'sessionId': 's1',
        'type': 'error',
        'actorUserId': 'server',
        'refSeq': seq,
        'code': 'forbidden',
        'message': 'moderation',
        'sentAt': '2026-01-01T10:00:00Z',
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(notices, hasLength(1));
    expect(notices.single.code, 'forbidden');
    expect(notices.single.refSeq, seq);
    expect(
      sink.sent.whereType<String>().any((e) => e.contains('"type":"stateSnapshotRequest"')),
      isTrue,
    );
    await sub.cancel();
    await svc.dispose();
    await incoming.close();
  });

  test('does not publish websocket when local requestTalk is rejected', () async {
    final sink = _FakeWebSocketSink();
    final transport = WebSocketTransportClient(
      uri: Uri.parse('ws://example.test'),
      channelConnector: (_) =>
          _FakeWebSocketChannel(const Stream<dynamic>.empty(), sink),
    );
    final svc = WebSocketRealtimePttService(
      session: GroupSession(
        sessionId: 's1',
        name: 'Demo',
        ownerUserId: 'u1',
        maxMembers: 10,
        createdAt: DateTime.now(),
      ),
      owner: const GroupMember(
        userId: 'u1',
        displayName: 'Owner',
        role: GroupRole.owner,
      ),
      transportClient: transport,
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    sink.sent.clear();
    final r = svc.requestTalk('unknown_user');
    expect(r, QueueEnqueueResult.forbidden);
    expect(sink.sent, isEmpty);
    await svc.dispose();
  });
}
