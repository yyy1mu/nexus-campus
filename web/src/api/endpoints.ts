import api from './index'
import axios from 'axios'

const authAxios = axios.create({
  baseURL: '/api',
  headers: { 'Content-Type': 'application/json' },
})

async function authPost(url: string, body: Record<string, unknown>) {
  const { data } = await authAxios.post(url, body)
  return data.data
}

export async function register(username: string, email: string, password: string) {
  return authPost('/register', { username, email, password })
}

export async function login(identification: string, password: string) {
  return authPost('/login', { identification, password })
}

// ── Agent ──

export async function fetchAgentContext() {
  const { data } = await api.get('/me/agent-context')
  return data.data
}

export async function fetchAgentProfile() {
  const { data } = await api.get('/me/agent-profile')
  return data.data
}

export async function updateAgentProfile(attrs: Record<string, unknown>) {
  const { data } = await api.patch('/me/agent-profile', attrs)
  return data.data
}

export async function fetchLlmSettings() {
  const { data } = await api.get('/llm-settings')
  return data.data
}

export async function updateLlmSettings(attrs: Record<string, unknown>) {
  const { data } = await api.patch('/llm-settings', attrs)
  return data.data
}

export async function fetchCapabilityLabels(keyword = '', limit = 20) {
  const params: Record<string, unknown> = { limit }
  if (keyword) params.inname = keyword
  const { data } = await api.get('/capability-labels', { params })
  return data.data ?? []
}

export async function fetchMyCapabilities() {
  const { data } = await api.get('/me/capabilities')
  return data.data ?? []
}

export async function updateMyCapabilities(caps: any[]) {
  const { data } = await api.patch('/me/capabilities', { capabilities: caps, userConfirmed: true })
  return data.data ?? []
}

export async function preflight(action: string) {
  const { data } = await api.post('/agent-preflight', { action })
  return data.data
}

// Agent memory

export async function fetchMemories(params: Record<string, unknown> = {}) {
  const { data } = await api.get('/me/memories', { params })
  return data.data ?? []
}

export async function fetchMemory(memoryId: string) {
  const { data } = await api.get(`/me/memories/${memoryId}`)
  return data.data
}

export async function recallMemories(attrs: Record<string, unknown>) {
  const { data } = await api.post('/me/memories/recall', attrs)
  return data.data ?? []
}

export async function createMemory(attrs: Record<string, unknown>) {
  const { data } = await api.post('/me/memories', attrs)
  return data.data
}

export async function updateMemory(memoryId: string, attrs: Record<string, unknown>) {
  const { data } = await api.patch(`/me/memories/${memoryId}`, attrs)
  return data.data
}

export async function deleteMemory(memoryId: string) {
  const { data } = await api.delete(`/me/memories/${memoryId}`, {
    data: { userConfirmed: true },
  })
  return data.data
}

export async function fetchMatchMemoryShares(matchId: string) {
  const { data } = await api.get(`/matches/${matchId}/memory-shares`)
  return data.data ?? []
}

export async function shareMatchMemories(matchId: string, memoryIds: number[]) {
  const { data } = await api.post(`/matches/${matchId}/memory-shares`, {
    memoryIds,
    userConfirmed: true,
  })
  return data.data ?? []
}

export async function revokeMatchMemoryShare(matchId: string, shareId: string) {
  const { data } = await api.patch(`/matches/${matchId}/memory-shares/${shareId}`, {
    revoked: true,
    userConfirmed: true,
  })
  return data.data
}

// ── Help Requests ──

export async function fetchHelpRequests(status?: string, limit = 20, offset = 0) {
  const params: Record<string, unknown> = { limit: String(limit), offset: String(offset) }
  if (status) params.status = status
  const { data } = await api.get('/help-requests', { params })
  return data.data ?? []
}

export async function fetchHelpRequest(id: string) {
  const { data } = await api.get(`/help-requests/${id}`)
  return data.data
}

export async function createHelpRequest(attrs: Record<string, unknown>) {
  const { data } = await api.post('/help-requests', attrs)
  return data.data
}

export async function updateHelpRequest(id: string, attrs: Record<string, unknown>) {
  const { data } = await api.patch(`/help-requests/${id}`, attrs)
  return data.data
}

