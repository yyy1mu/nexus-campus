# Edge-Vision Collaboration Journey

Date: 2026-07-31 (Asia/Shanghai)
Branch: `codex/frontend-ui-refresh-qwen`

## Goal

Make the case-processing UI explain the complete Nexus value chain, not only
task completion:

`Agent 发现阻塞 → 用户授权求助 → 能力匹配 → 双方 Agent 协作 → 人类决策 → 交付验收`

The primary demo is now an IC-oriented edge-vision case. A local deployment
Agent sees an accuracy regression after converting an FP32 model to INT8 for an
edge NPU. Public data does not match the target CMOS sensor and ISP pipeline,
so the user authorizes a structured request for anonymized calibration frames.
Nexus matches a lab with compatible sensor data, coordinates the two Agents,
escalates the delivery choice to the human, and records reviewable delivery.

## UI Behavior

`web/src/views/MatchWorkspaceView.vue` renders the six stages at the top of the
workspace. The display is derived from the workspace snapshot:

- stages 1-3 are complete once the accepted Match workspace exists;
- task planning is the active collaboration stage until a decision or delivery
  exists;
- an open decision makes `人类决策` active;
- once decisions are settled, a submitted or rejected deliverable makes
  `交付验收` active;
- an accepted deliverable or completed Match closes the final stage.

The status badge also names the current owner of attention: the local human,
the counterpart, or the Agent holding the baton. On mobile, the six stages
become a compact two-column grid to avoid horizontal scrolling.

## Demo Data

Run `node scripts/seed-collab-demo.mjs`, then sign in as:

```text
username: linzhou_demo
password: demo-password-1
```

The seeded workspace contains:

- a target CMOS sensor and ISP authorization check;
- packaging of 2,000 anonymized calibration frames with metadata and SHA-256;
- an edge-NPU INT8 accuracy and latency regression task;
- a human choice between campus HTTPS and encrypted SSD delivery;
- a reviewable calibration package with explicit use restrictions.

The forum seed and `scripts/e2e-collab.mjs` use the same narrative so the
public case, interactive workspace, and acceptance evidence tell one story.
The Match list response also includes `helpRequestSummary` and
`requesterUserId`, allowing `/collaborations` to use the original request as
the card title and identify the counterpart correctly instead of presenting
the helper's offer message as the case name.

## Verification

```bash
cd server && mvn test
cd web && npm run build
cd web && npm run type-check
node scripts/e2e-collab.mjs
```

Refresh the workspace screenshots at desktop `1440 x 900` and mobile
`390 x 844`. The in-progress seed should show `人类决策` as the current stage;
the completed acceptance flow should show all six stages complete.
