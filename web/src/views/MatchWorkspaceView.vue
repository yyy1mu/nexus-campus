<template>
  <div class="workspace-page">
    <AppHeader />
    <main class="page">
      <div v-if="loading" class="loading">加载协作工作台...</div>
      <div v-else-if="loadError" class="state error">{{ loadError }}</div>
      <template v-else-if="ws">
        <!-- 头部：进度与控制 -->
        <header class="ws-header card">
          <div class="ws-title">
            <router-link class="back-link" to="/collaborations">← 我的协作</router-link>
            <h1>{{ ws.helpRequestSummary || `求助 #${ws.helpRequestId}` }}</h1>
            <div class="ws-meta">
              <span class="status-tag" :class="ws.matchStatus">{{ statusLabel(ws.matchStatus) }}</span>
              <span class="role-chip">{{ ws.viewerRole === 'requester' ? '我是求助方' : '我是帮助方' }}</span>
              <span v-if="ws.collaborationState === 'paused'" class="paused-chip">已暂停</span>
              <span v-if="ws.batonRole && ws.matchStatus === 'accepted'" class="baton-chip" :class="{ mine: batonWithMe }">
                {{ batonWithMe ? '轮到我方推进' : '等待对方推进' }}
              </span>
            </div>
          </div>
          <div class="ws-progress">
            <div class="progress-line">
              <span>任务 {{ ws.progress.tasksDone }}/{{ ws.progress.tasksTotal }}</span>
              <span v-if="ws.progress.deliverableAccepted" class="ok">交付已验收</span>
            </div>
            <div class="progress-bar">
              <div class="progress-fill" :style="{ width: progressPercent + '%' }" />
            </div>
          </div>
          <div v-if="ws.matchStatus === 'accepted'" class="ws-controls">
            <button class="btn btn-sm btn-secondary" @click="togglePause">
              {{ ws.collaborationState === 'paused' ? '恢复协作' : '暂停协作' }}
            </button>
            <button class="btn btn-sm btn-secondary" @click="toggleBaton">
              {{ batonWithCounterpart ? '接管接力棒' : '移交给对方' }}
            </button>
            <button
              v-if="ws.viewerRole === 'requester'"
              class="btn btn-sm btn-primary"
              :disabled="hasPendingDeliverable || hasOpenDecision"
              :title="completeBlockReason"
              @click="completeMatch"
            >
              确认完成
            </button>
            <span v-else class="hint control-hint">协作完成由求助方确认</span>
          </div>
          <p v-if="actionError" class="error">{{ actionError }}</p>
          <p v-if="ws.collaborationState === 'paused'" class="hint pause-hint">
            协作已暂停：双方 Agent 无法新增任务、决策或交付物，但你仍可处理决策、验收交付或恢复协作。
          </p>
        </header>

        <div class="ws-grid">
          <div class="ws-col">
            <!-- 待我处理的决策：置顶高亮 -->
            <section v-if="myOpenDecisions.length" class="card decisions-card attention">
              <h2>待你决策 <span class="count-badge">{{ myOpenDecisions.length }}</span></h2>
              <div v-for="d in myOpenDecisions" :key="d.id" class="decision">
                <h3>{{ d.title }}</h3>
                <p v-if="d.context" class="decision-context">{{ d.context }}</p>
                <label v-for="opt in d.options" :key="opt.key" class="decision-option">
                  <input type="radio" :name="'decision-' + d.id" :value="opt.key" v-model="decisionChoice[d.id]" />
                  <span>
                    <strong>{{ opt.label }}</strong>
                    <em v-if="opt.note">{{ opt.note }}</em>
                  </span>
                </label>
                <div class="decision-actions">
                  <input v-model="decisionNote[d.id]" class="input" placeholder="备注（可选）" />
                  <button class="btn btn-sm btn-primary" :disabled="!decisionChoice[d.id] || busy" @click="decide(d)">
                    确认选择
                  </button>
                </div>
              </div>
            </section>

            <!-- 等待对方的决策 -->
            <section v-if="theirOpenDecisions.length" class="card">
              <h2>等待对方决策</h2>
              <div v-for="d in theirOpenDecisions" :key="d.id" class="waiting-item">
                <span class="dot" /> {{ d.title }}
              </div>
            </section>

            <!-- 交付物 -->
            <section class="card">
              <h2>交付物</h2>
              <p v-if="!visibleDeliverables.length" class="muted">尚未提交交付物。帮助方 Agent 会在双方确认方案后提交。</p>
              <div v-for="d in visibleDeliverables" :key="d.id" class="deliverable">
                <div class="deliverable-head">
                  <span class="status-tag" :class="deliverableClass(d.status)">{{ deliverableLabel(d.status) }}</span>
                  <strong>{{ d.title }}</strong>
                </div>
                <p v-if="d.description" class="deliverable-desc">{{ d.description }}</p>
                <div class="deliverable-meta">
                  <span v-if="d.accessHint">获取方式：{{ d.accessHint }}</span>
                  <span v-if="d.checksum" class="mono">校验和：{{ d.checksum }}</span>
                  <span v-if="d.licenseNote">许可：{{ d.licenseNote }}</span>
                </div>
                <p v-if="d.reviewNote" class="review-note">验收备注：{{ d.reviewNote }}</p>
                <div v-if="d.status === 'submitted' && d.submitterRole !== ws.viewerRole" class="deliverable-actions">
                  <button class="btn btn-sm btn-primary" :disabled="busy" @click="review(d, 'accept')">验收通过</button>
                  <button class="btn btn-sm btn-secondary" :disabled="busy" @click="review(d, 'reject')">退回</button>
                </div>
                <p v-else-if="d.status === 'submitted'" class="muted">等待对方验收。</p>
              </div>
            </section>

            <!-- 任务清单 -->
            <section class="card">
              <h2>任务清单</h2>
              <p v-if="!ws.tasks.length" class="muted">双方 Agent 还没有拆分任务。</p>
              <div v-for="t in ws.tasks" :key="t.id" class="task" :class="{ done: t.status === 'done' }">
                <div class="task-main">
                  <span class="task-status" :class="t.status">{{ taskLabel(t.status) }}</span>
                  <span class="task-title">{{ t.title }}</span>
                  <span class="task-owner">{{ t.ownerRole === ws.viewerRole ? '我方' : '对方' }}</span>
                </div>
                <p v-if="t.note" class="task-note">{{ t.note }}</p>
                <p v-if="t.blockedReason" class="task-blocked">受阻：{{ t.blockedReason }}</p>
                <div v-if="ws.matchStatus === 'accepted' && ws.collaborationState === 'active'" class="task-actions">
                  <template v-if="t.ownerRole === ws.viewerRole">
                    <button v-if="t.status === 'todo'" class="btn-link" @click="setTask(t, 'doing')">开始</button>
                    <button v-if="t.status === 'doing'" class="btn-link" @click="setTask(t, 'done')">完成</button>
                    <button v-if="t.status === 'blocked'" class="btn-link" @click="setTask(t, 'doing')">恢复</button>
                    <button v-if="t.status !== 'done' && t.status !== 'blocked'" class="btn-link danger" @click="blockTask(t)">受阻</button>
                  </template>
                  <button v-else-if="t.status !== 'done'" class="btn-link" @click="takeOverTask(t)">移交给我方</button>
                </div>
              </div>
              <form
                v-if="ws.matchStatus === 'accepted' && ws.collaborationState === 'active' && !batonWithCounterpart"
                class="task-form" @submit.prevent="addTask"
              >
                <input v-model="newTaskTitle" class="input" placeholder="添加任务（人工干预或补充计划）" maxlength="160" />
                <select v-model="newTaskOwner" class="input owner-select">
                  <option :value="ws.viewerRole">我方</option>
                  <option :value="counterpartRole">对方</option>
                </select>
                <button class="btn btn-sm btn-secondary" type="submit" :disabled="!newTaskTitle.trim() || busy">添加</button>
              </form>
              <p v-else-if="ws.matchStatus === 'accepted' && ws.collaborationState === 'active' && batonWithCounterpart" class="muted baton-hint">
                接力棒在对方手中，新增任务前请先点击上方“接管接力棒”。
              </p>
            </section>
          </div>

          <div class="ws-col">
            <!-- 私信 -->
            <section class="card messages-card">
              <h2>协作消息</h2>
              <div ref="msgListEl" class="msg-list">
                <p v-if="!messages.length" class="muted">还没有消息。双方 Agent 和人类都可以在这里沟通。</p>
                <div v-for="m in messages" :key="m.id" class="msg" :class="{ mine: m.userId === myUserId }">
                  <div class="msg-head">
                    <span class="msg-author">{{ m.userId === myUserId ? '我方' : '对方' }}</span>
                    <span v-if="m.kind && m.kind !== 'chat'" class="kind-chip" :class="m.kind">{{ kindLabel(m.kind) }}</span>
                    <span class="msg-time">{{ formatTime(m.createdAt) }}</span>
                  </div>
                  <p>{{ m.content }}</p>
                </div>
              </div>
              <form v-if="ws.matchStatus === 'accepted'" class="msg-form" @submit.prevent="send">
                <textarea v-model="msgText" class="input textarea" rows="2" placeholder="发送消息（对方与其 Agent 可见）" />
                <button class="btn btn-sm btn-primary" type="submit" :disabled="!msgText.trim() || busy">发送</button>
              </form>
            </section>

            <!-- 关键事件时间线 -->
            <section class="card timeline-card">
              <h2>关键事件</h2>
              <p v-if="!ws.events.length" class="muted">暂无事件。</p>
              <div v-for="e in timelineEvents" :key="e.id" class="event">
                <span class="event-dot" :class="eventClass(e.eventType)" />
                <div class="event-body">
                  <p>{{ e.summary }}</p>
                  <span class="event-time">{{ roleShort(e.actorRole) }}{{ formatTime(e.createdAt) }}</span>
                </div>
              </div>
            </section>
          </div>
        </div>
      </template>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import { useAuthStore } from '@/stores/auth'
