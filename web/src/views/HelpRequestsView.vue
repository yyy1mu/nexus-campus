<template>
  <div class="page">
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
            <button v-if="m.status === 'accepted'" class="btn btn-sm btn-secondary" @click="dispatchStore.loadMessages(m.id)">
              查看私信
            </button>
          </div>
        </div>

        <!-- Reply form for accepted match messages -->
        <div v-if="activeMatchId" class="msg-form">
          <textarea v-model="msgText" class="input textarea" rows="2" placeholder="发送私信..." />
          <button @click="sendMsg(activeMatchId)" class="btn btn-sm btn-primary">发送</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useHelpStore, useDispatchStore } from '@/stores/help'

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

function formatDate(d: string) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('zh-CN')
}
</script>

<style scoped>
.page { max-width: 800px; margin: 0 auto; padding: 20px; }
header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
h1 { font-size: 1.5rem; }
.card { background: #fff; border-radius: 10px; padding: 20px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,.06); cursor: pointer; transition: box-shadow .2s; }
.card:hover { box-shadow: 0 2px 8px rgba(0,0,0,.1); }
.request-card h3 { font-size: 1rem; margin: 8px 0 4px; }
.detail { color: #6b7280; font-size: 14px; margin: 0 0 8px; }
.meta { font-size: 12px; color: #9ca3af; display: flex; gap: 12px; }
.input { display: block; width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 8px; margin-bottom: 10px; font-size: 14px; }
.textarea { resize: vertical; }
.row { display: flex; gap: 10px; }
.row .input { flex: 1; }
.checkbox { font-size: 14px; margin-bottom: 12px; display: block; }
.btn { display: inline-block; padding: 8px 16px; border-radius: 8px; border: none; cursor: pointer; font-size: 14px; font-weight: 600; }
.btn-sm { padding: 6px 12px; font-size: 13px; }
.btn-primary { background: #3b82f6; color: #fff; }
.btn-secondary { background: #f3f4f6; color: #374151; }
.error { color: #ef4444; font-size: 14px; }
.filters { display: flex; gap: 8px; margin-bottom: 16px; flex-wrap: wrap; }
.status-tag { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; }
.status-tag.open { background: #dbeafe; color: #1d4ed8; }
.status-tag.matching { background: #fef3c7; color: #b45309; }
.status-tag.matched { background: #dcfce7; color: #15803d; }
.status-tag.closed, .status-tag.cancelled { background: #f3f4f6; color: #6b7280; }
.status-tag.accepted { background: #dcfce7; color: #15803d; }
.status-tag.declined { background: #fee2e2; color: #b91c1c; }
.status-tag.pending { background: #fef3c7; color: #b45309; }
.status-tag.offered { background: #ede9fe; color: #6d28d9; }
.status-tag.completed { background: #ccfbf1; color: #0f766e; }
.urgency { margin-left: 8px; font-size: 11px; color: #ef4444; }
.detail-section { margin-top: 16px; padding-top: 16px; border-top: 1px solid #f3f4f6; cursor: default; }
.detail-section h4 { font-size: 1rem; margin-bottom: 10px; }
.detail-section p { font-size: 14px; margin: 4px 0; }
.actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 12px; }
.sub-section { margin-top: 14px; }
.sub-section h5 { font-size: .9rem; margin-bottom: 8px; }
.sub-item { padding: 10px; background: #f9fafb; border-radius: 8px; margin-bottom: 8px; font-size: 14px; display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.messages { margin-top: 10px; }
.msg { padding: 6px 0; font-size: 13px; border-bottom: 1px solid #f3f4f6; }
.msg-form { margin-top: 8px; display: flex; gap: 8px; }
.msg-form .input { flex: 1; margin-bottom: 0; }
.loading, .empty { text-align: center; color: #9ca3af; padding: 40px 0; }
</style>
