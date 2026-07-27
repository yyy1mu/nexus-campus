<template>
  <div class="help-page">
    <AppHeader />
    <main class="page">
    <header>
      <h1>求助广场</h1>
      <button v-if="auth.isLoggedIn" @click="showForm = !showForm" class="btn btn-primary">
        {{ showForm ? '取消' : '发布求助' }}
      </button>
    </header>

    <!-- Create Form -->
    <section v-if="showForm" class="card">
      <h2>发布求助</h2>
      <form @submit.prevent="submitRequest">
        <input v-model="form.title" placeholder="标题 *" class="input" required />
        <textarea v-model="form.summary" placeholder="简要描述 *" class="input textarea" rows="3" required />
        <textarea v-model="form.content" placeholder="详细内容" class="input textarea" rows="4" />
        <div class="row">
          <input v-model="form.categoryLabel" placeholder="分类标签" class="input" />
          <select v-model="form.urgency" class="input">
            <option value="normal">普通</option>
            <option value="urgent">紧急</option>
            <option value="relaxed">不急</option>
          </select>
        </div>
        <input v-model="form.locationHint" placeholder="大致地点（如：图书馆一楼）" class="input" />
        <label class="checkbox"><input type="checkbox" v-model="confirmed" /> 我确认发布此求助信息</label>
        <button type="submit" class="btn btn-primary" :disabled="!confirmed || submitting">
          {{ submitting ? '发布中...' : '发布求助' }}
        </button>
        <p v-if="error" class="error">{{ error }}</p>
      </form>
    </section>

    <!-- Filters -->
    <div class="filters">
      <button v-for="s in statuses" :key="s.value" @click="filter = s.value"
        :class="['btn btn-sm', filter === s.value ? 'btn-primary' : 'btn-secondary']">
        {{ s.label }}
      </button>
    </div>

    <!-- List -->
    <div v-if="help.loading" class="loading">加载中...</div>
    <div v-else-if="!filteredRequests.length" class="empty">暂无求助</div>
    <div v-for="req in filteredRequests" :key="req.id" class="card request-card" @click="select(req)">
      <div class="req-header">
        <span class="status-tag" :class="req.status">{{ req.status }}</span>
        <span class="urgency" v-if="req.urgency !== 'normal'">{{ req.urgency }}</span>
      </div>
      <h3>{{ req.summary || req.categoryLabel || '(无标题)' }}</h3>
      <p v-if="req.summary" class="detail">{{ req.summary }}</p>
      <div class="meta">
        <span v-if="req.locationHint">📍 {{ req.locationHint }}</span>
        <span>{{ formatDate(req.createdAt) }}</span>
      </div>

      <!-- Expanded detail -->
      <div v-if="selected?.id === req.id" class="detail-section" @click.stop>
        <h4>详情</h4>
        <p><strong>状态：</strong>{{ req.status }}</p>
        <p><strong>分类：</strong>{{ req.categoryLabel }}</p>
        <p><strong>标签：</strong>{{ (req.neededLabels ?? []).join(', ') }}</p>
        <p><strong>地点：</strong>{{ req.locationHint || '未指定' }}</p>
        <p><strong>会面安全：</strong>{{ req.meetingSafetyState }}</p>
        <p><strong>创建者：</strong>{{ req.requesterUserId }}</p>

        <!-- Next Actions -->
        <div v-if="req.nextActions?.length" class="actions">
          <button v-for="act in req.nextActions" :key="act.name" class="btn btn-sm btn-secondary" @click="handleAction(req, act)">
            {{ act.name }}
          </button>
        </div>

        <!-- Dispatches -->
        <div v-if="dispatchStore.dispatches[req.id]?.length" class="sub-section">
          <h5>派单</h5>
          <div v-for="d in dispatchStore.dispatches[req.id]" :key="d.id" class="sub-item">
            <span class="status-tag" :class="d.status">{{ d.status }}</span>
            <span>→ helper {{ d.helperUserId }}</span>
            <span v-if="d.viewerRole">👁 {{ d.viewerRole }}</span>
            <div v-if="d.nextActions?.length" class="actions" style="margin-top:8px">
              <button v-for="act in d.nextActions" :key="act.name" class="btn btn-sm btn-secondary" @click="handleDispatchAction(d, act, req.id)">
                {{ act.name }}
              </button>
            </div>
          </div>
        </div>

        <!-- Matches -->
        <div v-if="dispatchStore.matches[req.id]?.length" class="sub-section">
          <h5>匹配</h5>
          <div v-for="m in dispatchStore.matches[req.id]" :key="m.id" class="sub-item">
            <span class="status-tag" :class="m.status">{{ m.status }}</span>
            <span>helper {{ m.helperUserId }}</span>
            <span v-if="m.meetingHint">📍 {{ m.meetingHint }}</span>
            <div v-if="m.nextActions?.length" class="actions" style="margin-top:8px">
              <button v-for="act in m.nextActions" :key="act.name" class="btn btn-sm btn-secondary" @click="handleMatchAction(m, act, req.id)">
                {{ act.name }}
              </button>
            </div>
            <!-- Messages -->
            <div v-if="m.status === 'accepted' && dispatchStore.messages[m.id]?.length" class="messages">
              <div v-for="msg in dispatchStore.messages[m.id]" :key="msg.id" class="msg">
                <strong>[user {{ msg.userId }}]</strong> {{ msg.content }}
              </div>
            </div>
            <router-link v-if="m.status === 'accepted'" class="btn btn-sm btn-primary" :to="`/matches/${m.id}/workspace`">
              协作工作台
            </router-link>
            <button v-if="m.status === 'accepted'" class="btn btn-sm btn-secondary" @click="dispatchStore.loadMessages(m.id)">
              查看私信
            </button>
            <button v-if="m.status === 'accepted'" class="btn btn-sm btn-secondary" @click="toggleMemoryPanel(String(m.id))">
              协作上下文
            </button>
            <div v-if="memoryPanelMatchId === String(m.id)" class="memory-share-panel">
              <h6>已共享记忆</h6>
              <p v-if="!matchShares.length" class="muted">双方尚未共享长期记忆。</p>
              <div v-for="share in matchShares" :key="share.id" class="shared-memory">
                <div>
                  <strong>{{ share.title }}</strong>
                  <span>user {{ share.ownerUserId }} · {{ share.kind }}</span>
                  <p>{{ share.content }}</p>
                </div>
                <button
                  v-if="share.ownerUserId === auth.context?.userId"
                  class="icon-action"
                  type="button"
                  title="撤销共享"
                  @click="revokeShare(String(m.id), String(share.id))"
                >
                  撤销
                </button>
              </div>

              <h6>选择我的可共享记忆</h6>
              <p v-if="!shareableMemories.length" class="muted">
                请先在“记忆”页面把共享策略设为“每次由用户明确确认”。
              </p>
              <label v-for="memory in shareableMemories" :key="memory.id" class="memory-option">
                <input v-model="selectedMemoryIds" type="checkbox" :value="memory.id" />
                <span><strong>{{ memory.title }}</strong>{{ memory.content }}</span>
              </label>
              <p v-if="memoryShareError" class="error">{{ memoryShareError }}</p>
              <button
                v-if="shareableMemories.length"
                class="btn btn-sm btn-primary"
                type="button"
                :disabled="!selectedMemoryIds.length"
                @click="shareSelected(String(m.id))"
              >
                确认共享所选快照
              </button>
            </div>
          </div>
        </div>

        <!-- Reply form for accepted match messages -->
        <div v-if="activeMatchId" class="msg-form">
          <textarea v-model="msgText" class="input textarea" rows="2" placeholder="发送私信..." />
          <button @click="sendMsg(activeMatchId)" class="btn btn-sm btn-primary">发送</button>
        </div>
      </div>
    </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import AppHeader from '@/components/AppHeader.vue'