import {
  createMatchTask,
  fetchMatchEvents,
  fetchMessages,
  fetchWorkspace,
  resolveMatchDecision,
  reviewMatchDeliverable,
  sendMessage,
  updateMatch,
  updateMatchTask,
  updateWorkspace,
} from '@/api/endpoints'

const route = useRoute()
const auth = useAuthStore()
const matchId = String(route.params.id)

const ws = ref<any>(null)
const messages = ref<any[]>([])
const loading = ref(true)
const loadError = ref('')
const actionError = ref('')
const busy = ref(false)
const msgText = ref('')
const newTaskTitle = ref('')
const newTaskOwner = ref('requester')
const decisionChoice = ref<Record<number, string>>({})
const decisionNote = ref<Record<number, string>>({})
const msgListEl = ref<HTMLElement | null>(null)

let lastEventId = 0
let lastMessageId = 0
let timer: ReturnType<typeof setInterval> | undefined

const myUserId = computed(() => auth.context?.userId)
const batonWithMe = computed(() => ws.value && ws.value.batonRole === ws.value.viewerRole)
const batonWithCounterpart = computed(() =>
  !!ws.value?.batonRole && ws.value.batonRole !== ws.value.viewerRole)
const hasOpenDecision = computed(() =>
  (ws.value?.decisions ?? []).some((d: any) => d.status === 'open'))
