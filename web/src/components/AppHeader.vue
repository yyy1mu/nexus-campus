<template>
  <header class="app-header">
    <div class="header-inner">
      <RouterLink class="brand" to="/" aria-label="Nexus 首页"><span class="brand-mark"><Network :size="22" /></span><span class="brand-copy"><strong>Nexus<span class="brand-dot">.</span></strong><small>你的协作与资源空间</small></span></RouterLink>
      <label v-if="searchValue !== undefined" class="search-box"><Search :size="16" /><input :value="searchValue" type="search" placeholder="搜索当前页面" aria-label="搜索当前页面" @input="$emit('update:searchValue', ($event.target as HTMLInputElement).value)" /></label>
      <nav class="side-navigation" aria-label="主导航">
        <div v-for="group in groups" :key="group.label" class="nav-group"><span class="nav-section-label">{{ group.label }}</span><RouterLink v-for="item in group.items" :key="item.to" :to="item.to" exact-active-class="active"><component :is="item.icon" :size="18" /><span>{{ item.label }}</span><ChevronRight :size="13" class="nav-arrow" /></RouterLink></div>
      </nav>
      <div class="header-actions">
        <RouterLink class="docs-shortcut" to="/docs"><BookOpen :size="17" /><span>帮助与文档</span><ChevronRight :size="13" /></RouterLink>
        <ThemeSelect />
        <div v-if="auth.isLoggedIn" ref="accountElement" class="account">
          <button class="profile-button" type="button" :aria-expanded="accountOpen" aria-label="账户菜单" @click="accountOpen = !accountOpen"><span class="profile-avatar">{{ initials }}</span><span class="profile-copy"><strong>{{ auth.username || '我的账户' }}</strong><small>已登录</small></span><ChevronRight :size="15" class="profile-chevron" :class="{ open: accountOpen }" /></button>
          <div v-if="accountOpen" class="account-menu">
            <div class="account-summary"><span class="profile-avatar">{{ initials }}</span><div class="account-summary-copy"><strong>{{ auth.username }}</strong><span>ID: {{ auth.context?.userId ?? '—' }}</span></div><p v-if="auth.contextError" class="account-error" role="status">{{ auth.contextError }}</p><button v-if="auth.contextError" @click="auth.loadContext()">重新加载用户信息</button></div>
            <p v-if="auth.logoutError" class="account-error" role="alert">{{ auth.logoutError }}</p>
            <button class="menu-logout" :disabled="auth.loggingOut" @click="logout"><LogOut :size="16" />{{ auth.loggingOut ? '退出中…' : '退出登录' }}</button>
          </div>
        </div>
        <button v-else class="login-button" type="button" @click="authOpen = true"><LogIn :size="17" /><span>登录</span><ChevronRight :size="15" class="login-arrow" /></button>
      </div>
    </div>
  </header>
  <nav class="mobile-navigation" aria-label="移动导航"><RouterLink v-for="item in mobileItems" :key="item.to" :to="item.to" exact-active-class="active"><component :is="item.icon" :size="20" /><span>{{ item.label }}</span></RouterLink><button :class="{ active: moreActive }" @click="moreDialog?.showModal()"><Menu :size="20" /><span>更多</span></button></nav>
  <Teleport to="body"><dialog ref="moreDialog" class="more-dialog" aria-labelledby="more-title" @click="($event.target === moreDialog) && moreDialog?.close()"><header><div><span class="auth-eyebrow">NEXUS WORKSPACE</span><h2 id="more-title">探索更多</h2></div><button class="icon-button" aria-label="关闭导航" @click="moreDialog?.close()"><X :size="20" /></button></header><nav aria-label="更多导航"><div v-for="group in groups" :key="group.label"><span class="nav-section-label">{{ group.label }}</span><RouterLink v-for="item in group.items" :key="item.to" :to="item.to" @click="moreDialog?.close()"><component :is="item.icon" :size="19" />{{ item.label }}<ChevronRight :size="14" /></RouterLink></div><RouterLink to="/docs" @click="moreDialog?.close()"><BookOpen :size="19" />帮助与文档<ChevronRight :size="14" /></RouterLink></nav></dialog></Teleport>
  <Teleport to="body">
    <dialog ref="authDialog" class="auth-dialog" :class="{ closing: authClosing }" aria-labelledby="auth-title" @close="onAuthClosed" @cancel.prevent="closeAuth" @click="authBackdrop">
        <header class="auth-dialog-header">
          <div>
            <span class="auth-eyebrow">Nexus 账户</span>
            <h2 id="auth-title">{{ authMode === 'login' ? '登录社区' : '创建账户' }}</h2>
          </div>
          <button class="icon-button" type="button" aria-label="关闭" @click="closeAuth">
            <X :size="19" />
          </button>
        </header>

        <div class="auth-modes" :class="authMode" aria-label="账户操作">
          <button type="button" :class="{ active: authMode === 'login' }" @click="switchMode('login')">登录</button>
          <button type="button" :class="{ active: authMode === 'register' }" @click="switchMode('register')">注册</button>
        </div>

        <form @submit.prevent="submitAuth">
          <label v-if="authMode === 'register'" class="register-only">
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
            <span v-if="authBusy" class="auth-spinner" aria-hidden="true" />
            {{ authBusy ? '处理中...' : authMode === 'login' ? '登录' : '注册并登录' }}
          </button>
        </form>
    </dialog>
  </Teleport>
