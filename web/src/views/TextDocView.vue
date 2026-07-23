<template>
  <pre class="text-page">{{ content }}</pre>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

const skill = `# Nexus Skill for Local Agents

Shortest onboarding path:

\`\`\`text
/docs/agent-quickstart.md
\`\`\`

This document is the operational skill for Codex, Hermes, Claude, opencode, or any user-authorized local agent that wants to use Nexus as a bridge from chat to real-world campus help.

LLM provider settings are optional. A local Codex/opencode/Hermes/Claude-style agent can call Nexus APIs directly with the user's Nexus token even when no forum builtin or custom LLM provider is configured.

Base URL:

\`\`\`text
Use the origin that served this document or /.well-known/nexus-agent.json.
Local dev example: http://10.98.65.32:8080
\`\`\`

Primary references:

\`\`\`text
/llms.txt
/api/nexus/agent-health
/docs/agent-tools.json
/docs/agent-quickstart.md
/docs/agent-recipes.md
/docs/index.md
/.well-known/nexus-agent.json
/schemas/nexus-agent-manifest.v1.json
/v3/api-docs
/docs/llms.txt
\`\`\`

Use Nexus only when the user's need benefits from another real person or offline coordination.

## Mission

Nexus is not a generic chat answer tool. It is for:

- real-world resource gaps: licensed datasets, lab equipment, room access, device repair, or campus process help
- human expertise: someone nearby or someone with a practical capability label
- team or activity coordination when a person, teammate, or partner is needed
- safe requester/helper matching and private coordination after a match exists
- future mobile/Linkgo signals through coarse device-signal placeholders

## First Decision

Before using Nexus, classify the user's need:

A. AI can solve directly:
   Answer in chat. Do not post.

B. Human experience is useful:
   Search forum discussions and capability labels. Ask before posting.`

const llms = `# Nexus Campus Agent Entry

Start here when an agent receives only the Nexus origin.

- Public guide: /docs/
- Agent health: /api/nexus/agent-health
- Agent manifest: /.well-known/nexus-agent.json
- OpenAPI: /v3/api-docs
- Skill manual: /docs/nexus-skill.md
- Tool contract: /docs/agent-tools.json

Local agents can call Nexus APIs directly with the user's Nexus token. LLM provider settings are optional.`

const health = `{
  "data": {
    "status": "ok",
    "schemaVersion": "0.2",
    "llmProviderOptionalForLocalAgents": true,
    "docs": {
      "rootAgentEntry": "/llms.txt",
      "publicGuide": "/docs/",
      "agentTools": "/docs/agent-tools.json",
      "openapi": "/v3/api-docs"
    },
    "checks": {
      "publicDocs": true,
      "forumGateway": true,
      "agentContextRequiresToken": true
    },
    "nextActions": [
      "Read /llms.txt",
      "Read /.well-known/nexus-agent.json",
      "Fetch /docs/agent-tools.json",
      "Call /api/nexus/me/agent-context with user token"
    ]
  }
}`

const content = computed(() => {
  if (route.path.includes('agent-health')) return health
  if (route.path.includes('llms.txt')) return llms
  return skill
})
</script>

<style scoped>
.text-page {
  min-height: 100vh;
  padding: var(--nx-space-4);
  overflow: auto;
  color: var(--nx-text-secondary);
  background: transparent;
  font-family: var(--nx-font-mono);
  font-size: var(--nx-fs-13);
  line-height: 1.55;
  white-space: pre-wrap;
}
</style>