const completeBlockReason = computed(() => {
  if (hasPendingDeliverable.value) return '请先验收或退回待处理交付物'
  if (hasOpenDecision.value) return '请先处理未决的决策'
  return ''
})
const counterpartRole = computed(() =>
  ws.value?.viewerRole === 'requester' ? 'helper' : 'requester')
const progressPercent = computed(() => {
  if (!ws.value?.progress?.tasksTotal) return ws.value?.progress?.deliverableAccepted ? 100 : 0
  return Math.round((ws.value.progress.tasksDone / ws.value.progress.tasksTotal) * 100)
})
const myOpenDecisions = computed(() =>
  (ws.value?.decisions ?? []).filter((d: any) => d.status === 'open' && d.assignedRole === ws.value.viewerRole))
const theirOpenDecisions = computed(() =>
  (ws.value?.decisions ?? []).filter((d: any) => d.status === 'open' && d.assignedRole !== ws.value.viewerRole))
const visibleDeliverables = computed(() =>
  (ws.value?.deliverables ?? []).filter((d: any) => d.status !== 'withdrawn'))
const hasPendingDeliverable = computed(() =>
  (ws.value?.deliverables ?? []).some((d: any) => d.status === 'submitted'))
const timelineEvents = computed(() => [...(ws.value?.events ?? [])].reverse().slice(0, 30))

