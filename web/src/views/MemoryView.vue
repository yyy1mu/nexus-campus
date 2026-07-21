<template>
  <div class="memory-shell">
    <AppHeader />
    <main class="memory-page">
      <header class="page-header">
        <div>
          <h1>长期记忆</h1>
          <p>管理 Agent 在长期任务中可以召回的用户上下文。</p>
        </div>
        <button
          class="button primary create-button"
          type="button"
          aria-label="新建记忆"
          title="新建记忆"
          @click="startCreate"
        >
          <Plus :size="17" /> <span>新建记忆</span>
        </button>
      </header>

      <section class="summary-strip" aria-label="记忆统计">
        <div><strong>{{ memories.length }}</strong><span>当前结果</span></div>
        <div><strong>{{ pinnedCount }}</strong><span>已置顶</span></div>
        <div><strong>{{ shareableCount }}</strong><span>可确认共享</span></div>
        <p><ShieldCheck :size="16" /> 默认仅用户与其 Agent 可见</p>
      </section>

      <div class="workspace" :class="{ 'editor-visible': editorOpen }">
        <section class="memory-browser">
          <div class="toolbar">
            <label class="search-field">
              <Search :size="17" />
              <input
                v-model.trim="query"
                type="search"
                placeholder="搜索标题、内容或标签"
                aria-label="搜索记忆"
              />
            </label>
            <select v-model="kind" aria-label="记忆类型">
              <option value="">全部类型</option>
              <option v-for="option in kindOptions" :key="option.value" :value="option.value">
                {{ option.label }}
              </option>
            </select>
            <select v-model="status" aria-label="记忆状态">
              <option value="active">有效</option>
              <option value="archived">已归档</option>
              <option value="">全部状态</option>
            </select>
          </div>

          <div v-if="loading" class="state">正在载入记忆...</div>
          <div v-else-if="error" class="state error">{{ error }}</div>
          <div v-else-if="!memories.length" class="state empty">
            <Brain :size="30" />
            <strong>没有符合条件的记忆</strong>
            <span>新建一条项目、环境、资源或偏好记忆。</span>
          </div>

          <div v-else class="memory-list">
            <article
              v-for="memory in memories"
              :key="memory.id"
              class="memory-row"
              :class="{ selected: editingId === memory.id }"
              @click="startEdit(memory)"
            >
              <div class="memory-main">
                <div class="memory-heading">
                  <Pin v-if="memory.pinned" :size="14" class="pin" />
                  <span class="kind">{{ kindLabel(memory.kind) }}</span>
                  <span v-if="memory.sensitivity !== 'normal'" class="sensitivity">
                    {{ sensitivityLabel(memory.sensitivity) }}
                  </span>
                </div>
                <h2>{{ memory.title }}</h2>
                <p>{{ memory.content }}</p>
                <div v-if="memory.tags?.length" class="tags">
                  <span v-for="tag in memory.tags" :key="tag">{{ tag }}</span>
                </div>
              </div>
              <div class="memory-meta">
                <span>重要度 {{ memory.importance }}/5</span>
                <span>{{ memory.sharePolicy === 'ask_each_time' ? '可确认共享' : '私有' }}</span>
                <time>{{ formatDate(memory.updatedAt) }}</time>
              </div>
            </article>
          </div>
        </section>

        <aside v-if="editorOpen" class="editor-panel">
          <div class="editor-header">
            <div>
              <span>{{ editingId ? '编辑记忆' : '新建记忆' }}</span>
              <strong>{{ editingId ? form.title || '未命名记忆' : '记录长期上下文' }}</strong>
            </div>
            <button class="icon-button" type="button" title="关闭" @click="closeEditor">
              <X :size="18" />
            </button>
          </div>

          <form @submit.prevent="save">
            <label>
              <span>类型</span>
              <select v-model="form.kind">
                <option v-for="option in kindOptions" :key="option.value" :value="option.value">
                  {{ option.label }}
                </option>
              </select>
            </label>

            <label>
              <span>标题</span>
              <input v-model.trim="form.title" maxlength="160" required />
            </label>

            <label>
              <span>记忆内容</span>
              <textarea
                v-model.trim="form.content"
                rows="8"
                maxlength="12000"
                required
                placeholder="记录对未来任务有持续价值的事实，不要填写密码、Token 或 API Key。"
              />
            </label>

            <label>
              <span>标签</span>
              <input v-model="form.tagsText" placeholder="dataset, gpu-lab, campus-network" />
            </label>

            <div class="field-grid">
              <label>
                <span>重要度</span>
                <select v-model.number="form.importance">
                  <option v-for="level in 5" :key="level" :value="level">{{ level }}</option>
                </select>
              </label>
              <label>
                <span>敏感级别</span>
                <select v-model="form.sensitivity">
                  <option value="normal">普通</option>
                  <option value="sensitive">敏感</option>
                  <option value="restricted">受限，不可共享</option>
                </select>
              </label>
            </div>

            <label>
              <span>Match 共享策略</span>
              <select v-model="form.sharePolicy">
                <option value="private">始终私有</option>
                <option value="ask_each_time">每次由用户明确确认</option>
              </select>
            </label>

            <label>
              <span>失效时间（可选）</span>
              <input v-model="form.expiresAt" type="datetime-local" />
            </label>

            <div class="binary-options">
              <label>
                <input v-model="form.pinned" type="checkbox" />
                <span>置顶并加入 Agent 启动摘要</span>
              </label>
            </div>

            <p v-if="saveError" class="form-error">{{ saveError }}</p>

            <div class="editor-actions">
              <button v-if="editingId" class="button danger-text" type="button" @click="remove">
                <Trash2 :size="16" /> 永久删除
              </button>
              <button
                v-if="editingId && form.status === 'active'"
                class="button secondary"
                type="button"
                @click="archive"
              >
                <Archive :size="16" /> 归档
              </button>
              <button class="button primary" type="submit" :disabled="saving">
                <Save :size="16" /> {{ saving ? '保存中...' : '保存记忆' }}
              </button>
            </div>
          </form>
        </aside>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Archive, Brain, Pin, Plus, Save, Search, ShieldCheck, Trash2, X } from '@lucide/vue'
