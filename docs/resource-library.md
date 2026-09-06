# Skill 与 MCP 资源库

`/skills` 与 `/mcp-servers` 分别提供 Skill 和 MCP Server 资源收录与展示，拥有同级导航入口。旧 `/skills?type=mcp` 链接重定向到 MCP 页面。Skill 和 MCP Server 使用独立条目，统一支持搜索、收藏、个人收录与创建者管理。无第三方榜单依赖、预置排名或模拟安装量。

## 页面与权限

- 访客：浏览列表、按名称 / 简介 / 分类搜索、查看资源详情。
- 登录用户：公开收录资源、收藏 / 取消收藏、查看自己的收藏和收录。
- 创建者：编辑或删除自己的条目。删除资源同时清理其收藏关系。
- 收藏数量来自实际账号收藏；重复收藏不会重复计数。列表每页 24 条，按收录时间倒序。
- `/agent-profile` 重定向到 `/skills`。原有协作授权与能力标签移至账户菜单的“协作设置”，已有协作接口仍可使用。

## 两类资源

共同字段：名称、分类、简介、使用说明、公开项目 / 文档链接。

Skill 附加可复制的安装命令。可以填写 `npx skills add owner/repo`，也可以描述项目自己的安装方式。网站只展示文本，不执行安装命令。

MCP 附加传输协议（Streamable HTTP / SSE / stdio）、远程服务地址和鉴权方式（Bearer Token / 无 HTTP 鉴权）。本地 stdio 展示启动说明；远程连接提供 VS Code `mcp.json` 配置。结构参照 [VS Code MCP 配置参考](https://code.visualstudio.com/docs/agents/reference/mcp-configuration)。

Bearer 配置使用 `Authorization: Bearer ${input:...}`，通过客户端的密码输入获取凭据。Nexus 不接收、保存或代理真实 MCP Token，也不会自动访问用户填写的服务地址。目录标记的是收录者声明的鉴权方式，不代表已经连接或验证该服务；真正的鉴权由目标 MCP Server 执行。配置适用于支持 `inputs` 的 VS Code MCP 会话；Agent Host 等其他运行环境应参考对应客户端文档。

公开 URL 限 HTTPS，不接受 URL 内的账户、查询参数或片段，防止把连接凭据放进公开地址。

## API

接口前缀 `/api/nexus/resources`，统一返回 `{ data: ... }`。写入与个人筛选复用现有 Nexus 账号的 `Authorization: Token <nexus-token>`，与外部 MCP Bearer Token 无关。

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET | `/` | 列表；参数 `kind=skill|mcp`、`q`、`scope=all|mine|favorites`、`page`（从 0 开始） |
| GET | `/{id}` | 详情 |
| POST | `/` | 新建 |
| PUT | `/{id}` | 创建者完整更新；资源类型不可变更 |
| DELETE | `/{id}` | 创建者删除 |
| PUT | `/{id}/favorite` | 幂等收藏 |
| DELETE | `/{id}/favorite` | 幂等取消收藏 |

请求字段定义见 `CatalogRequest`；响应只使用 `CatalogResponse`，不暴露收藏用户列表。收藏写入使用资源行锁及数据库唯一约束，避免并发重复计数。

## 存储与部署

新增表 `nexus_catalog_resources`、`nexus_catalog_favorites`；迁移文件为 `V4__resource_catalog.sql`。

现有 Docker Compose 使用 Hibernate `ddl-auto=update` 且关闭 Flyway，会自动创建新表。使用 `ddl-auto=validate` 的独立生产部署，应先按部署流程执行 V4 迁移；不要直接启用 Flyway 去接管尚未建立基线的已有库。

验证命令：`mvn -f server/pom.xml test`（Java 21）、`npm --prefix web run type-check`、`npm --prefix web run build`。

## 本地演示数据

运行 `node scripts/seed-resource-demo.mjs`，向当前本地 Docker 实例导入 6 条 Skill 与 6 条 MCP Server。可用 `NEXUS_DEMO_BASE_URL` 指定另一个 localhost 端口，默认 `http://127.0.0.1:8080`。

数据定义位于 `scripts/fixtures/resource-demo.json`，包含六类资源、HTTP / SSE / stdio、Bearer Token 与无 HTTP 鉴权示例。名称带“演示”，详情包含 MOCK 提示，地址使用 `example.invalid`，安装命令经过注释，不代表真实可用服务。少量收藏由演示账号实际创建，仅用于展示收藏状态。

脚本使用独立的 `nexus_resources_demo` 账号，随机密码保存在 `.local/resource-demo-8080.json`（端口变化时文件名随之变化），权限为 0600，目录已忽略提交。需要用该账号编辑演示条目时，可以从本地文件获取登录信息。脚本完成后会撤销本次导入会话的 Token。

重复运行跳过已存在条目，不覆盖编辑。执行 `node scripts/seed-resource-demo.mjs --remove` 可删除该演示账号收录的这组固定演示条目及其收藏关系，其他资源保持不变。
