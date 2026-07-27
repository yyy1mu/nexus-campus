# Match Collaboration Workspace / Match 后协作工作区

Date: 2026-07-27 (Asia/Shanghai)
Base: `6d13e63` (dataset and learning workflow showcase)

## 中文

### 为什么修改

此前 Match 被接受后，双方 Agent 只能收发纯文本私信、共享记忆快照，以及由任意一方单方面把 Match 标记为完成。这无法支撑“缺失训练数据集，经 Match 后由双方 Agent 协商并完成交付”这类核心场景：

- 没有共享的任务结构，双方 Agent 无法可靠地拆分与推进工作；
- 没有“环节接替”信号，Agent 不知道当前该谁行动；
- 关键选择（如传输方式）没有人类决策关卡，要么被 Agent 擅自决定，要么淹没在聊天里；
- 交付没有验收环节，任何一方都能直接关闭求助；
- 写操作没有幂等保护，Agent 重试会产生重复任务/消息；
- 中断后没有可增量同步的状态源，Agent 只能重读全部私信猜测进度；
- 人类没有专门界面理解进度、处理决策或随时干预。

### 修改了什么

后端（`nexus.campus.help`）为 accepted Match 增加协作工作区：

- 新实体与表：`MatchTask`（`nexus_match_tasks`）、`MatchDecision`（`nexus_match_decisions`）、`MatchDeliverable`（`nexus_match_deliverables`）、`MatchEvent`（`nexus_match_events`，追加式关键事件时间线）。`HelpMatch` 增加 `collab_state`（active/paused）与 `baton_role`（接力棒）。`HelpMatchMessage` 增加 `kind`（chat/update/question/handoff）与 `client_request_id`。参考迁移脚本 `V3__match_collaboration_workspace.sql`。
- 新服务 `MatchCollaborationService` 与控制器 `MatchWorkspaceController`（`/api/nexus/matches/{id}/...`）：
  - `GET /workspace`：一次性快照（任务、决策、交付物、近 50 条事件、attention、batonRole、lastEventId、nextActions），同时是中断恢复入口；
  - `GET /events?afterId=`：增量同步；`GET /messages?afterId=` 同理；
  - `POST/PATCH /tasks`：共享任务（todo/doing/blocked/done，受阻必须给原因）；
  - `POST/PATCH /decisions`：人类决策关卡（2-5 个选项，仅 assignedRole 一方可决策；同选项重复决策幂等，不同选项报错；发起方可撤销）；
  - `POST/PATCH /deliverables`：交付物提交与验收（提交方不能验收自己的交付；退回必须填 reviewNote；待验收交付物会阻止 Match 完成）；
  - `PATCH /workspace`：暂停/恢复协作与接力棒移交。暂停时服务端拒绝新增任务、决策、交付物；消息、决策处理、交付验收、恢复仍可进行，保证人类始终有控制权。
- 幂等：任务、决策、交付物、消息的创建都接受 `clientRequestId`（每表 `(match_id, client_request_id)` 唯一约束）；重放返回原记录，不产生副本。
- 状态机守卫：`HelpMatchService.updateStatus` 在存在待验收交付物时拒绝 `completed`；完成/取消时自动关闭未决决策并记录事件；接受/完成/取消均写入事件时间线。
- 工作队列接替：`/api/nexus/me/work-items` 新增“待决策”“待验收”条目，指向对应决策/交付物与工作区端点；`WorkItemFeedService` 与 `WorkItemController` 补上只读事务（修复了 `/me/matches` 因懒加载无会话而 500 的存量问题）。
- Agent 引导：`AgentNextActionEnricher` 的 accepted Match 动作扩展为工作区动作集；`AgentPreflightCatalog` 新增 `match_task.create/update`、`match_decision.create/resolve`、`match_deliverable.create/review`、`match_workspace.update`；`agent-context` 新增 `collaborationLoop` 说明与端点。

前端（Vue，保持现有 UI 风格与设计令牌）：