// ── Dispatches ──

export async function fetchDispatches(helpRequestId: string) {
  const { data } = await api.get(`/help-requests/${helpRequestId}/dispatches`)
  return data.data ?? []
}

export async function createDispatch(helpRequestId: string, attrs: Record<string, unknown>) {
  const { data } = await api.post(`/help-requests/${helpRequestId}/dispatches`, attrs)
  return data.data
}

export async function updateDispatch(dispatchId: string, attrs: Record<string, unknown>) {
  const { data } = await api.patch(`/dispatches/${dispatchId}`, attrs)
  return data.data
}

// ── Matches ──

export async function fetchMatches(helpRequestId: string) {
  const { data } = await api.get(`/help-requests/${helpRequestId}/matches`)
  return data.data ?? []
}

export async function createMatch(helpRequestId: string, attrs: Record<string, unknown>) {
  const { data } = await api.post(`/help-requests/${helpRequestId}/matches`, attrs)
  return data.data
}

export async function updateMatch(matchId: string, attrs: Record<string, unknown>) {
  const { data } = await api.patch(`/matches/${matchId}`, attrs)
  return data.data
}

export async function fetchMessages(matchId: string, afterId?: number) {
  const params: Record<string, unknown> = {}
  if (afterId) params.afterId = afterId
  const { data } = await api.get(`/matches/${matchId}/messages`, { params })
  return data.data ?? []
}

export async function sendMessage(matchId: string, content: string, kind = 'chat') {
  const { data } = await api.post(`/matches/${matchId}/messages`, { content, kind, userConfirmed: true })
  return data.data
}

// ── Match Collaboration Workspace ──

export async function fetchMyMatches() {
  const { data } = await api.get('/me/matches')
  return data.data ?? []
}

export async function fetchWorkspace(matchId: string) {
  const { data } = await api.get(`/matches/${matchId}/workspace`)
  return data.data
}

export async function updateWorkspace(matchId: string, attrs: Record<string, unknown>) {
  const { data } = await api.patch(`/matches/${matchId}/workspace`, { ...attrs, userConfirmed: true })
  return data.data
}

export async function fetchMatchEvents(matchId: string, afterId?: number) {
  const params: Record<string, unknown> = {}
  if (afterId) params.afterId = afterId
  const { data } = await api.get(`/matches/${matchId}/events`, { params })
  return data.data ?? []
}

export async function createMatchTask(matchId: string, attrs: Record<string, unknown>) {
  const { data } = await api.post(`/matches/${matchId}/tasks`, { ...attrs, userConfirmed: true })
  return data.data
}

export async function updateMatchTask(matchId: string, taskId: number, attrs: Record<string, unknown>) {
  const { data } = await api.patch(`/matches/${matchId}/tasks/${taskId}`, { ...attrs, userConfirmed: true })
  return data.data
}

export async function resolveMatchDecision(matchId: string, decisionId: number, attrs: Record<string, unknown>) {
  const { data } = await api.patch(`/matches/${matchId}/decisions/${decisionId}`, { ...attrs, userConfirmed: true })
  return data.data
}

export async function reviewMatchDeliverable(matchId: string, deliverableId: number, attrs: Record<string, unknown>) {
  const { data } = await api.patch(`/matches/${matchId}/deliverables/${deliverableId}`, { ...attrs, userConfirmed: true })
  return data.data
}

// ── Work Items ──

export async function fetchWorkItems() {
  const { data } = await api.get('/me/work-items')
  return data.data ?? []
}

// ── Forum ──

export async function fetchForumDiscussions(q?: string, limit = 20, offset = 0) {
  const params: Record<string, unknown> = { limit: String(limit), offset: String(offset) }
  if (q) params.q = q
  const { data } = await api.get('/forum/discussions', { params })
  return data.data ?? []
}

export async function createForumDiscussion(attrs: Record<string, unknown>) {
  const { data } = await api.post('/forum/discussions', attrs)
  return data.data
}

export async function replyForum(discussionId: string, content: string) {
  const { data } = await api.post(`/forum/discussions/${discussionId}/posts`, { content, userConfirmed: true })
  return data.data
}
