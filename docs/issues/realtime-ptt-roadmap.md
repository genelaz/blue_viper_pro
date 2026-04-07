# Realtime PTT Roadmap

This index summarizes planning-ready realtime PTT issues.

## Issue Index

| ID | Title | Priority | Owner | Target Sprint | Status | Dependencies |
|---|---|---|---|---|---|---|
| 01 | Apply Remote Events In PTT Service | P0 | Realtime Client | Sprint 1 | Ready | Issue 03 |
| 02 | Add Transport Unit Tests | P1 | Realtime Client | Sprint 1 | Ready | none |
| 03 | Implement state.snapshot Contract End-to-End | P0 | Realtime Backend + Realtime Client | Sprint 1-2 | Ready | backend room/session gateway readiness |
| 04 | Enforce Role-Based Moderation Server-Side | P0 | Realtime Backend | Sprint 2 | Ready | Issue 03 |
| 05 | Add ACK/ERROR Handling and Client Retry Policy | P1 | Realtime Client + Realtime Backend | Sprint 2 | Ready | Issue 03 |
| 06 | Member Rename Policy (Owner/Admin + Self) | P1 | Realtime Client + Realtime Backend | Sprint 1 | In Review | Issue 01 |

## Current Progress (Simple Checklist)

- [x] Issue 01 - Apply Remote Events In PTT Service
- [x] Issue 02 - Add Transport Unit Tests
- [x] Issue 03 - Implement state.snapshot Contract End-to-End
- [ ] Issue 04 - Enforce Role-Based Moderation Server-Side
- [x] Issue 05 - Add ACK/ERROR Handling and Client Retry Policy
- [x] Issue 06 - Member Rename Policy (Owner/Admin + Self)

## How To Use (Quick)

1. Pick the first unchecked item.
2. Open its linked issue spec.
3. Implement all Acceptance Criteria.
4. Run Test Plan and verify green.
5. Mark checkbox as done and update Status.

## Detailed Specs

- [Issue 01](./realtime-ptt-01-apply-remote-events.md)
- [Issue 02](./realtime-ptt-02-transport-tests.md)
- [Issue 03](./realtime-ptt-03-state-snapshot.md)
- [Issue 04](./realtime-ptt-04-role-enforcement.md)
- [Issue 05](./realtime-ptt-05-ack-retry-policy.md)
- [Issue 06](./realtime-ptt-06-member-rename-policy.md)

## Suggested Execution Order

1. Issue 03 (snapshot contract) in parallel with Issue 02 (transport tests)
2. Issue 01 (apply remote events in client)
3. Issue 06 (member rename policy)
4. Issue 04 (role enforcement)
5. Issue 05 (ack/retry policy)

## Backend Pending (Open Items)

- Implement websocket room/session gateway with strict `sessionId` scoping.
- Implement authoritative `state.snapshot` response source.
- Enforce role policy server-side for moderation events (`mute/remove/force_next/rename`).
- Implement server ACK/ERROR emission with `refSeq` and stable error codes.
- Add replay/rate-limit protections and moderation audit logs.

## Backend Kickoff Doc

- [Realtime Backend Minimum Spec](../realtime-backend-min-spec.md)
- [WebSocket wire contract + JSON Schema (v1)](../realtime-websocket-json-schema.md)
- [AsyncAPI stub (optional tooling)](../asyncapi/realtime-ptt-v1.yaml)