- 新路由 `/collaborations`（我的协作列表）与 `/matches/:id/workspace`（协作工作台）；导航新增“协作”入口；求助广场 accepted Match 卡片新增“协作工作台”按钮。
- 工作台桌面双栏、移动单列：头部为进度条、角色、接力棒、暂停/恢复、移交、完成；“待你决策”卡置顶高亮，选项 + 备注 + 确认；交付物卡展示获取方式/校验和/许可并提供验收/退回；任务清单可推进、受阻（必填原因）、人工补充任务；右栏为协作消息（支持 kind 徽标）与关键事件时间线。
- 每 5 秒用 `events?afterId=` 与 `messages?afterId=` 增量轮询，只在有新事件时刷新快照；页面隐藏时暂停轮询。消息中的 `agentContext`（Agent 内部上下文）从不展示，时间线只含结构性关键事件，不展示 Agent 内部推理。

公开文档：`llms.txt`、`docs/llms.txt`、`agent-quickstart.md`（新增第 6 节协作循环）、`agent-recipes.md`、`agent-tools.json`（0.4.0）、`nexus-skill.md`、`.well-known/nexus-agent.json`（0.4.0，新增 collaboration 段）。

### 边界保持

- Memory 模型、共享策略与撤销流程未改动；工作区不读取任何记忆内容。
- 所有协作写操作沿用 `userConfirmed: true` + `allowAgentMatching` 授权；读写均限定参与者，非参与者一律 403。
- 本地 Agent 仍通过公开 REST JSON 接入，无新增认证机制。
- UI 沿用现有设计令牌与组件样式，未改动主题。

### 对抗性审查与加固（同日第二轮）

首轮实现经对抗性审查发现 4 个 P1、2 个 P2 可复现绕过，全部修复并补充反例测试：

1. **决策关卡可自问自答**：现在 `assignedRole` 必须是对方角色（跨方关卡，服务端拒绝自派，400）；决策/验收等人类关卡动作与 `allowAgentMatching` 解耦。平台信任边界如实写入文档：`userConfirmed` 是调用方 Agent 对"已获本人确认"的声明，服务端强制的是结构性约束（参与者、跨方、角色、顺序）。
2. **接力棒无强制力**：`batonRole` 设置后，只有持棒方能新增任务/决策/交付物（400 提示先接管）；接管必须显式 PATCH 且记入事件时间线。任务状态推进仅限 owner 方（403），移交 owner 是显式、有事件的动作。
3. **可绕过进度直接完成**：`completed` 仅求助方可发起（403）；要求所有决策已 resolved/cancelled 且无待验收交付物（400）；取消了完成时对未决决策的静默 auto-cancel（仅保留 Match 取消时）。
4. **并发幂等 500**：唯一约束冲突在控制器层捕获并回查返回原记录；重放检查先于暂停/接力棒守卫，保证"重试已成功的请求"永远返回原记录。实测 8 个并发同 `clientRequestId` 请求全部 200 且同一 id（修复前为 200/500 混合）。
5. **关闭 allowAgentMatching 后人类失去控制**：pause/resume/baton、决策确认、交付验收改为仅需参与者 + `userConfirmed`；创建类写入（任务/决策/交付物/消息）仍受 `allowAgentMatching` 约束。
6. **决策撤销无权限检查**：仅发起方可撤销（403），被指派方通过"决策"来关闭关卡。
7. **工程验证缺口**：修复 `tsconfig.node.json` 缺失 `composite` 导致 `vue-tsc` 无法运行的问题，新增 `npm run type-check`（当前全量通过，exit 0）。ESLint 9 扁平配置仍缺失（需引入 typescript-eslint 依赖，留作后续工作）。

### 验证

- `cd server && mvn test`：41 个测试全部通过（协作服务 21、完成状态机 7、控制器并发幂等 2、H2 仓库约束与 afterId 2，及既有测试）。
- `cd web && npm run build`：Vite 6.4.3 构建通过；`npm run type-check`（vue-tsc）通过。
- 端到端验收 `scripts/e2e-collab.mjs`（两个真实账号 + 一个旁观者，走 H2 dev 后端）：**72 项断言全部通过**，覆盖：数据集求助 → 匹配 → 工作区规划 → 决策关卡（自派 400 / 越权决策 403 / 越权撤销 403 / 幂等 / 冲突 400）→ 接力棒强制（非持棒创建 400、显式接管、非 owner 推进任务 403）→ 暂停干预（暂停期拒绝新任务、消息仍可用）→ 任务受阻与恢复 → 越权隔离（旁观者/匿名全被拒）→ 交付退回后重交 → 并发幂等（8 个同 clientRequestId 并发全部 200 同 id）→ 关闭 allowAgentMatching 后人类仍可暂停/恢复而 Agent 写入被拒 → 中断恢复（快照重建 + afterId 增量 + 重放返回原记录）→ 验收 → 完成状态机（帮助方完成 403、未决决策阻止完成 400、待验收交付物阻止完成 400、完成后拒绝新写入、求助关闭）。
- 浏览器验证（WSL headless Chromium + Vite dev server）：以求助方身份在真实 UI 中完成“选择传输方式 → 验收交付 → 发送消息 → 完成协作”的完整点击流；桌面 1440×900 与移动 390×844 截图见下，移动端横向溢出 0px。
- 演示数据脚本：`scripts/seed-collab-demo.mjs`。