onMounted(async () => {
  await auth.loadContext()
  await load()
  timer = setInterval(sync, 5000)
})
onUnmounted(() => { if (timer) clearInterval(timer) })

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    ws.value = await fetchWorkspace(matchId)
    lastEventId = ws.value.lastEventId ?? 0
    newTaskOwner.value = ws.value.viewerRole
    messages.value = await fetchMessages(matchId)
    lastMessageId = messages.value.length ? messages.value[messages.value.length - 1].id : 0
    scrollMessages()
  } catch (exception: any) {
    loadError.value = exception.response?.status === 403
      ? '你不是该协作的参与者。'
      : exception.response?.data?.errors?.[0]?.message ?? '无法加载协作工作台。'
  } finally {
    loading.value = false
  }
}

async function sync() {
  if (!ws.value || document.hidden) return
  try {
    const events = await fetchMatchEvents(matchId, lastEventId)
    if (events.length) {
      lastEventId = events[events.length - 1].id
      ws.value = await fetchWorkspace(matchId)
    }
    const fresh = await fetchMessages(matchId, lastMessageId)
    if (fresh.length) {
      messages.value.push(...fresh)
      lastMessageId = fresh[fresh.length - 1].id
      scrollMessages()
    }
  } catch { /* 网络抖动时静默，下一轮重试 */ }
}

async function refresh() {
  ws.value = await fetchWorkspace(matchId)
  lastEventId = ws.value.lastEventId ?? 0
}

function scrollMessages() {
  nextTick(() => {
    if (msgListEl.value) msgListEl.value.scrollTop = msgListEl.value.scrollHeight
  })
}

async function run(action: () => Promise<unknown>) {
  busy.value = true
  actionError.value = ''
  try {
    await action()
    await refresh()
  } catch (exception: any) {
    actionError.value = exception.response?.data?.errors?.[0]?.detail
      ?? exception.response?.data?.errors?.[0]?.message ?? '操作失败，请重试。'
  } finally {
    busy.value = false
  }
}

function togglePause() {
  const target = ws.value.collaborationState === 'paused' ? 'active' : 'paused'
  run(() => updateWorkspace(matchId, { collaborationState: target }))
}

function toggleBaton() {
  // Take the baton when the counterpart holds it, hand it over otherwise.
  const target = batonWithCounterpart.value ? ws.value.viewerRole : counterpartRole.value
  run(() => updateWorkspace(matchId, { baton: target }))
}

function takeOverTask(task: any) {
  run(() => updateMatchTask(matchId, task.id, { ownerRole: ws.value.viewerRole }))
}

function completeMatch() {
  if (!window.confirm('确认双方协作已完成？完成后求助将关闭。')) return
  run(() => updateMatch(matchId, { status: 'completed', userConfirmed: true }))
}

function decide(decision: any) {
  run(() => resolveMatchDecision(matchId, decision.id, {
    action: 'decide',
    optionKey: decisionChoice.value[decision.id],
    note: decisionNote.value[decision.id] || undefined,
  }))
}

function review(deliverable: any, action: 'accept' | 'reject') {
  let reviewNote: string | undefined
  if (action === 'reject') {
    reviewNote = window.prompt('请填写退回理由（必填）：') || ''
    if (!reviewNote.trim()) return
  }
  run(() => reviewMatchDeliverable(matchId, deliverable.id, { action, reviewNote }))
}

function addTask() {
  const title = newTaskTitle.value.trim()
  if (!title) return
  run(async () => {
    await createMatchTask(matchId, { title, ownerRole: newTaskOwner.value })
    newTaskTitle.value = ''
  })
}

function setTask(task: any, status: string) {
  run(() => updateMatchTask(matchId, task.id, { status }))
}

