# Issue 01 - Apply Remote Events In PTT Service

## Planning

- Priority: P0
- Estimate: 2-3 days
- Owner: Realtime Client
- Dependencies: `Issue 03`
- Status: In Review
- Target Sprint: Sprint 1

## Definition of Done

- All acceptance criteria are implemented.
- Unit tests for remote event application are added and passing.
- No regression in existing realtime/maps tests.
- PR reviewed and merged with updated docs if contract changed.

## Title
Implement remote event application in `WebSocketRealtimePttService`.

## Description
`onRemoteEvent` currently does not mutate queue state based on incoming events.
Implement deterministic application for:

- `ptt.request`
- `ptt.release`
- `ptt.force_next`
- `member.mute`
- `member.unmute`
- `member.remove`
- `state.snapshot`

## Acceptance Criteria

- Incoming event with matching `sessionId` updates local PTT state.
- Unknown/invalid event types are ignored safely.
- No duplicate side effects when same event is reprocessed.

## Test Plan

- Add unit test with ordered event stream; assert final speaker/queue/member states.
- Add out-of-order/replay test and verify conflict policy.
