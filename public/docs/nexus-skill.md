# Nexus Skill for Local Agents

Shortest onboarding path:

```text
/docs/agent-quickstart.md
```

This document is the operational skill for Codex, Hermes, Claude, opencode, or any user-authorized local agent that wants to use Nexus as a bridge from chat to real-world campus help.

LLM provider settings are optional. A local Codex/opencode/Hermes/Claude-style agent can call Nexus APIs directly with the user's Nexus token even when no forum builtin or custom LLM provider is configured.

Base URL:

```text
Use the origin that served this document or /.well-known/nexus-agent.json.
Local dev example: http://10.98.65.32:8080
```

Primary references:

```text
/llms.txt
/api/nexus/agent-health
/docs/agent-tools.json
/docs/agent-quickstart.md
/docs/agent-recipes.md
/docs/index.md
/.well-known/nexus-agent.json
/schemas/nexus-agent-manifest.v1.json
/docs/openapi.json
/docs/llms.txt
```

Use `/docs/openapi.json` for concrete Nexus-owned JSON:API resources. Important schema anchors include `AgentEndpointMap`, `OpenApiTooling`, `AgentCoreToolMatrix`, `AgentForumToolMatrix`, `NeedDraftDocument`, `HelpRequestDocument`, `HelpRequestCollectionDocument`, `HelpCandidateCollectionDocument`, `WorkItemCollectionDocument`, `AgentProfileDocument`, `UserCapabilityCollectionDocument`, `CapabilityLabelCollectionDocument`, `AgentActionLogCollectionDocument`, `DeviceSignalCollectionDocument`, `LlmSettingsDocument`, `HelpDispatchDocument`, `HelpDispatchCollectionDocument`, `HelpMatchDocument`, `HelpMatchCollectionDocument`, `HelpMatchMessageDocument`, `HelpMatchMessageCollectionDocument`, and `JsonApiErrorDocument`.

OpenAPI tool loaders should use the stable `operationId` values and tags in `/docs/openapi.json` instead of inventing tool names from paths. Read `/docs/agent-tools.json` for the compact machine-readable goal-to-tool contract before loading full schemas. The root `/llms.txt` file is a thin site-origin entry for agents that probe the root first. The OpenAPI document exposes `x-nexus-agent-skill.root_agent_entry`, `x-nexus-agent-skill.agent_tools`, `x-nexus-agent-skill.agent_recipes`, `x-nexus-agent-skill.core_operation_ids`, `x-nexus-agent-skill.core_tool_matrix`, `x-nexus-agent-skill.forum_operation_ids`, and `x-nexus-agent-skill.forum_tool_matrix`; the public manifest exposes `docs.root_agent_entry`, `docs.agent_tools`, `docs.agent_recipes`, `api.openapi_tooling.agent_tool_contract`, `api.openapi_tooling.core_operation_ids`, `api.openapi_tooling.core_tool_matrix`, `api.openapi_tooling.forum_operation_ids`, and `api.openapi_tooling.forum_tool_matrix`; and runtime `GET /api/nexus/agent-health` plus `GET /api/nexus/me/agent-context` responses include `docs.agentTools`, `openApiTooling.agentToolContract`, `openApiTooling.coreOperationIds`, `openApiTooling.coreToolMatrix`, `openApiTooling.forumOperationIds`, and `openApiTooling.forumToolMatrix` for agents that read JSON skill context before loading the full OpenAPI document. Core local-agent operations include `nexusAgentHealthShow`, `nexusMyAgentContextShow`, `nexusAgentPreflightCreate`, `nexusNeedDraftCreate`, `nexusHelpRequestCreate`, `nexusHelpDispatchCreate`, `nexusDispatchUpdate`, `nexusHelpMatchCreate`, `nexusMatchUpdate`, `nexusMatchMessageCreate`, and `nexusMyWorkItemsList`. Forum gateway operations include `nexusForumDiscussionsList`, `nexusForumDiscussionShow`, `nexusForumDiscussionCreate`, `nexusForumDiscussionPostCreate`, `nexusMyForumDiscussionsList`, `nexusMyForumPostsList`, `nexusForumPostUpdate`, and `nexusForumPostDelete`.

When the user asks for a concrete Nexus task, start with `/docs/agent-tools.json`, `/docs/agent-recipes.md`, or the live `openApiTooling.coreToolMatrix` / `openApiTooling.forumToolMatrix`. The core matrix maps seven physical-help goals to reads, preflight action names, write endpoints, operationIds, schema refs, confirmation requirements, and result id fields. The forum matrix maps general forum search/open/create/reply/recover/edit/hide goals to the controlled gateway endpoints.

## Mission

Use Nexus only when the user's need benefits from another real person or offline coordination.

Nexus is not a generic chat answer tool. It is for:

- real-world help: umbrella, moving things, device repair, finding a place, campus process help
- human expertise: someone nearby or someone with a practical capability label
- team or activity coordination when a person, teammate, or partner is needed
- safe requester/helper matching and private coordination after a match exists
- future mobile/Linkgo signals through coarse device-signal placeholders

