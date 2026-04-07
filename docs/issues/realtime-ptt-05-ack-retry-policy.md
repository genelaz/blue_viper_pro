# Issue 05 - Add ACK/ERROR Handling and Client Retry Policy

## Planning

- Priority: P1
- Estimate: 2-3 days
- Owner: Realtime Client + Realtime Backend
- Dependencies: `Issue 03`
- Status: In Review (client-side skeleton done)
- Target Sprint: Sprint 2

## Definition of Done

- ACK timeout/retry behavior is implemented with bounded retries.
- Error handling paths (`rate_limited`, `session_closed`, etc.) are covered.
- Retry policy is documented in realtime protocol docs.
- No regressions in realtime/maps test suites.

## Title
Implement ACK timeout and retry policy for outbound realtime events.

## Description
Add sequence tracking and retry for unacknowledged events; handle server
`error` responses gracefully.

## Acceptance Criteria

- Every outbound command has `seq`.
- Missing ACK within timeout triggers bounded retry.
- `error` response marks command failed and updates UI state.

## Test Plan

- Simulate dropped ACK and verify retry count/interval.
- Simulate `rate_limited` and `session_closed` errors; verify client behavior.
