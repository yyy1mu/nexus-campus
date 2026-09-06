<template>
  <AppHeader />
  <main class="article-shell">
    <RouterLink class="back-link" to="/forum">← 返回讨论</RouterLink>
    <StatePanel v-if="loading" tone="loading" title="正在加载讨论" />
    <StatePanel v-else-if="loadError" tone="error" title="讨论暂时无法加载" :description="loadError"><button class="btn btn-secondary" @click="load">重新加载</button></StatePanel>
    <template v-else-if="discussion">
      <PageIntro :eyebrow="`COMMUNITY / ${discussion.tags[0]?.name || '讨论'}`" :title="discussion.title" :description="`${discussion.author} 发起 · ${new Date(discussion.createdAt).toLocaleDateString('zh-CN')}`" />
      <article v-for="post in discussion.posts" :key="post.id" class="article-body">
        <div class="post-meta"><span class="avatar">{{ avatarOf(post.author) }}</span><strong>{{ post.author }}</strong><time>{{ new Date(post.createdAt).toLocaleDateString('zh-CN') }}</time><span class="post-number">#{{ post.number }}</span></div>
        <p v-for="(line, index) in linesOf(post.content)" :key="index">{{ line }}</p>
      </article>
      <footer class="article-footer">需要寻找帮助或开展协作？<RouterLink to="/help-requests">前往求助广场 →</RouterLink></footer>
    </template>
    <StatePanel v-else title="未找到这篇讨论" description="内容可能已移除，请返回讨论列表。" />
  </main>
</template>
<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import PageIntro from '@/components/PageIntro.vue'
import StatePanel from '@/components/StatePanel.vue'
import { fetchForumDiscussion } from '@/api/endpoints'

interface ForumPost {
  id: number; number: number; author: string
  content: string; createdAt: string
}
interface ForumDiscussionDetail {
  id: number; title: string; author: string; createdAt: string
  tags: { id: number; slug: string; name: string; color: string }[]
  posts: ForumPost[]
}

const route = useRoute()
const discussion = ref<ForumDiscussionDetail | null>(null)
const loading = ref(false)
const loadError = ref('')

function avatarOf(author: string) {
  return (author || '?').slice(0, 2).toUpperCase()
}
function linesOf(content: string) {
  return (content || '').split('\n').filter(line => line.trim())
}

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    discussion.value = await fetchForumDiscussion(String(route.params.id))
  } catch (e: any) {
    loadError.value = e?.message || '网络错误'
  } finally {
    loading.value = false
  }
}
onMounted(load)
</script>
<style scoped>
.article-shell { max-width:1020px; padding:40px 36px 100px; margin:auto; }.back-link { display:inline-block; margin-bottom:28px; color:var(--nx-text-tertiary); }.article-body { border:1px solid var(--nx-border-subtle); border-radius:18px; padding:32px; background:var(--nx-bg-raised); margin-bottom:16px; }.post-meta { display:flex; flex-wrap:wrap; align-items:center; gap:12px; margin-bottom:30px; font-size:13px; }.post-meta time { color:var(--nx-text-tertiary); }.post-number { margin-left:auto; color:var(--nx-text-tertiary); font:11px var(--nx-font-mono); }.avatar { padding:10px; border-radius:10px; background:var(--nx-accent-subtle); color:var(--nx-accent); }.article-body p { line-height:1.95; margin:14px 0; color:var(--nx-text-secondary); overflow-wrap:anywhere; }.article-footer { margin-top:32px; padding-top:24px; border-top:1px solid var(--nx-border-subtle); color:var(--nx-text-tertiary); font-size:13px; line-height:1.8; }.article-footer a { display:block; color:var(--nx-accent); margin-top:8px; }@media(max-width:720px) { .article-shell { padding:28px 16px 90px; }.article-body { padding:20px; } }
</style>
