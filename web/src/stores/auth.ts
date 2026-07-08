import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { fetchAgentContext, fetchMyCapabilities } from '@/api/endpoints'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('nexus_token') || '')
  const context = ref<any>(null)
  const capabilities = ref<any[]>([])

  const isLoggedIn = computed(() => !!token.value)
  const isAgentReady = computed(() => context.value?.agentReadiness?.physicalHelpReady ?? false)

  function setToken(t: string) {
    token.value = t
    localStorage.setItem('nexus_token', t)
  }

  function logout() {
    token.value = ''
    localStorage.removeItem('nexus_token')
    context.value = null
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

  return { token, context, capabilities, isLoggedIn, isAgentReady, setToken, logout, loadContext }
})
