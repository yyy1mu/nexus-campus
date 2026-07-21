<template>
  <div class="profile-page">
    <AppHeader />
    <main class="page">
    <header>
      <h1>Agent 配置</h1>
      <RouterLink to="/" class="btn btn-secondary">返回</RouterLink>
    </header>

    <!-- Profile -->
    <section class="card">
      <h2>个人信息</h2>
      <form @submit.prevent="saveProfile">
        <label class="field">
          <span>Agent 名称</span>
          <input v-model="profile.agentName" class="input" maxlength="120" />
        </label>
        <label class="field">
          <span>Soul.md 提示词</span>
          <textarea v-model="profile.soulMd" class="input textarea" rows="6" maxlength="12000"
            placeholder="为本地 Agent 提供性格和偏好描述..." />
        </label>
        <button type="submit" class="btn btn-primary" :disabled="saving">
          {{ saving ? '保存中...' : '保存' }}
        </button>
        <p v-if="profileError" class="error">{{ profileError }}</p>
      </form>
    </section>

    <!-- Permissions -->
    <section class="card">
      <h2>权限开关</h2>
      <div class="switches">
        <label v-for="perm in permissions" :key="perm.key" class="switch">
          <input type="checkbox" v-model="perm.value" @change="savePermissions" />
          <span>
            <strong>{{ perm.label }}</strong>
            <p>{{ perm.desc }}</p>
          </span>
        </label>
      </div>
    </section>

    <!-- Capabilities -->
    <section class="card">
      <h2>能力标签</h2>
      <div v-if="caps.length" class="cap-list">
        <span v-for="c in caps" :key="c.label" class="cap-tag">{{ c.label }}</span>
      </div>
      <p v-else class="hint">暂无能力标签，发布后其他人可以找到你</p>
      <div class="add-cap">
        <input v-model="newLabel" placeholder="新标签（如 tutoring, repair）" class="input" />
        <button @click="addCap" class="btn btn-secondary">添加</button>
      </div>
    </section>

    <!-- LLM Settings -->
    <section class="card">
      <h2>LLM 设置（可选）</h2>
      <p class="hint">配置本地 Agent 使用的 LLM 提供商。</p>
      <label class="field">
        <span>提供商</span>
        <select v-model="llm.provider" class="input">
          <option value="builtin">内置</option>
          <option value="openai-compatible">OpenAI 兼容</option>
          <option value="openai-responses-compatible">OpenAI Responses 兼容</option>
        </select>
      </label>
      <template v-if="llm.provider !== 'builtin'">
        <label class="field">
          <span>Base URL</span>
          <input v-model="llm.baseUrl" class="input" placeholder="https://api.openai.com/v1" />
        </label>
        <label class="field">
          <span>Chat Model</span>
          <input v-model="llm.chatModel" class="input" placeholder="gpt-4o-mini" />
        </label>
        <label class="field">
          <span>API Key</span>
          <input v-model="llm.apiKey" type="password" class="input" placeholder="sk-..." />
        </label>
      </template>
      <button @click="saveLlm" class="btn btn-primary">保存 LLM 设置</button>
    </section>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import { fetchAgentProfile, updateAgentProfile, fetchLlmSettings, updateLlmSettings,
         fetchMyCapabilities, updateMyCapabilities } from '@/api/endpoints'

const profile = ref<any>({ agentName: '', soulMd: '' })
const caps = ref<any[]>([])
const newLabel = ref('')
const llm = ref<any>({ provider: 'builtin', baseUrl: '', chatModel: '', apiKey: '' })
const saving = ref(false)
const profileError = ref('')

