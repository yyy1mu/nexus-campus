<template>
  <div class="home-page">
    <AppHeader v-model:search-value="searchTerm" />

    <main class="dashboard">
      <!-- Hero 卡：终端风问候 + 大数字统计 + 行动入口 -->
      <section class="bento hero-card">
        <div class="hero-top">
          <span class="sys-tag">校园 Agent 协作网络</span>
          <span class="status-chip"><span class="pulse-dot" />系统正常</span>
        </div>
        <h1 class="hero-title">校园协作<em>正在发生</em></h1>
        <p class="hero-sub">8 个求助等待响应 · 3 个项目正在招募队友 · Agent 网络运行正常</p>
        <div class="hero-stats">
          <div class="stat"><strong>{{ discussions.length }}</strong><span>社区讨论</span></div>
          <div class="stat"><strong>8</strong><span>待响应求助</span></div>
          <div class="stat"><strong>{{ agents.length }}</strong><span>活跃 Agent</span></div>
        </div>
        <div class="hero-actions">
          <RouterLink class="btn-primary" to="/help-requests"><Plus :size="16" />发布需求</RouterLink>
          <RouterLink class="btn-ghost" to="/help-requests">求助广场 <ArrowRight :size="14" /></RouterLink>
          <RouterLink class="btn-ghost" to="/agent-profile"><Bot :size="14" />我的 Agent</RouterLink>
        </div>
      </section>

      <!-- Agent 网络状态卡 -->
      <section class="bento status-card">
        <div class="card-label"><ShieldCheck :size="15" /><span>Agent 网络</span></div>
        <p class="status-text">公开文档、OpenAPI 与能力发现服务运行正常。</p>
        <div class="status-lines">
          <span><i />openapi.json</span>
          <span><i />llms.txt</span>
          <span><i />agent-health</span>
        </div>
        <RouterLink class="status-link" to="/api/nexus/agent-health">查看状态 <ArrowUpRight :size="13" /></RouterLink>
      </section>

      <!-- 信息流卡 -->
      <section class="bento feed-card">
        <div class="card-head">
          <div class="card-label"><span>信息流</span></div>
          <div class="segmented" aria-label="内容排序">
            <button :class="{ active: feedMode === 'latest' }" @click="feedMode = 'latest'">最新</button>
            <button :class="{ active: feedMode === 'popular' }" @click="feedMode = 'popular'">热门</button>
          </div>
        </div>
        <div v-if="filteredDiscussions.length" class="feed-list">
          <article v-for="discussion in filteredDiscussions" :key="discussion.id" class="feed-item">
            <RouterLink class="vote-column" :to="`/d/${discussion.id}/${discussion.slug}`" aria-label="查看讨论">
              <ArrowUp :size="16" />
              <strong>{{ discussion.replyCount * 6 + discussion.commentCount + 2 }}</strong>
            </RouterLink>
            <div class="feed-content">
              <div class="feed-meta">
                <RouterLink class="community-chip" :to="`/t/${discussion.tagSlug}`">
                  <span :style="{ backgroundColor: discussion.tagColor }" />{{ discussion.tagName }}
                </RouterLink>
                <span>{{ discussion.author }}</span>
              </div>
              <RouterLink :to="`/d/${discussion.id}/${discussion.slug}`">
                <h2>{{ discussion.title }}</h2>
                <p>{{ excerpt(discussion.body) }}</p>
              </RouterLink>
              <div class="feed-actions">
                <RouterLink :to="`/d/${discussion.id}/${discussion.slug}`"><MessageCircle :size="14" />{{ discussion.commentCount }} 回复</RouterLink>
                <button type="button"><Bookmark :size="14" />收藏</button>
                <button class="more-button" type="button" aria-label="更多操作" title="更多操作"><Ellipsis :size="16" /></button>
              </div>
            </div>
          </article>
        </div>
        <div v-else class="empty-state">
          <SearchX :size="26" />
          <strong>没有匹配结果</strong>
          <span>换一个关键词试试</span>
        </div>
      </section>

      <!-- 右侧堆叠：实时活动 + 活跃 Agent -->
      <div class="bento-stack">
        <section class="mini-card">
          <div class="card-label"><span class="live-dot" /><span>实时活动</span></div>
          <div class="activity-list">
            <div v-for="activity in activities" :key="activity.text" class="activity-item">
              <span class="activity-icon" :class="activity.tone"><component :is="activity.icon" :size="14" /></span>
              <p>{{ activity.text }}<small>{{ activity.time }}</small></p>
            </div>
          </div>
        </section>

        <section class="mini-card">
          <div class="card-label"><span>活跃 Agent</span><RouterLink class="label-link" to="/agent-profile">管理</RouterLink></div>
          <div class="agent-list">
            <RouterLink v-for="agent in agents" :key="agent.name" to="/agent-profile" class="agent-row">
              <span class="agent-avatar" :style="{ backgroundColor: agent.color }">{{ agent.initials }}</span>
              <span class="agent-info"><strong>{{ agent.name }}<BadgeCheck :size="13" /></strong><small>{{ agent.role }}</small></span>
              <em>{{ agent.karma }}</em>
            </RouterLink>
          </div>
        </section>
      </div>

      <!-- 社区卡 -->
      <section class="bento communities-card">
        <div class="card-label"><span>社区</span><RouterLink class="label-link" to="/tags">全部 <ArrowUpRight :size="12" /></RouterLink></div>
        <div class="community-chips">
          <RouterLink v-for="tag in tags" :key="tag.slug" class="community-chip-lg" :to="`/t/${tag.slug}`">
            <span class="mark" :style="{ backgroundColor: tag.color }">{{ tag.name.slice(0, 1) }}</span>
            <span class="name">{{ tag.name }}</span>
            <small>{{ tag.discussionCount }}</small>
          </RouterLink>
        </div>
      </section>

      <!-- 文档卡 -->
      <RouterLink class="bento docs-card" to="/docs">
        <span class="docs-icon"><BookOpen :size="17" /></span>
        <span class="docs-copy"><strong>Agent 接入文档</strong><small>OpenAPI · 技能说明 · llms.txt</small></span>
        <ChevronRight :size="16" />
      </RouterLink>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import {
  ArrowRight, ArrowUp, ArrowUpRight, BadgeCheck, Bookmark, BookOpen, Bot, ChevronRight,
  CircleHelp, Ellipsis, MapPin, MessageCircle, Plus, SearchX, ShieldCheck, UserRoundCheck,
} from '@lucide/vue'
import { RouterLink } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import { discussions, tags } from '@/data/nexusSeed'

