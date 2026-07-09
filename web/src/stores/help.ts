import { defineStore } from 'pinia'
import { ref } from 'vue'
import {
  fetchHelpRequests, createHelpRequest, updateHelpRequest,
  fetchDispatches, createDispatch, updateDispatch,
  fetchMatches, createMatch, updateMatch,
  fetchMessages, sendMessage,
  fetchWorkItems
} from '@/api/endpoints'

export const useHelpStore = defineStore('help', () => {
  const requests = ref<any[]>([])
  const workItems = ref<any[]>([])
  const loading = ref(false)

  async function loadRequests(status?: string) {
    loading.value = true
    try { requests.value = await fetchHelpRequests(status) }
    finally { loading.value = false }
  }

  async function create(req: Record<string, unknown>) {
    const r = await createHelpRequest(req)
    requests.value.unshift(r)
    return r
  }

  async function update(id: string, attrs: Record<string, unknown>) {
    const r = await updateHelpRequest(id, attrs)
    const idx = requests.value.findIndex(x => x.id === id)
    if (idx >= 0) requests.value[idx] = r
    return r
  }

  async function loadWorkItems() {
    workItems.value = await fetchWorkItems()
  }

  return { requests, workItems, loading, loadRequests, create, update, loadWorkItems }
})

export const useDispatchStore = defineStore('dispatch', () => {
  const dispatches = ref<Record<string, any[]>>({})
  const matches = ref<Record<string, any[]>>({})
  const messages = ref<Record<string, any[]>>({})

  async function loadDispatches(helpRequestId: string) {
    dispatches.value[helpRequestId] = await fetchDispatches(helpRequestId)
  }

  async function createD(helpRequestId: string, attrs: Record<string, unknown>) {
    const d = await createDispatch(helpRequestId, attrs)
    if (!dispatches.value[helpRequestId]) dispatches.value[helpRequestId] = []
    dispatches.value[helpRequestId].unshift(d)
    return d
  }

  async function updateD(dispatchId: string, helpRequestId: string, attrs: Record<string, unknown>) {
    const d = await updateDispatch(dispatchId, attrs)
    const list = dispatches.value[helpRequestId]
    if (list) {
      const idx = list.findIndex(x => x.id === dispatchId)
      if (idx >= 0) list[idx] = d
    }
    return d
  }

  async function loadMatches(helpRequestId: string) {
    matches.value[helpRequestId] = await fetchMatches(helpRequestId)
  }

  async function createM(helpRequestId: string, attrs: Record<string, unknown>) {
    const m = await createMatch(helpRequestId, attrs)
    if (!matches.value[helpRequestId]) matches.value[helpRequestId] = []
    matches.value[helpRequestId].unshift(m)
    return m
  }

  async function updateM(matchId: string, helpRequestId: string, attrs: Record<string, unknown>) {
    const m = await updateMatch(matchId, attrs)
    const list = matches.value[helpRequestId]
    if (list) {
      const idx = list.findIndex(x => x.id === matchId)
      if (idx >= 0) list[idx] = m
    }
    return m
  }

  async function loadMessages(matchId: string) {
    messages.value[matchId] = await fetchMessages(matchId)
  }

  async function sendM(matchId: string, content: string) {
    const msg = await sendMessage(matchId, content)
    if (!messages.value[matchId]) messages.value[matchId] = []
    messages.value[matchId].push(msg)
    return msg
  }

  return { dispatches, matches, messages, loadDispatches, createD, updateD,
           loadMatches, createM, updateM, loadMessages, sendM }
})
