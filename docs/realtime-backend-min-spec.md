# Realtime Backend Minimum Spec (v1)

This spec is the minimum server-side contract needed to complete remaining
realtime work.

**Wire JSON Schema (normative types, examples, ACK rules):**
[`realtime-websocket-json-schema.md`](realtime-websocket-json-schema.md) and
[`schemas/realtime/v1/ptt-wire-v1.schema.json`](schemas/realtime/v1/ptt-wire-v1.schema.json).

## 1) Transport and session scope

- Transport: WebSocket over TLS (`wss://`).
- Every frame MUST include `sessionId`.
- Server MUST isolate traffic by `sessionId` room.

## 2) Authentication and authorization

- Client connects with bearer token (header or query token).
- Token must include:
  - `sub` (user id)
  - `sid` (session id scope)
  - `role` (`owner|admin|member`)
  - `exp`
- If token invalid/expired: reject connection.

## 3) Message envelope

```json
{
  "sessionId": "string",
  "type": "string",
  "actorUserId": "string",
  "targetUserId": "string|null",
  "seq": 123,
  "refSeq": 122,
  "code": "optional",
  "message": "optional",
  "payload": {},
  "sentAt": "ISO-8601"
}
```

## 4) Supported client -> server events

- `session.join`
- `session.leave`
- `stateSnapshotRequest`
- `ptt.request`
- `ptt.release`
- `ptt.forceNext`
- `member.mute`
- `member.removeMember`
- `member.renameMember`

## 5) Supported server -> client events

- `stateSnapshot` (authoritative full state)
- `ack`
- `error`
- Fanout of accepted room events (PTT + moderation + optional collaboration types below)

### 5.1) Map collaboration fanout (optional, shipped client)

Wire JSON `type` strings (see schema `ptt-wire-v1.schema.json`):

- `chatMessage` — sohbet; `payload.text` required.
- `peerLocation` — canlı konum ping’i; `payload.latitude` / `longitude` required.
- `memberAudioPrefs` — ses UI tercihleri; `payload` = `{ inputMode, speakerOn, micSelfMuted }`.

Rules:

- Server MUST validate `actorUserId` against the connection’s authenticated user
  for `memberAudioPrefs` (and SHOULD for `peerLocation` / `chatMessage`).
- Apply rate limits on `peerLocation` and `chatMessage`; drops are acceptable
  under load.

## 6) Authoritative snapshot payload

```json
{
  "currentSpeakerId": "u3",
  "queuedUserIds": ["u2", "u4"],
  "members": [
    { "userId": "u1", "displayName": "Lider", "role": "owner", "muted": false },
    { "userId": "u2", "displayName": "Ekip-2", "role": "member", "muted": false }
  ],
  "memberAudioPrefsByUser": {
    "u2": {
      "inputMode": "pushToTalk",
      "speakerOn": true,
      "micSelfMuted": false
    }
  }
}
```

`memberAudioPrefsByUser` is **optional**. When included, it is a map of `userId`
→ last-known prefs so mobile clients can restore “kimler dinlemiyor / sessiz”
immediately after reconnect.

Rules:

- Snapshot MUST represent server truth at emission time.
- On reconnect, client sends `stateSnapshotRequest`; server replies with
  `stateSnapshot` quickly (target p95 <= 500ms internal).

## 7) Role enforcement matrix

- `owner`: all actions allowed.
- `admin`: moderation allowed (mute/remove/forceNext/rename others).
- `member`:
  - allowed: `ptt.request`, `ptt.release`, `member.renameMember` for self only
  - forbidden: moderation on others

## 8) ACK and error behavior

- For accepted command, server emits:

```json
{
  "sessionId": "s1",
  "type": "ack",
  "actorUserId": "server",
  "refSeq": 123,
  "sentAt": "ISO-8601"
}
```

- For rejected command, server emits:

```json
{
  "sessionId": "s1",
  "type": "error",
  "actorUserId": "server",
  "refSeq": 123,
  "code": "forbidden|invalid_payload|rate_limited|session_closed|replay",
  "message": "human readable",
  "sentAt": "ISO-8601"
}
```

## 9) Replay and rate limit requirements

- Reject duplicated `(actorUserId, seq)` for a rolling window.
- Enforce rate limits per user/session:
  - `ptt.request`: burst + sustained limits
  - moderation actions: stricter limits
  - location updates (when enabled): adaptive caps

## 10) Audit requirements

Server must persist moderation logs for:

- `member.mute`
- `member.removeMember`
- `ptt.forceNext`
- `member.renameMember` (actor/target/old/new)

Minimal fields:

- `sessionId`, `actorUserId`, `targetUserId`, `action`, `ts`, `result`.

## 11) Minimal implementation order

1. WebSocket auth + room isolation
2. Authoritative in-memory session state and snapshot
3. Role enforcement
4. ACK/error with `refSeq`
5. Replay/rate-limit
6. Audit logs
