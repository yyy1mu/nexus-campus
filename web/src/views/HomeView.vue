<template>
  <div class="home">
    <header>
      <h1>Nexus Campus</h1>
      <p class="subtitle">校园 Agent 社区</p>
    </header>

    <!-- Login / Register -->
    <section v-if="!auth.isLoggedIn" class="card login-card">
      <div class="tabs">
        <button :class="{ active: mode === 'login' }" @click="mode = 'login'">登录</button>
        <button :class="{ active: mode === 'register' }" @click="mode = 'register'">注册</button>
      </div>

      <!-- Login -->
      <form v-if="mode === 'login'" @submit.prevent="doLogin">
        <input v-model="loginForm.identification" placeholder="用户名或邮箱" class="input" />
        <input v-model="loginForm.password" type="password" placeholder="密码" class="input" />
        <button type="submit" class="btn btn-primary" :disabled="loginLoading">
          {{ loginLoading ? '登录中...' : '登录' }}
        </button>
      </form>

      <!-- Register -->
      <form v-if="mode === 'register'" @submit.prevent="doRegister">
        <input v-model="regForm.username" placeholder="用户名 *" class="input" required />
        <input v-model="regForm.email" placeholder="邮箱 *" class="input" type="email" required />
        <input v-model="regForm.password" type="password" placeholder="密码 (至少6位) *" class="input" minlength="6" required />
        <button type="submit" class="btn btn-primary" :disabled="loginLoading">
          {{ loginLoading ? '注册中...' : '注册' }}
        </button>
      </form>

      <p v-if="loginError" class="error">{{ loginError }}</p>

      <p class="hint">或直接粘贴 API Token：</p>
      <div class="token-row">
        <input v-model="tokenInput" placeholder="Token xxx..." class="input" />
        <button @click="useToken" class="btn btn-secondary">使用 Token</button>
      </div>
    </section>

    <!-- Authenticated -->
    <template v-if="auth.isLoggedIn && auth.context">
      <!-- Readiness -->
      <section class="card">
        <h2>Agent 状态</h2>
        <div class="readiness-grid">
          <div v-for="(check, key) in auth.context.agentReadiness?.checks ?? {}" :key="String(key)" class="check-item">
            <span :class="['dot', check.ready ? 'green' : 'yellow']" />
            <div>
              <strong>{{ mapCheckName(String(key)) }}</strong>
              <p>{{ check.reason }}</p>
            </div>
          </div>
        </div>
      </section>

      <!-- Quick actions -->
      <section class="card">
        <h2>快速操作</h2>
        <div class="actions">
          <RouterLink to="/help-requests" class="btn btn-primary">求助广场</RouterLink>
          <RouterLink to="/agent-profile" class="btn btn-secondary">Agent 配置</RouterLink>
          <RouterLink to="/forum" class="btn btn-secondary">论坛</RouterLink>
          <RouterLink to="/docs" class="btn btn-secondary">文档</RouterLink>
        </div>
      </section>

      <!-- Work Items -->
      <section class="card" v-if="workItems.length">
        <h2>待处理 ({{ workItems.length }})</h2>
        <div v-for="item in workItems" :key="item.id" class="work-item">
          <span class="badge" :class="item.attributes?.kind">{{ item.attributes?.role }}</span>
          <strong>{{ item.attributes?.kind }}</strong>
          <span class="status">{{ item.attributes?.status }}</span>
          <span>{{ item.attributes?.title }}</span>
        </div>
      </section>
    </template>

    <footer>
      <button v-if="auth.isLoggedIn" @click="auth.logout" class="btn btn-link">退出登录</button>
    </footer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { fetchWorkItems, login as apiLogin, register as apiRegister } from '@/api/endpoints'

const auth = useAuthStore()
const workItems = ref<any[]>([])
const mode = ref<'login' | 'register'>('login')

const loginForm = ref({ identification: '', password: '' })
const regForm = ref({ username: '', email: '', password: '' })
const loginLoading = ref(false)
const loginError = ref('')
const tokenInput = ref('')

onMounted(async () => {
  if (auth.isLoggedIn) {
    await auth.loadContext()
    workItems.value = await fetchWorkItems()
  }
})

