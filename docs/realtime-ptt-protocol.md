# Realtime PTT Protocol (v0 skeleton)

This document defines the current message envelope used by the client-side
realtime PTT transport.

## Envelope

Each websocket frame is JSON with these top-level keys:

- `sessionId` (string): room/session scope.
- `type` (string): one of
  - `join`
  - `leave`
  - `stateSnapshotRequest`
  - `requestTalk`
  - `releaseTalk`
  - `forceNext`
  - `mute`
  - `renameMember`
  - `removeMember`
  - `stateSnapshot`
  - `ack`
  - `error`
  - `chatMessage` (harita sohbeti)
  - `peerLocation` (harita konum paylaşımı)
  - `memberAudioPrefs` (ses tercihleri: giriş modu, hoparlör, öz-sessiz)
- `actorUserId` (string): user that emitted the action.
- `targetUserId` (string, optional): user impacted by the action.
- `muted` (bool, optional): mute state for `mute` event.
- `sentAt` (ISO-8601 string): client event timestamp.

## Session filtering

Client ignores events where incoming `sessionId` does not match current
`GroupSession.sessionId`.

## Runtime configuration

App supports these `--dart-define` keys:

- `PTT_BACKEND=remote|inMemory` (default: `remote`)
- `PTT_WS_URL=wss://...` (optional)

Example:

`flutter run --dart-define=PTT_BACKEND=remote --dart-define=PTT_WS_URL=wss://example/ws`

## Normative schema (backend)

For event-by-event JSON Schema (Draft 2020-12) and AsyncAPI stub, see
[`realtime-websocket-json-schema.md`](realtime-websocket-json-schema.md).
