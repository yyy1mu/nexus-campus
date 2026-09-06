import { defineStore } from 'pinia'
import { ref, computed, onScopeDispose } from 'vue'
import { isAxiosError } from 'axios'
import { fetchAgentContext, fetchMyCapabilities } from '@/api/endpoints'
import { authApi } from '@/api'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('nexus_token') || '')
  const username = ref(localStorage.getItem('nexus_username') || '')
  const context = ref<any>(null)
  const capabilities = ref<any[]>([])
  const contextError = ref('')
  const logoutError = ref('')
  const loggingOut = ref(false)
  const isLoggedIn = computed(() => !!token.value)
  const isAgentReady = computed(() => context.value?.agentReadiness?.physicalHelpReady ?? false)
  let contextRequest = 0

  function setToken(value: string, name = '') {
    contextRequest++
    token.value = value
    username.value = name
    context.value = null
    capabilities.value = []
    contextError.value = ''
    logoutError.value = ''
    localStorage.setItem('nexus_username', name)
    localStorage.setItem('nexus_token', value)
  }

  function clearSession(expectedToken = token.value) {
    // A delayed 401/logout from a previous session must not clear a newer login.
    if (token.value !== expectedToken) return
    const storedToken = localStorage.getItem('nexus_token') || ''
    if (storedToken && storedToken !== expectedToken) { syncSession(); return }
    contextRequest++
    token.value = ''; username.value = ''
    localStorage.removeItem('nexus_username')
    localStorage.removeItem('nexus_token')
    context.value = null; capabilities.value = []
    contextError.value = ''; logoutError.value = ''
  }

  async function logout(): Promise<boolean> {
    if (loggingOut.value) return false
    const currentToken = token.value
    if (!currentToken) return true
    loggingOut.value = true; logoutError.value = ''
    try {
      await authApi.post('/logout', null, { headers: { Authorization: `Token ${currentToken}` } })
      clearSession(currentToken)
      return true
    } catch (error) {
      // An expired/revoked token is already signed out on the server.
      if (isAxiosError(error) && error.response?.status === 401) {
        clearSession(currentToken)
        return true
      }
      logoutError.value = '退出未完成，请检查网络后重试。'
      return false
    } finally { loggingOut.value = false }
  }

  async function loadContext() {
    const currentToken = token.value
    if (!currentToken) return
    const sequence = ++contextRequest
    const results = await Promise.allSettled([fetchAgentContext(), fetchMyCapabilities()])
    if (token.value !== currentToken || sequence !== contextRequest) return
    const invalid = results.some(result => result.status === 'rejected'
      && isAxiosError(result.reason) && result.reason.response?.status === 401)
    if (invalid) { clearSession(currentToken); return }
    if (results[0].status === 'fulfilled') context.value = results[0].value
    if (results[1].status === 'fulfilled') capabilities.value = results[1].value
    contextError.value = results.some(result => result.status === 'rejected')
      ? '用户信息暂时加载失败，登录状态已保留。' : ''
  }

  function syncSession() {
    const storedToken = localStorage.getItem('nexus_token') || ''
    if (storedToken === token.value) return
    contextRequest++
    token.value = storedToken
    username.value = localStorage.getItem('nexus_username') || ''
    context.value = null; capabilities.value = []
    contextError.value = ''; logoutError.value = ''
    if (storedToken) void loadContext()
  }
  function storageChanged(event: StorageEvent) {
    if (event.key === 'nexus_token' || event.key === null) syncSession()
  }
  window.addEventListener('storage', storageChanged)
  onScopeDispose(() => window.removeEventListener('storage', storageChanged))

  return { token, username, context, capabilities, contextError, logoutError, loggingOut,
    isLoggedIn, isAgentReady, setToken, clearSession, logout, loadContext }
})