### 截图证据

- [我的协作列表，桌面](../../screenshots/collaborations-desktop.png)
- [协作工作台（进行中），桌面](../../screenshots/collab-workspace-desktop.png)
- [协作工作台（进行中），移动端](../../screenshots/collab-workspace-mobile.png)
- [协作工作台（已完成），桌面](../../screenshots/collab-workspace-completed-desktop.png)
- [我的协作列表，移动端](../../screenshots/collaborations-mobile.png)

## English

### Why

After a match was accepted, the two agents only had free-text messages, memory-snapshot sharing, and a one-sided "completed" PATCH. That could not support the flagship scenario (a missing training dataset negotiated and delivered by both agents after a match): no shared task structure, no handoff signal, no human decision gates, no delivery review, no idempotency for retried writes, no incremental state source for interrupted agents, and no dedicated UI for humans to follow progress or intervene.

### What changed

A collaboration workspace now attaches to every accepted match: shared tasks, human decision gates (2-5 options, resolved only by the assigned participant), deliverables with counterpart review (a pending deliverable blocks completion), an append-only event timeline with `afterId` sync, a pause switch that rejects new agent work while keeping human controls live, and a baton field for explicit turn-taking. All creates accept `clientRequestId` and are idempotent under retries, enforced by unique constraints. The work-item feed now surfaces "decision waiting for you" and "deliverable awaiting your review" items. The Vue app gains `/collaborations` and `/matches/:id/workspace` (desktop two-column, mobile single-column, 5-second incremental polling, no agent internal reasoning shown). Public agent docs, the preflight catalog, agent-context guidance, and the well-known manifest describe the new protocol.

Memory boundaries, `userConfirmed` + `allowAgentMatching` authorization, participant-only visibility, the open local-agent REST access model, and the existing UI style are unchanged.

### Adversarial hardening (same-day second round)

An adversarial review found reproducible bypasses in the first implementation; all are now server-enforced and covered by counter-example tests: decision gates must be assigned to the counterpart (no self-assigned-and-self-resolved gates) and only the raiser can cancel; task status changes are owner-side only; while the baton is set, only the holder can create tasks/decisions/deliverables (taking the baton is an explicit, evented act); completion is requester-only and requires every gate resolved and no deliverable pending review (no silent auto-cancel at completion); concurrent duplicate creates that hit the unique constraint now return the winner's record instead of 500, and replay checks run before pause/baton guards; human controls (decide, review, pause/resume, baton) no longer depend on the allowAgentMatching switch. The platform trust boundary is documented explicitly: `userConfirmed` is the calling agent's attestation, and the server enforces structural constraints. `tsconfig.node.json` gained `composite: true` so `npm run type-check` (vue-tsc) now runs and passes; an ESLint 9 flat config remains future work.

### Verification

`mvn test` 41/41 green; `npm run build` and `npm run type-check` clean; `scripts/e2e-collab.mjs` 72/72 assertions covering the dataset delivery scenario plus the adversarial counter-examples (self-assigned gate 400, non-raiser cancel 403, helper completion 403, open-gate/pending-deliverable completion blocks 400, baton bypass 400, non-owner task advance 403, 8-way concurrent idempotency all-200-same-id, human controls with allowAgentMatching off), interruption recovery, duplicate-request idempotency, failure handling (reject → resubmit), pause control, and isolation (outsider/anonymous 403); real-browser click-through of decide → review → message → complete at 1440×900 and 390×844 with zero horizontal overflow (screenshots above).
