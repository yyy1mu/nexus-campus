<template>
  <div class="forum-page">
    <AppHeader v-model:search-value="searchTerm" />

    <main class="forum-shell">
      <aside class="forum-sidebar">
        <RouterLink class="new-post" to="/help-requests"><Plus :size="17" />发起讨论</RouterLink>
        <nav class="base-links">
          <RouterLink to="/forum" :class="{ active: !activeSlug }"><MessagesSquare :size="17" />全部讨论</RouterLink>
          <RouterLink to="/tags"><LayoutGrid :size="17" />社区目录</RouterLink>
        </nav>
        <div class="sidebar-label">社区</div>
        <nav class="tag-links">
          <RouterLink
            v-for="tag in tags"
            :key="tag.slug"
            :class="{ active: tag.slug === activeSlug }"
            :to="`/t/${tag.slug}`"
          >
            <span :style="{ backgroundColor: tag.color }">{{ tag.name.slice(0, 1) }}</span>
            <strong>{{ tag.name }}</strong>
            <small>{{ tag.discussionCount }}</small>
          </RouterLink>
        </nav>
      </aside>

      <section class="forum-content">
        <header class="content-header">
          <div class="title-row">
            <span class="title-mark" :style="{ backgroundColor: activeTag?.color || '#2a2a32' }">
              {{ activeTag?.name.slice(0, 1) || '全' }}
            </span>
            <div>
              <h1>{{ activeTag?.name || '全部讨论' }}</h1>
              <p>{{ activeTag?.description || '浏览 Nexus 校园社区中的讨论、求助与协作记录。' }}</p>
            </div>
          </div>
          <div class="header-stats">
            <strong>{{ filtered.length }}</strong>
            <span>当前讨论</span>
          </div>
        </header>

        <div class="filter-bar">
          <div class="segmented-control">
            <button :class="{ active: sortMode === 'latest' }" @click="sortMode = 'latest'">最新</button>
            <button :class="{ active: sortMode === 'popular' }" @click="sortMode = 'popular'">热门</button>
            <button :class="{ active: sortMode === 'unanswered' }" @click="sortMode = 'unanswered'">待回复</button>
          </div>
          <span v-if="searchTerm">“{{ searchTerm }}” 的结果</span>
          <button class="view-button" type="button" title="列表视图" aria-label="列表视图"><List :size="18" /></button>
        </div>

        <div class="discussion-list">
          <article v-for="discussion in filtered" :key="discussion.id" class="discussion-row">
            <RouterLink class="avatar" :to="`/d/${discussion.id}/${discussion.slug}`">{{ discussion.avatar }}</RouterLink>
            <div class="discussion-main">
              <div class="discussion-meta">
                <RouterLink :to="`/t/${discussion.tagSlug}`" class="tag-label">
                  <span :style="{ backgroundColor: discussion.tagColor }" />{{ discussion.tagName }}
                </RouterLink>
                <span>{{ discussion.author }}</span>
                <span>4 天前</span>
              </div>
              <RouterLink :to="`/d/${discussion.id}/${discussion.slug}`">
                <h2>{{ discussion.title }}</h2>
                <p>{{ excerpt(discussion.body) }}</p>
              </RouterLink>
            </div>
            <div class="discussion-metrics">
              <span><MessageCircle :size="16" /><strong>{{ discussion.commentCount }}</strong><small>回复</small></span>
              <span><ArrowUp :size="16" /><strong>{{ discussion.replyCount * 6 + 3 }}</strong><small>赞同</small></span>
            </div>
          </article>

          <div v-if="!filtered.length" class="empty-state">
            <SearchX :size="28" />
            <strong>没有找到讨论</strong>
            <span>调整筛选条件或搜索关键词</span>
          </div>
        </div>
      </section>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { ArrowUp, LayoutGrid, List, MessageCircle, MessagesSquare, Plus, SearchX } from '@lucide/vue'
import { RouterLink, useRoute } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import { discussionsByTag, tagBySlug, tags } from '@/data/nexusSeed'

const route = useRoute()
const searchTerm = ref('')
const sortMode = ref<'latest' | 'popular' | 'unanswered'>('latest')
const activeSlug = computed(() => String(route.params.slug || ''))
const activeTag = computed(() => tagBySlug(activeSlug.value))