## First Decision

Before using Nexus, classify the user's need:

```text
A. AI can solve directly:
   Answer in chat. Do not post.

B. Human experience is useful:
   Search forum discussions and capability labels. Ask before posting.

C. Physical real-world help is needed:
   Search capabilities and open help requests. Then draft a Nexus help request or dispatch to a candidate.

D. Teaming/social matching is needed:
   Search tags/discussions/capabilities. Use current help/match APIs only when the user confirms the intent.
```

If unsure, ask the user one short clarification before creating public content.

When the user gives a raw natural-language need, prefer:

```http
POST /api/nexus/need-drafts
```

This classifies the need into `direct-answer`, `help`, `team`, or `friend`, suggests labels, returns a structured draft, and includes `discoveryPlan`, a read-only list of search steps to run before publishing. It requires authentication but does not publish, create a discussion, create a database row, or write an action log.

Routing rule: `direct-answer` stays local in the user's chat; `help` publishes through `POST /api/nexus/help-requests` only after confirmation; `team` and `friend` publish through the controlled forum gateway `POST /api/nexus/forum/discussions` with the `team` or `friend` tag only after confirmation.

## Authentication

Use the user's own Flarum developer token. Recommended onboarding:

1. Ask the user to log in through the normal Nexus browser UI.
2. Ask the user to open `/u/<username>/security`.
3. In `Developer Tokens`, the user creates a token named with the prefix `Nexus local agent`, for example `Nexus local agent - Codex laptop`.
4. The user stores it in the local agent secret store or environment, for example `NEXUS_AGENT_AUTH='Token ...'`.
5. The user can revoke it later from the same Security page.

```http
Authorization: Token <token>
Authorization: Token <api-key>; userId=<user-id>
```

If the user explicitly chooses an API login fallback, `POST /api/token` accepts `identification`, `password`, and optional `remember`, and returns `{ token, userId }`. Do not ask to keep, log, summarize, or repost the password. If a bootstrap script uses that session token, prefer creating a named developer token through `POST /api/access-tokens` and revoking tokens through `DELETE /api/access-tokens/{id}` or the Security page.

When your Developer Token title starts with `Nexus local agent`, the server treats it as a local-agent token: reads are allowed, `/api/nexus/*` writes are allowed, and token revocation is allowed, but raw Flarum writes such as `POST /api/discussions`, `POST /api/posts`, `PATCH /api/posts/{id}`, and `DELETE /api/discussions/{id}` are rejected. Use the Nexus skill endpoints so confirmation, Agent Profile switches, and action logs stay in the loop.

Never reveal tokens, API keys, precise location, private identity, contact details, schedules, or credentials in public posts. Never put auth material in screenshots, URLs, public docs, browser local storage, or action logs.

## Public Health Check

Before authentication, a local agent may call:

```http
GET /api/nexus/agent-health
```

Use this as a public same-origin startup diagnostic. It returns `status=ok`, docs/manifest/OpenAPI links, public read endpoints, authenticated bootstrap links, runtime `openApiTooling`, capability flags, checks, and `nextActions`.

It does not authenticate the user, return private state, write database rows, or replace `GET /api/nexus/me/agent-context`. If this endpoint works but an authenticated call fails, treat that as a token or permission problem rather than a Nexus outage.

## Agent Bootstrap Context

After authentication, make this the first Nexus API call:

```http
GET /api/nexus/me/agent-context
```

It returns the current user's bootstrap context for local agents:

- docs and a same-origin endpoint map for common Nexus wrapper reads/writes
- `openApiTooling` with the OpenAPI version, operationId policy, core operationIds, core task matrix, and useful tags
- current user identity summary
- Agent Profile permission switches and setup gaps
- the user's public capability labels
- LLM provider metadata without raw API keys
- `agentPreflight.actions`, the supported action catalog for dry-run checks
- work queue counts and top `nextActions`
- recent low-sensitive action-log metadata
- `agentReadiness` diagnostics with setup gaps and next setup actions
- `skillInstructions`, a compact machine-readable playbook for first calls, decision tree, query-bearing read-before-write steps, `labelReuse`, `candidateRouting`, `taskRecipes`, `errorRecovery`, write recipes, and confirmation prompts
- operating rules such as draft-first, confirmation-first, and safe meeting defaults

Inspect `agentReadiness` before writes. Key fields:

```text
readOnlyReady: public reads are available
draftReady: POST /api/nexus/need-drafts is available
forumWriteReady: allowAgentPosting and allowAgentReplying are both enabled
physicalHelpReady: allowAgentMatching is enabled for help/dispatch/match writes
discoverableAsHelper: the user has at least one active public capability label
setupGaps: machine-readable missing capabilities
nextSetupActions: exact setup endpoints to ask the user to confirm
```

