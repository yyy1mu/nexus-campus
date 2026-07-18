# Auth Entry and Match Authorization / 登录入口与 Match 权限加固

Status: implemented and verified on `codex/agent-memory`
Base: `refactor/backend-v2` at `4f14f82`

## 中文

### 为什么修改

浏览器端已经实现 `/api/login`、`/api/register`、Axios token 注入和 Pinia auth store，但没有任何可见登录入口。用户打开记忆、Agent 配置等受保护页面后只能得到 `401`，无法从 UI 恢复。accepted match 冒烟测试还发现，`HelpMatchService.updateStatus` 没有在所有状态转换前统一拒绝非参与者。

### 修改内容

- `AppHeader.vue` 增加登录/注册弹窗、已登录账户菜单和退出入口；
- auth store 持久化用户名，应用启动时恢复 Agent context；
- `MemoryView.vue` 监听 token 变化，登录后立即重新读取记忆；
- `HelpMatchService.updateStatus` 在任何转换前要求 actor 是 requester 或 helper；
- 增加非参与者不能完成 accepted match 的回归测试。

### 兼容性

认证协议没有变化，仍使用 `Authorization: Token <token>`。后端接口和现有本地 Agent 调用方式不受影响。权限修复只会拒绝此前不应被允许的第三方 match 状态写入。

### 验证

- 通过真实浏览器完成注册、自动登录、会话恢复和退出菜单检查；
- `mvn test`: 9 项通过；
- accepted match 的第三方读取返回 `403`，非参与者状态变更单元测试返回 `403`；
- Vue 生产构建通过。

## English

### Why

The Vue client already had register/login APIs, Axios token injection, and a Pinia auth store, but no visible authentication entry point. Protected pages could only display a `401` state. The accepted-match smoke flow also exposed that `HelpMatchService.updateStatus` did not reject non-participants before every transition.

### What Changed

- Added a header login/register dialog, account menu, and logout action.
- Persisted the display username and restored Agent context on application startup.
- Reloaded the memory view when the authentication token changes.
- Required every match status actor to be the requester or helper.
- Added a regression test for a non-participant attempting to complete an accepted match.

### Compatibility and Evidence

The token protocol and Agent API remain unchanged. The authorization change only rejects writes that were outside the match participant boundary. Browser authentication, 9 backend tests, the Vue production build, and participant/non-participant HTTP behavior were verified.
