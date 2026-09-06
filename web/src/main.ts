import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from './router'
import App from './App.vue'
import { useThemeStore } from './stores/theme'
import { useAuthStore } from './stores/auth'
import { onUnauthorized } from './api'

const app = createApp(App)

const pinia = createPinia()
app.use(pinia)
useThemeStore(pinia)
onUnauthorized(token => useAuthStore(pinia).clearSession(token))
app.use(router)

app.mount('#app')