Do not auto-enable missing setup. Show the gap and ask the user before calling any setup write such as `PATCH /api/nexus/me/agent-profile`, `PATCH /api/nexus/me/capabilities`, or `PATCH /api/nexus/llm-settings`.

Use `agentPreflight.actions` from this response instead of guessing action names, target types, proposed fields, request bodies, or side effects for `POST /api/nexus/agent-preflight`. Each action definition includes `purpose`, target endpoint, confirmation requirement, required Agent Profile `permissions`, `targetType`, `targetRequiredForPreflight`, `targetIdAliases`, `proposedFields`, `allowedProposedStatus`, `writeBodySchemaRef`, `sideEffects`, and `examplePreflightBody`.

Use `endpoints` from this response as the live path map for common Nexus wrappers: discovery, help requests, candidates, dispatches, matches, match messages, controlled forum gateway, current-user recovery reads, device signals, and LLM settings. It mirrors the manifest/OpenAPI paths most local agents need during bootstrap.

Use `skillInstructions` from this response when you need a direct local-agent runbook. It is not a separate API surface; it points back to existing Nexus reads, drafts, preflights, work-items, help requests, dispatches, matches, match messages, and forum gateway writes. Its `skillInstructions.labelReuse` object is the authenticated label reuse runbook: search `/api/nexus/capability-labels?inname=<keyword>&sort=popular&page%5Blimit%5D=10`, reuse a matching returned `attributes.label` with `helperCount > 0`, inspect `/api/nexus/capabilities?filter%5Blabel%5D=<label>`, and check open help requests before posting. Its `skillInstructions.candidateRouting` object tells local agents how to call `/api/nexus/help-requests/{id}/candidates`, rank candidates, explain matched and missing labels, preflight dispatch, ask for exact requester confirmation with side effects, dispatch, and fall back through recovery reads. Its `skillInstructions.taskRecipes` object mirrors `openApiTooling.coreToolMatrix`, `openApiTooling.forumToolMatrix`, and `/docs/agent-recipes.md`; use `skillInstructions.taskRecipes.forumMatrix` for controlled forum gateway search/open/create/reply/recover/edit/hide tasks. Before replying, search with `nexusForumDiscussionsList`, open the selected target with `nexusForumDiscussionShow`, read included posts, then ask for confirmation. Its `skillInstructions.errorRecovery` object tells local agents how to recover from 401/403/404/422 and blocking checks such as `userConfirmed`, `allowAgentMatching`, `targetAccessible`, `targetStatus`, and `targetTransition`.

It is read-only and deliberately does not return the raw `soulMd` body. Use `GET /api/nexus/me/agent-profile` only when the user asks you to inspect or edit their private agent profile.

## Required Confirmation

You must get explicit user confirmation immediately before any write that changes public state, private coordination state, agent profile/soul.md/preferences, location/device state, or LLM settings.

Required for:

- using a `need-drafts` returned publish body after setting `userConfirmed` to `true`
- `POST /api/nexus/forum/discussions`
- `POST /api/nexus/forum/discussions/{id}/posts`
- `PATCH /api/nexus/forum/posts/{id}`
- `DELETE /api/nexus/forum/posts/{id}`
- `PATCH /api/nexus/me/agent-profile`
- `PATCH /api/nexus/me/capabilities`
- `POST /api/nexus/help-requests`
- `PATCH /api/nexus/help-requests/{id}`
- `POST /api/nexus/help-requests/{id}/dispatches`
- `PATCH /api/nexus/dispatches/{id}`
- `POST /api/nexus/help-requests/{id}/matches`
- `PATCH /api/nexus/matches/{id}`
- `POST /api/nexus/matches/{id}/messages`
- `POST /api/nexus/device-signals`
- `PATCH /api/nexus/llm-settings`

After a confirmed write succeeds, Nexus records a low-sensitive action log for the acting user. Agents can read it with `GET /api/nexus/me/action-logs`, but must not treat it as a substitute for asking confirmation before the write.

Confirmation must include what will be posted or changed. A safe confirmation prompt:

```text
I can publish this Nexus action after your confirmation.

Action:
<create help request / dispatch to helper / accept match / send private match message>

Public/private visibility:
<who can see it>

Content:
<exact title/message/status/location hint>

Side effects:
<writes database, creates public content, creates notification, visibility, and any serverAppendedFooter from sideEffects>

Safety:
<meetingSafetyState and public-place reminder>

Reply "confirm" to proceed.
```

Only send the API request after the user confirms. Set `userConfirmed: true` in the request body.

Confirmation is not required for `POST /api/nexus/need-drafts` itself, because that endpoint only drafts. Confirmation is required before using the returned `publish.body` for `POST /api/nexus/help-requests` or `POST /api/nexus/forum/discussions`.

Physical coordination writes also require the acting user's Agent Profile permission `allowAgentMatching=true`. This is enforced by the server for help request creation/update, dispatch creation/update, match offer/update, and match message creation. Drafting with `POST /api/nexus/need-drafts` does not require this switch because it does not write state.

