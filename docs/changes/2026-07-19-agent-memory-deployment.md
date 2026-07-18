# Agent Memory Deployment / Agent 长期记忆部署记录

Date: 2026-07-19 (Asia/Shanghai)
Target: `/opt/nexus-campus`
Source: `codex/agent-memory` at `b7bdb83928a7719f83dc7f35e4ed25ad2b705dae`

## 中文

### 为什么记录

本记录证明长期记忆功能不只在本地 H2 和前端开发服务中可用，也已在 Nexus 开发服务器的 Spring Boot、MySQL、Nginx 和 systemd 环境中完成部署与验证。记录不包含 SSH、数据库或 GitLab 凭据。

### 部署步骤

1. 确认服务器工作树干净，原分支为 `codex/server-deployment`。
2. 在更新前生成 MySQL 全库备份：
   `/var/backups/nexus-campus/nexus-before-agent-memory-20260718-162258.sql.gz`。
3. 从 GitLab 获取并切换到 `codex/agent-memory`。
4. 执行 `deploy/native/install-or-update.sh`，重新构建 Spring Boot 0.3.0 和 Vue/Vite 前端，更新 Nginx 并重启 systemd 服务。
5. 通过服务器本机 API 对部署后的 MySQL 数据路径进行冒烟测试。

### 验证证据

- 服务器提交：`b7bdb83928a7719f83dc7f35e4ed25ad2b705dae`，工作树干净。
- `nexus-campus`、`nginx`、`mysql`、`redis-server` 均为 `active`。
- `nexus_agent_memories` 和 `nexus_match_memory_shares` 两张表均存在。
- `/api/nexus/agent-health`、`/llms.txt`、Agent manifest、memory 文档、tool contract、OpenAPI 和 `/memories` 均返回 `200`。
- 运行时 OpenAPI 版本为 `0.3.0`，包含 memory 路径和 `clearExpiresAt`。
- 16 项远端 API 检查通过：注册、创建、单条读取、清除失效时间、召回、凭据内容 `400`、删除和删除后 `404`。
- 部署后 `nexus-campus.service` 的 error 级别日志数为 0。
- 合成冒烟用户在验收后从开发数据库清理。

### 网络限制

服务器当前只有 SSH NAT 映射。Nginx 和 API 已在服务器本机通过验收，但外部浏览器仍需要管理员配置 HTTP/HTTPS NAT 或域名入口。

## English

### Purpose

This record proves that Agent memory is deployed beyond local H2 and Vite development: it was built and exercised against the Nexus development server's Spring Boot, MySQL, Nginx, and systemd stack. No SSH, database, or GitLab credentials are recorded here.

### Deployment and Evidence

1. Confirmed a clean server worktree and created the pre-update MySQL backup
   `/var/backups/nexus-campus/nexus-before-agent-memory-20260718-162258.sql.gz`.
2. Fetched `codex/agent-memory` and deployed commit
   `b7bdb83928a7719f83dc7f35e4ed25ad2b705dae` with the native installer.
3. Rebuilt Spring Boot 0.3.0 and the Vue/Vite client, validated Nginx, and restarted systemd.
4. Verified all four services are active and both memory tables exist.
5. Verified seven public routes return `200`, OpenAPI exposes the memory contract and `clearExpiresAt`, and all 16 deployed MySQL API smoke checks pass.
6. Confirmed zero service errors after deployment and removed the synthetic smoke user.

The application is healthy on the server-local Nginx origin. Public browser access still depends on an external HTTP/HTTPS NAT or domain mapping.
