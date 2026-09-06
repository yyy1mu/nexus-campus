<template>
  <AppHeader />
  <main class="forum-shell">
    <PageIntro eyebrow="COMMUNITY / 讨论" :title="activeTag?.name || '让想法产生连接'" :description="activeTag?.description || '分享经验、交流灵感，在校园中找到同行的人。'">
      <RouterLink class="btn btn-primary" to="/help-requests"><Plus :size="17" />发布求助</RouterLink>
    </PageIntro>
    <nav class="community-tabs" aria-label="讨论社区"><RouterLink to="/forum" :class="{ selected: !activeSlug }">全部讨论</RouterLink><RouterLink v-for="tag in tags" :key="tag.slug" :to="`/t/${tag.slug}`" :class="{ selected: activeSlug === tag.slug }"><i :style="{ background: tag.color }" />{{ tag.name }}</RouterLink></nav>
    <div class="filter-bar"><label class="forum-search"><Search :size="18" /><input v-model="searchTerm" placeholder="搜索讨论、作者或关键词" aria-label="搜索讨论" /></label><div class="sort-tabs"><button v-for="option in ([['latest','最新'],['popular','热门'],['unanswered','待回复']] as const)" :key="option[0]" :aria-pressed="sortMode === option[0]" :class="{ selected: sortMode === option[0] }" @click="sortMode = option[0]">{{ option[1] }}</button></div></div>
    <div class="results-note"><span>{{ filtered.length }} 篇讨论</span></div>
    <StatePanel v-if="loading" tone="loading" title="正在加载讨论" />
    <StatePanel v-else-if="loadError" tone="error" title="讨论暂时无法加载" :description="loadError"><button class="btn btn-secondary" @click="load">重新加载</button></StatePanel>
    <section v-else class="discussion-list" aria-label="讨论列表">
      <article v-for="discussion in filtered" :key="discussion.id" class="discussion-row">
        <div class="avatar">{{ avatarOf(discussion.author) }}</div><div class="discussion-main"><div class="discussion-meta"><RouterLink v-if="discussion.tags[0]" :to="`/t/${discussion.tags[0].slug}`">{{ discussion.tags[0].name }}</RouterLink><span>{{ discussion.author }}</span><time>{{ new Date(discussion.createdAt).toLocaleDateString('zh-CN') }}</time></div><RouterLink :to="`/d/${discussion.id}/${discussion.slug}`"><h2>{{ discussion.title }}</h2><p>{{ excerpt(discussion.excerpt) }}</p></RouterLink></div><span class="reply-count"><MessageCircle :size="17" />{{ discussion.commentCount }}<small>回复</small></span>
      </article>
      <StatePanel v-if="!filtered.length" title="没有找到讨论" description="试试其他关键词或切换社区。" />
    </section>
  </main>
</template>
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { MessageCircle, Plus, Search } from '@lucide/vue'
import { RouterLink, useRoute } from 'vue-router'
import PageIntro from '@/components/PageIntro.vue'
import StatePanel from '@/components/StatePanel.vue'
import AppHeader from '@/components/AppHeader.vue'
import { fetchForumDiscussions, fetchForumTags } from '@/api/endpoints'

interface ForumTag { id: number; slug: string; name: string; color: string; description?: string }
interface ForumDiscussionSummary {
  id: number; title: string; slug: string; author: string
  commentCount: number; createdAt: string; lastPostedAt: string
  excerpt: string; tags: ForumTag[]
}

const route = useRoute()
const searchTerm = ref('')
const sortMode = ref<'latest' | 'popular' | 'unanswered'>('latest')
const tags = ref<ForumTag[]>([])
const discussions = ref<ForumDiscussionSummary[]>([])
const loading = ref(false)
const loadError = ref('')

const activeSlug = computed(() => String(route.params.slug || ''))
const activeTag = computed(() => tags.value.find(t => t.slug === activeSlug.value))

const filtered = computed(() => {
  const query = searchTerm.value.trim().toLowerCase()
  let result = discussions.value.filter((item) => {
    if (activeSlug.value && !item.tags.some(t => t.slug === activeSlug.value)) return false
    if (!query) return true
    const tagNames = item.tags.map(t => t.name).join(' ')
    return `${item.title} ${item.excerpt} ${item.author} ${tagNames}`.toLowerCase().includes(query)
  })
  if (sortMode.value === 'unanswered') result = result.filter((item) => item.commentCount <= 1)
  return [...result].sort((a, b) => sortMode.value === 'popular'
    ? b.commentCount - a.commentCount
    : Date.parse(b.lastPostedAt || b.createdAt) - Date.parse(a.lastPostedAt || a.createdAt))
})