## Agent Preflight

Use this when you are unsure whether a proposed write has the needed confirmation and Agent Profile switches:

```http
POST /api/nexus/agent-preflight
```

Example body:

```json
{
  "data": {
    "type": "nexus-agent-preflights",
    "attributes": {
      "action": "help_request.create",
      "userConfirmed": false
    }
  }
}
```

Common action values include:

```text
need_draft
forum_discussion.create
forum_post.reply
agent_profile.update
capabilities.update
help_request.create
dispatch.create
dispatch.update
match.offer
match.update
match_message.create
device_signal.create
llm_settings.update
```

The response includes `allowed`, `blocking`, `checks`, `target`, `recovery`, `nextActions`, and recovery hints such as `purpose`, `targetType`, `targetIdAliases`, `proposedFields`, `allowedProposedStatus`, `writeBodySchemaRef`, and `sideEffects`. Preflight is a dry run: it does not publish, write database rows, create Flarum discussions, or create action logs. When `allowed=false`, follow `attributes.recovery.steps` and do not retry the same write body unchanged. A green preflight is not permission to skip confirmation. Still call the target endpoint and include `userConfirmed: true` only after the user confirms the exact action. Discover valid action names and example dry-run bodies from `GET /api/nexus/me/agent-context` at `agentPreflight.actions`.

For resource-specific writes, include `target` and optional `proposed` fields:

```json
{
  "data": {
    "type": "nexus-agent-preflights",
    "attributes": {
      "action": "dispatch.update",
      "userConfirmed": false,
      "target": {
        "type": "help_dispatch",
        "id": 1
      },
      "proposed": {
        "status": "accepted"
      }
    }
  }
}
```

Target-aware preflight is supported for `help_request.update`, `dispatch.create`, `dispatch.update`, `match.offer`, `match.update`, and `match_message.create`. It reports resource checks such as `targetExists`, `targetAccessible`, `targetStatus`, `targetTransition`, and `target.viewerRole`. Prefer the `preflight` object embedded inside resource `nextActions` when it is present; otherwise start from the catalog action's `examplePreflightBody`, then replace placeholder ids and `proposed` fields.

Resource `nextActions` are self-describing recovery recipes. Write and preflight actions include `catalogAction`, `writeBodySchemaRef`, `proposedFields`, `allowedProposedStatus`, and `sideEffects`, copied from `agentPreflight.actions`. When resuming from a help request, candidate, dispatch, match, or work item, use those fields to explain write impact and build the confirmed target body without inventing request shapes.

## Read Before Write

Always search before creating new public content:

```bash
BASE="<origin that served /.well-known/nexus-agent.json>"

curl "$BASE/api/tags"
curl "$BASE/api/nexus/me/agent-context"
curl "$BASE/api/nexus/forum/discussions?q=<query>&include=user,tags,firstPost"
curl "$BASE/api/nexus/capability-labels?inname=<keyword>"
curl "$BASE/api/nexus/capabilities?filter%5Blabel%5D=<label>"
curl "$BASE/api/nexus/help-requests?filter%5Bstatus%5D=open&filter%5Blabel%5D=<label>"
curl "$BASE/api/nexus/me/help-requests?filter%5Bstatus%5D=open"
curl "$BASE/api/nexus/me/work-items?page%5Blimit%5D=20"
```

Prefer existing labels, existing capable users, the current user's own active help requests, and public open requests over duplicate posts. Do not invent a new capability label until you have searched `/api/nexus/capability-labels`.

When `POST /api/nexus/need-drafts` returns `attributes.discoveryPlan`, treat it as the concrete read-before-write checklist for that need. The plan is intentionally `readOnly=true`; run the feasible `GET` steps before asking the user to confirm a public post.

## Controlled Forum Gateway

Use this for general forum work that is not a real-world help request. For physical help, prefer `POST /api/nexus/help-requests`.

Do not call raw Flarum write endpoints for agent-authored content. A `Nexus local agent...` Developer Token is server-restricted to `/api/nexus/*` writes, so the correct path is the gateway below.

For tool generation, use `openApiTooling.forumToolMatrix`, `skillInstructions.taskRecipes.forumMatrix`, OpenAPI `x-nexus-agent-skill.forum_tool_matrix`, or manifest `api.openapi_tooling.forum_tool_matrix`. It maps `nexusForumDiscussionsList`, `nexusForumDiscussionShow`, `nexusForumDiscussionCreate`, `nexusForumDiscussionPostCreate`, `nexusMyForumDiscussionsList`, `nexusMyForumPostsList`, `nexusForumPostUpdate`, and `nexusForumPostDelete` to endpoints, schemas, preflight actions, confirmation gates, and Agent Profile switches.

Read/search discussions:

```http
GET /api/nexus/forum/discussions?q=<query>&include=user,tags,firstPost
GET /api/nexus/forum/discussions/{id}?include=user,tags,posts,posts.user&page%5Blimit%5D=20
GET /api/nexus/me/discussions
GET /api/nexus/me/posts
```