function blockTask(task: any) {
  const reason = window.prompt('受阻原因（必填）：') || ''
  if (!reason.trim()) return
  run(() => updateMatchTask(matchId, task.id, { status: 'blocked', blockedReason: reason }))
}

async function send() {
  const content = msgText.value.trim()
  if (!content) return
  busy.value = true
  try {
    const msg = await sendMessage(matchId, content)
    messages.value.push(msg)
    lastMessageId = msg.id
    msgText.value = ''
    scrollMessages()
  } catch (exception: any) {
    actionError.value = exception.response?.data?.errors?.[0]?.detail ?? '消息发送失败。'
  } finally {
    busy.value = false
  }
}

function statusLabel(status: string) {
  return ({ accepted: '协作中', completed: '已完成', cancelled: '已取消', offered: '待接受' } as Record<string, string>)[status] ?? status
}
function taskLabel(status: string) {
  return ({ todo: '待办', doing: '进行中', blocked: '受阻', done: '完成' } as Record<string, string>)[status] ?? status
}
function deliverableLabel(status: string) {
  return ({ submitted: '待验收', accepted: '已验收', rejected: '已退回' } as Record<string, string>)[status] ?? status
}
function deliverableClass(status: string) {
  return ({ submitted: 'pending', accepted: 'accepted', rejected: 'declined' } as Record<string, string>)[status] ?? ''
}
function kindLabel(kind: string) {
  return ({ update: '进展', question: '提问', handoff: '交接' } as Record<string, string>)[kind] ?? kind
}
function roleShort(role: string | null) {
  if (!role) return ''
  return (role === 'requester' ? '求助方' : '帮助方') + ' · '
}
function eventClass(type: string) {
  if (type.startsWith('deliverable')) return 'deliverable'
  if (type.startsWith('decision')) return 'decision'
  if (type.startsWith('workspace') || type.startsWith('baton')) return 'control'
  if (type.startsWith('match')) return 'match'
  return 'task'
}
function formatTime(value: string) {
  if (!value) return ''
  const date = new Date(value)
  const now = new Date()
  const sameDay = date.toDateString() === now.toDateString()
  return sameDay
    ? date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
    : date.toLocaleDateString('zh-CN', { month: 'numeric', day: 'numeric' })
      + ' ' + date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
}
</script>

<style scoped>
.workspace-page { min-height: 100vh; background: transparent; }
.page { max-width: 1080px; margin: 0 auto; padding: 28px 20px 72px; }

/* ── 头部 ── */
.ws-header { display: flex; flex-direction: column; gap: var(--nx-space-3); }
.back-link { color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); }
.back-link:hover { color: var(--nx-text-primary); }
.ws-title h1 { margin-top: 6px; color: var(--nx-text-primary); font-size: var(--nx-fs-20); font-weight: 800; letter-spacing: -0.01em; line-height: 1.35; }
.ws-meta { display: flex; flex-wrap: wrap; gap: var(--nx-space-2); margin-top: var(--nx-space-2); align-items: center; }
.role-chip { padding: 2px 9px; border-radius: 999px; background: var(--nx-bg-inset); color: var(--nx-text-secondary); font-size: var(--nx-fs-11); }
.paused-chip { padding: 2px 9px; border-radius: 999px; background: var(--nx-danger-bg); color: var(--nx-danger); font-size: var(--nx-fs-11); font-weight: 700; }
.baton-chip { padding: 2px 9px; border-radius: 999px; background: var(--nx-bg-inset); color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); }
.baton-chip.mine { background: var(--nx-accent); color: var(--nx-on-accent); font-weight: 700; }
.ws-progress { display: flex; flex-direction: column; gap: 6px; }
.progress-line { display: flex; justify-content: space-between; color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); }
.progress-line .ok { color: var(--nx-accent); font-weight: 700; }
.progress-bar { height: 6px; border-radius: 3px; background: var(--nx-bg-inset); overflow: hidden; }
.progress-fill { height: 100%; border-radius: 3px; background: var(--nx-accent); transition: width var(--nx-duration-fast) var(--nx-ease-out); }
.ws-controls { display: flex; flex-wrap: wrap; gap: var(--nx-space-2); align-items: center; }
.control-hint { color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); }
.pause-hint { margin: 0; }
.baton-hint { margin-top: var(--nx-space-3); }

