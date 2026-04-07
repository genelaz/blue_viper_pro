# Security Model (Realtime Sessions)

This document defines baseline security controls for unified realtime sessions.

## 1) Identity and authorization

- Require authenticated user identity.
- Issue short-lived session-scoped token:
  - `sub` = user id
  - `sid` = session id
  - `role` = owner/admin/member
  - `exp` = short expiry
- Realtime gateway validates token on connect and periodically.

## 2) Role policy

- **owner**
  - full moderation and lifecycle controls
- **admin**
  - moderation controls granted by owner
- **member**
  - location/presence/PTT participation only

Server must enforce role checks for moderation events.

## 3) Message integrity and replay protection

- Require:
  - `seq` monotonic per actor
  - `sentAt` within acceptable skew window
- Reject replayed or stale commands.

## 4) Confidentiality

- Transport: TLS required.
- Recommended: end-to-end encrypted payload envelope for:
  - location data
  - PTT control metadata if sensitive

## 5) Key management (if E2EE enabled)

- Per-session key material
- Rotate keys on:
  - member removal
  - privileged role changes
  - periodic schedule
- Ensure removed users cannot decrypt future payloads.

## 6) Abuse controls

- Rate limits per user/session for:
  - location updates
  - moderation actions
  - join attempts
- Temporary mute or cooldown on abuse.
- Audit all moderation actions.

## 7) Privacy controls

- Session visibility strictly by membership.
- Optional retention policy:
  - ephemeral live-only mode
  - bounded history mode
- Expose user controls:
  - start/stop sharing
  - leave session
  - emergency privacy stop

## 8) Operational security

- Structured logs without sensitive raw coordinates where possible.
- Alerting for:
  - auth failures
  - replay spikes
  - anomaly in event volume
- Incident runbook for token/key revocation.
