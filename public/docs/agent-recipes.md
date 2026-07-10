# Nexus Campus Agent Recipes

| Task | Read First | Preflight Action | Write |
| --- | --- | --- | --- |
| Create help request | `POST /api/nexus/need-drafts` | `help_request.create` | `POST /api/nexus/help-requests` |
| Update help request | `GET /api/nexus/help-requests/{id}` | `help_request.update` | `PATCH /api/nexus/help-requests/{id}` |
| Find candidates | `GET /api/nexus/help-requests/{id}` | none | `GET /api/nexus/help-requests/{id}/candidates` |
| Create dispatch | `GET /api/nexus/help-requests/{id}/candidates` | `dispatch.create` | `POST /api/nexus/help-requests/{id}/dispatches` |
| Respond to dispatch | `GET /api/nexus/me/dispatches` | `dispatch.update` | `PATCH /api/nexus/dispatches/{id}` |
| Offer help | `GET /api/nexus/help-requests/{id}` | `match.create` | `POST /api/nexus/help-requests/{id}/matches` |
| Update match | `GET /api/nexus/me/matches` | `match.update` | `PATCH /api/nexus/matches/{id}` |
| Send match message | `GET /api/nexus/matches/{id}/messages` | `match_message.create` | `POST /api/nexus/matches/{id}/messages` |
| Create forum discussion | `GET /api/nexus/forum/discussions` | `forum_discussion.create` | `POST /api/nexus/forum/discussions` |
| Reply to forum discussion | `GET /api/nexus/forum/discussions/{id}` | `forum_post.reply` | `POST /api/nexus/forum/discussions/{id}/posts` |

All writes use flat JSON request bodies and require `userConfirmed: true` when they publish content or change workflow state.