import AppHeader from '@/components/AppHeader.vue'
import { useAuthStore } from '@/stores/auth'
import {
  createMemory,
  deleteMemory,
  fetchMemories,
  updateMemory,
} from '@/api/endpoints'

const kindOptions = [
  { value: 'preference', label: '用户偏好' },
  { value: 'project', label: '项目状态' },
  { value: 'environment', label: '环境与设备' },
  { value: 'resource', label: '可用资源' },
  { value: 'relationship', label: '协作关系' },
  { value: 'workflow', label: '工作流程' },
  { value: 'constraint', label: '约束与权限' },
  { value: 'outcome', label: '结果与经验' },
  { value: 'other', label: '其他' },
]

const emptyForm = () => ({
  kind: 'project',
  title: '',
  content: '',
  tagsText: '',
  status: 'active',
  importance: 3,
  pinned: false,
  sensitivity: 'normal',
  sharePolicy: 'private',
  sourceType: 'user',
  expiresAt: '',
})

const memories = ref<any[]>([])
const auth = useAuthStore()
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const saveError = ref('')
const query = ref('')
const kind = ref('')
const status = ref('active')
const editorOpen = ref(false)
const editingId = ref<number | null>(null)
const form = ref(emptyForm())
let loadTimer: ReturnType<typeof setTimeout> | undefined

const pinnedCount = computed(() => memories.value.filter(memory => memory.pinned).length)
const shareableCount = computed(
  () => memories.value.filter(memory => memory.sharePolicy === 'ask_each_time').length,
)

watch([query, kind, status], () => {
  if (loadTimer) clearTimeout(loadTimer)
  loadTimer = setTimeout(load, 220)
})

watch(() => auth.token, load, { immediate: true })

async function load() {
  loading.value = true
  error.value = ''
  try {
    memories.value = await fetchMemories({
      query: query.value || undefined,
      kind: kind.value || undefined,
      status: status.value || undefined,
      limit: 50,
    })
  } catch (exception: any) {
    error.value = apiError(exception, '无法读取记忆，请先登录。')
  } finally {
    loading.value = false
  }
}

function startCreate() {
  editingId.value = null
  form.value = emptyForm()
  saveError.value = ''
  editorOpen.value = true
}

function startEdit(memory: any) {
  editingId.value = memory.id
  form.value = {
    kind: memory.kind,
    title: memory.title,
    content: memory.content,
    tagsText: (memory.tags ?? []).join(', '),
    status: memory.status,
    importance: memory.importance,
    pinned: memory.pinned,
    sensitivity: memory.sensitivity,
    sharePolicy: memory.sharePolicy,
    sourceType: memory.sourceType,
    expiresAt: memory.expiresAt ? memory.expiresAt.slice(0, 16) : '',
  }
  saveError.value = ''
  editorOpen.value = true
}

function closeEditor() {
  editorOpen.value = false
  editingId.value = null
  saveError.value = ''
}

