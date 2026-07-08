<template>
  <div class="page">
    <header>
      <h1>校园论坛</h1>
      <button v-if="auth.isLoggedIn" @click="showForm = !showForm" class="btn btn-primary">
        {{ showForm ? '取消' : '发帖' }}
      </button>
    </header>

    <!-- Create Form -->
    <section v-if="showForm" class="card">
      <h2>新建讨论</h2>
      <form @submit.prevent="createDiscussion">
        <input v-model="newTitle" placeholder="标题 *" class="input" required />
        <textarea v-model="newContent" placeholder="内容 *" class="input textarea" rows="5" required />
        <button type="submit" class="btn btn-primary" :disabled="posting">
          {{ posting ? '发布中...' : '发布讨论' }}
        </button>
      </form>
    </section>

    <!-- List -->
    <div v-if="loading" class="loading">加载中...</div>
    <div v-else-if="!discussions.length" class="empty">暂无讨论</div>
    <div v-for="d in discussions" :key="d.id" class="card discussion-card" @click="select(d)">
      <h3>{{ d.title }}</h3>
      <div class="meta">
        <span>💬 {{ d.commentCount }}</span>
        <span>{{ formatDate(d.createdAt) }}</span>
        <span v-if="d.lastPostedAt">最后回复 {{ formatDate(d.lastPostedAt) }}</span>
      </div>

      <!-- Detail -->
      <div v-if="selected?.id === d.id" class="detail-section" @click.stop>
        <h4>帖子</h4>
        <div v-for="p in d.posts" :key="p.id" class="post-item">
          <p>{{ p.content }}</p>
          <span class="meta">{{ formatDate(p.createdAt) }}</span>
        </div>
        <!-- Reply -->
        <div v-if="auth.isLoggedIn" class="reply-form">
          <textarea v-model="replyText" class="input textarea" rows="3" placeholder="回复..." />
          <button @click="reply(d.id)" class="btn btn-primary btn-sm">回复</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { fetchForumDiscussions, createForumDiscussion, replyForum } from '@/api/endpoints'

const auth = useAuthStore()
const discussions = ref<any[]>([])
const selected = ref<any>(null)
const showForm = ref(false)
const newTitle = ref('')
const newContent = ref('')
const replyText = ref('')
const loading = ref(false)
const posting = ref(false)

onMounted(async () => { await load() })

async function load() {
  loading.value = true
  try { discussions.value = await fetchForumDiscussions() }
  finally { loading.value = false }
}

async function createDiscussion() {
  posting.value = true
  try {
    await createForumDiscussion({ title: newTitle.value, content: newContent.value, userConfirmed: true })
    showForm.value = false
    newTitle.value = ''
    newContent.value = ''
    await load()
  } finally { posting.value = false }
}

async function select(d: any) {
  selected.value = d
  // In a real app, you'd fetch full detail with posts
  const { data } = await fetch(`/api/nexus/forum/discussions/${d.id}`).then(r => r.json())
  if (data) {
    d.posts = data.attributes?.posts ?? []
  }
}

async function reply(discId: string) {
  if (!replyText.value.trim()) return
  await replyForum(discId, replyText.value.trim())
  replyText.value = ''
  if (selected.value?.id === discId) await select(selected.value)
}

function formatDate(d: string) {
  return d ? new Date(d).toLocaleDateString('zh-CN') : ''
}
</script>

<style scoped>
.page { max-width: 800px; margin: 0 auto; padding: 20px; }
header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
h1 { font-size: 1.5rem; }
.card { background: #fff; border-radius: 10px; padding: 20px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,.06); }
.discussion-card { cursor: pointer; transition: box-shadow .2s; }
.discussion-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,.1); }
h3 { font-size: 1rem; margin-bottom: 8px; }
.meta { font-size: 12px; color: #9ca3af; display: flex; gap: 12px; }
.input { display: block; width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 8px; margin-bottom: 10px; font-size: 14px; }
.textarea { resize: vertical; }
.btn { display: inline-block; padding: 8px 16px; border-radius: 8px; border: none; cursor: pointer; font-size: 14px; font-weight: 600; }
.btn-sm { padding: 6px 12px; font-size: 13px; }
.btn-primary { background: #3b82f6; color: #fff; }
.detail-section { margin-top: 16px; padding-top: 16px; border-top: 1px solid #f3f4f6; cursor: default; }
.detail-section h4 { font-size: 1rem; margin-bottom: 10px; }
.post-item { padding: 10px 0; border-bottom: 1px solid #f3f4f6; }
.post-item p { font-size: 14px; white-space: pre-wrap; }
.reply-form { display: flex; gap: 8px; margin-top: 12px; align-items: flex-end; }
.reply-form .textarea { flex: 1; }
.loading, .empty { text-align: center; color: #9ca3af; padding: 40px 0; }
</style>
