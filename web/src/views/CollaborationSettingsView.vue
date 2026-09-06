<template>
  <div class="profile-page">
    <AppHeader />
    <main class="page">
    <PageIntro title="协作设置" eyebrow="PERSONAL / PREFERENCES" description="管理协作授权与能力标签，让每次连接都符合你的意愿。" />
    <StatePanel v-if="!auth.isLoggedIn" title="登录后管理协作偏好" description="授权开关和能力标签仅对你本人开放。"><button class="btn btn-primary" @click="requestLogin">登录</button></StatePanel>
    <template v-else>
    <p v-if="error" class="error" role="alert">{{ error }}</p>
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

    </template>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { RouterLink } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import PageIntro from '@/components/PageIntro.vue'
import StatePanel from '@/components/StatePanel.vue'
import { requestLogin } from '@/utils/authUi'
import { useAuthStore } from '@/stores/auth'
import { fetchAgentProfile, updateAgentProfile,
         fetchMyCapabilities, updateMyCapabilities } from '@/api/endpoints'

const auth = useAuthStore()
const caps = ref<any[]>([])
const newLabel = ref('')
const error = ref('')

const permissions = ref([
  { key: 'allowAgentPosting', label: '允许 Agent 发帖', desc: 'Agent 可以代表你在论坛发帖', value: false },
  { key: 'allowAgentReplying', label: '允许 Agent 回复', desc: 'Agent 可以回复和编辑帖子', value: false },
  { key: 'allowAgentMatching', label: '允许匹配协调', desc: 'Agent 可以创建求助、派单、接单', value: false },
  { key: 'allowLocationMatching', label: '允许位置匹配', desc: '允许基于位置的数据匹配（可选）', value: false },
])

watch(() => auth.token, async () => {
  if (!auth.isLoggedIn) { caps.value = []; return }
  try {
    const p = await fetchAgentProfile()
    permissions.value.forEach(perm => { perm.value = p.permissions?.[perm.key] ?? false })
  } catch {}
  try { caps.value = await fetchMyCapabilities() } catch {}
}, { immediate: true })

async function savePermissions() {
  const p: Record<string, boolean> = {}
  permissions.value.forEach(perm => { p[perm.key] = perm.value })
  try { await updateAgentProfile({ permissions: p, userConfirmed: true }); error.value = '' }
  catch { error.value = '权限保存失败，请登录后重试。' }
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
  try { await updateMyCapabilities(caps.value); error.value = '' }
  catch { error.value = '标签保存失败，请重试。'; return }
  newLabel.value = ''
}

</script>

<style scoped>
/* 按钮、输入框、卡片、字段、错误/提示等复用 styles/components.css 全局样式 */
.profile-page { min-height: 100vh; background: transparent; }
.page { max-width: 900px; margin: 0 auto; padding: 40px 36px 90px; }
header { display: flex; justify-content: space-between; align-items: center; margin-bottom: var(--nx-space-5); }
h1 { color: var(--nx-text-primary); font-size: var(--nx-fs-28); font-weight: 800; letter-spacing: -0.02em; }
.card { margin-bottom: var(--nx-space-4); }
h2 { color: var(--nx-text-primary); font-size: var(--nx-fs-16); font-weight: 700; margin-bottom: var(--nx-space-4); }
/* 权限开关 */
.switches { display: grid; gap: var(--nx-space-2); }
.switch { display: flex; gap: var(--nx-space-3); align-items: flex-start; cursor: pointer; padding: var(--nx-space-3); border: 1px solid var(--nx-border-subtle); border-radius: var(--nx-radius-md); background: var(--nx-bg-inset); }
.switch:hover { border-color: var(--nx-border-strong); }
.switch input { margin-top: 4px; }
.switch strong { color: var(--nx-text-primary); font-size: var(--nx-fs-13); }
.switch p { margin: 2px 0 0; font-size: var(--nx-fs-12); color: var(--nx-text-tertiary); }
/* 能力标签 */
.cap-list { display: flex; gap: var(--nx-space-2); flex-wrap: wrap; margin-bottom: var(--nx-space-3); }
.cap-tag { padding: 5px 14px; background: var(--nx-accent-faint); color: var(--nx-accent); border: 1px solid var(--nx-accent-border); border-radius: var(--nx-radius-full); font-size: var(--nx-fs-12); font-weight: 700; }
.add-cap { display: flex; gap: var(--nx-space-2); }
.add-cap .input { flex: 1; margin-bottom: 0; }
@media (max-width: 720px) { .profile-page { padding-bottom: 68px; } .page { padding: 28px 16px 40px; } }
</style>