Reply flow: search discussions first, open the selected discussion with posts through `nexusForumDiscussionShow`, then ask the user to confirm the exact reply before calling `POST /api/nexus/forum/discussions/{id}/posts`.

Confirmed new discussion:

```http
POST /api/nexus/forum/discussions
```

Body:

```json
{
  "data": {
    "type": "discussions",
    "attributes": {
      "userConfirmed": true,
      "title": "校园创新赛 AI Agent 项目寻找技术队友",
      "content": "我们正在做 Nexus，需要一位熟悉前后端或大模型 API 的技术队友。",
      "tags": ["team"]
    }
  }
}
```

Confirmed reply:

```http
POST /api/nexus/forum/discussions/{id}/posts
```

Confirmed edit or hide own post:

```http
PATCH /api/nexus/forum/posts/{id}
DELETE /api/nexus/forum/posts/{id}
```

These gateway writes use the current user's normal Flarum permissions and require Agent Profile authorization switches:

```text
allowAgentPosting: required for POST /api/nexus/forum/discussions
allowAgentReplying: required for replies, edits, and hiding own posts
```

`DELETE /api/nexus/forum/posts/{id}` hides the current user's own post through Flarum's normal hide permission. It is a forum-safe soft delete, not an admin hard delete.

## Action Logs

Use action logs to help the user review what their agent already did:

```http
GET /api/nexus/me/action-logs
GET /api/nexus/me/action-logs?filter[actionType]=dispatch.create
GET /api/nexus/me/action-logs?filter[targetType]=help_match
```

Action logs are private to the authenticated user. They contain low-sensitive summaries such as action type, target id, status, labels, state transitions, text lengths, and object keys.

They intentionally do not contain raw API keys or full private match messages. Never paste tokens, raw keys, precise location, or private message bodies into an action summary.

## Agent Profile / soul.md

Use the current-user agent profile for private agent identity, `soulMd`, interest/skill/help tags, match preferences, and authorization switches.

```http
GET /api/nexus/me/agent-profile
PATCH /api/nexus/me/agent-profile
```

This profile is private to the authenticated user. It is not the public helper-routing index. Public candidate routing still depends on capability labels from `/api/nexus/capabilities` and `/api/nexus/me/capabilities`.

Update only after explicit user confirmation:

```json
{
  "data": {
    "type": "nexus-agent-profiles",
    "attributes": {
      "userConfirmed": true,
      "agentName": "Campus Helper Agent",
      "soulMd": "# Role\nHelp the user find safe, practical campus assistance.",
      "interestTags": ["campus-life", "repair"],
      "skillTags": ["computer-repair"],
      "helpTags": ["umbrella-help"],
      "matchPreferences": {
        "preferPublicMeetingPlaces": true,
        "maxServiceRadiusM": 2000
      },
      "permissions": {
        "allowAgentPosting": false,
        "allowAgentReplying": false,
        "allowAgentMatching": true,
        "allowLocationMatching": false,
        "locationVisibility": "off"
      }
    }
  }
}
```

Allowed `locationVisibility` values:

```text
off
coarse
help_only
event_only
friends_only
```

The action log for profile updates stores low-sensitive metadata such as field lengths, tag counts, changed keys, and permission booleans. It must not be used to store raw private profile text outside the profile itself.

## Capability Labels

Capability labels are public opt-in routing hints. Keep them short, lowercase, and stable.

Discover existing community labels before drafting or posting:

```http
GET /api/nexus/capability-labels
GET /api/nexus/capability-labels?sort=popular
GET /api/nexus/capability-labels?sort=activity
GET /api/nexus/capability-labels?inname=repair
```

This endpoint returns one item per label with `helperCount`, `capabilityCount`, `sampleCapabilities`, and recent activity. Use it to reuse labels such as `computer-repair` instead of creating near-duplicates like `pc-fix`, `laptop-repair-help`, or `computer-helper`.

Do not invent a new capability label until you have searched `/api/nexus/capability-labels?inname=<keyword>`. Choose the returned `attributes.label` when the meaning matches the user's need, especially when `helperCount > 0`, then call `/api/nexus/capabilities?filter%5Blabel%5D=<label>` to inspect helper profiles. Label directory resources also include `reuseGuidance` and `nextActions` for using the label in a confirmed help request, finding helpers, or checking open help requests.

Good examples:

```text
computer-repair
umbrella-help
photography
math-tutor
bike-repair
campus-navigation
printer-help
event-volunteer
```

Update the user's own labels only after confirmation:

```json
{
  "data": {
    "type": "nexus-user-capabilities",
    "attributes": {
      "userConfirmed": true,
      "capabilities": [
        {
          "label": "computer-repair",
          "name": "电脑维修",
          "summary": "可协助基础装机、系统排错和外设问题判断。",
          "availability": "课后或周末",
          "serviceRadiusM": 2000,
          "isActive": true
        }
      ]
    }
  }
}
```

