# Realtime System Architecture (Unified)

This document describes a unified realtime architecture for:

- group presence
- live location sharing
- push-to-talk queue
- role-based moderation

All capabilities are scoped by a common `sessionId`.

## 1) High-level components

- **Mobile App (Flutter)**
  - Maps UI, session UI, PTT controls
  - Local state cache and stale detection
  - Secure token handling
- **Realtime Gateway**
  - WebSocket entrypoint
  - Session-level authorization
  - Fanout by room (`sessionId`)
- **Session Service**
  - session lifecycle (create/join/leave/close)
  - role and membership policies
- **State Service**
  - optional state snapshot source
  - last known positions/presence
  - queue/mute/member control state
- **Audit + Metrics**
  - moderation logs
  - message latency/drop metrics

## 2) Unified session model

Minimum session fields:

- `sessionId`
- `ownerUserId`
- `maxMembers` (10/20/30)
- `createdAt`
- `expiresAt`

All realtime messages must include `sessionId`.

## 3) Runtime flow

1. App gets auth token and session token.
2. App opens websocket and sends `session.join`.
3. App receives `state.snapshot`.
4. App emits:
   - `location.update`
   - `ptt.request` / `ptt.release`
   - moderation events (owner/admin)
5. Gateway validates token scope + role permissions.
6. Gateway fans out accepted events to room peers.

## 4) Queue and moderation behavior

- Single-speaker PTT (default)
- FIFO queue
- owner/admin can:
  - force next speaker
  - mute/unmute
  - remove member

## 5) Scalability guidelines

- 10 members: 2-3s location cadence
- 20 members: 3-5s location cadence
- 30 members: 5-8s adaptive cadence

Client rendering:

- viewport-aware markers
- stale-state rendering
- optional clustering for high density

## 6) Resilience and reconnect

- exponential backoff reconnect
- event ACK/sequence for ordering and retry
- on reconnect, request `state.snapshot`
- resolve local state from snapshot + newer events

## 7) Phased rollout

- **Phase A:** in-memory transport + local behavior
- **Phase B:** remote gateway wired, no E2EE
- **Phase C:** E2EE envelopes + key rotation
- **Phase D:** production hardening (abuse controls, SLOs)
