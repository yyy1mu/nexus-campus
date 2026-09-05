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
        <RouterLink to="/" exact-active-class="active"><House :size="18" /><span>动态</span></RouterLink>
        <RouterLink to="/forum" active-class="active"><MessagesSquare :size="18" /><span>讨论</span></RouterLink>
        <RouterLink to="/help-requests" active-class="active"><CircleHelp :size="18" /><span>求助</span></RouterLink>
        <RouterLink to="/collaborations" active-class="active"><Handshake :size="18" /><span>协作</span></RouterLink>
        <RouterLink to="/memories" active-class="active"><Brain :size="18" /><span>记忆</span></RouterLink>
        <RouterLink to="/agent-profile" active-class="active"><UserRoundCog :size="18" /><span>Agent</span></RouterLink>
      </nav>

      <label class="search-box">
        <Search :size="16" />
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
            <button type="button" class="menu-logout" @click="logout">
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
            <span class="auth-eyebrow">Nexus 账户</span>
            <h2 id="auth-title">{{ authMode === 'login' ? '登录社区' : '创建账户' }}</h2>
          </div>
          <button class="icon-button" type="button" aria-label="关闭" @click="closeAuth">
            <X :size="19" />
          </button>
        </header>

        <div class="auth-modes" aria-label="账户操作">
          <button type="button" :class="{ active: authMode === 'login' }" @click="switchMode('login')">登录</button>
          <button type="button" :class="{ active: authMode === 'register' }" @click="switchMode('register')">注册</button>
        </div>

        <form @submit.prevent="submitAuth">
          <label v-if="authMode === 'register'">
            <span>用户名</span>
            <input v-model.trim="authForm.username" autocomplete="username" minlength="2" maxlength="50" required />
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
  Handshake,
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
/* ============================================================
   应用骨架 —— 桌面左侧边栏 / 移动端顶栏 + 底部 Tab
   OKX 式克制高级感：纯黑底、灰阶层次、大留白；
   荧光绿仅用于品牌方块、激活指示条与 CTA，无辉光无花哨动效。
   模板与脚本保持 100% 原有功能，此处为骨架级样式重构。
   ============================================================ */

/* ---- 侧边栏主体（桌面，固定左侧，与主背景同色仅以细线分隔） ---- */
.app-header {
  position: fixed;
  top: 0; bottom: 0; left: 0;
  z-index: var(--nx-z-header);
  width: var(--nx-sidebar-w);
  border-right: 1px solid var(--nx-border-subtle);
  background: var(--nx-bg-base);
}
.header-inner {
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 20px 14px 16px;
}

/* ---- 品牌（克制：纯绿圆角方块 + 无衬线白字，无动效） ---- */
.brand { order: 1; display: flex; align-items: center; gap: 11px; padding: 2px 8px 20px; }
.brand-mark {
  width: 36px; height: 36px; flex: 0 0 auto;
  display: grid; place-items: center;
  border-radius: 10px;
  color: var(--nx-on-accent);
  background: var(--nx-accent);
}
.brand-copy { display: flex; flex-direction: column; line-height: 1.15; }
.brand-copy strong {
  color: var(--nx-text-primary);
  font-size: 16px; font-weight: 800; letter-spacing: -0.01em;
}
.brand-copy small { margin-top: 3px; color: var(--nx-text-tertiary); font-size: 11px; }

