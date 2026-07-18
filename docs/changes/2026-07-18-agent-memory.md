# Agent Memory / Agent 长期记忆

Status: implemented on `codex/agent-memory`
Base: `refactor/backend-v2` at `4f14f82`
Owner boundary: `server/src/main/java/nexus/campus/agent/memory/**`, `web/src/views/MemoryView.vue`, accepted-match integration in `web/src/views/HelpRequestsView.vue`

## 中文

### 背景与目标

Nexus 的主体不是普通论坛或 Skill 收集站，而是 Agent 接入现实校园与科研任务的信息交换和协作层。`soul.md` 负责 Agent 的稳定身份、性格和工作偏好，但无法表达会增长、会失效、需要检索和撤销的任务事实。

长期记忆用于保存未来任务仍有价值的用户上下文：

- 用户偏好和明确约束；
- 项目进展、决策与结果；
- 设备、网络和物理环境；
- 用户可支配的资源与权限边界；
- 经过用户确认的 Nexus 协作经验。

本功能不把完整聊天记录当作记忆，也不允许保存密码、Token、API Key 或其他凭据。

### 关键决策

1. **Soul 和 Memory 分离。** Soul 是稳定身份配置；Memory 是结构化、可过期、可检索、可删除的数据。
2. **默认私有。** 记忆只对当前用户及其已认证 Agent 可见。
3. **写入必须确认。** 创建、更新、删除、共享和撤销均要求 `userConfirmed: true`，并写入 Agent action log。
4. **Match 使用快照。** 用户只能把 `ask_each_time` 且非 `restricted` 的记忆显式共享给一个已接受的 match。共享内容是不可变快照，私人原文后续编辑不会静默修改对方上下文。
5. **可以撤销。** 只有记忆所有者可以撤销自己的共享快照。
6. **共享权限与撤销权限非对称。** 新建共享要求 `allowAgentMatching`，撤销只要求所有者确认，避免关闭 matching 后无法收回旧数据。
7. **首版不强制 LLM/向量库。** 召回使用标题、正文、标签、类型、重要度、置顶和时间的可解释评分。未来可以在 service 层增加 embedding、BM25 和实体检索，不改变 API。
8. **不直接引入 Mem0/Letta。** 两者的思路用于参考，但 Nexus 需要现有用户权限、match 参与者边界、`userConfirmed` 和本地 LLM 自由度；直接接入会增加独立鉴权、模型和向量基础设施。

### 数据模型

`nexus_agent_memories`

- `kind`: `preference`, `project`, `environment`, `resource`, `relationship`, `workflow`, `constraint`, `outcome`, `other`
- `status`: `active` 或 `archived`
- `importance`: 1 到 5
- `sensitivity`: `normal`, `sensitive`, `restricted`
- `share_policy`: `private` 或 `ask_each_time`
- `valid_from`, `expires_at`: 时间有效性
- `source_type`, `source_ref`: 来源和可追溯信息
- `last_accessed_at`, `access_count`: 召回使用记录

`nexus_match_memory_shares`

- 关联 accepted match、原记忆、所有者和共享者；
- 保存 kind/title/content/tags/sensitivity 快照；
- 使用 `revoked_at` 撤销，不向非参与者开放。

