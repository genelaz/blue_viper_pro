# Realtime PTT — WebSocket wire contract (JSON Schema v1)

Normative machine-readable schema:

- [`schemas/realtime/v1/ptt-wire-v1.schema.json`](schemas/realtime/v1/ptt-wire-v1.schema.json)

Human-oriented minimum server requirements remain in:

- [`realtime-backend-min-spec.md`](realtime-backend-min-spec.md)

This document aligns **wire `type` strings** with the shipped client enum
`RealtimePttEventType.name` (`lib/core/realtime/realtime_ptt_events.dart`).
Implementations SHOULD validate inbound frames with the JSON Schema above
(or generate types from it).

---

## 1. Transport and framing

| Aspect | Rule |
|--------|------|
| Protocol | WebSocket over TLS (`wss://`) |
| Frame | One UTF-8 JSON object per text frame |
| Session scope | Every frame MUST include `sessionId`; server isolates by room |
| Auth | Bearer token at connect (header or query); claims per [min-spec](realtime-backend-min-spec.md) §2 |

---

## 2. Shared envelope

All frames extend the same core fields (see `$defs.envelopeBase` in the schema):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sessionId` | string | yes | Active session / room id |
| `type` | string | yes | Event discriminator (see §4) |
| `actorUserId` | string | yes | User that caused emission (use stable id from token `sub`) |
| `targetUserId` | string \| null | no | Subject user for targeted actions |
| `muted` | boolean | no | Required when `type === "mute"` |
| `seq` | integer | see §3 | Client command sequence |
| `refSeq` | integer | ack/error | References the client `seq` being acknowledged or rejected |
| `code` | string | error | Stable machine code (§6) |
| `message` | string | no | Human-readable supplemental text |
| `payload` | object | snapshot/rename | Event-specific body |
| `sentAt` | string (date-time) | yes | RFC 3339 timestamp |

---

## 3. Sequencing, ACK, retry

- **Client commands:** SHOULD send monotonically increasing `seq` per
  `(sessionId, actorUserId)`. The shipped client assigns `seq` for every
  outbound command and tracks pending ACKs (see `WebSocketRealtimePttService`).
- **Server `ack`:** MUST include `refSeq` equal to the accepted command’s
  `seq`. `actorUserId` is typically `server` or a sentinel id; `sessionId`
  MUST match.
- **Server `error`:** MUST include `refSeq`, `code`, and SHOULD include
  `message`. Client clears pending state for that `seq`.
- **Idempotency:** Server SHOULD reject duplicate `(actorUserId, seq)` within
  a rolling window ([min-spec](realtime-backend-min-spec.md) §9).

---

## 4. Event catalog (by `type`)

Unless noted, events MAY flow **client → server** as commands and **server →**
**client** as fanout after authorization. `stateSnapshot` is normally **server**
**→ client** only.

### 4.1 `join`

| Direction | Required fields | Notes |
|-----------|-----------------|-------|
| C → S | `sessionId`, `type`, `actorUserId`, `sentAt` | Initial connect handshake from app also sends `stateSnapshotRequest` |
| S → C | same + optional `targetUserId` | Fanout when a member enters; `targetUserId` MAY identify the joined user if distinct from `actor` |

### 4.2 `leave`

| Direction | Required fields | Notes |
|-----------|-----------------|-------|
| C → S | envelope | Voluntary exit |
| S → C | envelope + `targetUserId` typical | Confirm removal / disconnect |

### 4.3 `stateSnapshotRequest`

| Direction | Required fields | Notes |
|-----------|-----------------|-------|
| C → S | envelope | Client asks for authoritative state (e.g. after connect or reconnect) |
| S → C | — | Not fanout; server responds with `stateSnapshot` |

### 4.4 `stateSnapshot`

| Direction | Required fields | Notes |
|-----------|-----------------|-------|
| S → C | `payload` per `$defs.stateSnapshotPayload` | Authoritative truth; overrides local cache |

`payload` shape:

```json
{
  "currentSpeakerId": "u3",
  "queuedUserIds": ["u2", "u4"],
  "members": [
    {
      "userId": "u1",
      "displayName": "Lider",
      "role": "owner",
      "muted": false
    }
  ],
  "memberAudioPrefsByUser": {
    "u2": {
      "inputMode": "pushToTalk",
      "speakerOn": false,
      "micSelfMuted": false
    }
  }
}
```

`memberAudioPrefsByUser` is **optional**. When present, servers SHOULD include the
last-known prefs for each connected user so clients can repaint “dinlemiyorum /
sessiz mikrofon” after reconnect without waiting for fresh `memberAudioPrefs`
events.

### 4.5 `requestTalk` / `releaseTalk`

PTT floor control: request a turn / release the floor.

| Direction | Required fields | Role |
|-----------|-----------------|-------|
| C → S | envelope | `actorUserId` is the speaker |

### 4.6 `forceNext`

| Direction | Required fields | Role |
|-----------|-----------------|-------|
| C → S | envelope | **owner/admin** only (server MUST enforce) |

### 4.7 `mute`

| Direction | Required fields | Role |
|-----------|-----------------|-------|
| C → S | `targetUserId`, `muted` | **owner/admin** only |

### 4.8 `removeMember`

| Direction | Required fields | Role |
|-----------|-----------------|-------|
| C → S | `targetUserId` | **owner/admin**; cannot remove `owner` |

### 4.9 `renameMember`

| Direction | Required fields | Role |
|-----------|-----------------|-------|
| C → S | `targetUserId`, `payload.displayName` | Owner/admin may rename others; members may rename **self** only (`targetUserId === actorUserId`) |

### 4.10 `ack`

| Direction | Required fields | Notes |
|-----------|-----------------|-------|
| S → C | `refSeq` | Positive acknowledgment of command |

### 4.11 `error`

| Direction | Required fields | Notes |
|-----------|-----------------|-------|
| S → C | `refSeq`, `code` | Rejection of command |

### 4.12 `chatMessage` (harita işbirliği sohbeti)

| Direction | Required fields | Role |
|-----------|-----------------|-------|
| C → S, fanout to room | `payload.text` | Any member in session; server SHOULD rate-limit length / frequency |

`payload` MAY include `displayName` (client-supplied label for UI).

### 4.13 `peerLocation` (harita işbirliği konum ping’i)

| Direction | Required fields | Role |
|-----------|-----------------|-------|
| C → S, fanout to room | `payload.latitude`, `payload.longitude` | Optional `altitudeM`; server SHOULD cap update rate per user |

### 4.14 `memberAudioPrefs` (ses UI tercihleri — hoparlör / öz-sessiz / giriş modu)

| Direction | Required fields | Role |
|-----------|-----------------|-------|
| C → S, fanout to room | `payload` per `$defs.memberAudioPrefsPayload` | Emitter updates **own** prefs (`actorUserId`); server MUST NOT allow spoofing another user’s prefs |

Payload matches `MemberAudioPrefs.toPayload` in `lib/core/realtime/member_audio_prefs.dart`:

| Field | Type | Meaning |
|-------|------|---------|
| `inputMode` | `voiceActivated` \| `pushToTalk` \| `alwaysOn` | Planned mic behavior (UI + future audio pipeline) |
| `speakerOn` | boolean | `false` = kullanıcı odayı dinlemiyor (hoparlör kapalı) |
| `micSelfMuted` | boolean | Kullanıcının kendi mikrofonunu sessize alması (moderatör `mute` ayrı) |

**ACK:** Shipped client sends `seq` on collab events including `memberAudioPrefs`;
servers MAY ACK them like other commands, or accept without ACK if gateway treats
them as fire-and-forget (client already applied prefs locally).

---

## 5. Crosswalk: min-spec names ↔ wire `type`

[`realtime-backend-min-spec.md`](realtime-backend-min-spec.md) uses dotted
identifiers for readability. On the wire the client uses the **`type` values**
below.

| Min-spec (conceptual) | Wire `type` |
|-----------------------|-------------|
| `session.join` | `join` |
| `session.leave` | `leave` |
| `stateSnapshotRequest` | `stateSnapshotRequest` |
| `ptt.request` | `requestTalk` |
| `ptt.release` | `releaseTalk` |
| `ptt.forceNext` | `forceNext` |
| `member.mute` | `mute` |
| `member.removeMember` | `removeMember` |
| `member.renameMember` | `renameMember` |
| `stateSnapshot` | `stateSnapshot` |
| `ack` | `ack` |
| `error` | `error` |
| _(extension)_ `collab.chat` | `chatMessage` |
| _(extension)_ `collab.peerLocation` | `peerLocation` |
| _(extension)_ `member.audioPrefs` | `memberAudioPrefs` |

---

## 6. Stable `error.code` values

| Code | Typical use |
|------|-------------|
| `forbidden` | Role policy denied the command |
| `invalid_payload` | Schema / semantic validation failed |
| `rate_limited` | Quota exceeded |
| `session_closed` | Room no longer active |
| `replay` | Duplicate or out-of-window `seq` |

Additional codes MAY be added with backward-compatible client handling
(unknown code → generic error UX).

---

## 7. AsyncAPI stub (optional tooling)

For codegen / documentation generators that expect AsyncAPI, see:

- [`asyncapi/realtime-ptt-v1.yaml`](asyncapi/realtime-ptt-v1.yaml)

---

## 8. Validation

Backend teams can validate sample fixtures in CI using any JSON Schema
Draft 2020-12 validator against `ptt-wire-v1.schema.json`.