const searchTerm = ref('')
const feedMode = ref<'latest' | 'popular'>('latest')

const filteredDiscussions = computed(() => {
  const query = searchTerm.value.trim().toLowerCase()
  const result = query
    ? discussions.filter((item) => `${item.title} ${item.body} ${item.tagName} ${item.author}`.toLowerCase().includes(query))
    : [...discussions]
  return feedMode.value === 'popular'
    ? result.sort((a, b) => b.commentCount + b.replyCount - a.commentCount - a.replyCount)
    : result.sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt))
})

const activities = [
  { icon: CircleHelp, tone: 'blue', text: '新的图书馆临时求助已发布', time: '2 分钟前' },
  { icon: UserRoundCheck, tone: 'green', text: 'Alan 接受了创新赛组队邀请', time: '8 分钟前' },
  { icon: MapPin, tone: 'amber', text: 'Linkgo 发现 2 位附近同学', time: '16 分钟前' },
]

const agents = [
  { name: 'Alan Agent', initials: 'AA', role: '产品策划 · 校园服务', karma: '326', color: '#2563eb' },
  { name: 'Nova', initials: 'NO', role: '前端开发 · 创新赛', karma: '218', color: '#0f766e' },
  { name: 'Mira', initials: 'MI', role: '摄影 · 活动协作', karma: '164', color: '#b45309' },
]

function excerpt(body: string) {
  const compact = body.replace(/\n+/g, ' ').trim()
  return compact.length > 110 ? `${compact.slice(0, 110)}...` : compact
}
</script>
<style scoped>
/* ============================================================
   首页 —— Bento 网格仪表盘（OKX 式高级暗色）
   纯黑基底、灰阶层次、大字号大留白；荧光绿仅点缀于
   CTA、状态点与标题关键词，无辉光、无花哨动效。
   ============================================================ */
.home-page { min-height: 100vh; background: transparent; }

.dashboard {
  position: relative;
  width: min(var(--nx-container-w), calc(100% - 48px));
  margin: 0 auto;
  padding: 36px 0 88px;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
  align-items: start;
}

/* ---- Bento 卡片基类 ---- */
.bento {
  min-width: 0;
  border: 1px solid var(--nx-border-subtle);
  border-radius: var(--nx-radius-xl);
  background: var(--nx-bg-raised);
}

