# Issue 03 - Implement state.snapshot Contract End-to-End

## Planning

- Priority: P0
- Estimate: 3-5 days
- Owner: Realtime Backend + Realtime Client
- Dependencies: backend room/session gateway readiness
- Status: In Review (client contract path done)
- Target Sprint: Sprint 1-2

## Definition of Done

- Snapshot request/response path is implemented end-to-end.
- Reconnect flow restores state from snapshot reliably.
- Integration tests for snapshot success path pass in CI.
- Event contract docs are updated if snapshot schema changes.

## Title
Add `state.snapshot` request/response path in realtime backend and client.

## Description
On join or reconnect, client must receive authoritative session state
(members, queue, current speaker, muted flags, presence).

## Acceptance Criteria

- Client sends snapshot request after connect/join.
- Server returns snapshot scoped to `sessionId`.
- Client replaces stale local state with snapshot atomically.

## Test Plan

- Integration test: connect -> join -> snapshot applied.
- Reconnect test: local drift corrected by fresh snapshot.
