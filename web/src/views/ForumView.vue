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
            <span class="title-mark" :style="{ backgroundColor: activeTag?.color || '#111827' }">
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
.forum-page { min-height: 100vh; background: #f6f7f9; }
.forum-shell { width: min(1280px, calc(100vw - 40px)); margin: 0 auto; padding: 24px 0 64px; display: grid; grid-template-columns: 210px minmax(0, 1fr); gap: 28px; }
.forum-sidebar { min-width: 0; }
.new-post { height: 40px; display: flex; align-items: center; justify-content: center; gap: 8px; border-radius: 7px; color: #fff; background: #2563eb; font-size: 13px; font-weight: 700; }
.base-links { margin-top: 16px; padding-bottom: 16px; border-bottom: 1px solid #e1e4e8; }
.base-links a { height: 40px; padding: 0 10px; display: flex; align-items: center; gap: 10px; border-radius: 6px; color: #667085; font-size: 13px; font-weight: 600; }
.base-links a:hover, .base-links a.active { color: #111827; background: #e9edf3; }
.sidebar-label { height: 44px; display: flex; align-items: center; color: #8a94a4; font-size: 10px; font-weight: 800; text-transform: uppercase; }
.tag-links { display: grid; gap: 3px; }
.tag-links a { height: 40px; padding: 0 8px; display: flex; align-items: center; gap: 9px; border-radius: 6px; color: #667085; }
.tag-links a:hover, .tag-links a.active { background: #e9edf3; }
.tag-links a > span { width: 25px; height: 25px; display: grid; place-items: center; border-radius: 6px; color: #fff; font-size: 10px; font-weight: 800; }
.tag-links strong { min-width: 0; flex: 1; overflow: hidden; color: #475467; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
.tag-links small { color: #98a2b3; font-size: 10px; }
.forum-content { min-width: 0; }
.content-header { min-height: 112px; padding: 20px 22px; display: flex; align-items: center; justify-content: space-between; border: 1px solid #e0e4e9; border-radius: 8px; background: #fff; }
.title-row { display: flex; align-items: center; gap: 14px; }
.title-mark { width: 48px; height: 48px; display: grid; place-items: center; border-radius: 8px; color: #fff; font-size: 17px; font-weight: 800; }
.content-header h1 { color: #111827; font-size: 20px; }
.content-header p { max-width: 690px; margin-top: 6px; color: #77808f; font-size: 11px; line-height: 1.5; }
.header-stats { min-width: 82px; padding-left: 20px; display: flex; flex-direction: column; border-left: 1px solid #eceef1; text-align: center; }
.header-stats strong { color: #111827; font-size: 20px; }
.header-stats span { margin-top: 3px; color: #98a2b3; font-size: 10px; }
.filter-bar { height: 66px; display: flex; align-items: center; gap: 12px; }
.filter-bar > span { color: #7b8493; font-size: 11px; }
.segmented-control { height: 32px; padding: 3px; display: flex; border: 1px solid #dfe3e8; border-radius: 7px; background: #eceff3; }
.segmented-control button { min-width: 58px; border: 0; border-radius: 5px; color: #667085; background: transparent; font-size: 11px; cursor: pointer; }
.segmented-control button.active { color: #111827; background: #fff; box-shadow: 0 1px 2px rgba(16, 24, 40, .08); font-weight: 700; }
.view-button { width: 34px; height: 34px; margin-left: auto; display: grid; place-items: center; border: 1px solid #dfe3e8; border-radius: 7px; color: #667085; background: #fff; }
.discussion-list { border: 1px solid #e0e4e9; border-radius: 8px; overflow: hidden; background: #fff; }
.discussion-row { min-height: 126px; padding: 18px 20px; display: grid; grid-template-columns: 38px minmax(0, 1fr) 142px; align-items: start; gap: 14px; border-bottom: 1px solid #e8ebef; }
.discussion-row:last-child { border-bottom: 0; }
.discussion-row:hover { background: #fcfcfd; }
.avatar { width: 36px; height: 36px; display: grid; place-items: center; border-radius: 7px; color: #fff; background: #0f766e; font-size: 12px; font-weight: 800; }
.discussion-main { min-width: 0; }
.discussion-meta { display: flex; align-items: center; gap: 8px; color: #98a2b3; font-size: 10px; }
.tag-label { display: inline-flex; align-items: center; gap: 5px; color: #475467; font-weight: 700; }
.tag-label span { width: 7px; height: 7px; border-radius: 2px; }
.discussion-main h2 { margin-top: 8px; color: #202631; font-size: 15px; line-height: 1.35; }
.discussion-main p { max-width: 780px; margin-top: 6px; color: #667085; font-size: 11px; line-height: 1.55; }
.discussion-metrics { align-self: center; display: grid; grid-template-columns: 1fr 1fr; }
.discussion-metrics span { display: flex; flex-direction: column; align-items: center; gap: 2px; color: #98a2b3; }
.discussion-metrics strong { color: #475467; font-size: 12px; }
.discussion-metrics small { font-size: 9px; }
.empty-state { height: 260px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 7px; color: #98a2b3; }
.empty-state strong { color: #475467; font-size: 13px; }
.empty-state span { font-size: 11px; }
@media (max-width: 820px) {
  .forum-shell { width: calc(100vw - 24px); padding-top: 14px; grid-template-columns: 1fr; }
  .forum-sidebar { display: none; }
  .discussion-row { grid-template-columns: 36px minmax(0, 1fr); padding: 15px 13px; }
  .discussion-metrics { display: none; }
  .content-header { padding: 16px; }
  .header-stats { display: none; }
  .content-header p { max-width: none; }
  .forum-page { padding-bottom: 58px; }
}
</style>
