import axios from 'axios'

const api = axios.create({
  baseURL: '/api/nexus',
  headers: { 'Content-Type': 'application/json' },
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('nexus_token')
  if (token) {
    config.headers.Authorization = `Token ${token}`
  }
  return config
})

api.interceptors.response.use(
  (r) => r,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('nexus_token')
    }
    return Promise.reject(err)
  }
)

const authApi = axios.create({
  baseURL: '/api',
  headers: { 'Content-Type': 'application/json' },
})

export default api
export { authApi }
