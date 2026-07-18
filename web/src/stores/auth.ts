import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { fetchAgentContext, fetchMyCapabilities } from '@/api/endpoints'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('nexus_token') || '')
  const username = ref(localStorage.getItem('nexus_username') || '')
  const context = ref<any>(null)
  const capabilities = ref<any[]>([])

  const isLoggedIn = computed(() => !!token.value)
  const isAgentReady = computed(() => context.value?.agentReadiness?.physicalHelpReady ?? false)

  function setToken(t: string, name = '') {
    token.value = t
    localStorage.setItem('nexus_token', t)
    if (name) {
      username.value = name
      localStorage.setItem('nexus_username', name)
    }
  }

  function logout() {
    token.value = ''
    username.value = ''
    localStorage.removeItem('nexus_token')
    localStorage.removeItem('nexus_username')
    context.value = null
    capabilities.value = []
  }

  async function loadContext() {
    if (!token.value) return
    try {
      context.value = await fetchAgentContext()
      capabilities.value = await fetchMyCapabilities()
    } catch {
      logout()
    }
  }

  return {
    token,
    username,
    context,
    capabilities,
    isLoggedIn,
    isAgentReady,
    setToken,
    logout,
    loadContext,
  }
})