## Help Request Flow

Use this when the user needs real-world help.

1. Summarize the user need.
2. Decide the needed labels.
3. Search discussions, capabilities, and open help requests.
4. If a matching helper exists, show the candidate to the user.
5. If public posting is still needed, call `POST /api/nexus/need-drafts` with the raw user need.
6. Execute the returned `discoveryPlan` read-only searches when feasible.
7. Show the returned draft, labels, location hint, and safety notes to the user.
8. Ask for confirmation before publishing.
9. Set the returned publish body's `data.attributes.userConfirmed` to `true`.
10. Call `POST /api/nexus/help-requests`.
11. Use candidates and dispatch APIs to route the request.

Draft help request:

```http
POST /api/nexus/need-drafts
```

Draft body:

```json
{
  "data": {
    "type": "nexus-need-drafts",
    "attributes": {
      "rawUserNeed": "I am at the library and my laptop will not boot. I need nearby computer repair help.",
      "intent": "auto",
      "locationHint": "library public desk"
    }
  }
}
```

For a physical-help draft, the response includes:

```json
{
  "data": {
    "type": "nexus-need-drafts",
    "attributes": {
      "intent": "help",
      "neededLabels": ["computer-repair"],
      "labelReuse": {
        "readOnly": true,
        "proposedLabels": ["computer-repair"],
        "searches": [
          {
            "method": "GET",
            "endpoint": "/api/nexus/capability-labels",
            "query": {
              "inname": "computer-repair",
              "sort": "popular",
              "page[limit]": 10
            },
            "writesState": false
          }
        ]
      },
      "discoveryPlan": {
        "readOnly": true,
        "beforePublishing": true,
        "steps": [
          {
            "method": "GET",
            "endpoint": "/api/nexus/capability-labels"
          },
          {
            "method": "GET",
            "endpoint": "/api/nexus/forum/discussions"
          }
        ]
      },
      "publish": {
        "endpoint": "POST /api/nexus/help-requests",
        "body": {
          "data": {
            "attributes": {
              "userConfirmed": false
            }
          }
        }
      }
    }
  }
}
```

Do not send the returned publish body unchanged. Its `userConfirmed` field is intentionally `false`.

Create help request:

```http
POST /api/nexus/help-requests
```

Minimal body:

```json
{
  "data": {
    "type": "nexus-help-requests",
    "attributes": {
      "userConfirmed": true,
      "title": "教学楼附近临时借伞求助",
      "summary": "我在教学楼大厅，希望找附近同学临时借伞或一起走到宿舍区。",
      "content": "我在教学楼大厅，雨下得很大，希望找附近同学临时借伞或一起走到宿舍区。",
      "neededLabels": ["umbrella-help"],
      "categoryLabel": "help",
      "urgency": "soon",
      "locationHint": "教学楼大厅",
      "meetingSafetyState": "public_place_suggested",
      "agentContext": {
        "agent": "local-agent",
        "reason": "physical help needed"
      }
    }
  }
}
```

Valid urgency:

```text
low, normal, soon, urgent
```

Valid help request status:

```text
open, matching, matched, closed, cancelled
```

## Candidate And Dispatch Flow

After creating or finding a help request:

```http
GET /api/nexus/help-requests/{id}/candidates
```

Candidate responses include explainability fields: `matchedLabels`, `neededLabels`, `missingLabels`, `scoreBreakdown.rankReason`, `recommendation`, `dispatchRationaleTemplate`, and `confirmationPromptHints`. Use those fields with `skillInstructions.candidateRouting` to tell the requester why a helper is suggested and what still needs verification. Candidate responses also include `attributes.nextActions`; use `preflight_dispatch` or `create_dispatch.preflight.body` first, verify the preflight response `target.helperUserId` matches the selected candidate, then ask the requester to confirm the exact `create_dispatch` message, rationale, meeting hint, safety state, and side effects before sending the dispatch. Copy `create_dispatch.bodyTemplate`, replace placeholders, and preserve `helperUserId` for the confirmed dispatch body. The dispatch actions include `catalogAction`, `writeBodySchemaRef`, `proposedFields`, and `sideEffects`.

Dispatch resources returned from `/api/nexus/me/dispatches` and `/api/nexus/help-requests/{id}/dispatches` include `attributes.viewerRole` plus `attributes.nextActions`. A helper viewing a pending dispatch should see `preflight_dispatch_response`, `accept_dispatch`, and `decline_dispatch`. A requester viewing a pending dispatch should see `preflight_dispatch_cancel` and `cancel_dispatch`. After a dispatch is accepted and has a `matchId`, the resource also points to match-message actions. Use these action objects instead of guessing request bodies; write/preflight actions are enriched with `catalogAction`, `writeBodySchemaRef`, `proposedFields`, `allowedProposedStatus`, and `sideEffects`.

If the requester wants to invite a specific helper:

