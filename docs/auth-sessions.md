# 登录会话

注册和每次登录均签发独立的随机 Token，响应包含 `token`、`expiresAt`、`userId` 和 `username`。默认有效期 7 天，可通过 `AUTH_TOKEN_TTL` 配置（如 `24h`、`7d`）。到期后需要重新登录，不自动续期。

`POST /api/logout` 携带当前账号凭据 `Authorization: Token <token>`，服务端删除当前 Token。其他设备的独立会话继续有效。账号和 Token 的注册写入处于同一数据库事务内。

鉴权行为：

- 缺少、失效或过期的凭据：401。
- 已登录但无操作权限：403。
- 查询凭据时数据库不可用：503，前端保留会话。

前端只在明确收到当前 Token 的 401 后清除登录状态。网络错误、超时、5xx 和普通权限不足不触发退出；用户信息可从账户菜单重试加载。退出请求失败时保留登录状态并显示重试提示，避免把本地清理误报为服务端退出成功。

退出成功、凭据失效和重新登录会同步到同源的其他标签页。旧请求延迟返回的 401 不会清除更新后的会话。

## 更新已有部署

迁移 `V5__expiring_sessions.sql` 为 `api_keys` 增加可空的 `expires_at`。旧数据的空有效期不接受认证，升级后现有用户需要重新登录。Docker Compose 继续通过现有 Hibernate `ddl-auto=update` 自动添加该列；独立部署使用 `validate` 时需先执行迁移。不要直接启用 Flyway 接管未建立基线的旧库。

这些 Token 用于 Nexus 账号会话，与资源目录里外部 MCP Server 的 Bearer Token 分开。此次修改未增加邮箱验证、登录限流或找回密码。
