# Issue 02 - Add Transport Unit Tests

## Planning

- Priority: P1
- Estimate: 1-2 days
- Owner: Realtime Client
- Dependencies: none
- Status: In Review
- Target Sprint: Sprint 1

## Definition of Done

- Transport unit test suite covers reconnect/backoff/dispose scenarios.
- Flaky behavior is not observed across repeated CI runs.
- Existing realtime/maps tests remain green.

## Title
Add unit tests for `WebSocketTransportClient` reconnect/backoff behavior.

## Description
Add tests for connect lifecycle, reconnection timing growth, message parsing,
and disposal behavior.

## Acceptance Criteria

- Reconnect attempts use exponential backoff and cap at max delay.
- `dispose()` stops reconnect attempts.
- JSON messages are emitted as `Map<String, dynamic>`.

## Test Plan

- Use a fake/mock channel stream.
- Verify delay sequence and cancellation semantics.
- Verify malformed payload handling (ignored/no crash).