async function save() {
  saving.value = true
  saveError.value = ''
  const payload = {
    kind: form.value.kind,
    title: form.value.title,
    content: form.value.content,
    tags: form.value.tagsText.split(',').map(tag => tag.trim()).filter(Boolean),
    status: form.value.status,
    importance: form.value.importance,
    pinned: form.value.pinned,
    sensitivity: form.value.sensitivity,
    sharePolicy: form.value.sharePolicy,
    sourceType: form.value.sourceType,
    expiresAt: form.value.expiresAt || undefined,
    clearExpiresAt: editingId.value ? !form.value.expiresAt : undefined,
    userConfirmed: true,
  }
  try {
    if (editingId.value) {
      await updateMemory(String(editingId.value), payload)
    } else {
      await createMemory(payload)
    }
    await load()
    closeEditor()
  } catch (exception: any) {
    saveError.value = apiError(exception, '记忆保存失败。')
  } finally {
    saving.value = false
  }
}

async function archive() {
  if (!editingId.value) return
  await updateMemory(String(editingId.value), { status: 'archived', userConfirmed: true })
  await load()
  closeEditor()
}

async function remove() {
  if (!editingId.value || !window.confirm('永久删除这条记忆以及它的 Match 共享快照？')) return
  try {
    await deleteMemory(String(editingId.value))
    await load()
    closeEditor()
  } catch (exception: any) {
    saveError.value = apiError(exception, '记忆删除失败。')
  }
}

function kindLabel(value: string) {
  return kindOptions.find(option => option.value === value)?.label ?? value
}

function sensitivityLabel(value: string) {
  return value === 'restricted' ? '受限' : '敏感'
}

function formatDate(value: string) {
  return value ? new Date(value).toLocaleDateString('zh-CN') : ''
}

function apiError(exception: any, fallback: string) {
  return exception.response?.data?.errors?.[0]?.message ?? fallback
}
</script>