import { useAuthStore } from '@/stores/auth'
import { useHelpStore, useDispatchStore } from '@/stores/help'
import {
  fetchMatchMemoryShares,
  fetchMemories,
  revokeMatchMemoryShare,
  shareMatchMemories,
} from '@/api/endpoints'

const auth = useAuthStore()
const help = useHelpStore()
const dispatchStore = useDispatchStore()

const showForm = ref(false)
const confirmed = ref(false)
const submitting = ref(false)
const error = ref('')
const filter = ref('')
const selected = ref<any>(null)
const msgText = ref('')
const activeMatchId = ref<string | null>(null)
const memoryPanelMatchId = ref<string | null>(null)
const shareableMemories = ref<any[]>([])
const matchShares = ref<any[]>([])
const selectedMemoryIds = ref<number[]>([])
const memoryShareError = ref('')

const statuses = [
  { label: '全部', value: '' },
  { label: '开放', value: 'open' },
  { label: '匹配中', value: 'matching' },
  { label: '已匹配', value: 'matched' },
  { label: '已关闭', value: 'closed' },
  { label: '已取消', value: 'cancelled' },
]

const form = ref({
  title: '', summary: '', content: '', categoryLabel: '', urgency: 'normal', locationHint: '',
  meetingSafetyState: 'not_arranged', userConfirmed: true,
})

const filteredRequests = computed(() => {
  if (!filter.value) return help.requests
  return help.requests.filter(r => r.status === filter.value)
})

watch(filter, (val) => help.loadRequests(val || undefined), { immediate: true })
onMounted(() => auth.loadContext())

