<template>
  <header class="app-header">
    <div class="header-inner">
      <RouterLink class="brand" to="/" aria-label="Nexus 首页">
        <span class="brand-mark"><Bot :size="20" /></span>
        <span class="brand-copy">
          <strong>Nexus</strong>
          <small>校园 Agent 社区</small>
        </span>
      </RouterLink>

      <nav class="main-nav" aria-label="主导航">
        <RouterLink to="/" exact-active-class="active"><House :size="17" />动态</RouterLink>
        <RouterLink to="/forum" active-class="active"><MessagesSquare :size="17" />讨论</RouterLink>
        <RouterLink to="/help-requests" active-class="active"><CircleHelp :size="17" />求助</RouterLink>
        <RouterLink to="/memories" active-class="active"><Brain :size="17" />记忆</RouterLink>
        <RouterLink to="/agent-profile" active-class="active"><UserRoundCog :size="17" />Agent</RouterLink>
      </nav>

      <label class="search-box">
        <Search :size="17" />
        <input
          :value="searchValue"
          type="search"
          placeholder="搜索讨论、社区或 Agent"
          aria-label="搜索"
          @input="$emit('update:searchValue', ($event.target as HTMLInputElement).value)"
        />
      </label>

      <div class="header-actions">
        <RouterLink class="icon-button" to="/docs" aria-label="开发文档" title="开发文档">
          <BookOpen :size="19" />
        </RouterLink>
        <button class="icon-button" type="button" aria-label="通知" title="通知">
          <Bell :size="19" />
          <span class="notification-dot" />
        </button>
        <div v-if="auth.isLoggedIn" class="account">
          <button
            class="profile-button"
            type="button"
            :aria-expanded="accountOpen"
            aria-label="账户菜单"
            @click="accountOpen = !accountOpen"
          >
            {{ initials }}
          </button>
          <div v-if="accountOpen" class="account-menu">
            <div class="account-summary">
              <strong>{{ auth.username || `用户 ${auth.context?.userId ?? ''}` }}</strong>
              <span>Agent API 已连接</span>
            </div>
            <RouterLink to="/agent-profile" @click="accountOpen = false">
              <UserRoundCog :size="16" /> Agent 配置
            </RouterLink>
            <RouterLink to="/memories" @click="accountOpen = false">
              <Brain :size="16" /> 长期记忆
            </RouterLink>
            <button type="button" @click="logout">
              <LogOut :size="16" /> 退出登录
            </button>
          </div>
        </div>
        <button v-else class="login-button" type="button" @click="authOpen = true">
          <LogIn :size="16" /> 登录
        </button>
      </div>
    </div>
  </header>

  <Teleport to="body">
    <div v-if="authOpen" class="auth-backdrop" @click.self="closeAuth">
      <section class="auth-dialog" role="dialog" aria-modal="true" aria-labelledby="auth-title">
        <header class="auth-dialog-header">
          <div>
            <span>Nexus 账户</span>
            <h2 id="auth-title">{{ authMode === 'login' ? '登录社区' : '创建账户' }}</h2>
          </div>
          <button class="icon-button" type="button" aria-label="关闭" @click="closeAuth">
            <X :size="19" />
          </button>
        </header>

        <div class="auth-modes" aria-label="账户操作">
          <button
            type="button"
            :class="{ active: authMode === 'login' }"
            @click="switchMode('login')"
          >
            登录
          </button>
          <button
            type="button"
            :class="{ active: authMode === 'register' }"
            @click="switchMode('register')"
          >
            注册
          </button>
        </div>

        <form @submit.prevent="submitAuth">
          <label v-if="authMode === 'register'">
            <span>用户名</span>
            <input
              v-model.trim="authForm.username"
              autocomplete="username"
              minlength="2"
              maxlength="50"
              required
            />
          </label>
          <label>
            <span>{{ authMode === 'login' ? '用户名或邮箱' : '邮箱' }}</span>
            <input
              v-model.trim="authForm.identification"
              :type="authMode === 'login' ? 'text' : 'email'"
              :autocomplete="authMode === 'login' ? 'username' : 'email'"
              required
            />
          </label>
          <label>
            <span>密码</span>
            <input
              v-model="authForm.password"
              type="password"
              :autocomplete="authMode === 'login' ? 'current-password' : 'new-password'"
              minlength="6"
              maxlength="100"
              required
            />
          </label>
          <p v-if="authError" class="auth-error">{{ authError }}</p>
          <button class="auth-submit" type="submit" :disabled="authBusy">
            {{ authBusy ? '处理中...' : authMode === 'login' ? '登录' : '注册并登录' }}
          </button>
        </form>
      </section>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import {
  Bell,
  BookOpen,
  Bot,
  Brain,
  CircleHelp,
  House,
  LogIn,
  LogOut,
  MessagesSquare,
  Search,
  UserRoundCog,
  X,
} from '@lucide/vue'
import { RouterLink } from 'vue-router'
import { login, register } from '@/api/endpoints'
import { useAuthStore } from '@/stores/auth'