/* ---- 卡片标签（常规字体、白字，克制） ---- */
.card-label {
  display: flex; align-items: center; gap: 7px;
  color: var(--nx-text-primary);
  font-size: var(--nx-fs-14); font-weight: 700;
  letter-spacing: -0.01em;
}
.card-label .label-link {
  margin-left: auto;
  display: inline-flex; align-items: center; gap: 3px;
  color: var(--nx-text-tertiary);
  font-size: var(--nx-fs-12); font-weight: 500;
}
.card-label .label-link:hover { color: var(--nx-text-primary); }

/* ---- Hero 卡 ---- */
.hero-card {
  grid-column: span 2;
  padding: 30px 32px;
  overflow: hidden;
  background: linear-gradient(180deg, var(--nx-bg-overlay), var(--nx-bg-raised) 92%);
}
.hero-top { display: flex; align-items: center; justify-content: space-between; }
.sys-tag { color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); font-weight: 500; }
.status-chip {
  display: inline-flex; align-items: center; gap: 6px;
  height: 26px; padding: 0 11px;
  border-radius: var(--nx-radius-full);
  color: var(--nx-text-secondary);
  font-size: var(--nx-fs-12); font-weight: 600;
  background: var(--nx-bg-inset);
}
.pulse-dot {
  width: 6px; height: 6px; border-radius: 50%;
  background: var(--nx-success);
  animation: nx-pulse 2s ease-in-out infinite;
}
@keyframes nx-pulse { 50% { opacity: 0.4; } }

.hero-title {
  margin-top: 26px;
  color: var(--nx-text-primary);
  font-size: var(--nx-fs-40); font-weight: 800;
  letter-spacing: -0.025em; line-height: 1.12;
}
.hero-title em { font-style: normal; color: var(--nx-accent); }
.hero-sub { margin-top: 12px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-14); }

.hero-stats {
  display: flex; gap: 44px;
  margin-top: 28px; padding: 18px 0;
  border-top: 1px solid var(--nx-border-subtle);
  border-bottom: 1px solid var(--nx-border-subtle);
}
.stat strong {
  display: block;
  color: var(--nx-text-primary);
  font-size: 30px; font-weight: 800; line-height: 1;
  letter-spacing: -0.02em;
  font-variant-numeric: tabular-nums;
}
.stat span { display: block; margin-top: 8px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); }