const filtered = computed(() => {
  const query = searchTerm.value.trim().toLowerCase()
  let result = discussionsByTag(activeSlug.value || undefined).filter((item) => {
    if (!query) return true
    return `${item.title} ${item.body} ${item.author} ${item.tagName}`.toLowerCase().includes(query)
  })
  if (sortMode.value === 'unanswered') result = result.filter((item) => item.replyCount === 0)
  return [...result].sort((a, b) => sortMode.value === 'popular'
    ? b.commentCount + b.replyCount - a.commentCount - a.replyCount
    : Date.parse(b.createdAt) - Date.parse(a.createdAt))
})

function excerpt(body: string) {
  const compact = body.replace(/\n+/g, ' ').trim()
  return compact.length > 96 ? `${compact.slice(0, 96)}...` : compact
}
</script>

<style scoped>
.forum-page { min-height: 100vh; background: transparent; }
.forum-shell { width: min(1280px, calc(100% - 40px)); margin: 0 auto; padding: var(--nx-space-8) 0 72px; display: grid; grid-template-columns: 216px minmax(0, 1fr); gap: 28px; }
.forum-sidebar { min-width: 0; }
.new-post { height: 44px; display: flex; align-items: center; justify-content: center; gap: var(--nx-space-2); border-radius: var(--nx-radius-full); color: var(--nx-on-accent); background: var(--nx-accent); font-size: var(--nx-fs-13); font-weight: 700; transition: background-color var(--nx-duration-fast) var(--nx-ease-out); }
.new-post:hover { background: var(--nx-accent-strong); }
.new-post:active { background: var(--nx-accent-dim); }
.base-links { margin-top: var(--nx-space-5); padding-bottom: var(--nx-space-4); border-bottom: 1px solid var(--nx-border-subtle); }
.base-links a { height: 42px; padding: 0 12px; display: flex; align-items: center; gap: 10px; border-radius: var(--nx-radius-md); color: var(--nx-text-tertiary); font-size: var(--nx-fs-13); font-weight: 600; transition: color var(--nx-duration-fast) var(--nx-ease-out), background-color var(--nx-duration-fast) var(--nx-ease-out); }
.base-links a:hover { color: var(--nx-text-secondary); background: var(--nx-bg-hover); }
.base-links a.active { color: var(--nx-text-primary); background: var(--nx-bg-active); }
.sidebar-label { height: 46px; display: flex; align-items: center; color: var(--nx-text-tertiary); font-size: 12px; font-weight: 600; }
.tag-links { display: grid; gap: 3px; }
.tag-links a { height: 42px; padding: 0 10px; display: flex; align-items: center; gap: 10px; border-radius: var(--nx-radius-md); color: var(--nx-text-tertiary); transition: background-color var(--nx-duration-fast) var(--nx-ease-out); }
.tag-links a:hover { background: var(--nx-bg-hover); }
.tag-links a.active { background: var(--nx-bg-active); }
.tag-links a > span { width: 26px; height: 26px; display: grid; place-items: center; border-radius: var(--nx-radius-md); color: #fff; font-size: 10px; font-weight: 800; }
.tag-links strong { min-width: 0; flex: 1; overflow: hidden; color: var(--nx-text-secondary); font-size: var(--nx-fs-12); text-overflow: ellipsis; white-space: nowrap; }
.tag-links small { color: var(--nx-text-tertiary); font-size: 10px; }
.forum-content { min-width: 0; }

/* ---- 内容头部（OKX 式大标题卡片） ---- */
.content-header { min-height: 120px; padding: 22px 24px; display: flex; align-items: center; justify-content: space-between; border: 1px solid var(--nx-border-subtle); border-radius: var(--nx-radius-xl); background: var(--nx-bg-raised); }
.title-row { display: flex; align-items: center; gap: 16px; }
.title-mark { width: 52px; height: 52px; display: grid; place-items: center; border-radius: var(--nx-radius-lg); color: #fff; font-size: 18px; font-weight: 800; }
.content-header h1 { color: var(--nx-text-primary); font-size: var(--nx-fs-24); font-weight: 800; letter-spacing: -0.02em; }
.content-header p { max-width: 690px; margin-top: 6px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); line-height: 1.55; }
.header-stats { min-width: 88px; padding-left: 22px; display: flex; flex-direction: column; border-left: 1px solid var(--nx-border-subtle); text-align: center; }
.header-stats strong { color: var(--nx-accent); font-size: var(--nx-fs-24); font-weight: 800; }
.header-stats span { margin-top: 3px; color: var(--nx-text-tertiary); font-size: 10px; }

/* ---- 筛选栏（OKX 胶囊分段控件） ---- */
.filter-bar { height: 70px; display: flex; align-items: center; gap: var(--nx-space-3); }
.filter-bar > span { color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); }
.segmented-control { height: 36px; padding: 4px; display: flex; border-radius: var(--nx-radius-full); background: var(--nx-bg-inset); }
.segmented-control button { min-width: 60px; border: 0; border-radius: var(--nx-radius-full); color: var(--nx-text-tertiary); background: transparent; font-size: var(--nx-fs-12); font-weight: 600; cursor: pointer; transition: color var(--nx-duration-fast) var(--nx-ease-out), background-color var(--nx-duration-fast) var(--nx-ease-out); }
.segmented-control button:hover { color: var(--nx-text-secondary); }
.segmented-control button.active { color: var(--nx-on-accent); background: var(--nx-accent); font-weight: 700; }
.view-button { width: 36px; height: 36px; margin-left: auto; display: grid; place-items: center; border: 1px solid var(--nx-border-default); border-radius: var(--nx-radius-md); color: var(--nx-text-tertiary); background: var(--nx-bg-raised); cursor: pointer; transition: color var(--nx-duration-fast) var(--nx-ease-out), border-color var(--nx-duration-fast) var(--nx-ease-out); }
.view-button:hover { color: var(--nx-text-primary); border-color: var(--nx-border-strong); }