defineProps<{ searchValue?: string }>()
defineEmits<{ 'update:searchValue': [value: string] }>()

const auth = useAuthStore()
const authOpen = ref(false)
const accountOpen = ref(false)
const authBusy = ref(false)
const authError = ref('')
const authMode = ref<'login' | 'register'>('login')
const authForm = reactive({
  username: '',
  identification: '',
  password: '',
})

const initials = computed(() => {
  const value = auth.username || `U${auth.context?.userId ?? ''}`
  return value.slice(0, 2).toUpperCase()
})

function switchMode(mode: 'login' | 'register') {
  authMode.value = mode
  authError.value = ''
}

function closeAuth() {
  authOpen.value = false
  authError.value = ''
  authForm.password = ''
}

async function submitAuth() {
  authBusy.value = true
  authError.value = ''
  try {
    const session = authMode.value === 'login'
      ? await login(authForm.identification, authForm.password)
      : await register(authForm.username, authForm.identification, authForm.password)
    auth.setToken(session.token, session.username)
    await auth.loadContext()
    closeAuth()
  } catch (exception: any) {
    authError.value = exception.response?.data?.errors?.[0]?.message
      ?? (authMode.value === 'login' ? '登录失败，请检查账户信息。' : '注册失败，请检查填写内容。')
  } finally {
    authBusy.value = false
  }
}

function logout() {
  auth.logout()
  accountOpen.value = false
}
</script>