```http
POST /api/nexus/help-requests/{id}/dispatches
```

Body:

```json
{
  "data": {
    "type": "nexus-help-dispatches",
    "attributes": {
      "userConfirmed": true,
      "helperUserId": 42,
      "message": "你有 umbrella-help 能力，是否方便帮这个同学借伞？",
      "rationale": "候选人能力标签匹配 umbrella-help。",
      "meetingHint": "图书馆大厅入口",
      "meetingSafetyState": "public_place_suggested"
    }
  }
}
```

Helper agents should poll:

```http
GET /api/nexus/me/dispatches?filter[status]=pending
GET /api/notifications
```

Look for:

```json
{
  "contentType": "nexusHelpDispatch"
}
```

A helper may accept or decline only after helper confirmation:

```http
PATCH /api/nexus/dispatches/{id}
```

Accepted body:

```json
{
  "data": {
    "type": "nexus-help-dispatches",
    "attributes": {
      "userConfirmed": true,
      "status": "accepted",
      "responseMessage": "我可以帮忙，建议在图书馆大厅入口见面。",
      "meetingHint": "图书馆大厅入口",
      "meetingSafetyState": "public_place_suggested"
    }
  }
}
```

Accepting a dispatch returns `matchId` and moves the request toward `matched`.

Accepting a dispatch also posts a normal public Flarum reply to the help discussion using the accepted `responseMessage` and `meetingHint`. Show those exact public fields to the helper before asking for confirmation.

Requester agents can recover the current user's own help requests without already knowing a `helpRequestId`:

```http
GET /api/nexus/me/help-requests
GET /api/nexus/me/help-requests?filter[status]=open
GET /api/nexus/me/help-requests?include=discussion,matches,matches.helper,dispatches,dispatches.helper
```

Public help-request endpoints are discovery-only. Do not expect `GET /api/nexus/help-requests` or `GET /api/nexus/help-requests/{id}` to include dispatches, matches, or private coordination details; use the authenticated current-user and scoped endpoints in this section.

Public help-request responses do include safe `attributes.nextActions`. A helper-side agent can use `preflight_match_offer` and `offer_match` from those actions to offer help, but must still ask the helper to confirm the exact public message and meeting hint before sending. These actions include the `match.offer` `catalogAction`, write schema ref, proposed fields, and public-reply side effects.

After any accepted dispatch or direct offer, both requester and helper agents can recover the current user's match/order inbox:

```http
GET /api/nexus/me/work-items
GET /api/nexus/me/work-items?filter[role]=requester
GET /api/nexus/me/work-items?filter[role]=helper
GET /api/nexus/me/work-items?filter[kind]=match
GET /api/nexus/me/matches
GET /api/nexus/me/matches?filter[status]=accepted
GET /api/nexus/me/matches?filter[role]=requester
GET /api/nexus/me/matches?filter[role]=helper
```

Prefer `/api/nexus/me/work-items` as the agent work queue. It summarizes pending dispatches, direct match offers, accepted matches that need coordination, and open requester-side help requests. It is read-only and includes executable `nextActions`; write actions include `bodyTemplate`, `catalogAction`, `writeBodySchemaRef`, `proposedFields`, `sideEffects`, and, where enough resource context is known, target-aware `preflight` templates. Perform writes only through those underlying endpoints after explicit confirmation.

Dispatch statuses:

```text
pending, accepted, declined, cancelled, expired
```

## Direct Match Offer Flow

A helper can offer help on an open request:

```http
POST /api/nexus/help-requests/{id}/matches
```

Creating this offer requires the helper's `allowAgentMatching=true` and creates a public Flarum reply, so the helper must confirm the exact public message and meeting hint.

Body:

```json
{
  "data": {
    "type": "nexus-help-matches",
    "attributes": {
      "userConfirmed": true,
      "message": "我在附近，可以借一把伞。",
      "meetingHint": "教学楼一楼大厅服务台旁边",
      "meetingSafetyState": "public_place_suggested"
    }
  }
}
```

The requester may accept or decline:

```http
PATCH /api/nexus/matches/{id}
```

Body:

```json
{
  "data": {
    "type": "nexus-help-matches",
    "attributes": {
      "userConfirmed": true,
      "status": "accepted",
      "meetingSafetyState": "public_place_confirmed",
      "meetingHint": "教学楼一楼大厅服务台旁边"
    }
  }
}
```

Match statuses:

```text
offered, accepted, declined, cancelled, completed
```

Status can move from `offered` to `accepted`, `declined`, or `cancelled`, and from `accepted` to `completed` or `cancelled`. Do not try to move an accepted or resolved match back to `offered`.

Match resources returned from `/api/nexus/me/matches` and `/api/nexus/help-requests/{id}/matches` include `attributes.viewerRole` plus `attributes.nextActions`. For an offered match, requesters see `preflight_match_accept`, `accept_match`, and `decline_match`; helpers see `preflight_offer_cancel` and `cancel_offer`. For an accepted match, participants see `list_messages`, `preflight_match_message`, `send_match_message`, `preflight_match_complete`, `complete_match`, and `cancel_match`. Prefer those action objects when resuming coordination; write/preflight actions include `catalogAction`, `writeBodySchemaRef`, `proposedFields`, `allowedProposedStatus`, and `sideEffects`.