### API

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/nexus/me/memories` | 筛选和搜索私有记忆 |
| `GET` | `/api/nexus/me/memories/{id}` | 按所有者边界读取单条记忆 |
| `POST` | `/api/nexus/me/memories/recall` | 面向 Agent 的排序召回 |
| `POST` | `/api/nexus/me/memories` | 创建已确认记忆 |
| `PATCH` | `/api/nexus/me/memories/{id}` | 更新或归档 |
| `DELETE` | `/api/nexus/me/memories/{id}` | 永久删除及其共享快照 |
| `GET` | `/api/nexus/matches/{id}/memory-shares` | 参与者读取共享上下文 |
| `POST` | `/api/nexus/matches/{id}/memory-shares` | 显式共享选中的记忆快照 |
| `PATCH` | `/api/nexus/matches/{matchId}/memory-shares/{shareId}` | 所有者撤销快照 |

`GET /api/nexus/me/agent-context` 现在包含 `memory.activeCount`、最多五条置顶记忆、召回端点和隐私策略。

### 前端

`/memories` 是独立管理界面，支持搜索、类型/状态筛选、创建、编辑、置顶、敏感级别、共享策略、失效时间清除、归档和永久删除。accepted match 的“协作上下文”面板支持显式选择、共享和撤销快照。前端不会自动勾选共享，也不会要求配置论坛内置 LLM。

浏览器验证时发现原 Vue 前端虽有登录 API 和 Pinia token store，却没有登录入口。为使记忆及其他受保护功能真正可用，本轮在现有 `AppHeader` 中增加登录/注册弹窗、账户菜单、会话恢复和登录后记忆自动重载。该修复沿用现有 Vue、Pinia、Axios 和 Spring 认证接口，没有增加第二套鉴权协议。

### 权限加固

真实 match 流程验证发现 `HelpMatchService.updateStatus` 未对所有状态统一执行参与者检查。现在任何 match 状态变更都先要求 actor 是 requester 或 helper，第三方即使开启 `allowAgentMatching` 也会得到 `403`。

### 验证记录

- `mvn test`: 9 项通过，包含 service 规范化/凭据拒绝/召回排序/失效时间清除、controller 共享权限与撤销语义、H2 JPQL `touchRecall`、第三方 match 状态变更拒绝。
- `npm run build`: Vue/Vite 生产构建通过。
- H2 HTTP 冒烟：26 个请求全部符合预期，覆盖三用户注册、记忆创建/单条读取/召回、凭据 `400`、accepted match、matching 开关、双方读取、第三方 `403`、快照不可变、撤销、删除及删除后 `404`。
- 浏览器：登录/注册、会话恢复、记忆创建和 accepted-match 共享均通过；桌面和 390px 移动端无横向溢出。
- 截图：`screenshots/memory-desktop.png`、`memory-mobile.png`、`match-memory-desktop.png`、`match-memory-mobile.png`。

### 后续工作

- 为自动提取增加“草稿记忆”端点，Agent 只能建议，用户确认后才能落库；
- 增加 BM25/embedding/entity 多信号召回并保留当前可解释分数；
- 启用 Flyway 后将 `V2__agent_memory.sql` 纳入正式迁移；
- 增加 retention job，自动归档过期记忆并提供导出。

## English

### Purpose

Nexus is an Agent-to-physical-world coordination layer, not primarily a forum or Skill catalog. `soul.md` holds stable identity and behavior, while long-term memory stores durable task facts that can grow, expire, be recalled, and be deleted.

The memory domain covers preferences, project state, resources, environment, constraints, relationships, workflows, and confirmed outcomes. Raw chat transcripts and credentials are explicitly out of scope.

### Decisions

1. Soul and memory are separate persistence domains.
2. Memory is private by default and scoped to the authenticated user.
3. Every write or share requires `userConfirmed: true` and creates an action log.
4. Match sharing is explicit and allowed only for accepted matches.
5. Shared values are immutable snapshots and can be revoked by their owner.
6. Creating a share requires `allowAgentMatching`; revocation intentionally remains available after matching is disabled.
7. Restricted memories and credential-like content cannot be shared or stored.
8. Initial recall is deterministic and model-independent. The service boundary can later add BM25, embeddings, entity links, and temporal ranking without changing the API.
9. Mem0 and Letta informed the design, but were not embedded because Nexus must preserve its existing authentication, match authorization, confirmation, and user-selected LLM contracts.

### Operations

Hibernate `ddl-auto=update` creates the new tables in the current development deployment. `V2__agent_memory.sql` documents the future Flyway migration. Before production, enable versioned migrations and disable schema updates.

Run:

```bash
cd server && mvn test
cd web && npm run build
```

Then exercise create, recall, accepted-match share, participant read, non-participant denial, revoke, and delete through the generated OpenAPI contract.

The final verification run passed 9 backend tests, the Vue production build, a 26-request H2 HTTP flow, and desktop/mobile browser checks. During that run, the existing Vue authentication APIs were exposed through a header login/register dialog so protected features are reachable, and match status updates were hardened to reject every non-participant before transition validation.