<style scoped>
/* 按钮、输入框、select/textarea、状态等复用 styles/components.css 全局样式 */
.memory-shell { min-height: 100vh; color: var(--nx-text-secondary); background: var(--nx-bg-base); }
.memory-page { width: min(1240px, calc(100vw - 40px)); margin: 0 auto; padding: 28px 0 72px; }
.page-header { display: flex; align-items: center; justify-content: space-between; gap: var(--nx-space-5); margin-bottom: 18px; }
.page-header h1 { color: var(--nx-text-primary); font-size: var(--nx-fs-24); letter-spacing: 0; }
.page-header p { margin-top: 5px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-13); }
.summary-strip {
  min-height: 66px; display: flex; align-items: center; gap: 0; margin-bottom: var(--nx-space-4);
  border: 1px solid var(--nx-border-subtle); border-radius: var(--nx-radius-lg); background: var(--nx-bg-raised);
}
.summary-strip > div { min-width: 130px; padding: 0 22px; border-right: 1px solid var(--nx-border-subtle); }
.summary-strip strong { display: block; color: var(--nx-text-primary); font-size: var(--nx-fs-18); }
.summary-strip span { color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); }
.summary-strip p { margin-left: auto; padding: 0 22px; display: flex; align-items: center; gap: 7px; color: var(--nx-accent); }
.workspace { display: grid; grid-template-columns: minmax(0, 1fr); gap: var(--nx-space-4); align-items: start; }
.workspace.editor-visible { grid-template-columns: minmax(0, 1fr) 390px; }
.memory-browser, .editor-panel { border: 1px solid var(--nx-border-subtle); border-radius: var(--nx-radius-lg); background: var(--nx-bg-raised); }
.toolbar {
  min-height: 62px; display: grid; grid-template-columns: minmax(220px, 1fr) 160px 140px;
  gap: 10px; align-items: center; padding: var(--nx-space-3); border-bottom: 1px solid var(--nx-border-subtle);
}
.search-field {
  height: var(--nx-control-h); display: flex; align-items: center; gap: var(--nx-space-2); padding: 0 11px;
  border: 1px solid var(--nx-border-default); border-radius: var(--nx-radius-md); color: var(--nx-text-tertiary); background: var(--nx-bg-inset);
}
.search-field:hover { border-color: var(--nx-border-strong); }
.search-field:focus-within { border-color: var(--nx-accent); background: var(--nx-bg-base); box-shadow: 0 0 0 3px rgba(200, 245, 66, 0.12); }
.search-field input { width: 100%; border: 0; outline: 0; background: transparent; color: var(--nx-text-primary); min-height: 0; padding: 0; box-shadow: none; }
.memory-list { min-height: 300px; }
.memory-row {
  display: grid; grid-template-columns: minmax(0, 1fr) 120px; gap: 18px;
  padding: 18px; border-bottom: 1px solid var(--nx-border-subtle); cursor: pointer;
}
.memory-row:last-child { border-bottom: 0; }
.memory-row:hover { background: var(--nx-bg-hover); }
.memory-row.selected { background: var(--nx-bg-hover); box-shadow: inset 3px 0 var(--nx-accent); }
.memory-heading { min-height: 20px; display: flex; align-items: center; gap: 7px; }
.kind, .sensitivity, .tags span { padding: 2px 7px; border-radius: var(--nx-radius-sm); font-size: var(--nx-fs-11); }
.kind { color: var(--nx-accent); background: var(--nx-accent-faint); border: 1px solid var(--nx-accent-border); }
.sensitivity { color: var(--nx-warning); background: var(--nx-warning-bg); border: 1px solid rgba(217, 166, 72, 0.25); }
.pin { color: var(--nx-accent); }
.memory-main h2 { margin-top: 7px; color: var(--nx-text-primary); font-size: 15px; }
.memory-main > p {
  max-height: 44px; margin-top: 6px; overflow: hidden; color: var(--nx-text-tertiary);
  line-height: 1.55; font-size: var(--nx-fs-13);
}
.tags { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 9px; }
.tags span { color: var(--nx-text-secondary); background: var(--nx-bg-active); }
.memory-meta { display: flex; flex-direction: column; align-items: flex-end; gap: 6px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); }
.editor-panel { position: sticky; top: 80px; overflow: hidden; }
.editor-header {
  min-height: 66px; display: flex; align-items: center; justify-content: space-between;
  padding: 12px 16px; border-bottom: 1px solid var(--nx-border-subtle); background: var(--nx-bg-overlay);
}
.editor-header > div { min-width: 0; display: flex; flex-direction: column; gap: 4px; }
.editor-header span { color: var(--nx-accent); font-size: var(--nx-fs-11); font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; }
.editor-header strong { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--nx-text-primary); font-size: var(--nx-fs-14); }
.editor-panel form { padding: var(--nx-space-4); }
.editor-panel form > label { display: block; margin-bottom: 13px; }
.field-grid { display: grid; grid-template-columns: 110px 1fr; gap: 10px; margin-bottom: 13px; }
.binary-options { margin: 4px 0 16px; padding: 10px 0; border-top: 1px solid var(--nx-border-subtle); border-bottom: 1px solid var(--nx-border-subtle); }
.binary-options label { display: flex; align-items: center; gap: var(--nx-space-2); cursor: pointer; }
.binary-options input { width: 16px; height: 16px; min-height: 0; }
.binary-options span { margin: 0; color: var(--nx-text-secondary); font-weight: 500; }
.editor-actions { display: flex; justify-content: flex-end; gap: var(--nx-space-2); flex-wrap: wrap; }
.button.danger-text { margin-right: auto; }
.icon-button {
  width: 34px; height: 34px; display: grid; place-items: center; border: 0;
  border-radius: var(--nx-radius-md); color: var(--nx-text-tertiary); background: transparent; cursor: pointer;
}
.icon-button:hover { color: var(--nx-text-primary); background: var(--nx-bg-hover); }
.state { min-height: 280px; display: flex; align-items: center; justify-content: center; color: var(--nx-text-tertiary); }
@media (max-width: 960px) {
  .workspace.editor-visible { grid-template-columns: 1fr; }
  .editor-panel { position: static; grid-row: 1; }
}
@media (max-width: 720px) {
  .memory-shell { padding-bottom: 58px; }
  .memory-page { width: calc(100vw - 24px); padding-top: 20px; }
  .page-header { align-items: flex-start; }
  .create-button {
    width: 40px;
    min-width: 40px;
    height: 40px;
    padding: 0;
    justify-content: center;
  }
  .create-button span { display: none; }
  .summary-strip { flex-wrap: wrap; padding: 10px 0; }
  .summary-strip > div { min-width: 33.333%; padding: 5px 12px; }
  .summary-strip p { width: 100%; margin: 8px 0 0; padding: 8px 12px 0; border-top: 1px solid var(--nx-border-subtle); }
  .toolbar { grid-template-columns: 1fr 1fr; }
  .search-field { grid-column: 1 / -1; }
  .memory-row { grid-template-columns: 1fr; }
  .memory-meta { flex-direction: row; align-items: center; }
}
</style>
