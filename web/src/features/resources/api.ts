import api from '@/api'

export type ResourceKind = 'skill' | 'mcp'
export interface ResourceInput {
  kind: ResourceKind
  name: string
  category: string
  summary: string
  description: string
  sourceUrl: string
  installCommand: string
  endpoint: string
  transport: '' | 'streamable-http' | 'sse' | 'stdio'
  authType: '' | 'none' | 'bearer'
}
export interface Resource extends ResourceInput {
  id: number
  ownerId: number
  favoriteCount: number
  favorited: boolean
  editable: boolean
  createdAt: string
  updatedAt: string
}
export interface ResourceListing { items: Resource[]; total: number; page: number; totalPages: number }
export const categories = ['开发工具', '设计体验', '数据处理', '学习研究', '效率工具', '其他']
export const emptyResource = (kind: ResourceKind): ResourceInput => ({
  kind, name: '', category: '开发工具', summary: '', description: '', sourceUrl: '',
  installCommand: '', endpoint: '', transport: kind === 'mcp' ? 'streamable-http' : '',
  authType: kind === 'mcp' ? 'bearer' : '',
})
export async function listResources(params: { kind: ResourceKind; q: string; scope: string; page: number; category?: string }, signal?: AbortSignal) {
  return (await api.get<{ data: ResourceListing }>('/resources', { params, signal })).data.data
}
export async function getResource(id: number) {
  return (await api.get<{ data: Resource }>(`/resources/${id}`)).data.data
}
export async function saveResource(input: ResourceInput, id?: number) {
  return (await api.request<{ data: Resource }>({ url: id ? `/resources/${id}` : '/resources',
    method: id ? 'PUT' : 'POST', data: input })).data.data
}
export async function deleteResource(id: number) { await api.delete(`/resources/${id}`) }
export async function setFavorite(resource: Resource) {
  return (await api.request<{ data: Resource }>({ url: `/resources/${resource.id}/favorite`,
    method: resource.favorited ? 'DELETE' : 'PUT' })).data.data
}
export function errorMessage(error: unknown): string {
  const response = (error as { response?: { status?: number; data?: { errors?: { message?: string }[] } } })?.response
  if (response?.status === 401 || response?.status === 403) return '请先登录；编辑和删除仅限资源创建者。'
  return response?.data?.errors?.[0]?.message || '请求失败，请检查连接后重试。'
}
