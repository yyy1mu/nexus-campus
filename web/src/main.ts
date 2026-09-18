import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from './router'
import App from './App.vue'
import { useThemeStore } from './stores/theme'
import { useAuthStore } from './stores/auth'
import { onUnauthorized } from './api'
import { login } from './api/endpoints'

const app = createApp(App)

const pinia = createPinia()
app.use(pinia)
useThemeStore(pinia)
onUnauthorized(token => useAuthStore(pinia).clearSession(token))
app.use(router)

// 演示环境默认账号：chenyu_algo_demo（seed 数据中的 LoRA 协作求助方）
const DEMO_IDENTIFICATION = 'chenyu_algo_demo'
const DEMO_PASSWORD = 'demo-password-1'

async function bootstrap() {
  const auth = useAuthStore(pinia)
  if (!auth.token) {
    try {
      const session = await login(DEMO_IDENTIFICATION, DEMO_PASSWORD)
      auth.setToken(session.token, session.username)
    } catch {
      // 默认账号不可用（如未导入 seed 数据）时保持未登录
    }
  }
  app.mount('#app')
}

void bootstrap()
