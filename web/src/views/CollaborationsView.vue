<template>
  <div class="collab-page">
    <AppHeader />
    <main class="page">
      <PageIntro title="我的协作" eyebrow="WORKSPACE / COLLABORATION" description="从任务到交付，集中跟进每一次共同努力。"><RouterLink class="btn btn-secondary" to="/help-requests">寻找协作机会</RouterLink></PageIntro>
      <StatePanel v-if="!auth.isLoggedIn" title="登录后，继续你的协作" description="所有任务、沟通与交付记录，都在这里。"><button class="btn btn-primary" @click="requestLogin">登录</button></StatePanel>
      <StatePanel v-else-if="loading" tone="loading" title="正在加载协作" />
      <StatePanel v-else-if="error" tone="error" title="协作暂时无法加载" :description="error"><button class="btn btn-secondary" @click="load">重新加载</button></StatePanel>
      <template v-else>
        <section v-if="active.length">
          <h2>进行中</h2>
          <router-link v-for="m in active" :key="m.id" class="card match-card" :to="`/matches/${m.id}/workspace`">
            <div class="match-head">
              <span class="status-tag accepted">协作中</span>
              <span class="role-chip">{{ m.role === 'requester' ? '我是求助方' : '我是帮助方' }}</span>
              <span v-if="m.collaborationState === 'paused'" class="paused-chip">已暂停</span>
              <span v-if="m.batonRole === m.role" class="baton-chip">轮到我方</span>
            </div>
            <h3>{{ m.helpRequestSummary || m.message || `Match #${m.id}` }}</h3>
            <div class="meta">
              <span>对方：user {{ m.role === 'requester' ? m.helperUserId : m.requesterUserId }}</span>
              <span>{{ formatDate(m.acceptedAt || m.createdAt) }}</span>
            </div>
          </router-link>
        </section>

        <section v-if="pending.length">
          <h2>待接受</h2>
          <div v-for="m in pending" :key="m.id" class="card match-card muted-card">
            <div class="match-head">
              <span class="status-tag offered">待接受</span>
              <span class="role-chip">{{ m.role === 'requester' ? '我是求助方' : '我是帮助方' }}</span>
            </div>
            <h3>{{ m.helpRequestSummary || m.message || `Match #${m.id}` }}</h3>
            <p class="hint-line">在「求助广场」中接受匹配后即可打开协作工作台。</p>
          </div>
        </section>

        <section v-if="closed.length">
          <h2>已结束</h2>
          <router-link v-for="m in closed" :key="m.id" class="card match-card muted-card" :to="`/matches/${m.id}/workspace`">
            <div class="match-head">
              <span class="status-tag" :class="m.status">{{ m.status === 'completed' ? '已完成' : statusLabel(m.status) }}</span>
              <span class="role-chip">{{ m.role === 'requester' ? '我是求助方' : '我是帮助方' }}</span>
            </div>
            <h3>{{ m.helpRequestSummary || m.message || `Match #${m.id}` }}</h3>
          </router-link>
        </section>

        <StatePanel v-if="!active.length && !pending.length && !closed.length" title="一次合作，从一个需求开始" description="发布求助或响应他人需求，匹配后即可在这里推进协作。"><RouterLink to="/help-requests" class="btn btn-secondary">浏览求助广场</RouterLink></StatePanel>
      </template>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed, watch, ref } from 'vue'
import AppHeader from '@/components/AppHeader.vue'
import { RouterLink } from 'vue-router'
import PageIntro from '@/components/PageIntro.vue'
import StatePanel from '@/components/StatePanel.vue'
import { requestLogin } from '@/utils/authUi'
import { useAuthStore } from '@/stores/auth'
import { fetchMyMatches } from '@/api/endpoints'

const auth = useAuthStore()
const matches = ref<any[]>([])
const loading = ref(false)
const error = ref('')

const active = computed(() => matches.value.filter(m => m.status === 'accepted'))
const pending = computed(() => matches.value.filter(m => m.status === 'offered'))
const closed = computed(() => matches.value.filter(m => ['completed', 'cancelled', 'declined'].includes(m.status)))

async function load() {
  matches.value = []; error.value = ''
  if (!auth.isLoggedIn) return
  const currentToken = auth.token
  loading.value = true
  try {
    await auth.loadContext()
    const result = await fetchMyMatches()
    if (auth.token === currentToken) matches.value = result
  } catch (exception: any) {
    error.value = exception.response?.data?.errors?.[0]?.message ?? '无法加载协作列表。'
  } finally {
    loading.value = false
  }
}
watch(() => auth.token, load, { immediate: true })

function statusLabel(status: string) {
  return ({ cancelled: '已取消', declined: '已婉拒' } as Record<string, string>)[status] ?? status
}
function formatDate(value: string) {
  if (!value) return ''
  return new Date(value).toLocaleDateString('zh-CN')
}
</script>

<style scoped>
.collab-page { min-height: 100vh; background: transparent; }
.page { max-width: 1100px; margin: 0 auto; padding: 40px 36px 90px; }
header { margin-bottom: var(--nx-space-5); }
h1 { color: var(--nx-text-primary); font-size: var(--nx-fs-28); font-weight: 800; letter-spacing: -0.02em; }
.sub { margin-top: 6px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-13); }
section { margin-bottom: var(--nx-space-5); }
section h2 { color: var(--nx-text-secondary); font-size: var(--nx-fs-14); font-weight: 700; margin-bottom: var(--nx-space-3); }
.match-card { display: block; margin-bottom: var(--nx-space-3); cursor: pointer; transition: border-color var(--nx-duration-fast) var(--nx-ease-out), background-color var(--nx-duration-fast) var(--nx-ease-out); }
.match-card:hover { border-color: var(--nx-border-strong); background: var(--nx-bg-hover); }
.match-card h3 { color: var(--nx-text-primary); font-size: var(--nx-fs-15); font-weight: 700; margin-top: var(--nx-space-2); line-height: 1.4; }
.muted-card h3 { color: var(--nx-text-secondary); }
.match-head { display: flex; align-items: center; gap: var(--nx-space-2); flex-wrap: wrap; }
.role-chip { padding: 2px 9px; border-radius: 999px; background: var(--nx-bg-inset); color: var(--nx-text-secondary); font-size: var(--nx-fs-11); }
.paused-chip { padding: 2px 9px; border-radius: 999px; background: var(--nx-danger-bg); color: var(--nx-danger); font-size: var(--nx-fs-11); font-weight: 700; }
.baton-chip { padding: 2px 9px; border-radius: 999px; background: var(--nx-accent); color: var(--nx-on-accent); font-size: var(--nx-fs-11); font-weight: 700; }
.meta { display: flex; gap: var(--nx-space-3); margin-top: var(--nx-space-2); color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); }
.hint-line { margin-top: var(--nx-space-2); color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); }
@media (max-width: 720px) { .collab-page { padding-bottom: 68px; } .page { padding: 28px 16px 40px; } }
</style>