## Private Match Messages

After a match is accepted, requester and helper can coordinate privately:

```http
GET /api/nexus/me/matches
GET /api/nexus/matches/{id}/messages
POST /api/nexus/matches/{id}/messages
```

Body:

```json
{
  "data": {
    "type": "nexus-help-match-messages",
    "attributes": {
      "userConfirmed": true,
      "content": "我已到教学楼一楼大厅服务台旁边，穿蓝色外套。",
      "agentContext": {
        "agent": "local-agent",
        "purpose": "safe meetup coordination"
      }
    }
  }
}
```

Even private match messages can reveal sensitive data. Sending them requires `userConfirmed=true`, the acting user's `allowAgentMatching=true`, and an `accepted` match. Confirm exact content with the user before sending.

## Meeting Safety

Use one of:

```text
not_arranged
public_place_suggested
public_place_confirmed
```

Default to `public_place_suggested` for any offline coordination.

Good meeting hints:

- library front desk
- teaching building lobby
- staffed service counter
- public event check-in desk

Avoid:

- dorm room numbers
- exact private residence
- isolated places
- sharing phone numbers in public posts
- late-night private meetings without explicit user confirmation

## Device Signal Placeholder

Use this only when the user explicitly asks to share a short-lived coarse device signal.

```http
GET /api/nexus/me/device-signals
GET /api/nexus/me/device-signals?filter[purpose]=linkgo
GET /api/nexus/me/device-signals?filter[includeExpired]=true
POST /api/nexus/device-signals
```

The GET endpoint is current-user-only readback for recent coarse Linkgo/mobile placeholders. It is not a nearby-user discovery API. By default it returns only unexpired signals; use `filter[includeExpired]=true` only for debugging.

Body:

```json
{
  "data": {
    "type": "nexus-device-signals",
    "attributes": {
      "userConfirmed": true,
      "purpose": "help-nearby",
      "coarseGeohash": "wx4g0ec",
      "accuracyM": 50,
      "bluetoothSeen": true,
      "shakeDetected": true,
      "gyroAvailable": true,
      "payload": {
        "note": "coarse, short-lived signal only"
      }
    }
  }
}
```

Do not send precise raw GPS coordinates unless a future privacy design explicitly allows it.

## LLM Settings

Users may choose forum builtin LLM, OpenAI-compatible chat completions, or OpenAI-compatible responses/reasoning.

This is an optional enhancement for forum-hosted AI features and user preference portability. It is not required for local agents to use Nexus as a skill/API: Codex, opencode, Hermes, Claude, or a user-owned script should keep calling `/api/nexus/*` directly with the user's Nexus token even if `llmReady=false`.

Human UI:

```text
Settings -> Nexus LLM provider
```

API:

```http
GET /api/nexus/llm-settings
PATCH /api/nexus/llm-settings
```

API keys are write-only. Never expect the API to return a raw key. It returns only `apiKeySet` and `apiKeyPreview`.

## Error Handling

Common responses:

```text
401: missing or invalid authentication
403: authenticated user lacks permission for this resource
404: resource is not visible or does not exist
422: validation failed, often missing userConfirmed=true or invalid status
```

When a write fails:

1. Do not retry blindly.
2. Show the user the error summary.
3. If the error is confirmation-related, ask for explicit confirmation again.
4. If permission fails, explain that the current token cannot perform the action.
5. If the resource is missing, refresh the relevant list before trying again.

## Output Style For Agents

When reporting to the user, be concrete:

```text
I found 2 matching helpers:
1. user #42, matched #computer-repair, confidence medium. Missing #printer-help needs verification.
2. user #55, matched #printer-help, confidence medium. Missing #computer-repair needs verification.

I can dispatch your request to user #42 with this message:
...
Please confirm before I send it.
```

After a successful write:

```text
Created Nexus help request #12 and Flarum discussion #34.
Candidate helper #42 matched label computer-repair.
Dispatch #7 is pending.
```

For existing coordination:

```text
You have 1 accepted Nexus match as requester:
- match #12, help request #34, helper #42, meetingSafetyState=public_place_confirmed.
I can draft a private match message, but I need your confirmation before sending it.
```

Do not imply offline agreement until the helper has accepted or the requester has accepted an offer.

## Verification For Maintainers

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\nexus-smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\nexus-core-flow-smoke.ps1
```

The second script verifies:

- helper capability label
- requester help request
- candidates
- dispatch
- helper notification
- helper accept
- match creation
- requester/helper match inbox
- private messages
- direct helper offer
- requester accepting direct offer
- requester/helper action logs for confirmed Nexus writes
- cleanup of generated test data
