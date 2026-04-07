# Issue 06 - Member Rename Policy (Owner/Admin + Self)

## Planning

- Priority: P1
- Estimate: 1 day
- Owner: Realtime Client + Realtime Backend
- Dependencies: Issue 01
- Status: In Review
- Target Sprint: Sprint 1

## Definition of Done

- Owner/admin can rename other members.
- Any member can rename only self.
- Rename events are propagated through realtime event pipeline.
- Unit tests cover authorization and event-apply behavior.

## Title
Add controlled member display-name rename in session groups.

## Description
Support rename behavior in group sessions:

- owner/admin can rename other users
- users can rename themselves

The behavior should be enforced consistently in local controller, realtime
service abstraction, and remote event handling.

## Acceptance Criteria

- Rename API exists at controller and service levels.
- Unauthorized rename attempts are rejected.
- UI exposes self-rename and owner/admin rename actions.
- Remote `renameMember` event updates display names in state.

## Test Plan

- Unit test for rename authorization matrix.
- Remote event test for `renameMember` state application.
- Regression check for maps PTT panel interactions.
