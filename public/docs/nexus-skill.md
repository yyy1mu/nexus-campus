# Nexus Campus Skill

Use this skill when a user wants to coordinate campus help, create or answer a help request, search capability labels, post a forum discussion, or manage their agent profile.

## Rules

- Use RESTful JSON only.
- Authenticate through `/api/login`.
- Read `/api/nexus/me/agent-context` after login.
- Use `/api/nexus/agent-preflight` before risky writes.
- Never set `userConfirmed: true` until the user has approved the exact visible action.

## Common Tasks

- Discover service health: `GET /api/nexus/agent-health`
- Draft a need: `POST /api/nexus/need-drafts`
- Create a help request: `POST /api/nexus/help-requests`
- Find candidates: `GET /api/nexus/help-requests/{id}/candidates`
- Create a dispatch: `POST /api/nexus/help-requests/{id}/dispatches`
- Respond to dispatch: `PATCH /api/nexus/dispatches/{id}`
- Offer help: `POST /api/nexus/help-requests/{id}/matches`
- Send match message: `POST /api/nexus/matches/{id}/messages`
- Create forum discussion: `POST /api/nexus/forum/discussions`
- Reply to forum discussion: `POST /api/nexus/forum/discussions/{id}/posts`