</template>
<script setup lang="ts">
import { computed, reactive, ref, watch, nextTick, onMounted, onBeforeUnmount } from 'vue'
import {
  Network,
  Menu,
  ChevronRight,
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
  Settings,
  Blocks,
  Plug,
  X,
} from '@lucide/vue'
import { RouterLink, useRoute } from 'vue-router'
import { login, register } from '@/api/endpoints'
import { useAuthStore } from '@/stores/auth'
import ThemeSelect from '@/components/ThemeSelect.vue'

defineProps<{ searchValue?: string }>()
defineEmits<{ 'update:searchValue': [value: string] }>()

const route = useRoute()
const authDialog = ref<HTMLDialogElement>()
const moreDialog = ref<HTMLDialogElement>()
const accountElement = ref<HTMLElement>()
const groups = [
  { label: '动态', items: [{ to: '/', label: '概览', icon: House }, { to: '/forum', label: '讨论', icon: MessagesSquare }, { to: '/help-requests', label: '求助广场', icon: CircleHelp }] },
  { label: 'Skill', items: [{ to: '/skills', label: 'Skill', icon: Blocks }, { to: '/mcp-servers', label: 'MCP', icon: Plug }] },
  { label: 'Agent', items: [{ to: '/memories', label: '长期记忆', icon: Brain }, { to: '/collaboration-settings', label: '协作设置', icon: Settings }] },
  { label: '我的', items: [{ to: '/collaborations', label: '我的协作', icon: Handshake }] },
]
const mobileItems = [groups[0]!.items[0]!, groups[0]!.items[1]!, groups[0]!.items[2]!, groups[1]!.items[0]!]
const moreActive = computed(() => !mobileItems.some(item => route.path === item.to))
const auth = useAuthStore()
const authOpen = ref(false)
const authClosing = ref(false)
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
  // 先播放退出动画，再真正关闭弹窗；@close 事件负责同步状态。
  if (authClosing.value || !authDialog.value?.open) { authOpen.value = false; return }
  authClosing.value = true
  window.setTimeout(() => {
    authClosing.value = false
    authOpen.value = false
  }, 180)
}

function onAuthClosed() {
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
    if (!auth.isLoggedIn) { authError.value = '登录凭据已失效，请重新登录。'; return }
    closeAuth()
  } catch (exception: any) {
    authError.value = exception.response?.data?.errors?.[0]?.message
      ?? (authMode.value === 'login' ? '登录失败，请检查账户信息。' : '注册失败，请检查填写内容。')
  } finally {
    authBusy.value = false
  }
}

