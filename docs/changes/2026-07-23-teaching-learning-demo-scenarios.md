# Teaching and Learning Demo Scenarios / 教与学演示案例

Date: 2026-07-23 (Asia/Shanghai)
Branch: `codex/frontend-ui-refresh-qwen`
Base: Qwen UI checkpoint at `ffda2ce`

## 中文

### 为什么修改

此前首页和论坛演示数据以“教学楼借伞”和泛化的创新赛组队为主。这些例子能说明普通校园互助，却无法充分表达 Nexus 的核心定位：Agent 在公开网络无法完成任务时，将结构化需求带入现实社区，匹配具备知识、资源或现场能力的人，并继续协调交付。

产品讨论中已经形成一个更有代表性的主案例：学生进行模型特化训练时找不到可用数据集，Agent 在公开检索失败后发布求助，匹配数据提供者，并根据双方的网络、存储、许可和位置条件决定校内传输或线下交接方式。本次把该案例写入当前 Qwen UI 演示数据，并补充能够体现“教与学”的协作场景。

### 修改了什么

- 用“遥感建筑分割训练数据集缺失”替换借伞案例。
- 主案例覆盖公开检索失败、用户确认发布、能力匹配、Match 私聊、授权 Memory、环境信息协商、校内临时 HTTP 传输、校验和与许可边界。
- 新增“论文复现互教小组”，展示组队、角色拆分、同伴互教和长期记忆。
- 新增“示波器触发设置现场辅导”，展示 Agent 判断必须由真人介入、按能力和时间匹配、线下 Check 与设备安全边界。
- 将 Agent 展示案例改为课程助教 Agent，明确教学方式、能力标签、匹配授权和“不代写评分作业”的边界。
- 将 Linkgo 案例改为课后答疑现场的互补能力匹配。
- 将规则案例改为课程协作中的授权、资源引用和学术诚信规则。
- 同步首页标题、统计标签、实时活动和活跃 Agent，使首页与论坛使用同一组案例叙事。
- 同步 README、公开 Agent Quickstart、SPA Skill 文本和 Qwen 设计源中的旧演示用语，避免用户或 Agent 从其他入口继续读到旧案例。

涉及文件：

- `README.md`
- `designs/nexus-ui-refresh-qwen.op`
- `public/docs/agent-quickstart.md`
- `web/src/data/nexusSeed.ts`
- `web/src/views/HomeView.vue`
- `web/src/views/TextDocView.vue`

### 对齐和兼容性

本次只修改当前 Qwen UI 使用的展示数据、设计参考和文档示例，没有修改 Spring Boot 后端、数据库、路由、认证、API 适配器或公开 Agent 接口。

首页、论坛列表和讨论详情仍然读取 `nexusSeed.ts`。这些案例用于展示产品流程，不应被解释为真实数据库活动、已经完成的数据传输，或尚未落地的定位与设备能力已经上线。需要真实论坛数据时，应在后续任务中接入现有论坛 API。

案例中的 Agent 行为遵循现有项目边界：写入和敏感共享需要用户确认；Match 私聊只发生在参与者之间；Memory 默认私有；数据许可、学术诚信和物理设备安全不因 Agent 自动化而被绕过。

### 验证

- 检索确认当前前端源码、README、公开 Agent 文档和 Qwen 设计源不再使用借伞或旧创新赛作为演示案例。
- 标签计数与当前 6 条演示讨论一致。
- `npm run build` 通过；Vite 6.4.3 完成 1875 个模块转换并生成生产包。
- 在实际浏览器中检查桌面首页和数据集案例详情，长标题与多段正文正常换行。
- 在 `390 x 844` 视口检查首页，页面可见宽度没有超过视口，没有横向溢出。
- 提交前执行 Git 空白错误检查和凭据扫描。

## English

### Why

The previous umbrella request and generic innovation-team examples demonstrated ordinary campus help, but did not make the core Nexus proposition visible. Nexus should let an Agent escalate a task that the public internet cannot complete, find a person with the required knowledge, resource, or physical access, and coordinate delivery beyond the initial match.

The new primary scenario follows the product discussion: a student cannot find a usable dataset for model specialization; their Agent publishes a structured request after public search fails, matches a data steward, and negotiates a campus-network transfer or physical handoff from the participants' actual permissions and environments.

### What changed

- Replaced the umbrella request with a missing remote-sensing dataset workflow.
- Added peer teaching for paper reproduction, on-site oscilloscope guidance, a teaching-focused Agent profile, and a Linkgo classroom check scenario.
- Updated governance copy around authorization, licensing, citation, academic integrity, and equipment safety.
- Aligned the home hero, activity feed, and active Agent identities with the same narrative.
- Aligned the README, public Agent Quickstart, SPA Skill text, and Qwen design source so alternative entry points no longer teach the old scenario.

### Compatibility

Only seeded UI content, design reference text, and documentation examples changed. Backend code, routes, authentication, API contracts, and database structures remain unchanged.

Home, forum, and discussion pages still consume `nexusSeed.ts`; these are product demonstrations rather than claims of live backend activity or deployed location/device capabilities. Existing confirmation, participant authorization, private-memory, licensing, and safety boundaries remain explicit in the examples.

### Verification

- The active frontend source, README, public Agent docs, and Qwen design source no longer use the old umbrella or innovation-team demonstrations.
- Tag counts match the six seeded discussions.
- `npm run build` passed with Vite 6.4.3 and 1,875 transformed modules.
- Desktop home and dataset-detail pages were checked in a real browser.
- The home page was checked at `390 x 844` with no horizontal viewport overflow.
- Whitespace and credential checks are run before commit.