async function submitRequest() {
  submitting.value = true
  error.value = ''
  try {
    await help.create({ ...form.value, userConfirmed: true })
    showForm.value = false
    form.value = { title: '', summary: '', content: '', categoryLabel: '', urgency: 'normal', locationHint: '', meetingSafetyState: 'not_arranged', userConfirmed: true }
    confirmed.value = false
  } catch (e: any) {
    error.value = e.response?.data?.errors?.[0]?.detail || '创建失败'
  } finally { submitting.value = false }
}

async function select(req: any) {
  selected.value = req
  await dispatchStore.loadDispatches(String(req.id))
  await dispatchStore.loadMatches(String(req.id))
}

async function handleAction(req: any, action: any) {
  if (action.name === 'offer_match') {
    const m = await dispatchStore.createM(String(req.id), {
      message: prompt('输入帮助信息：') || '我来帮你！',
      meetingSafetyState: 'public_place_suggested',
      userConfirmed: true,
    })
    if (m.status === 'accepted') {
      activeMatchId.value = String(m.id)
      dispatchStore.loadMessages(String(m.id))
    }
  }
}

async function handleDispatchAction(d: any, action: any, helpRequestId: string) {
  if (action.name === 'accept_dispatch') {
    await dispatchStore.updateD(String(d.id), helpRequestId, { status: 'accepted', userConfirmed: true })
  } else if (action.name === 'decline_dispatch') {
    await dispatchStore.updateD(String(d.id), helpRequestId, { status: 'declined', userConfirmed: true })
  }
  dispatchStore.loadDispatches(helpRequestId)
  dispatchStore.loadMatches(helpRequestId)
}

async function handleMatchAction(m: any, action: any, helpRequestId: string) {
  if (action.name === 'accept_match') {
    await dispatchStore.updateM(String(m.id), helpRequestId, { status: 'accepted', userConfirmed: true })
    activeMatchId.value = String(m.id)
    dispatchStore.loadMessages(String(m.id))
  } else if (action.name === 'decline_match') {
    await dispatchStore.updateM(String(m.id), helpRequestId, { status: 'declined', userConfirmed: true })
  } else if (action.name === 'complete_match') {
    await dispatchStore.updateM(String(m.id), helpRequestId, { status: 'completed', userConfirmed: true })
  } else if (action.name === 'list_messages') {
    activeMatchId.value = String(m.id)
    dispatchStore.loadMessages(String(m.id))
  }
  dispatchStore.loadMatches(helpRequestId)
}

async function sendMsg(matchId: string) {
  if (!msgText.value.trim()) return
  await dispatchStore.sendM(matchId, msgText.value.trim())
  msgText.value = ''
}

async function toggleMemoryPanel(matchId: string) {
  if (memoryPanelMatchId.value === matchId) {
    memoryPanelMatchId.value = null
    return
  }
  memoryPanelMatchId.value = matchId
  selectedMemoryIds.value = []
  memoryShareError.value = ''
  try {
    const [memories, shares] = await Promise.all([
      fetchMemories({ status: 'active', limit: 50 }),
      fetchMatchMemoryShares(matchId),
    ])
    shareableMemories.value = memories.filter(
      (memory: any) => memory.sharePolicy === 'ask_each_time' && memory.sensitivity !== 'restricted',
    )
    matchShares.value = shares
  } catch (exception: any) {
    memoryShareError.value = exception.response?.data?.errors?.[0]?.message ?? '无法读取协作上下文。'
  }
}

async function shareSelected(matchId: string) {
  memoryShareError.value = ''
  try {
    matchShares.value = await shareMatchMemories(matchId, selectedMemoryIds.value)
    selectedMemoryIds.value = []
  } catch (exception: any) {
    memoryShareError.value = exception.response?.data?.errors?.[0]?.message ?? '共享失败。'
  }
}

async function revokeShare(matchId: string, shareId: string) {
  memoryShareError.value = ''
  try {
    await revokeMatchMemoryShare(matchId, shareId)
    matchShares.value = await fetchMatchMemoryShares(matchId)
  } catch (exception: any) {
    memoryShareError.value = exception.response?.data?.errors?.[0]?.message ?? '撤销失败。'
  }
}

function formatDate(d: string) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('zh-CN')
}
</script>

