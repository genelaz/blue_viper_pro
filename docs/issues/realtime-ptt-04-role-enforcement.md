# Issue 04 - Enforce Role-Based Moderation Server-Side

## Planning

- Priority: P0
- Estimate: 2-4 days
- Owner: Realtime Backend
- Dependencies: `Issue 03`
- Status: Ready
- Target Sprint: Sprint 2

## Definition of Done

- Server blocks unauthorized moderation actions for member role.
- Forbidden error path is covered by integration tests.
- Owner/admin allowed flows verified and documented.
- Audit logging for moderation actions is validated.

## Title
Enforce owner/admin permissions for moderation events.

## Description
Ensure only owner/admin can emit:

- `member.mute`
- `member.unmute`
- `member.remove`
- `ptt.force_next`

## Acceptance Criteria

- Member role receives `forbidden` for moderation actions.
- Owner/admin actions succeed and broadcast.
- Owner removal is blocked by policy.

## Test Plan

- Integration tests per role/event pair.
- Verify `error` payload returns `code=forbidden`.