function avatarOf(author: string) {
  return (author || '?').slice(0, 2).toUpperCase()
}

function excerpt(body: string) {
  const compact = (body || '').replace(/\n+/g, ' ').trim()
  return compact.length > 96 ? `${compact.slice(0, 96)}...` : compact
}

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    const [tagList, list] = await Promise.all([fetchForumTags(), fetchForumDiscussions(undefined, 50)])
    tags.value = tagList
    discussions.value = list
  } catch (e: any) {
    loadError.value = e?.message || '网络错误'
  } finally {
    loading.value = false
  }
}
onMounted(load)
</script>

<style scoped>
.forum-shell { max-width:1240px; margin:auto; padding:40px 36px 90px; }
.community-tabs { display:flex; flex-wrap:wrap; gap:8px; padding-bottom:22px; border-bottom:1px solid var(--nx-border-subtle); }
.community-tabs a { display:flex; align-items:center; gap:7px; padding:11px 14px; border:1px solid transparent; border-radius:9px; color:var(--nx-text-secondary); }
.community-tabs a:hover,.community-tabs .selected { background:var(--nx-accent-subtle); color:var(--nx-accent); border-color:var(--nx-border-default); }
.community-tabs i { width:6px; height:6px; border-radius:50%; }
.filter-bar { display:flex; gap:16px; justify-content:space-between; margin:24px 0 18px; }
.forum-search { display:flex; align-items:center; gap:12px; padding:0 14px; border:1px solid var(--nx-border-default); border-radius:10px; background:var(--nx-bg-raised); color:var(--nx-text-tertiary); flex:1; max-width:440px; }
.forum-search input { width:100%; min-width:0; height:44px; border:0; background:transparent; color:var(--nx-text-primary); outline:none; }
.forum-search:focus-within { border-color:var(--nx-accent); }
.sort-tabs { display:flex; gap:4px; padding:3px; border-radius:10px; background:var(--nx-bg-inset); }
.sort-tabs button { padding:9px 16px; border:0; border-radius:7px; color:var(--nx-text-tertiary); background:transparent; cursor:pointer; }
.sort-tabs .selected { color:var(--nx-accent); background:var(--nx-bg-active); }
.results-note { display:flex; flex-wrap:wrap; gap:8px; justify-content:space-between; margin-bottom:12px; color:var(--nx-text-tertiary); font-size:11px; }
.discussion-list { border:1px solid var(--nx-border-subtle); border-radius:16px; background:var(--nx-bg-raised); overflow:hidden; }
.discussion-row { display:grid; grid-template-columns:40px minmax(0,1fr) 54px; gap:18px; padding:25px; border-bottom:1px solid var(--nx-border-subtle); transition:background .2s; }
.discussion-row:last-child { border:0; }.discussion-row:hover { background:var(--nx-bg-hover); }
.avatar { width:40px; height:40px; display:grid; place-items:center; border:1px solid var(--nx-border-default); border-radius:12px; background:var(--nx-accent-subtle); color:var(--nx-accent); font-weight:700; }
.discussion-meta { display:flex; flex-wrap:wrap; gap:12px; font-size:11px; color:var(--nx-text-tertiary); }.discussion-meta a { color:var(--nx-accent); }
h2 { margin:10px 0 7px; font-size:16px; line-height:1.5; }a:hover h2 { color:var(--nx-accent); }.discussion-main p { color:var(--nx-text-tertiary); font-size:13px; line-height:1.7; }.reply-count { display:flex; align-items:center; flex-direction:column; gap:4px; color:var(--nx-text-secondary); font-size:12px; }.reply-count small { color:var(--nx-text-tertiary); }
@media(max-width:720px) { .forum-shell { padding:28px 16px 90px; }.filter-bar { flex-direction:column; }.forum-search { max-width:none; }.sort-tabs { align-self:flex-start; }.discussion-row { grid-template-columns:32px minmax(0,1fr); padding:18px 14px; gap:12px; }.avatar { width:32px; height:32px; }.reply-count { display:none; } }
</style>
