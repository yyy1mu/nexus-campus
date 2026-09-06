import axios from 'axios'

const api = axios.create({
  baseURL: '/api/nexus',
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
})

let unauthorizedHandler: ((token: string) => void) | undefined
export function onUnauthorized(handler: (token: string) => void) { unauthorizedHandler = handler }

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('nexus_token')
  if (token) config.headers.Authorization = `Token ${token}`
  return config
})

api.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      const header = String(error.config?.headers?.Authorization || '')
      if (header.startsWith('Token ')) unauthorizedHandler?.(header.slice(6))
    }
    return Promise.reject(error)
  }
)

const authApi = axios.create({
  baseURL: '/api',
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
})

export default api
export { authApi }
