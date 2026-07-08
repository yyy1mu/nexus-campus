import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '@/views/HomeView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'home', component: HomeView },
    { path: '/help-requests', name: 'help-requests',
      component: () => import('@/views/HelpRequestsView.vue') },
    { path: '/agent-profile', name: 'agent-profile',
      component: () => import('@/views/AgentProfileView.vue') },
    { path: '/forum', name: 'forum',
      component: () => import('@/views/ForumView.vue') },
    { path: '/docs', name: 'docs',
      component: () => import('@/views/DocsView.vue') },
  ],
})

export default router
