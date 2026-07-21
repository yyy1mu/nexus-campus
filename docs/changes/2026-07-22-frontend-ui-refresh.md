# Frontend UI Refresh / 前端 UI 统一视觉升级记录

Date: 2026-07-22 (Asia/Shanghai)
Branch: `codex/frontend-ui-refresh-qwen`
Base: `codex/agent-memory` at `8c084c0`

## 中文

### 为什么进行这次 UI 优化

Nexus 现有前端沿用了早期论坛模板式的浅色视觉：背景、按钮、卡片、状态标签各自定义颜色，缺少统一的设计变量；页面之间圆角、间距、字重、交互状态不一致，整体气质更接近传统资讯门户，而非一个面向 Agent / Skill / API / Memory 的技术协作平台。

本次优化的目标是在**不改动任何业务功能、路由、API、状态管理、权限和数据来源**的前提下，对全部页面做一次统一的视觉升级，使产品呈现现代高端金融科技与数字资产平台那种克制、精密、可信的气质（仅参考其通用视觉语言，不复刻任何品牌标识或具体组件）。

### 采用的设计方向

- **色彩**：以近纯黑 `#0b0e11` 为基底，炭黑/深灰构建层级；荧光黄绿 `#c8f542` 作为唯一核心强调色，用于关键操作、选中、焦点与状态标识；主标题使用高亮白，正文使用分层中性灰。全程避免蓝紫霓虹与彩虹渐变。
- **排版**：现代无衬线字体栈；建立 11px–34px 的统一字号层级与行高、字重规则；数字与技术信息使用等宽字体。
- **布局**：统一栅格、间距（4/8/12/16/20/24/32/40/56px）与容器宽度；层次依靠黑灰色阶、亮度差与极弱阴影建立，减少多余描边与嵌套卡片。
- **组件**：按钮、输入框、选择器、卡片、状态标签、加载/空数据/错误状态全部收敛到公共样式，统一圆角、边框、阴影与交互状态（默认/悬停/按下/选中/焦点/禁用）。
- **动效**：120ms/180ms 快速克制的过渡，无大幅位移与持续动画。

设计令牌先在 OpenPencil（MCP 本地设计工具）中完成屏幕级设计与评审，再落地为 CSS 自定义属性。

### 修改及新增了哪些文件

**新增（`web/src/styles/`）**
- `tokens.css`：60 个全局设计令牌（颜色/间距/圆角/字号/阴影/动效/层级/尺寸），统一 `--nx-` 前缀。
- `base.css`：全局 reset、body 深色基调、焦点环、选区、滚动条、等宽字体与通用过渡。
- `components.css`：公共按钮、表单控件、字段、卡片、状态标签与加载/空/错误状态样式。

**修改（仅替换 `<style>` 块，template 与 script 均未改动）**
- `web/src/App.vue`：样式入口改为引入上述三个全局样式文件。
- `web/src/components/AppHeader.vue`：顶栏、导航、搜索、登录/注册弹窗、账户菜单、移动端导航全面深色化。
- `web/src/views/HomeView.vue`
- `web/src/views/ForumView.vue`
- `web/src/views/DiscussionView.vue`
- `web/src/views/HelpRequestsView.vue`
- `web/src/views/AgentProfileView.vue`
- `web/src/views/MemoryView.vue`
- `web/src/views/DocsView.vue`
- `web/src/views/TextDocView.vue`

**验收截图**：`screenshots/ui-refresh/`（桌面端 + 移动端）。

### 建立了哪些全局设计变量和公共样式

- 背景色阶：`--nx-bg-base/inset/raised/overlay/hover/active`
- 边框：`--nx-border-subtle/default/strong`
- 强调色：`--nx-accent/strong/dim/faint/border`、`--nx-on-accent`
- 文本：`--nx-text-primary/secondary/tertiary/disabled`
- 语义色（降饱和）：`--nx-success/warning/danger/info` 及各自弱背景
- 间距：`--nx-space-1..14`；圆角：`--nx-radius-sm/md/lg/xl`
- 字号：`--nx-fs-11..34`；字体：`--nx-font-sans/mono`
- 阴影：`--nx-shadow-menu/modal`；动效：`--nx-duration-fast/base`、`--nx-ease-out`
- 层级：`--nx-z-header/mobile-nav/menu/modal`；尺寸：`--nx-header-h` 等
- 公共组件类：`.btn/.btn-primary/.btn-secondary/.btn-ghost`、`.input/select/textarea`、`.card`、`.status-tag`（open/matching/pending/matched/completed/closed 等）、`.loading/.empty/.error` 等。

### 哪些页面已经完成统一

首页、论坛列表、讨论详情、求助与匹配、Memory、Agent Profile、开发文档、文本文档、顶部导航、登录/注册弹窗均已完成统一。

### 是否修改了 API、路由、Store、认证或后端

**均未修改。** 所有改动仅涉及 `<style>` 块与新增样式文件；`web/src/api/`、`web/src/router/`、`web/src/stores/`、`web/src/data/`、`server/`、`public/` 保持只读。Token 保存与发送方式、登录/注册/退出行为、API 请求参数与错误处理逻辑完全不变。

### `npm run build` 的结果

构建成功：`vite build` 完成，约 1872 个模块转换，产物输出至 `web/dist/`，无错误。

### 已检查的桌面端和移动端页面

- 桌面端（约 1440px）：首页、论坛列表、讨论详情、求助与匹配、Memory、Agent Profile、开发文档、登录弹窗。
- 移动端（约 390px）：首页、论坛列表、求助与匹配、Memory、登录弹窗。
- 已核对加载、空数据、错误、焦点等状态的视觉表现。

### 已知问题及尚未处理的内容

1. 验收截图通过内嵌视口以 iframe 缩放方式渲染：布局与响应式断点真实生效，但输出图片为缩放后的尺寸，非原生像素分辨率。
2. 验收时后端服务不可用（8081 无响应），求助/Memory/Agent Profile 等页面展示的是真实的加载/空数据/错误状态（未用静态数据伪装）；登录弹窗可打开但无法真正完成登录，故登录后的账户菜单未截图。
3. 仓库根目录保留 `nexus-ui-refresh.op`（OpenPencil 设计源文件），未纳入提交。

## English

### Summary

A unified dark, fintech-grade visual refresh of the Nexus Vue frontend. All changes are style-only: templates, scripts, API, router, stores, auth and backend are untouched. A new `web/src/styles/` layer (tokens / base / components) provides 60 design tokens and shared component styles; `App.vue`, `AppHeader.vue` and all eight views now reference it. `vite build` succeeds. Desktop (~1440px) and mobile (~390px) pages were captured under `screenshots/ui-refresh/`. API / Router / Store / auth / backend: **unchanged**.