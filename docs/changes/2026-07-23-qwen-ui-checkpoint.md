# Qwen Frontend UI Checkpoint / Qwen 前端 UI 更新节点

Date: 2026-07-23 (Asia/Shanghai)
Branch: `codex/frontend-ui-refresh-qwen`
Base: `codex/agent-memory` at `8c084c0`
Previous UI commit: `bfbea23`

## 中文

### 为什么固化这个节点

本节点把当前 Qwen 前端方案保存为一个可追溯、可比较的 UI 更新节点，供后续继续优化或与其他视觉分支比较。它不是生产发布记录，也不表示当前视觉方案已经最终验收。

2026-07-22 的维护记录描述的是上一轮深色金融科技方案。此后工作区继续演进为浅色主题，并加入由产品方明确要求的动态代码字符背景，因此本记录作为当前状态的补充说明，不改写旧记录的历史事实。

### 本节点包含什么

- 全局视觉系统调整为浅灰白背景、白色内容层和橄榄绿色强调色。
- 新增 `web/src/components/TechBg.vue`，提供全屏动态代码字符背景、鼠标响应、页面隐藏时暂停和 `prefers-reduced-motion` 降级。
- `App.vue` 接入动态背景及全局 design tokens、基础样式和公共组件样式。
- 重组 `AppHeader.vue` 与首页布局；首页采用 Bento 信息布局。
- 统一论坛、讨论详情、求助与匹配、Memory、Agent Profile、文档和文本页面的视觉表现。
- 保留 OpenPencil 设计源文件 `designs/nexus-ui-refresh-qwen.op`。

动态代码背景是 Nexus 当前视觉方向的一部分，不是临时占位特效。后续优化应调整其密度、对比度、性能和页面融合方式，不应在没有产品决策的情况下直接移除。

### 后端和接口边界

本节点没有修改：

- `server/`
- `web/src/api/`
- `web/src/router/`
- `web/src/stores/`
- `public/`
- `deploy/`
- 数据库结构、认证协议和 API 契约

登录注册、Agent Profile、LLM 设置、Capability、求助、派发、匹配、Match 私聊、Memory 和 Match Memory 共享继续使用 `codex/agent-memory` 中已经验证的 Spring Boot API。相关页面的业务脚本没有因本次视觉节点而改变。

### 已知的前后端对齐缺口

这些问题大多来自基线，当前 UI 节点保留了它们，并未用假后端改动掩盖：

1. 首页、论坛列表和讨论详情仍读取 `web/src/data/nexusSeed.ts`，没有消费已经存在的论坛读取 API。
2. “发起讨论”和讨论回复尚未接通现有的创建讨论与回复 API。
3. 后端论坛列表响应尚未提供当前 UI 需要的作者、头像、正文摘要等字段；详情帖子只提供 `userId`，没有用户名或头像。
4. `Tag` 实体拥有描述、颜色、图标和讨论数，但论坛 API 的 `tagMap` 只返回 `id`、`slug` 和 `name`，并且还没有独立标签目录接口。
5. 首页的求助数、项目数、活动流、活跃 Agent 和“系统正常”状态仍是展示数据，不代表实时数据库状态。
6. Vue `TextDocView` 中存在硬编码的 Agent health 示例，与真实 `/api/nexus/agent-health` 响应及 `0.3.0` 公共 Manifest 不完全一致。

因此，本节点可以作为 UI 更新基线，但不能被描述为“全部页面已经连接真实后端”。

### 截图和设计证据

- `screenshots/ui-refresh/` 是 `bfbea23` 深色方案的历史验收截图。
- `screenshots/archive/qwen-dark-draft-2026-07-22/` 是后续深色/橙色 Qwen 草稿截图，仅作历史比较。
- 上述截图都不代表当前浅色 checkpoint。
- 当前浅色版本尚未提交匹配的桌面和移动端截图。后续视觉验收应重新生成，不得复用旧图冒充当前版本。

### 验证

- Git 范围审计确认后端、API、Router、Store、公开 Agent 文档和部署文件没有变化。
- 当前工作区已有 2026-07-23 生成的忽略目录 `web/dist/`，其中包含当前浅色 tokens 和 `TechBg` 构建产物。
- 本次整理环境没有可用的 Windows Node/npm，WSL 也不可用，因此没有重新执行 `npm run build`。不能仅凭现有 `dist/` 将本次整理记录为一次新的独立构建通过。
- 提交前执行 Git 差异、空白错误和凭据扫描。

### 后续处理边界

下一轮可以在此节点上继续视觉迭代，但论坛真实数据接入、标签 API、论坛响应 DTO 和公开文档路由一致性应作为独立功能任务处理，避免与纯 UI 提交混在一起。

## English

### Why this checkpoint exists

This checkpoint preserves the current Qwen frontend as a traceable UI milestone for later refinement and comparison. It is not a production deployment record and does not claim final visual acceptance.

The 2026-07-22 maintenance note describes the earlier dark fintech pass. The working tree later moved to a light theme and added the product-requested animated code-character background. This note records that newer state without rewriting the earlier history.

### Included changes

- A light gray/white visual system with an olive-green accent.
- A new `TechBg.vue` full-screen animated code background with pointer response, visibility pausing, and reduced-motion fallback.
- Global tokens, base styles, shared component styles, and the animated background wired through `App.vue`.
- A reorganized application header and Bento-style home layout.
- Visual updates for forum, discussion, help and matching, Memory, Agent Profile, docs, and text pages.
- The OpenPencil source file at `designs/nexus-ui-refresh-qwen.op`.

The animated code background is an explicit product direction. Future work may tune its density, contrast, performance, and integration, but should not remove it without a product decision.

### Backend boundary

This checkpoint does not modify `server/`, frontend API adapters, Router, stores, public Agent docs, deployment files, database structure, authentication, or API contracts.

Authentication, Agent Profile, LLM settings, capabilities, help requests, dispatches, matches, private match messages, Memory, and match-memory sharing retain the previously verified Spring Boot integrations.

### Known integration gaps

- Home, forum list, and discussion detail still use `nexusSeed.ts`.
- Forum creation and replies are not connected to the existing write endpoints.
- Current forum responses do not expose all author, avatar, excerpt, tag-color, and tag-directory fields expected by the UI.
- Home counters, activity, active agents, and health labels are display data rather than live backend state.
- The SPA `TextDocView` contains a hard-coded health example that does not exactly match the real endpoint or the `0.3.0` public manifest.

This is therefore a UI checkpoint, not proof that every page is backed by live data.

### Evidence and verification

The screenshots under `screenshots/ui-refresh/` and `screenshots/archive/qwen-dark-draft-2026-07-22/` belong to earlier dark drafts and are retained only for historical comparison. They are not current light-theme acceptance screenshots.

An ignored `web/dist/` generated on 2026-07-23 contains the current light tokens and `TechBg` bundle. This documentation pass could not rerun `npm run build` because Windows Node/npm and WSL were unavailable, so it does not claim a fresh independent build result. Git scope, whitespace, and credential checks are performed before the checkpoint commit.
