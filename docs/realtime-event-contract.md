# Realtime Event Contract (Unified v0)

This contract defines a common envelope for all realtime features.

## 1) Event envelope

```json
{
  "sessionId": "string",
  "type": "string",
  "actorUserId": "string",
  "targetUserId": "string|null",
  "payload": {},
  "seq": 123,
  "refSeq": 122,
  "code": "optional_error_or_status_code",
  "message": "optional_human_readable_message",
  "sentAt": "2026-04-07T10:00:00Z"
}
```

### Required fields

- `sessionId`
- `type`
- `actorUserId`
- `seq`
- `sentAt`

### Optional

- `targetUserId`
- `payload`
- `refSeq`
- `code`
- `message`

## 2) Event namespaces

- `session.join`
- `session.leave`
- `state.snapshot`
- `presence.update`
- `location.update`
- `ptt.request`
- `ptt.release`
- `ptt.force_next`
- `member.mute`
- `member.unmute`
- `member.remove`
- `error`
- `ack`

## 3) ACK contract

```json
{
  "sessionId": "string",
  "type": "ack",
  "ackSeq": 123,
  "serverTs": "2026-04-07T10:00:01Z"
}
```

If no ACK in timeout window, client may retry with same `seq`.

## 4) Error contract

```json
{
  "sessionId": "string",
  "type": "error",
  "code": "forbidden|invalid_payload|rate_limited|session_closed",
  "message": "human readable",
  "refSeq": 123
}
```

## 5) Session filtering

Client MUST ignore events where `sessionId` does not match active session.

## 6) Ordering rules

- `seq` must be monotonic per actor/session.
- Client applies only newer events for same actor where relevant.
- Snapshot events override stale local cache.

## 7) Presence and location payload examples

### presence.update

```json
{
  "isLive": true,
  "battery": 84,
  "network": "lte"
}
```

### location.update

```json
{
  "lat": 39.92,
  "lng": 32.85,
  "acc": 8.0,
  "heading": 124.0,
  "speed": 1.8
}
```

## 8) PTT payload examples

### ptt.request

```json
{
  "mode": "single_speaker"
}
```

### member.mute / member.unmute

```json
{
  "reason": "moderation"
}
```