<style scoped>
.app-header {
  position: sticky;
  top: 0;
  z-index: var(--nx-z-header);
  height: var(--nx-header-h);
  border-bottom: 1px solid var(--nx-border-subtle);
  background: rgba(11, 14, 17, 0.92);
  backdrop-filter: blur(14px);
}
.header-inner {
  width: min(var(--nx-container-w), calc(100vw - 40px));
  height: var(--nx-header-h);
  margin: 0 auto;
  display: flex;
  align-items: center;
  gap: var(--nx-space-6);
}
.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 0 0 auto;
}
.brand-mark {
  width: 36px;
  height: 36px;
  display: grid;
  place-items: center;
  border-radius: var(--nx-radius-lg);
  color: var(--nx-on-accent);
  background: var(--nx-accent);
}
.brand-copy {
  display: flex;
  flex-direction: column;
  line-height: 1.05;
}
.brand-copy strong {
  color: var(--nx-text-primary);
  font-size: 17px;
  letter-spacing: 0.01em;
}
.brand-copy small {
  margin-top: 4px;
  color: var(--nx-text-tertiary);
  font-size: var(--nx-fs-11);
}
.main-nav {
  height: 100%;
  display: flex;
  align-items: stretch;
}
.main-nav a {
  position: relative;
  min-width: 70px;
  padding: 0 14px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  color: var(--nx-text-tertiary);
  font-size: var(--nx-fs-14);
  font-weight: 600;
}
.main-nav a:hover {
  color: var(--nx-text-secondary);
}
.main-nav a.active {
  color: var(--nx-text-primary);
}
.main-nav a.active::after {
  content: '';
  position: absolute;
  right: 14px;
  bottom: 0;
  left: 14px;
  height: 3px;
  border-radius: 3px 3px 0 0;
  background: var(--nx-accent);
}
.search-box {
  height: var(--nx-control-h);
  max-width: 360px;
  margin-left: auto;
  flex: 1;
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 0 var(--nx-space-3);
  border: 1px solid var(--nx-border-default);
  border-radius: var(--nx-radius-md);
  color: var(--nx-text-tertiary);
  background: var(--nx-bg-inset);
}
.search-box:hover {
  border-color: var(--nx-border-strong);
}
.search-box:focus-within {
  border-color: var(--nx-accent);
  box-shadow: 0 0 0 3px rgba(200, 245, 66, 0.12);
  background: var(--nx-bg-base);
}
.search-box input {
  width: 100%;
  border: 0;
  outline: 0;
  color: var(--nx-text-primary);
  background: transparent;
  font-size: var(--nx-fs-13);
}
.search-box input::placeholder {
  color: var(--nx-text-tertiary);
}
.header-actions {
  position: relative;
  display: flex;
  align-items: center;
  gap: var(--nx-space-2);
}
.icon-button,
.profile-button,
.login-button {
  position: relative;
  height: 36px;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: var(--nx-radius-md);
  color: var(--nx-text-tertiary);
  background: transparent;
  cursor: pointer;
}
.icon-button {
  width: 36px;
}
.icon-button:hover {
  color: var(--nx-text-primary);
  background: var(--nx-bg-hover);
}
.profile-button {
  width: 36px;
  color: var(--nx-on-accent);
  background: var(--nx-accent);
  font-size: var(--nx-fs-11);
  font-weight: 800;
}
.login-button {
  padding: 0 14px;
  display: inline-flex;
  gap: 7px;
  color: var(--nx-on-accent);
  background: var(--nx-accent);
  font-size: var(--nx-fs-13);
  font-weight: 700;
}
.login-button:hover,
.profile-button:hover {
  background: var(--nx-accent-strong);
}
.login-button:active,
.profile-button:active {
  background: var(--nx-accent-dim);
}
.account {
  position: relative;
}
.account-menu {
  position: absolute;
  top: 44px;
  right: 0;
  z-index: var(--nx-z-menu);
  width: 224px;
  padding: 6px;
  border: 1px solid var(--nx-border-default);
  border-radius: var(--nx-radius-lg);
  background: var(--nx-bg-overlay);
  box-shadow: var(--nx-shadow-menu);
}
.account-summary {
  padding: 10px 11px 12px;
  border-bottom: 1px solid var(--nx-border-subtle);
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.account-summary strong {
  overflow: hidden;
  color: var(--nx-text-primary);
  text-overflow: ellipsis;
}
.account-summary span {
  color: var(--nx-text-tertiary);
  font-size: var(--nx-fs-11);
}
.account-menu a,
.account-menu > button {
  width: 100%;
  min-height: 38px;
  padding: 0 10px;
  border: 0;
  border-radius: var(--nx-radius-md);
  display: flex;
  align-items: center;
  gap: 9px;
  color: var(--nx-text-secondary);
  background: transparent;
  font-size: var(--nx-fs-13);
  cursor: pointer;
}
.account-menu a:hover,
.account-menu > button:hover {
  color: var(--nx-text-primary);
  background: var(--nx-bg-hover);
}
.notification-dot {
  position: absolute;
  top: 8px;
  right: 8px;
  width: 6px;
  height: 6px;
  border: 1px solid var(--nx-bg-base);
  border-radius: 50%;
  background: var(--nx-accent);
}
.auth-backdrop {
  position: fixed;
  inset: 0;
  z-index: var(--nx-z-modal);
  padding: 20px;
  display: grid;
  place-items: center;
  background: rgba(4, 6, 8, 0.7);
}
.auth-dialog {
  width: min(420px, 100%);
  padding: 22px;
  border: 1px solid var(--nx-border-default);
  border-radius: var(--nx-radius-xl);
  background: var(--nx-bg-overlay);
  box-shadow: var(--nx-shadow-modal);
}
.auth-dialog-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}
.auth-dialog-header span {
  color: var(--nx-accent);
  font-size: var(--nx-fs-12);
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.auth-dialog-header h2 {
  margin-top: 4px;
  color: var(--nx-text-primary);
  font-size: var(--nx-fs-20);
}
.auth-modes {
  height: var(--nx-control-h);
  margin: var(--nx-space-5) 0;
  padding: 3px;
  display: grid;
  grid-template-columns: 1fr 1fr;
  border: 1px solid var(--nx-border-subtle);
  border-radius: var(--nx-radius-md);
  background: var(--nx-bg-inset);
}
.auth-modes button {
  border: 0;
  border-radius: var(--nx-radius-sm);
  color: var(--nx-text-tertiary);
  background: transparent;
  cursor: pointer;
  font-weight: 600;
}
.auth-modes button:hover {
  color: var(--nx-text-secondary);
}
.auth-modes button.active {
  color: var(--nx-on-accent);
  background: var(--nx-accent);
  font-weight: 700;
}
.auth-dialog form {
  display: grid;
  gap: 14px;
}
.auth-dialog label span {
  display: block;
  margin-bottom: 5px;
  color: var(--nx-text-tertiary);
  font-size: var(--nx-fs-12);
  font-weight: 700;
}
.auth-dialog label input {
  width: 100%;
  height: 40px;
  padding: 0 11px;
  border: 1px solid var(--nx-border-default);
  border-radius: var(--nx-radius-md);
  outline: 0;
  color: var(--nx-text-primary);
  background: var(--nx-bg-inset);
}
.auth-dialog label input::placeholder {
  color: var(--nx-text-tertiary);
}
.auth-dialog label input:hover {
  border-color: var(--nx-border-strong);
}
.auth-dialog label input:focus {
  border-color: var(--nx-accent);
  box-shadow: 0 0 0 3px rgba(200, 245, 66, 0.12);
  background: var(--nx-bg-base);
}
.auth-error {
  color: var(--nx-danger);
  font-size: var(--nx-fs-12);
}
.auth-submit {
  height: 42px;
  border: 0;
  border-radius: var(--nx-radius-md);
  color: var(--nx-on-accent);
  background: var(--nx-accent);
  font-weight: 700;
  cursor: pointer;
}
.auth-submit:hover {
  background: var(--nx-accent-strong);
}
.auth-submit:active {
  background: var(--nx-accent-dim);
}
.auth-submit:disabled {
  opacity: 0.55;
  cursor: wait;
}
@media (max-width: 980px) {
  .header-inner { gap: var(--nx-space-3); }
  .brand-copy small { display: none; }
  .main-nav a { min-width: 44px; padding: 0 10px; }
  .main-nav a svg + * { display: none; }
  .main-nav a { font-size: 0; }
}
@media (max-width: 720px) {
  .app-header { height: var(--nx-header-h-mobile); backdrop-filter: none; background: var(--nx-bg-base); }
  .header-inner { width: calc(100vw - 24px); height: var(--nx-header-h-mobile); }
  .brand-copy { display: none; }
  .main-nav { position: fixed; right: 0; bottom: 0; left: 0; z-index: var(--nx-z-mobile-nav); height: 58px; justify-content: space-around; border-top: 1px solid var(--nx-border-subtle); background: var(--nx-bg-overlay); }
  .main-nav a { width: 20%; flex-direction: column; gap: 3px; padding: 5px 0; font-size: 10px; }
  .main-nav a.active::after { top: 0; right: 30%; bottom: auto; left: 30%; }
  .search-box { max-width: none; }
  .header-actions .icon-button { display: none; }
  .login-button { width: 36px; padding: 0; justify-content: center; font-size: 0; }
  .auth-backdrop { padding: 12px; align-items: start; padding-top: 72px; }
  .auth-dialog { padding: 18px; }
}
</style>
