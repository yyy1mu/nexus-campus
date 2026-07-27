# Match Collaboration Demo Handoff

Date: 2026-07-28 (Asia/Shanghai)
Branch: `codex/frontend-ui-refresh-qwen`
Feature detail: [`2026-07-27-match-collaboration-workspace.md`](2026-07-27-match-collaboration-workspace.md)

## What This Version Adds

This demo turns an accepted Match into a shared collaboration workspace for both
participants and their agents:

- structured tasks with owners and `todo/doing/blocked/done` progress;
- cross-party human decision gates;
- deliverable submission, rejection, resubmission, and acceptance;
- pause/resume controls and an explicit baton for turn-taking;
- typed collaboration messages and a key-event timeline;
- snapshot recovery plus `afterId` incremental synchronization;
- `clientRequestId` idempotency for retried creates;
- dedicated desktop/mobile UI at `/collaborations` and
  `/matches/:id/workspace`.

The backend implementation is under `server/src/main/java/nexus/campus/help/`.
The main frontend screens are `web/src/views/CollaborationsView.vue` and
`web/src/views/MatchWorkspaceView.vue`. Database changes are in
`server/src/main/resources/db/migration/V3__match_collaboration_workspace.sql`.

## Run The Demo

From the repository root, start the H2 development backend:

```bash
cd server
mvn spring-boot:run
```

In another terminal, start the frontend:

```bash
cd web
npm install
npm run dev -- --host 127.0.0.1 --port 5173
```

Seed a ready-to-use collaboration:

```bash
node scripts/seed-collab-demo.mjs
```

Sign in with:

```text
username: linzhou_demo
password: demo-password-1
```

Open the `协作` navigation item, then enter the seeded in-progress workspace.
The seed script is safe to rerun against a fresh H2 process. H2 data is
ephemeral and is cleared when the backend restarts.

## Verification

The committed acceptance commands are:

```bash
cd server && mvn test
cd web && npm run build
cd web && npm run type-check
node scripts/e2e-collab.mjs
```

Current evidence:

- Maven: 41 tests, 0 failures/errors/skips;
- collaboration E2E: 72 assertions passed;
- Vite production build and `vue-tsc --noEmit`: passed;
- real UI click-through: decision, deliverable review, message, completion;
- desktop and mobile evidence is stored under `screenshots/`.

## Demo Scope

- This is a product demo, not a production concurrency model. The verified
  contract covers the sequential collaboration flow and duplicate-create
  idempotency; simultaneous conflicting state transitions are out of scope.
- `userConfirmed` is an agent-supplied attestation. The server enforces
  participant, role, gate, review, and workflow structure, but cannot prove
  that a human physically initiated a request.
- Tasks communicate progress but do not hard-block requester-confirmed Match
  completion. Open decisions and submitted deliverables do block completion.
- Either participant may explicitly reassign a task owner; the event timeline
  records that handoff. Task status changes remain owner-only.
- Match status updates still require `allowAgentMatching`; decision review,
  deliverable review, pause/resume, and baton controls remain available after
  that permission is disabled.
- ESLint 9 flat configuration is not included. Build, type-check, Maven tests,
  and the collaboration E2E are the acceptance gates for this version.

## Screenshots

- [Collaboration list, desktop](../../screenshots/collaborations-desktop.png)
- [Collaboration list, mobile](../../screenshots/collaborations-mobile.png)
- [Workspace in progress, desktop](../../screenshots/collab-workspace-desktop.png)
- [Workspace in progress, mobile](../../screenshots/collab-workspace-mobile.png)
- [Completed workspace, desktop](../../screenshots/collab-workspace-completed-desktop.png)
