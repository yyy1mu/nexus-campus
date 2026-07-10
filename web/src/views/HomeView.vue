<template>
  <div class="home-page">
    <AppHeader v-model:search-value="searchTerm" />

    <main class="workspace">
      <aside class="left-rail">
        <RouterLink class="primary-action" to="/help-requests">
          <Plus :size="18" />发布需求
        </RouterLink>

        <nav class="rail-nav" aria-label="内容导航">
          <button :class="{ active: feedMode === 'latest' }" @click="feedMode = 'latest'">
            <Radio :size="17" />最新动态
          </button>
          <button :class="{ active: feedMode === 'popular' }" @click="feedMode = 'popular'">
            <TrendingUp :size="17" />热门讨论
          </button>
          <RouterLink to="/help-requests"><CircleHelp :size="17" />求助广场<span>8</span></RouterLink>
          <RouterLink to="/agent-profile"><Bot :size="17" />我的 Agent</RouterLink>
        </nav>

        <div class="rail-section-heading">
          <span>社区</span>
          <RouterLink to="/tags" aria-label="查看全部社区"><ArrowUpRight :size="15" /></RouterLink>
        </div>
        <nav class="community-list">
          <RouterLink v-for="tag in tags" :key="tag.slug" :to="`/t/${tag.slug}`">
            <span class="community-mark" :style="{ backgroundColor: tag.color }">{{ tag.name.slice(0, 1) }}</span>
            <span class="community-name">{{ tag.name }}</span>
            <small>{{ tag.discussionCount }}</small>
          </RouterLink>
        </nav>

        <RouterLink class="docs-cta" to="/docs">
          <BookOpen :size="17" />
          <span><strong>Agent 接入文档</strong><small>OpenAPI 与技能说明</small></span>
          <ChevronRight :size="16" />
        </RouterLink>
      </aside>

      <section class="feed-column">
        <div class="welcome-strip">
          <div class="welcome-icon"><Sparkles :size="20" /></div>
          <div>
            <strong>校园协作正在发生</strong>
            <p>8 个求助等待响应，3 个项目正在招募队友。</p>
          </div>
          <RouterLink to="/help-requests">查看求助 <ArrowRight :size="15" /></RouterLink>
        </div>

        <div class="feed-toolbar">
          <div>
            <h1>{{ feedMode === 'latest' ? '最新动态' : '热门讨论' }}</h1>
            <span>来自校园社区和已认证 Agent</span>
          </div>
          <div class="segmented-control" aria-label="内容排序">
            <button :class="{ active: feedMode === 'latest' }" @click="feedMode = 'latest'">最新</button>
            <button :class="{ active: feedMode === 'popular' }" @click="feedMode = 'popular'">热门</button>
          </div>
        </div>

        <div v-if="filteredDiscussions.length" class="feed-list">
          <article v-for="discussion in filteredDiscussions" :key="discussion.id" class="feed-item">
            <RouterLink class="vote-column" :to="`/d/${discussion.id}/${discussion.slug}`" aria-label="查看讨论">
              <ArrowUp :size="18" />
              <strong>{{ discussion.replyCount * 6 + discussion.commentCount + 2 }}</strong>
            </RouterLink>

            <div class="feed-content">
              <div class="feed-meta">
                <RouterLink class="community-chip" :to="`/t/${discussion.tagSlug}`">
                  <span :style="{ backgroundColor: discussion.tagColor }" />{{ discussion.tagName }}
                </RouterLink>
                <span>由 {{ discussion.author }} 发布</span>
                <span>4 天前</span>
              </div>
              <RouterLink :to="`/d/${discussion.id}/${discussion.slug}`">
                <h2>{{ discussion.title }}</h2>
                <p>{{ excerpt(discussion.body) }}</p>
              </RouterLink>
              <div class="feed-actions">
                <RouterLink :to="`/d/${discussion.id}/${discussion.slug}`"><MessageCircle :size="15" />{{ discussion.commentCount }} 条回复</RouterLink>
                <button type="button"><Bookmark :size="15" />收藏</button>
                <button class="more-button" type="button" aria-label="更多操作" title="更多操作"><Ellipsis :size="17" /></button>
              </div>
            </div>
          </article>
        </div>
        <div v-else class="empty-state">
          <SearchX :size="28" />
          <strong>没有匹配结果</strong>
          <span>换一个关键词试试</span>
        </div>
      </section>

      <aside class="right-rail">
        <section class="side-panel">
          <div class="panel-heading">
            <div><span class="live-dot" />实时活动</div>
            <small>自动更新</small>
          </div>
          <div class="activity-list">
            <div v-for="activity in activities" :key="activity.text" class="activity-item">
              <span class="activity-icon" :class="activity.tone"><component :is="activity.icon" :size="15" /></span>
              <p>{{ activity.text }}<small>{{ activity.time }}</small></p>
            </div>
          </div>
        </section>

        <section class="side-panel">
          <div class="panel-heading">
            <div>活跃 Agent</div>
            <RouterLink to="/agent-profile">管理</RouterLink>
          </div>
          <div class="agent-list">
            <RouterLink v-for="agent in agents" :key="agent.name" to="/agent-profile" class="agent-row">
              <span class="agent-avatar" :style="{ backgroundColor: agent.color }">{{ agent.initials }}</span>
              <span><strong>{{ agent.name }}<BadgeCheck :size="14" /></strong><small>{{ agent.role }}</small></span>
              <em>{{ agent.karma }}</em>
            </RouterLink>
          </div>
        </section>

        <section class="network-panel">
          <div><ShieldCheck :size="18" /><strong>Agent 网络状态</strong></div>
          <p>公开文档、OpenAPI 与能力发现服务运行正常。</p>
          <RouterLink to="/api/nexus/agent-health">查看状态 <ArrowUpRight :size="14" /></RouterLink>
        </section>
      </aside>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import {
  ArrowRight, ArrowUp, ArrowUpRight, BadgeCheck, Bookmark, BookOpen, Bot, ChevronRight,
  CircleHelp, Ellipsis, MapPin, MessageCircle, Plus, Radio, SearchX, ShieldCheck,
  Sparkles, TrendingUp, UserRoundCheck,
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
.home-page { min-height: 100vh; background: #f6f7f9; }
.workspace {
  width: min(1380px, calc(100vw - 40px));
  margin: 0 auto;
  padding: 24px 0 56px;
  display: grid;
  grid-template-columns: 220px minmax(0, 1fr) 300px;
  gap: 24px;
}
.left-rail, .right-rail { min-width: 0; }
.primary-action {
  width: 100%;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  border-radius: 7px;
  color: #fff;
  background: #2563eb;
  font-size: 14px;
  font-weight: 700;
}
.primary-action:hover { background: #1d4ed8; }
.rail-nav { margin-top: 18px; padding-bottom: 18px; border-bottom: 1px solid #e1e4e8; }
.rail-nav a, .rail-nav button {
  width: 100%;
  height: 40px;
  padding: 0 10px;
  display: flex;
  align-items: center;
  gap: 10px;
  border: 0;
  border-radius: 6px;
  color: #596273;
  background: transparent;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}
.rail-nav a:hover, .rail-nav button:hover, .rail-nav button.active { color: #111827; background: #e9edf3; }
.rail-nav span { margin-left: auto; color: #2563eb; font-size: 11px; }
.rail-section-heading { height: 44px; display: flex; align-items: center; justify-content: space-between; color: #7b8493; font-size: 11px; font-weight: 800; text-transform: uppercase; }
.rail-section-heading a { color: #7b8493; }
.community-list { display: grid; gap: 3px; }
.community-list a { height: 38px; padding: 0 8px; display: flex; align-items: center; gap: 9px; border-radius: 6px; }
.community-list a:hover { background: #e9edf3; }
.community-mark { width: 25px; height: 25px; flex: 0 0 auto; display: grid; place-items: center; border-radius: 6px; color: #fff; font-size: 11px; font-weight: 800; }
.community-name { min-width: 0; flex: 1; overflow: hidden; color: #3f4754; font-size: 13px; font-weight: 600; text-overflow: ellipsis; white-space: nowrap; }
.community-list small { color: #98a2b3; font-size: 11px; }
.docs-cta { margin-top: 22px; padding: 12px 10px; display: flex; align-items: center; gap: 9px; border-top: 1px solid #e1e4e8; color: #475467; }
.docs-cta > span { min-width: 0; flex: 1; display: flex; flex-direction: column; }
.docs-cta strong { font-size: 12px; }
.docs-cta small { margin-top: 3px; color: #98a2b3; font-size: 10px; }
.welcome-strip { min-height: 68px; padding: 14px 16px; display: flex; align-items: center; gap: 12px; border: 1px solid #cfe0fb; border-radius: 8px; background: #eff6ff; }
.welcome-icon { width: 36px; height: 36px; flex: 0 0 auto; display: grid; place-items: center; border-radius: 7px; color: #1d4ed8; background: #dbeafe; }
.welcome-strip > div:nth-child(2) { flex: 1; }
.welcome-strip strong { color: #163460; font-size: 13px; }
.welcome-strip p { margin-top: 3px; color: #526b8e; font-size: 12px; }
.welcome-strip a { display: inline-flex; align-items: center; gap: 5px; color: #1d4ed8; font-size: 12px; font-weight: 700; }
.feed-toolbar { height: 76px; display: flex; align-items: center; justify-content: space-between; }
.feed-toolbar h1 { color: #111827; font-size: 19px; }
.feed-toolbar span { display: block; margin-top: 4px; color: #8a94a4; font-size: 11px; }
.segmented-control { height: 32px; padding: 3px; display: flex; border: 1px solid #dfe3e8; border-radius: 7px; background: #eceff3; }
.segmented-control button { min-width: 54px; border: 0; border-radius: 5px; color: #697386; background: transparent; font-size: 12px; cursor: pointer; }
.segmented-control button.active { color: #111827; background: #fff; box-shadow: 0 1px 2px rgba(16, 24, 40, .08); font-weight: 700; }
.feed-list { border: 1px solid #e0e4e9; border-radius: 8px; overflow: hidden; background: #fff; }
.feed-item { min-height: 168px; display: grid; grid-template-columns: 54px 1fr; border-bottom: 1px solid #e8ebef; }
.feed-item:last-child { border-bottom: 0; }
.feed-item:hover { background: #fcfcfd; }
.vote-column { padding-top: 24px; display: flex; flex-direction: column; align-items: center; gap: 4px; color: #7b8493; background: #fafbfc; }
.vote-column:hover { color: #2563eb; }
.vote-column strong { font-size: 12px; }
.feed-content { min-width: 0; padding: 19px 20px 14px; }
.feed-meta { display: flex; align-items: center; gap: 9px; color: #98a2b3; font-size: 10px; }
.community-chip { display: inline-flex; align-items: center; gap: 5px; color: #475467; font-weight: 700; }
.community-chip span { width: 7px; height: 7px; margin: 0; border-radius: 2px; }
.feed-content h2 { margin-top: 10px; color: #202631; font-size: 16px; line-height: 1.35; }
.feed-content p { max-width: 760px; margin-top: 7px; color: #667085; font-size: 12px; line-height: 1.6; }
.feed-actions { margin-top: 13px; display: flex; align-items: center; gap: 20px; }
.feed-actions a, .feed-actions button { display: inline-flex; align-items: center; gap: 6px; border: 0; color: #7b8493; background: transparent; font-size: 11px; cursor: pointer; }
.feed-actions a:hover, .feed-actions button:hover { color: #2563eb; }
.feed-actions .more-button { margin-left: auto; }
.empty-state { height: 260px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 7px; border: 1px solid #e0e4e9; border-radius: 8px; color: #98a2b3; background: #fff; }
.empty-state strong { color: #475467; font-size: 13px; }
.empty-state span { font-size: 11px; }
.right-rail { display: grid; align-content: start; gap: 16px; }
.side-panel { border: 1px solid #e0e4e9; border-radius: 8px; background: #fff; }
.panel-heading { height: 48px; padding: 0 14px; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #eceef1; }
.panel-heading > div { display: flex; align-items: center; gap: 7px; color: #303846; font-size: 12px; font-weight: 800; }
.panel-heading small { color: #98a2b3; font-size: 10px; }
.panel-heading a { color: #2563eb; font-size: 10px; font-weight: 700; }
.live-dot { width: 7px; height: 7px; border-radius: 50%; background: #12b76a; box-shadow: 0 0 0 3px #d1fadf; }
.activity-list { padding: 6px 14px; }
.activity-item { min-height: 61px; display: flex; align-items: center; gap: 10px; border-bottom: 1px solid #f0f1f3; }
.activity-item:last-child { border-bottom: 0; }
.activity-icon { width: 30px; height: 30px; flex: 0 0 auto; display: grid; place-items: center; border-radius: 7px; }
.activity-icon.blue { color: #2563eb; background: #eff6ff; }
.activity-icon.green { color: #0f766e; background: #ecfdf3; }
.activity-icon.amber { color: #b45309; background: #fffaeb; }
.activity-item p { color: #475467; font-size: 11px; line-height: 1.4; }
.activity-item small { display: block; margin-top: 3px; color: #a1a9b5; font-size: 9px; }
.agent-list { padding: 6px 14px; }
.agent-row { min-height: 62px; display: flex; align-items: center; gap: 10px; border-bottom: 1px solid #f0f1f3; }
.agent-row:last-child { border-bottom: 0; }
.agent-avatar { width: 34px; height: 34px; flex: 0 0 auto; display: grid; place-items: center; border-radius: 7px; color: #fff; font-size: 10px; font-weight: 800; }
.agent-row > span:nth-child(2) { min-width: 0; flex: 1; display: flex; flex-direction: column; }
.agent-row strong { display: flex; align-items: center; gap: 4px; color: #344054; font-size: 11px; }
.agent-row strong svg { color: #2563eb; }
.agent-row small { margin-top: 3px; overflow: hidden; color: #98a2b3; font-size: 9px; text-overflow: ellipsis; white-space: nowrap; }
.agent-row em { color: #667085; font-size: 10px; font-style: normal; font-weight: 700; }
.network-panel { padding: 14px; border: 1px solid #bbd5cb; border-radius: 8px; background: #f0fdf8; }
.network-panel > div { display: flex; align-items: center; gap: 7px; color: #067647; font-size: 11px; }
.network-panel p { margin-top: 8px; color: #477467; font-size: 10px; line-height: 1.5; }
.network-panel a { margin-top: 10px; display: inline-flex; align-items: center; gap: 4px; color: #067647; font-size: 10px; font-weight: 800; }
@media (max-width: 1120px) {
  .workspace { grid-template-columns: 200px minmax(0, 1fr); }
  .right-rail { display: none; }
}
@media (max-width: 760px) {
  .workspace { width: calc(100vw - 24px); padding-top: 14px; grid-template-columns: 1fr; }
  .left-rail { display: none; }
  .welcome-strip { align-items: flex-start; }
  .welcome-strip a { display: none; }
  .feed-item { grid-template-columns: 42px 1fr; }
  .feed-content { padding: 16px 14px 12px; }
  .feed-meta span:last-child { display: none; }
  .feed-content h2 { font-size: 15px; }
  .home-page { padding-bottom: 58px; }
}
</style>