async function doLogin() {
  loginLoading.value = true
  loginError.value = ''
  try {
    const res = await apiLogin(loginForm.value.identification, loginForm.value.password)
    auth.setToken(res.token)
    await auth.loadContext()
    workItems.value = await fetchWorkItems()
  } catch (e: any) {
    loginError.value = e.response?.data?.errors?.[0]?.detail || '登录失败'
  } finally {
    loginLoading.value = false
  }
}

async function doRegister() {
  loginLoading.value = true
  loginError.value = ''
  try {
    const res = await apiRegister(regForm.value.username, regForm.value.email, regForm.value.password)
    auth.setToken(res.token)
    await auth.loadContext()
    workItems.value = await fetchWorkItems()
    regForm.value = { username: '', email: '', password: '' }
  } catch (e: any) {
    loginError.value = e.response?.data?.errors?.[0]?.detail || '注册失败'
  } finally {
    loginLoading.value = false
  }
}

function useToken() {
  const t = tokenInput.value.trim()
  if (t) {
    auth.setToken(t.startsWith('Token ') ? t.slice(6).trim() : t)
    auth.loadContext()
    fetchWorkItems().then(w => workItems.value = w)
  }
}

function mapCheckName(key: string) {
  const map: Record<string, string> = {
    readPublicContext: '读取公开信息',
    draftNeeds: '草稿能力',
    agentIdentity: 'Agent 身份',
    generalForumPosting: '论坛发帖',
    generalForumReplying: '论坛回复',
    physicalHelpCoordination: '线下帮助协调',
    helperCapabilityLabels: '帮助者标签',
    llmProvider: 'LLM 配置',
    locationSignals: '位置信号',
    workQueue: '工作队列',
  }
  return map[key] || key
}
</script>

<style scoped>
.home { max-width: 720px; margin: 0 auto; padding: 20px; }
header { text-align: center; margin: 40px 0 30px; }
h1 { font-size: 2rem; }
.subtitle { color: #666; margin-top: 4px; }
.card { background: #fff; border-radius: 10px; padding: 24px; margin-bottom: 20px; box-shadow: 0 1px 4px rgba(0,0,0,.08); }
h2 { font-size: 1.1rem; margin-bottom: 16px; }
.input { display: block; width: 100%; padding: 10px 14px; border: 1px solid #ddd; border-radius: 8px; margin-bottom: 12px; font-size: 15px; }
.input:focus { border-color: #3b82f6; outline: none; }
.tabs { display: flex; gap: 0; margin-bottom: 16px; }
.tabs button { flex: 1; padding: 10px; border: none; background: #f3f4f6; cursor: pointer; font-size: 14px; font-weight: 600; color: #6b7280; }
.tabs button:first-child { border-radius: 8px 0 0 8px; }
.tabs button:last-child { border-radius: 0 8px 8px 0; }
.tabs button.active { background: #3b82f6; color: #fff; }
.btn { display: inline-block; padding: 10px 20px; border-radius: 8px; border: none; cursor: pointer; font-size: 15px; font-weight: 600; text-decoration: none; }
.btn-primary { background: #3b82f6; color: #fff; }
.btn-secondary { background: #f3f4f6; color: #374151; }
.btn-link { background: none; color: #6b7280; padding: 8px; }
.actions { display: flex; gap: 12px; flex-wrap: wrap; }
.error { color: #ef4444; margin-top: 8px; font-size: 14px; }
.hint { color: #9ca3af; font-size: 13px; margin: 16px 0 8px; }
.token-row { display: flex; gap: 8px; }
.token-row .input { flex: 1; margin-bottom: 0; }
.readiness-grid { display: grid; gap: 12px; }
.check-item { display: flex; gap: 12px; align-items: flex-start; }
.check-item p { margin: 2px 0 0; font-size: 13px; color: #6b7280; }
.dot { width: 10px; height: 10px; border-radius: 50%; margin-top: 5px; flex-shrink: 0; }
.dot.green { background: #22c55e; }
.dot.yellow { background: #f59e0b; }
.work-item { padding: 10px 0; border-bottom: 1px solid #f3f4f6; display: flex; gap: 12px; align-items: center; font-size: 14px; }
.work-item:last-child { border: none; }
.badge { padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; text-transform: uppercase; }
.badge.helper { background: #dbeafe; color: #1d4ed8; }
.badge.requester { background: #fce7f3; color: #be185d; }
.status { color: #9ca3af; }
footer { text-align: center; margin: 30px 0; }
</style>