<style scoped>
/* 按钮、输入框、卡片、状态标签、加载/空/错误等复用 styles/components.css 全局样式 */
.help-page { min-height: 100vh; background: transparent; }
.page { max-width: 900px; margin: 0 auto; padding: 28px 20px 72px; }
header { display: flex; justify-content: space-between; align-items: center; margin-bottom: var(--nx-space-5); }
h1 { color: var(--nx-text-primary); font-size: var(--nx-fs-28); font-weight: 800; letter-spacing: -0.02em; }
/* 卡片间距与可点击请求卡（基础外观来自全局 .card） */
.card { margin-bottom: var(--nx-space-3); }
.card h2 { color: var(--nx-text-primary); font-size: var(--nx-fs-18); font-weight: 700; margin-bottom: var(--nx-space-4); }
.request-card { cursor: pointer; transition: border-color var(--nx-duration-fast) var(--nx-ease-out), background-color var(--nx-duration-fast) var(--nx-ease-out); }
.request-card:hover { border-color: var(--nx-border-strong); background: var(--nx-bg-hover); }
.request-card h3 { color: var(--nx-text-primary); font-size: var(--nx-fs-16); font-weight: 700; margin: var(--nx-space-2) 0 4px; }
.detail { color: var(--nx-text-tertiary); font-size: var(--nx-fs-14); margin: 0 0 var(--nx-space-2); }
.meta { font-size: var(--nx-fs-12); color: var(--nx-text-tertiary); display: flex; gap: var(--nx-space-3); }
/* 表单间距（输入框外观来自全局 .input） */
form .input { margin-bottom: 10px; }
.row { display: flex; gap: 10px; }
.row .input { flex: 1; }
.checkbox { margin-bottom: var(--nx-space-3); }
/* 状态筛选 */
.filters { display: flex; gap: var(--nx-space-2); margin-bottom: var(--nx-space-4); flex-wrap: wrap; }
.urgency { margin-left: var(--nx-space-2); font-size: var(--nx-fs-11); color: var(--nx-danger); font-weight: 700; }
/* 展开详情 */
.detail-section { margin-top: var(--nx-space-4); padding-top: var(--nx-space-4); border-top: 1px solid var(--nx-border-subtle); cursor: default; }
.detail-section h4 { color: var(--nx-text-primary); font-size: var(--nx-fs-16); margin-bottom: 10px; }
.detail-section p { color: var(--nx-text-secondary); font-size: var(--nx-fs-14); margin: 4px 0; }
.detail-section p strong { color: var(--nx-text-tertiary); }
.actions { display: flex; gap: var(--nx-space-2); flex-wrap: wrap; margin-top: var(--nx-space-3); }
.sub-section { margin-top: 14px; }
.sub-section h5 { color: var(--nx-text-secondary); font-size: var(--nx-fs-14); margin-bottom: var(--nx-space-2); }
.sub-item { padding: 10px; background: var(--nx-bg-inset); border: 1px solid var(--nx-border-subtle); border-radius: var(--nx-radius-lg); margin-bottom: var(--nx-space-2); font-size: var(--nx-fs-14); display: flex; flex-wrap: wrap; gap: var(--nx-space-2); align-items: center; color: var(--nx-text-secondary); }
.messages { margin-top: 10px; width: 100%; }
.msg { padding: 6px 0; font-size: var(--nx-fs-13); border-bottom: 1px solid var(--nx-border-subtle); color: var(--nx-text-secondary); }
.msg strong { color: var(--nx-accent); }
.msg-form { margin-top: var(--nx-space-2); display: flex; gap: var(--nx-space-2); }
.msg-form .input { flex: 1; margin-bottom: 0; }
/* 记忆共享面板 */
.memory-share-panel { width: 100%; margin-top: 10px; padding: var(--nx-space-3); border: 1px solid var(--nx-border-default); border-radius: var(--nx-radius-md); background: var(--nx-bg-overlay); }
.memory-share-panel h6 { margin: 4px 0 var(--nx-space-2); font-size: var(--nx-fs-12); color: var(--nx-text-secondary); }
.memory-share-panel h6:not(:first-child) { margin-top: 14px; padding-top: 12px; border-top: 1px solid var(--nx-border-subtle); }
.shared-memory { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--nx-space-3); padding: var(--nx-space-2) 0; border-bottom: 1px solid var(--nx-border-subtle); }
.shared-memory strong { display: block; font-size: var(--nx-fs-12); color: var(--nx-text-primary); }
.shared-memory span { display: block; margin-top: 2px; color: var(--nx-text-tertiary); font-size: 10px; }
.shared-memory p { margin-top: 4px; color: var(--nx-text-secondary); font-size: var(--nx-fs-12); line-height: 1.45; }
.icon-action { border: 0; color: var(--nx-danger); background: transparent; cursor: pointer; font-size: var(--nx-fs-11); }
.icon-action:hover { text-decoration: underline; }
.memory-option { display: flex; align-items: flex-start; gap: var(--nx-space-2); padding: 7px 0; cursor: pointer; }
.memory-option input { margin-top: 3px; }
.memory-option span { color: var(--nx-text-secondary); font-size: var(--nx-fs-11); line-height: 1.4; }
.memory-option strong { display: block; color: var(--nx-text-primary); font-size: var(--nx-fs-12); }
.muted { color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); }
@media (max-width: 720px) { .help-page { padding-bottom: 68px; } .page { padding: 20px 12px 40px; } }
</style>