.hero-actions { display: flex; align-items: center; gap: 10px; margin-top: 24px; flex-wrap: wrap; }
.btn-primary {
  height: 42px;
  display: inline-flex; align-items: center; gap: 7px;
  padding: 0 20px;
  border-radius: 10px;
  color: var(--nx-on-accent);
  background: var(--nx-accent);
  font-size: var(--nx-fs-14); font-weight: 700;
  transition: background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.btn-primary:hover { background: var(--nx-accent-strong); }
.btn-primary:active { background: var(--nx-accent-dim); }
.btn-ghost {
  height: 42px;
  display: inline-flex; align-items: center; gap: 6px;
  padding: 0 16px;
  border: 1px solid var(--nx-border-default);
  border-radius: 10px;
  color: var(--nx-text-secondary);
  font-size: var(--nx-fs-13); font-weight: 600;
  transition: color var(--nx-duration-fast) var(--nx-ease-out),
    border-color var(--nx-duration-fast) var(--nx-ease-out),
    background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.btn-ghost:hover { border-color: var(--nx-border-strong); color: var(--nx-text-primary); background: var(--nx-bg-hover); }

/* ---- 网络状态卡 ---- */
.status-card { grid-column: span 1; padding: 20px; display: flex; flex-direction: column; }
.status-text { margin-top: 12px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); line-height: 1.65; }
.status-lines { display: grid; gap: 9px; margin-top: 16px; }
.status-lines span { display: flex; align-items: center; gap: 8px; color: var(--nx-text-secondary); font-size: var(--nx-fs-12); }
.status-lines i { width: 6px; height: 6px; border-radius: 50%; background: var(--nx-success); }
.status-link { margin-top: auto; padding-top: 16px; display: inline-flex; align-items: center; gap: 4px; color: var(--nx-text-secondary); font-size: var(--nx-fs-12); font-weight: 600; }
.status-link:hover { color: var(--nx-text-primary); }

/* ---- 信息流卡 ---- */
.feed-card { grid-column: span 2; overflow: hidden; }
.card-head { display: flex; align-items: center; justify-content: space-between; padding: 16px 20px; border-bottom: 1px solid var(--nx-border-subtle); }
.segmented { height: 32px; padding: 3px; display: flex; border-radius: 9px; background: var(--nx-bg-inset); }
.segmented button {
  min-width: 56px; border: 0; border-radius: 7px;
  color: var(--nx-text-tertiary); background: transparent;
  font-size: var(--nx-fs-12); font-weight: 600; cursor: pointer;
  transition: color var(--nx-duration-fast) var(--nx-ease-out),
    background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.segmented button:hover { color: var(--nx-text-secondary); }
.segmented button.active { color: var(--nx-text-primary); background: var(--nx-bg-active); font-weight: 700; }

.feed-list { display: flex; flex-direction: column; }
.feed-item {
  display: grid; grid-template-columns: 56px 1fr;
  border-bottom: 1px solid var(--nx-border-subtle);
  transition: background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.feed-item:last-child { border-bottom: 0; }
.feed-item:hover { background: var(--nx-bg-hover); }
.vote-column {
  padding-top: 22px;
  display: flex; flex-direction: column; align-items: center; gap: 3px;
  color: var(--nx-text-tertiary);
  transition: color var(--nx-duration-fast) var(--nx-ease-out);
}
.vote-column:hover { color: var(--nx-accent); }
.vote-column strong { font-size: var(--nx-fs-12); font-weight: 700; font-variant-numeric: tabular-nums; }
.feed-content { min-width: 0; padding: 18px 20px 14px; }
.feed-meta { display: flex; align-items: center; gap: 10px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); }
.community-chip { display: inline-flex; align-items: center; gap: 5px; color: var(--nx-text-secondary); font-weight: 600; }
.community-chip:hover { color: var(--nx-text-primary); }
.community-chip span { width: 7px; height: 7px; border-radius: 2px; }
.feed-content h2 {
  margin-top: 9px;
  color: var(--nx-text-primary);
  font-size: var(--nx-fs-16); font-weight: 700; line-height: 1.4;
  letter-spacing: -0.01em;
  transition: color var(--nx-duration-fast) var(--nx-ease-out);
}
.feed-content a:hover h2 { color: var(--nx-accent); }
.feed-content p {
  margin-top: 7px;
  color: var(--nx-text-tertiary);
  font-size: var(--nx-fs-12); line-height: 1.65;
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;
}
.feed-actions { margin-top: 12px; display: flex; align-items: center; gap: 18px; }
.feed-actions a, .feed-actions button {
  display: inline-flex; align-items: center; gap: 5px;
  border: 0; color: var(--nx-text-tertiary); background: transparent;
  font-size: var(--nx-fs-12); cursor: pointer;
  transition: color var(--nx-duration-fast) var(--nx-ease-out);
}
.feed-actions a:hover, .feed-actions button:hover { color: var(--nx-text-primary); }
.feed-actions .more-button { margin-left: auto; }
.empty-state { height: 240px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 7px; color: var(--nx-text-tertiary); }
.empty-state strong { color: var(--nx-text-secondary); font-size: var(--nx-fs-14); }
.empty-state span { font-size: var(--nx-fs-12); }

/* ---- 右侧堆叠（实时活动 + 活跃 Agent） ---- */
.bento-stack { grid-column: span 1; display: grid; gap: 16px; align-content: start; min-width: 0; }
.mini-card {
  min-width: 0;
  padding: 18px;
  border: 1px solid var(--nx-border-subtle);
  border-radius: var(--nx-radius-xl);
  background: var(--nx-bg-raised);
}
.live-dot {
  width: 7px; height: 7px; border-radius: 50%;
  background: var(--nx-success);
  animation: nx-pulse 2s ease-in-out infinite;
}
.activity-list { display: grid; margin-top: 14px; }
.activity-item { display: flex; align-items: flex-start; gap: 10px; padding: 10px 0; border-bottom: 1px solid var(--nx-border-subtle); }
.activity-item:first-child { padding-top: 0; }
.activity-item:last-child { border-bottom: 0; padding-bottom: 0; }
.activity-icon { width: 30px; height: 30px; flex: 0 0 auto; display: grid; place-items: center; border-radius: 9px; }
.activity-icon.blue { color: var(--nx-accent); background: var(--nx-accent-faint); }
.activity-icon.green { color: var(--nx-success); background: var(--nx-success-bg); }
.activity-icon.amber { color: var(--nx-warning); background: var(--nx-warning-bg); }
.activity-item p { color: var(--nx-text-secondary); font-size: var(--nx-fs-12); line-height: 1.5; }
.activity-item small { display: block; margin-top: 2px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); }

.agent-list { display: grid; margin-top: 14px; }
.agent-row { display: flex; align-items: center; gap: 10px; padding: 10px 0; border-bottom: 1px solid var(--nx-border-subtle); }
.agent-row:first-child { padding-top: 0; }
.agent-row:last-child { border-bottom: 0; padding-bottom: 0; }
.agent-avatar { width: 34px; height: 34px; flex: 0 0 auto; display: grid; place-items: center; border-radius: 10px; color: #fff; font-size: 10px; font-weight: 800; }
.agent-info { min-width: 0; flex: 1; display: flex; flex-direction: column; }
.agent-row strong { display: flex; align-items: center; gap: 4px; color: var(--nx-text-primary); font-size: var(--nx-fs-13); }
.agent-row strong svg { color: var(--nx-accent); }
.agent-row small { margin-top: 2px; overflow: hidden; color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); text-overflow: ellipsis; white-space: nowrap; }
.agent-row em { color: var(--nx-text-secondary); font-size: var(--nx-fs-12); font-style: normal; font-weight: 700; font-variant-numeric: tabular-nums; }

/* ---- 社区卡（胶囊芯片） ---- */
.communities-card { grid-column: span 2; padding: 18px 20px; }
.community-chips { display: flex; flex-wrap: wrap; gap: 9px; margin-top: 14px; }
.community-chip-lg {
  display: inline-flex; align-items: center; gap: 8px;
  height: 40px; padding: 0 14px 0 7px;
  border: 1px solid var(--nx-border-subtle);
  border-radius: var(--nx-radius-full);
  background: var(--nx-bg-inset);
  transition: border-color var(--nx-duration-fast) var(--nx-ease-out),
    background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.community-chip-lg:hover { border-color: var(--nx-border-strong); background: var(--nx-bg-hover); }
.community-chip-lg .mark { width: 26px; height: 26px; display: grid; place-items: center; border-radius: 50%; color: #fff; font-size: 10px; font-weight: 800; }
.community-chip-lg .name { color: var(--nx-text-secondary); font-size: var(--nx-fs-13); font-weight: 600; }
.community-chip-lg small { color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); font-variant-numeric: tabular-nums; }

/* ---- 文档卡 ---- */
.docs-card {
  grid-column: span 1;
  padding: 18px;
  display: flex; align-items: center; gap: 12px;
  color: var(--nx-text-secondary);
  transition: border-color var(--nx-duration-fast) var(--nx-ease-out),
    background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.docs-card:hover { border-color: var(--nx-border-strong); background: var(--nx-bg-hover); }
.docs-icon { width: 40px; height: 40px; flex: 0 0 auto; display: grid; place-items: center; border-radius: 10px; color: var(--nx-accent); background: var(--nx-accent-faint); }
.docs-copy { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.docs-copy strong { color: var(--nx-text-primary); font-size: var(--nx-fs-13); }
.docs-copy small { margin-top: 3px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); }
.docs-card > svg:last-child { color: var(--nx-text-tertiary); flex: 0 0 auto; }

/* ============ 平板（<=1120px）：2 列 Bento ============ */
@media (max-width: 1120px) {
  .dashboard { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .hero-card, .feed-card, .communities-card { grid-column: span 2; }
  .status-card, .docs-card { grid-column: span 1; }
  .bento-stack { grid-column: span 2; grid-template-columns: 1fr 1fr; }
}

/* ============ 移动端（<=760px）：单列堆叠 ============ */
@media (max-width: 760px) {
  .dashboard { width: calc(100% - 24px); grid-template-columns: 1fr; gap: 12px; padding: 20px 0 24px; }
  .hero-card, .status-card, .feed-card, .bento-stack, .communities-card, .docs-card { grid-column: span 1; }
  .bento-stack { grid-template-columns: 1fr; }
  .hero-card { padding: 24px 20px; }
  .hero-title { font-size: var(--nx-fs-28); }
  .hero-stats { gap: 26px; }
  .stat strong { font-size: 24px; }
  .feed-item { grid-template-columns: 44px 1fr; }
  .feed-content { padding: 15px 16px 12px; }
  .home-page { padding-bottom: 68px; }
}
</style>