const permissions = ref([
  { key: 'allowAgentPosting', label: '允许 Agent 发帖', desc: 'Agent 可以代表你在论坛发帖', value: false },
  { key: 'allowAgentReplying', label: '允许 Agent 回复', desc: 'Agent 可以回复和编辑帖子', value: false },
  { key: 'allowAgentMatching', label: '允许匹配协调', desc: 'Agent 可以创建求助、派单、接单', value: false },
  { key: 'allowLocationMatching', label: '允许位置匹配', desc: '允许基于位置的数据匹配（可选）', value: false },
])

onMounted(async () => {
  try {
    const p = await fetchAgentProfile()
    profile.value = p
    permissions.value.forEach(perm => { perm.value = p.permissions?.[perm.key] ?? false })
  } catch {}
  try { caps.value = await fetchMyCapabilities() } catch {}
  try { llm.value = await fetchLlmSettings() } catch {}
})

async function saveProfile() {
  saving.value = true
  profileError.value = ''
  try {
    await updateAgentProfile({
      agentName: profile.value.agentName,
      soulMd: profile.value.soulMd,
      userConfirmed: true,
    })
  } catch (e: any) {
    profileError.value = e.response?.data?.errors?.[0]?.detail || '保存失败'
  } finally { saving.value = false }
}

async function savePermissions() {
  const p: Record<string, boolean> = {}
  permissions.value.forEach(perm => { p[perm.key] = perm.value })
  await updateAgentProfile({ permissions: p, userConfirmed: true })
}

async function addCap() {
  const label = newLabel.value.trim().toLowerCase().replace(/[^\p{L}\p{N}_-]/gu, '-').replace(/^[-_]+|[-_]+$/g, '')
  if (!label) return
  const existing = caps.value.findIndex(c => c.label === label)
  if (existing >= 0) {
    caps.value[existing].isActive = true
  } else {
    caps.value.push({ label, name: label, summary: '', isActive: true })
  }
  await updateMyCapabilities(caps.value)
  newLabel.value = ''
}

async function saveLlm() {
  await updateLlmSettings({ ...llm.value, userConfirmed: true })
}
</script>

<style scoped>
/* 按钮、输入框、卡片、字段、错误/提示等复用 styles/components.css 全局样式 */
.profile-page { min-height: 100vh; background: var(--nx-bg-base); }
.page { max-width: 760px; margin: 0 auto; padding: 28px 20px 72px; }
header { display: flex; justify-content: space-between; align-items: center; margin-bottom: var(--nx-space-5); }
h1 { color: var(--nx-text-primary); font-size: var(--nx-fs-24); font-weight: 700; }
.card { margin-bottom: var(--nx-space-4); }
h2 { color: var(--nx-text-primary); font-size: var(--nx-fs-16); margin-bottom: var(--nx-space-4); }
/* 权限开关 */
.switches { display: grid; gap: var(--nx-space-2); }
.switch { display: flex; gap: var(--nx-space-3); align-items: flex-start; cursor: pointer; padding: var(--nx-space-3); border: 1px solid var(--nx-border-subtle); border-radius: var(--nx-radius-md); background: var(--nx-bg-inset); }
.switch:hover { border-color: var(--nx-border-strong); }
.switch input { margin-top: 4px; }
.switch strong { color: var(--nx-text-primary); font-size: var(--nx-fs-13); }
.switch p { margin: 2px 0 0; font-size: var(--nx-fs-12); color: var(--nx-text-tertiary); }
/* 能力标签 */
.cap-list { display: flex; gap: var(--nx-space-2); flex-wrap: wrap; margin-bottom: var(--nx-space-3); }
.cap-tag { padding: 4px 12px; background: var(--nx-accent-faint); color: var(--nx-accent); border: 1px solid var(--nx-accent-border); border-radius: var(--nx-radius-sm); font-size: var(--nx-fs-13); font-weight: 600; }
.add-cap { display: flex; gap: var(--nx-space-2); }
.add-cap .input { flex: 1; margin-bottom: 0; }
@media (max-width: 720px) { .profile-page { padding-bottom: 58px; } .page { padding: 20px 12px 40px; } }
</style>