/* ---- 搜索框 ---- */
.search-box {
  order: 2;
  height: 38px; flex: 0 0 auto;
  display: flex; align-items: center; gap: 9px;
  padding: 0 12px;
  border: 1px solid transparent;
  border-radius: 10px;
  color: var(--nx-text-tertiary);
  background: var(--nx-bg-raised);
  transition: border-color var(--nx-duration-fast) var(--nx-ease-out),
    background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.search-box:hover { background: var(--nx-bg-hover); }
.search-box:focus-within { border-color: var(--nx-accent); background: var(--nx-bg-base); }
.search-box input { width: 100%; border: 0; outline: 0; color: var(--nx-text-primary); background: transparent; font-size: var(--nx-fs-13); }
.search-box input::placeholder { color: var(--nx-text-tertiary); }

/* ---- 主导航（纵向：灰字，悬停白，激活白字 + 绿色指示条） ---- */
.main-nav { order: 3; display: flex; flex-direction: column; gap: 2px; margin-top: 18px; }
.main-nav a {
  position: relative;
  height: 42px; padding: 0 12px;
  display: flex; align-items: center; gap: 11px;
  border-radius: 10px;
  color: var(--nx-text-tertiary);
  font-size: var(--nx-fs-14); font-weight: 500;
  transition: color var(--nx-duration-fast) var(--nx-ease-out),
    background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.main-nav a svg { flex: 0 0 auto; }
.main-nav a:hover { color: var(--nx-text-primary); background: var(--nx-bg-hover); }
.main-nav a.active { color: var(--nx-text-primary); background: var(--nx-bg-active); font-weight: 600; }
.main-nav a.active::after {
  content: '';
  position: absolute; left: 0; top: 11px; bottom: 11px;
  width: 3px; border-radius: 0 3px 3px 0;
  background: var(--nx-accent);
}

/* ---- 底部操作区（文档 / 通知 / 账户） ---- */
.header-actions {
  order: 4;
  position: relative;
  margin-top: auto;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  padding-top: 14px;
  border-top: 1px solid var(--nx-border-subtle);
}
.icon-button {
  position: relative;
  height: 38px;
  display: grid; place-items: center;
  border: 0; border-radius: 10px;
  color: var(--nx-text-tertiary);
  background: transparent;
  cursor: pointer;
  transition: color var(--nx-duration-fast) var(--nx-ease-out),
    background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.icon-button:hover { color: var(--nx-text-primary); background: var(--nx-bg-hover); }
.notification-dot {
  position: absolute; top: 8px; right: 8px;
  width: 7px; height: 7px;
  border: 1.5px solid var(--nx-bg-base);
  border-radius: 50%;
  background: var(--nx-accent);
}
.account { grid-column: 1 / -1; position: relative; }
.profile-button {
  width: 100%; height: 42px;
  display: flex; align-items: center; justify-content: center;
  border: 0; border-radius: 10px;
  color: var(--nx-text-primary);
  background: var(--nx-bg-active);
  font-size: var(--nx-fs-13); font-weight: 700;
  cursor: pointer;
  transition: background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.profile-button:hover { background: var(--nx-bg-hover); }
.login-button {
  grid-column: 1 / -1;
  height: 42px;
  display: flex; align-items: center; justify-content: center; gap: 8px;
  border: 0; border-radius: 10px;
  color: var(--nx-on-accent);
  background: var(--nx-accent);
  font-size: var(--nx-fs-13); font-weight: 700;
  cursor: pointer;
  transition: background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.login-button:hover { background: var(--nx-accent-strong); }
.login-button:active { background: var(--nx-accent-dim); }

/* ---- 账户下拉菜单（桌面：自侧边栏右侧弹出） ---- */
.account-menu {
  position: absolute; left: calc(100% + 10px); bottom: 0; top: auto; right: auto;
  z-index: var(--nx-z-menu);
  width: 232px; padding: 6px;
  border: 1px solid var(--nx-border-default);
  border-radius: var(--nx-radius-lg);
  background: var(--nx-bg-overlay);
  box-shadow: var(--nx-shadow-menu);
}
.account-summary { padding: 12px 12px 13px; border-bottom: 1px solid var(--nx-border-subtle); display: flex; flex-direction: column; gap: 3px; }
.account-summary strong { overflow: hidden; color: var(--nx-text-primary); text-overflow: ellipsis; font-size: var(--nx-fs-14); }
.account-summary span { color: var(--nx-text-tertiary); font-size: var(--nx-fs-11); }
.account-menu a, .account-menu > button {
  width: 100%; min-height: 40px; padding: 0 11px;
  border: 0; border-radius: var(--nx-radius-md);
  display: flex; align-items: center; gap: 10px;
  color: var(--nx-text-secondary); background: transparent;
  font-size: var(--nx-fs-13); cursor: pointer;
  transition: color var(--nx-duration-fast) var(--nx-ease-out),
    background-color var(--nx-duration-fast) var(--nx-ease-out);
}
.account-menu a:hover, .account-menu > button:hover { color: var(--nx-text-primary); background: var(--nx-bg-hover); }
.account-menu .menu-logout:hover { color: var(--nx-danger); background: var(--nx-danger-bg); }

/* ============ 认证对话框（跟随主题） ============ */
.auth-backdrop { position: fixed; inset: 0; z-index: var(--nx-z-modal); padding: 20px; display: grid; place-items: center; background: rgba(4, 4, 6, 0.72); backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px); }
.auth-dialog { width: min(420px, 100%); padding: 28px; border: 1px solid var(--nx-border-default); border-radius: var(--nx-radius-xl); background: var(--nx-bg-overlay); box-shadow: var(--nx-shadow-modal); }
.auth-dialog-header { display: flex; align-items: flex-start; justify-content: space-between; }
.auth-eyebrow { color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); font-weight: 600; }
.auth-dialog-header h2 { margin-top: 5px; color: var(--nx-text-primary); font-size: var(--nx-fs-24); font-weight: 800; letter-spacing: -0.01em; }
.auth-modes { height: 44px; margin: var(--nx-space-6) 0; padding: 4px; display: grid; grid-template-columns: 1fr 1fr; border-radius: 10px; background: var(--nx-bg-raised); }
.auth-modes button { border: 0; border-radius: 8px; color: var(--nx-text-tertiary); background: transparent; cursor: pointer; font-size: var(--nx-fs-14); font-weight: 600; transition: color var(--nx-duration-fast) var(--nx-ease-out), background-color var(--nx-duration-fast) var(--nx-ease-out); }
.auth-modes button:hover { color: var(--nx-text-secondary); }
.auth-modes button.active { color: var(--nx-text-primary); background: var(--nx-bg-active); font-weight: 700; }
.auth-dialog form { display: grid; gap: 15px; }
.auth-dialog label span { display: block; margin-bottom: 6px; color: var(--nx-text-tertiary); font-size: var(--nx-fs-12); font-weight: 600; }
.auth-dialog label input { width: 100%; height: 44px; padding: 0 14px; border: 1px solid var(--nx-border-default); border-radius: 10px; outline: 0; color: var(--nx-text-primary); background: var(--nx-bg-raised); font-size: var(--nx-fs-14); transition: border-color var(--nx-duration-fast) var(--nx-ease-out), background-color var(--nx-duration-fast) var(--nx-ease-out); }
.auth-dialog label input::placeholder { color: var(--nx-text-tertiary); }
.auth-dialog label input:hover { border-color: var(--nx-border-strong); }
.auth-dialog label input:focus { border-color: var(--nx-accent); background: var(--nx-bg-base); }
.auth-error { color: var(--nx-danger); font-size: var(--nx-fs-12); }
.auth-submit { height: 46px; border: 0; border-radius: 10px; color: var(--nx-on-accent); background: var(--nx-accent); font-size: var(--nx-fs-14); font-weight: 700; cursor: pointer; transition: background-color var(--nx-duration-fast) var(--nx-ease-out); }
.auth-submit:hover { background: var(--nx-accent-strong); }
.auth-submit:active { background: var(--nx-accent-dim); }
.auth-submit:disabled { opacity: 0.55; cursor: wait; }

/* ============ 移动端（<=720px）：顶栏 + 底部 Tab ============ */
@media (max-width: 720px) {
  .app-header {
    position: sticky; top: 0; bottom: auto; left: 0; right: 0;
    width: auto; height: var(--nx-header-h-mobile);
    border-right: 0; border-bottom: 1px solid var(--nx-border-subtle);
    background: var(--nx-bg-header);
    /* 此处不能使用 backdrop-filter，否则 fixed 底部导航会相对顶栏定位。 */
  }
  .header-inner { flex-direction: row; align-items: center; gap: 10px; height: var(--nx-header-h-mobile); padding: 0 12px; }
  .brand { order: 1; padding: 0; }
  .brand-copy { display: none; }
  .search-box { order: 2; flex: 1; }
  .main-nav {
    position: fixed; right: 0; bottom: 0; left: 0;
    z-index: var(--nx-z-mobile-nav);
    height: var(--nx-tabbar-h);
    flex-direction: row; justify-content: space-around;
    margin-top: 0;
    padding: 0 4px env(safe-area-inset-bottom);
    border-top: 1px solid var(--nx-border-subtle);
    background: var(--nx-bg-mobile-nav);
    backdrop-filter: blur(18px); -webkit-backdrop-filter: blur(18px);
  }
  .main-nav a { flex: 1 1 0; min-width: 0; height: auto; flex-direction: column; justify-content: center; gap: 3px; padding: 7px 0 5px; border-radius: 0; font-size: 10px; background: transparent; }
  .main-nav a:hover { background: transparent; }
  .main-nav a.active { background: transparent; }
  .main-nav a.active::after { left: 32%; right: 32%; top: 0; bottom: auto; width: auto; height: 3px; border-radius: 0 0 3px 3px; }
  .header-actions { order: 3; margin-top: 0; display: flex; flex-direction: row; gap: 6px; padding-top: 0; border-top: 0; }
  .header-actions .icon-button { display: none; }
  .account { grid-column: auto; }
  .profile-button { width: 38px; height: 38px; font-size: var(--nx-fs-12); }
  .login-button { grid-column: auto; height: 38px; padding: 0 14px; }
  .account-menu { left: auto; right: 0; top: 48px; bottom: auto; }
  .auth-backdrop { padding: 12px; align-items: start; padding-top: 64px; }
  .auth-dialog { padding: 20px; }
}
</style>