async function logout() {
  if (await auth.logout()) accountOpen.value = false
}
watch(authOpen, async open => {
  await nextTick()
  if (open && authOpen.value && !authDialog.value?.open) {
    authDialog.value?.showModal()
    authDialog.value?.querySelector('input')?.focus()
  } else if (!open) authDialog.value?.close()
})
watch(() => route.fullPath, () => { accountOpen.value = false; moreDialog.value?.close() })
function authBackdrop(event: MouseEvent) { if (event.target === authDialog.value) closeAuth() }
function closeOutside(event: PointerEvent) {
  if (accountOpen.value && !accountElement.value?.contains(event.target as Node)) accountOpen.value = false
}
function closeWithEscape(event: KeyboardEvent) { if (event.key === 'Escape') accountOpen.value = false }
function requestedLogin() { authOpen.value = true }
onMounted(() => { window.addEventListener('nexus:request-login', requestedLogin); document.addEventListener('pointerdown', closeOutside); document.addEventListener('keydown', closeWithEscape) })
onBeforeUnmount(() => { window.removeEventListener('nexus:request-login', requestedLogin); document.removeEventListener('pointerdown', closeOutside); document.removeEventListener('keydown', closeWithEscape) })
</script>
<style scoped>
.app-header { position: fixed; inset: 0 auto 0 0; z-index: var(--nx-z-header); width: var(--nx-sidebar-w); border-right: 1px solid var(--nx-border-default); background: var(--nx-bg-base); }
.header-inner { height: 100%; display: flex; flex-direction: column; padding: 28px 18px 18px; overflow-y: auto; }
.brand { display: flex; align-items: center; gap: 11px; padding: 0 6px 28px; }
.brand-mark { display: grid; place-items: center; width: 38px; height: 42px; color: var(--nx-accent); border: 1px solid var(--nx-accent-border); background: var(--nx-accent-subtle); border-radius: 12px 4px 12px 4px; box-shadow: inset 0 0 18px var(--nx-accent-subtle); }
.brand-copy strong { color: var(--nx-text-primary); font-size: 24px; letter-spacing: -.06em; line-height: 1; }.brand-dot { color: var(--nx-accent); }.brand-copy small { display: block; color: var(--nx-text-tertiary); font-size: 10px; margin-top: 7px; }
.search-box { display: flex; align-items: center; gap: 8px; height: 38px; flex-shrink: 0; margin-top: 16px; padding: 0 10px; color: var(--nx-text-tertiary); background: var(--nx-bg-inset); border: 1px solid var(--nx-border-subtle); border-radius: 8px; }.search-box input { width:100%; min-width:0; border:0; outline:none; background:transparent; font-size:12px; }
.side-navigation { padding-top: 18px; }.nav-group + .nav-group { margin-top: 18px; }.nav-section-label { display: block; padding: 0 12px 8px; font-size: 10px; color: var(--nx-text-tertiary); letter-spacing: .08em; }
.side-navigation a { display: flex; align-items: center; gap: 11px; height: 42px; margin: 3px 0; padding: 0 12px; color: var(--nx-text-secondary); border: 1px solid transparent; border-radius: 8px; font-size:13px; }.nav-arrow { margin-left:auto; opacity:0; }.side-navigation a:hover { color:var(--nx-text-primary); background:var(--nx-bg-hover); }.side-navigation a.active { color:var(--nx-accent); border-color:var(--nx-accent-border); background:linear-gradient(90deg,var(--nx-accent-faint),var(--nx-accent-subtle)); }.side-navigation a.active .nav-arrow { opacity:1; }
.header-actions { display: flex; flex-direction: column; gap: 10px; margin-top: auto; padding-top:24px; }.docs-shortcut { display:flex; align-items:center; gap:10px; color:var(--nx-text-tertiary); padding:10px 12px; font-size:12px; }.docs-shortcut svg:last-child {margin-left:auto;}
.login-button { display:flex; align-items:center; justify-content:center; gap:8px; height:44px; border:1px solid var(--nx-accent-border); border-radius:9px; background:var(--nx-accent); color:var(--nx-on-accent); font-weight:700; font-size:13px; }.login-arrow {margin-left:auto;}.login-button span {margin-right:auto;}
.account { position:relative; }.profile-button { display:flex; align-items:center; gap:10px; width:100%; height:52px; padding:8px; border:1px solid var(--nx-border-default); border-radius:9px; background:var(--nx-bg-raised); text-align:left; }.profile-avatar {display:grid;place-items:center;width:32px;height:32px;flex-shrink:0;border-radius:8px;background:var(--nx-accent-faint);color:var(--nx-accent);font-size:12px;font-weight:700;}.profile-copy{min-width:0;flex:1;}.profile-copy strong{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:var(--nx-text-primary);font-size:12px;}.profile-copy small{font-size:10px;color:var(--nx-text-tertiary);}
.account-menu { position:fixed; left:calc(var(--nx-sidebar-w) + 10px); bottom:18px; z-index:var(--nx-z-menu); width:264px; padding:7px; background:var(--nx-bg-overlay); border:1px solid var(--nx-border-default); border-radius:14px; box-shadow:var(--nx-shadow-menu); animation:menu-in .16s ease; }@keyframes menu-in {from {opacity:0;transform:translateY(6px);}}.profile-chevron{transition:transform .18s;}.profile-chevron.open{transform:rotate(90deg);}.account-summary {display:flex;align-items:center;gap:10px;flex-wrap:wrap;padding:13px;border-bottom:1px solid var(--nx-border-subtle);}.account-summary-copy{min-width:0;flex:1;display:flex;flex-direction:column;gap:2px;}.account-summary strong{color:var(--nx-text-primary);overflow-wrap:anywhere;font-size:14px;}.account-summary-copy span{font-size:11px;color:var(--nx-text-tertiary);}.account-menu a,.account-menu button {display:flex;align-items:center;gap:10px;width:100%;min-height:42px;padding:8px 12px;background:transparent;border:0;border-radius:7px;text-align:left;font-size:12px;}.account-menu a:hover,.account-menu button:hover {background:var(--nx-bg-hover);color:var(--nx-text-primary);}.account-error{padding:10px;color:var(--nx-danger);font-size:12px;}.menu-logout{color:var(--nx-danger);}
.mobile-navigation {display:none;}.icon-button {display:grid;place-items:center;width:36px;height:36px;flex-shrink:0;border:1px solid var(--nx-border-default);background:var(--nx-bg-inset);border-radius:8px;}
.auth-dialog,.more-dialog {position:fixed;inset:0;margin:auto;width:min(440px,calc(100% - 32px));max-height:calc(100dvh - 40px);overflow:auto;padding:28px;border:1px solid var(--nx-border-strong);border-radius:18px;color:var(--nx-text-secondary);background:var(--nx-bg-overlay);box-shadow:var(--nx-shadow-modal);}.auth-dialog::backdrop,.more-dialog::backdrop {background:rgba(0,5,14,.65);backdrop-filter:blur(8px);}.auth-dialog-header,.more-dialog header{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;}.auth-eyebrow{color:var(--nx-accent);font:10px var(--nx-font-mono);letter-spacing:.06em;}.auth-dialog h2,.more-dialog h2{color:var(--nx-text-primary);font-size:26px;margin-top:8px;letter-spacing:-.03em;}
/* —— 弹窗进出动画 —— */
.auth-dialog[open] {animation:auth-in .28s cubic-bezier(.2,.9,.25,1.05);}
.auth-dialog::backdrop {animation:backdrop-in .24s ease;}
.auth-dialog.closing {animation:auth-out .18s ease-in forwards;}
.auth-dialog.closing::backdrop {animation:backdrop-out .18s ease-in forwards;}
@keyframes auth-in {from {opacity:0;transform:translateY(16px) scale(.96);} to {opacity:1;transform:none;}}
@keyframes auth-out {to {opacity:0;transform:translateY(10px) scale(.98);}}
@keyframes backdrop-in {from {opacity:0;}}
@keyframes backdrop-out {to {opacity:0;}}
/* —— 登录/注册切换：滑动指示器 —— */
.auth-modes{position:relative;display:flex;padding:4px;background:var(--nx-bg-inset);border:1px solid var(--nx-border-subtle);border-radius:10px;margin:24px 0;}
.auth-modes::before{content:'';position:absolute;top:4px;left:4px;width:calc(50% - 4px);height:calc(100% - 8px);border-radius:7px;background:var(--nx-bg-active);transition:transform .22s cubic-bezier(.3,.9,.3,1);}
.auth-modes.register::before{transform:translateX(100%);}
.auth-modes button{position:relative;flex:1;height:36px;border:0;border-radius:7px;background:transparent;color:var(--nx-text-tertiary);transition:color .18s;}.auth-modes button.active{color:var(--nx-text-primary);}
/* —— 表单细节动画 —— */
.register-only{animation:field-in .24s ease;}
@keyframes field-in {from {opacity:0;transform:translateY(-6px);}}
.auth-dialog form{display:grid;gap:18px;}.auth-dialog label span{display:block;font-size:12px;margin-bottom:7px;}.auth-dialog input{width:100%;height:46px;padding:0 12px;background:var(--nx-bg-inset);border:1px solid var(--nx-border-default);border-radius:8px;color:var(--nx-text-primary);transition:border-color .16s,outline-color .16s;}.auth-dialog input:focus{outline:2px solid var(--nx-accent-border);border-color:var(--nx-accent);}
.auth-error{color:var(--nx-danger);font-size:12px;animation:error-shake .32s;}
@keyframes error-shake {0%,100% {transform:translateX(0);} 20% {transform:translateX(-5px);} 40% {transform:translateX(5px);} 60% {transform:translateX(-3px);} 80% {transform:translateX(3px);}}
.auth-submit{display:flex;align-items:center;justify-content:center;gap:8px;height:46px;border:0;border-radius:8px;background:var(--nx-accent);color:var(--nx-on-accent);font-weight:700;transition:transform .15s,box-shadow .15s,opacity .15s;}.auth-submit:not(:disabled):hover{transform:translateY(-1px);box-shadow:var(--nx-accent-glow);}.auth-submit:not(:disabled):active{transform:translateY(0);}.auth-submit:disabled{opacity:.6;}
.auth-spinner{width:14px;height:14px;border:2px solid currentColor;border-top-color:transparent;border-radius:50%;animation:auth-spin .7s linear infinite;}
@keyframes auth-spin {to {transform:rotate(360deg);}}
@media (prefers-reduced-motion: reduce) {.auth-dialog[open],.auth-dialog.closing,.auth-dialog::backdrop,.auth-dialog.closing::backdrop,.register-only,.auth-error,.auth-spinner{animation:none !important;}.auth-modes::before,.auth-modes button,.auth-submit,.auth-dialog input{transition:none !important;}}
.more-dialog nav{margin-top:22px;}.more-dialog .nav-section-label{padding-top:14px;}.more-dialog nav a{display:flex;align-items:center;gap:12px;min-height:44px;padding:8px 12px;border-radius:8px;}.more-dialog nav a:hover{background:var(--nx-bg-hover);}.more-dialog nav a svg:last-child{margin-left:auto;}
@media(max-width:720px){.app-header{position:sticky;inset:0 0 auto;width:auto;height:64px;border-right:0;border-bottom:1px solid var(--nx-border-default);background:var(--nx-bg-header);}.header-inner{height:64px;padding:0 16px;flex-direction:row;align-items:center;gap:12px;overflow:visible;}.brand{padding:0;gap:8px;}.brand-mark{width:30px;height:34px;}.brand-copy strong{font-size:21px;}.brand-copy small,.side-navigation,.search-box,.docs-shortcut{display:none;}.header-actions{flex-direction:row;align-items:center;gap:8px;margin:0 0 0 auto;padding:0;}.login-button{height:36px;padding:0 12px;}.login-arrow,.login-button > svg:first-child{display:none;}.login-button span{margin:0;}.profile-button{width:36px;height:36px;padding:0;border:0;background:transparent;}.profile-copy,.profile-button > svg{display:none;}.profile-avatar{width:36px;height:36px;}.account-menu{position:absolute;left:auto;right:0;bottom:auto;top:46px;width:264px;}.mobile-navigation{position:fixed;inset:auto 0 0;z-index:var(--nx-z-mobile-nav);display:flex;padding:6px 8px max(8px,env(safe-area-inset-bottom));height:calc(64px + env(safe-area-inset-bottom));border-top:1px solid var(--nx-border-default);background:var(--nx-bg-mobile-nav);backdrop-filter:blur(16px);}.mobile-navigation a,.mobile-navigation button{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;flex:1;min-width:0;border:0;border-radius:9px;background:transparent;color:var(--nx-text-tertiary);font-size:10px;}.mobile-navigation .active{background:var(--nx-accent-subtle);color:var(--nx-accent);}.more-dialog{inset:auto 0 0;width:100%;max-height:85dvh;border-radius:20px 20px 0 0;padding:24px 20px 32px;}.auth-dialog{padding:24px;}}
</style>