/* ---- 讨论列表（OKX 式卡片行） ---- */
.discussion-list { border: 1px solid var(--nx-border-subtle); border-radius: var(--nx-radius-xl); overflow: hidden; background: var(--nx-bg-raised); }
.discussion-row { min-height: 128px; padding: 19px 22px; display: grid; grid-template-columns: 40px minmax(0, 1fr) 148px; align-items: start; gap: 15px; border-bottom: 1px solid var(--nx-border-subtle); transition: background-color var(--nx-duration-fast) var(--nx-ease-out); }
.discussion-row:last-child { border-bottom: 0; }
.discussion-row:hover { background: var(--nx-bg-hover); }
.avatar { width: 38px; height: 38px; display: grid; place-items: center; border-radius: var(--nx-radius-md); color: var(--nx-on-accent); background: var(--nx-accent-dim); font-size: var(--nx-fs-12); font-weight: 800; }
.discussion-main { min-width: 0; }
.discussion-meta { display: flex; align-items: center; gap: 9px; color: var(--nx-text-tertiary); font-size: 10px; }
.tag-label { display: inline-flex; align-items: center; gap: 5px; color: var(--nx-text-secondary); font-weight: 700; }
.tag-label:hover { color: var(--nx-accent); }
.tag-label span { width: 7px; height: 7px; border-radius: 2px; }
.discussion-main h2 { margin-top: 9px; color: var(--nx-text-primary); font-size: var(--nx-fs-16); font-weight: 700; line-height: 1.35; letter-spacing: -0.01em; transition: color var(--nx-duration-fast) var(--nx-ease-out); }
.discussion-main a:hover h2 { color: var(--nx-accent); }
.discussion-main p { max-width: 780px; margin-top: 7px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); line-height: 1.6; }
.discussion-metrics { align-self: center; display: grid; grid-template-columns: 1fr 1fr; }
.discussion-metrics span { display: flex; flex-direction: column; align-items: center; gap: 2px; color: var(--nx-text-tertiary); }
.discussion-metrics strong { color: var(--nx-text-secondary); font-size: var(--nx-fs-13); font-weight: 700; }
.discussion-metrics small { font-size: 9px; }
.empty-state { height: 280px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; color: var(--nx-text-tertiary); }
.empty-state strong { color: var(--nx-text-secondary); font-size: var(--nx-fs-14); }
.empty-state span { font-size: var(--nx-fs-11); }
@media (max-width: 820px) {
  .forum-shell { width: calc(100vw - 24px); padding-top: 16px; grid-template-columns: 1fr; }
  .forum-sidebar { display: none; }
  .discussion-row { grid-template-columns: 38px minmax(0, 1fr); padding: 16px 14px; }
  .discussion-metrics { display: none; }
  .content-header { padding: 18px; }
  .header-stats { display: none; }
  .content-header p { max-width: none; }
  .forum-page { padding-bottom: 68px; }
}
</style>