/* ── 双栏布局 ── */
.ws-grid { display: grid; grid-template-columns: 1.15fr 0.85fr; gap: var(--nx-space-3); margin-top: var(--nx-space-3); align-items: start; }
.ws-col { display: flex; flex-direction: column; gap: var(--nx-space-3); min-width: 0; }
.card h2 { color: var(--nx-text-primary); font-size: var(--nx-fs-15); font-weight: 700; margin-bottom: var(--nx-space-3); display: flex; align-items: center; gap: var(--nx-space-2); }
.count-badge { min-width: 20px; height: 20px; padding: 0 6px; display: inline-grid; place-items: center; border-radius: 999px; background: var(--nx-accent); color: var(--nx-on-accent); font-size: var(--nx-fs-11); font-weight: 800; }
.muted { color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); }

/* ── 决策卡 ── */
.decisions-card.attention { border-color: var(--nx-accent); }
.decision { padding: var(--nx-space-3) 0; border-top: 1px solid var(--nx-border-subtle); }
.decision:first-of-type { border-top: 0; padding-top: 0; }
.decision h3 { color: var(--nx-text-primary); font-size: var(--nx-fs-14); font-weight: 700; margin-bottom: 6px; }
.decision-context { color: var(--nx-text-secondary); font-size: var(--nx-fs-12); line-height: 1.55; margin-bottom: var(--nx-space-2); white-space: pre-wrap; }
.decision-option { display: flex; gap: 9px; align-items: flex-start; padding: 8px 10px; border: 1px solid var(--nx-border-subtle); border-radius: var(--nx-radius-md); margin-bottom: 6px; cursor: pointer; transition: border-color var(--nx-duration-fast) var(--nx-ease-out); }
.decision-option:hover { border-color: var(--nx-border-strong); }
.decision-option:has(input:checked) { border-color: var(--nx-accent); background: var(--nx-bg-hover); }
.decision-option input { margin-top: 3px; accent-color: var(--nx-accent); }
.decision-option strong { display: block; color: var(--nx-text-primary); font-size: var(--nx-fs-13); }
.decision-option em { display: block; color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); font-style: normal; margin-top: 2px; }
.decision-actions { display: flex; gap: var(--nx-space-2); margin-top: var(--nx-space-2); }
.decision-actions .input { flex: 1; margin: 0; }
.waiting-item { display: flex; align-items: center; gap: 9px; color: var(--nx-text-secondary); font-size: var(--nx-fs-13); padding: 6px 0; }
.waiting-item .dot { width: 7px; height: 7px; border-radius: 50%; background: var(--nx-warning, #e8a33d); flex: 0 0 auto; }

/* ── 交付物 ── */
.deliverable { padding: var(--nx-space-3) 0; border-top: 1px solid var(--nx-border-subtle); }
.deliverable:first-of-type { border-top: 0; padding-top: 0; }
.deliverable-head { display: flex; align-items: center; gap: var(--nx-space-2); flex-wrap: wrap; }
.deliverable-head strong { color: var(--nx-text-primary); font-size: var(--nx-fs-14); }
.deliverable-desc { color: var(--nx-text-secondary); font-size: var(--nx-fs-12); line-height: 1.55; margin-top: 6px; white-space: pre-wrap; }
.deliverable-meta { display: flex; flex-direction: column; gap: 3px; margin-top: var(--nx-space-2); color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); }
.deliverable-meta .mono { font-family: var(--nx-font-mono, ui-monospace, monospace); word-break: break-all; }
.review-note { margin-top: 6px; color: var(--nx-danger); font-size: var(--nx-fs-12); }
.deliverable-actions { display: flex; gap: var(--nx-space-2); margin-top: var(--nx-space-2); }
.status-tag.pending { color: var(--nx-warning, #e8a33d); background: rgba(232, 163, 61, 0.12); }

/* ── 任务 ── */
.task { padding: 9px 0; border-top: 1px solid var(--nx-border-subtle); }
.task:first-of-type { border-top: 0; }
.task-main { display: flex; align-items: center; gap: var(--nx-space-2); flex-wrap: wrap; }
.task-status { flex: 0 0 auto; padding: 1px 8px; border-radius: 999px; font-size: var(--nx-fs-11); font-weight: 700; background: var(--nx-bg-inset); color: var(--nx-text-tertiary); }
.task-status.doing { color: var(--nx-accent); background: color-mix(in srgb, var(--nx-accent) 14%, transparent); }
.task-status.done { color: var(--nx-on-accent); background: var(--nx-accent); }
.task-status.blocked { color: var(--nx-danger); background: var(--nx-danger-bg); }
.task-title { color: var(--nx-text-primary); font-size: var(--nx-fs-13); }
.task.done .task-title { color: var(--nx-text-tertiary); text-decoration: line-through; }
.task-owner { margin-left: auto; color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); }
.task-note { color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); margin-top: 3px; }
.task-blocked { color: var(--nx-danger); font-size: var(--nx-fs-12); margin-top: 3px; }
.task-actions { display: flex; gap: var(--nx-space-3); margin-top: 4px; }
.btn-link { border: 0; background: transparent; color: var(--nx-accent); font-size: var(--nx-fs-12); cursor: pointer; padding: 0; }
.btn-link:hover { text-decoration: underline; }
.btn-link.danger { color: var(--nx-danger); }
.task-form { display: flex; gap: var(--nx-space-2); margin-top: var(--nx-space-3); }
.task-form .input { flex: 1; margin: 0; }
.owner-select { flex: 0 0 auto; width: 84px; }

/* ── 消息 ── */
.messages-card { display: flex; flex-direction: column; }
.msg-list { max-height: 380px; overflow-y: auto; display: flex; flex-direction: column; gap: var(--nx-space-2); padding-right: 4px; }
.msg { padding: 8px 11px; border-radius: var(--nx-radius-md); background: var(--nx-bg-inset); max-width: 92%; align-self: flex-start; }
.msg.mine { align-self: flex-end; background: var(--nx-bg-active); }
.msg-head { display: flex; align-items: center; gap: var(--nx-space-2); margin-bottom: 3px; }
.msg-author { color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); font-weight: 700; }
.msg.mine .msg-author { color: var(--nx-accent); }
.msg-time { color: var(--nx-text-tertiary); font-size: 10px; }
.kind-chip { padding: 0 6px; border-radius: 999px; font-size: 10px; font-weight: 700; background: var(--nx-bg-raised); color: var(--nx-text-secondary); }
.kind-chip.handoff { color: var(--nx-accent); }
.kind-chip.question { color: var(--nx-warning, #e8a33d); }
.msg p { color: var(--nx-text-secondary); font-size: var(--nx-fs-13); line-height: 1.5; white-space: pre-wrap; word-break: break-word; }
.msg-form { display: flex; gap: var(--nx-space-2); margin-top: var(--nx-space-3); }
.msg-form .input { flex: 1; margin: 0; }
.msg-form button { align-self: flex-end; }

/* ── 时间线 ── */
.timeline-card .event { display: flex; gap: 10px; padding: 7px 0; border-top: 1px solid var(--nx-border-subtle); }
.timeline-card .event:first-of-type { border-top: 0; }
.event-dot { flex: 0 0 auto; width: 8px; height: 8px; border-radius: 50%; margin-top: 6px; background: var(--nx-text-tertiary); }
.event-dot.deliverable { background: var(--nx-accent); }
.event-dot.decision { background: var(--nx-warning, #e8a33d); }
.event-dot.control { background: var(--nx-danger); }
.event-dot.match { background: var(--nx-text-primary); }
.event-body p { color: var(--nx-text-secondary); font-size: var(--nx-fs-12); line-height: 1.5; }
.event-time { color: var(--nx-text-tertiary); font-size: 10px; }

/* ── 移动端 ── */
@media (max-width: 720px) {
  .workspace-page { padding-bottom: 68px; }
  .page { padding: 20px 12px 40px; }
  .ws-grid { grid-template-columns: 1fr; }
  .ws-title h1 { font-size: var(--nx-fs-18); }
  .msg-list { max-height: 300px; }
  .decision-actions { flex-direction: column; }
  .task-form { flex-wrap: wrap; }
}
</style>
