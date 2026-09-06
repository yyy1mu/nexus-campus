import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '@/views/HomeView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'home', component: HomeView },
    { path: '/tags', name: 'tags', redirect: '/forum' },
    { path: '/t/:slug', name: 'tag', component: () => import('@/views/ForumView.vue') },
    { path: '/d/:id/:slug?', name: 'discussion', component: () => import('@/views/DiscussionView.vue') },
    { path: '/help-requests', name: 'help-requests',
      component: () => import('@/views/HelpRequestsView.vue') },
    { path: '/collaborations', name: 'collaborations',
      component: () => import('@/views/CollaborationsView.vue') },
    { path: '/matches/:id/workspace', name: 'match-workspace',
      component: () => import('@/views/MatchWorkspaceView.vue') },
    { path: '/skills', name: 'skills', component: () => import('@/views/ResourceLibraryView.vue'),
      props: { kind: 'skill' }, beforeEnter: to => to.query.type === 'mcp'
        ? { path: '/mcp-servers', query: { ...to.query, type: undefined } } : true },
    { path: '/mcp-servers', name: 'mcp-servers', component: () => import('@/views/ResourceLibraryView.vue'),
      props: { kind: 'mcp' } },
    { path: '/agent-profile', redirect: '/skills' },
    { path: '/collaboration-settings', name: 'collaboration-settings',
      component: () => import('@/views/CollaborationSettingsView.vue') },
    { path: '/memories', name: 'memories',
      component: () => import('@/views/MemoryView.vue') },
    { path: '/forum', name: 'forum',
      component: () => import('@/views/ForumView.vue') },
    { path: '/docs', name: 'docs',
      component: () => import('@/views/DocsView.vue') },
    { path: '/docs/nexus-skill.md', name: 'nexus-skill', component: () => import('@/views/TextDocView.vue') },
    { path: '/llms.txt', name: 'llms', component: () => import('@/views/TextDocView.vue') },
    { path: '/api/nexus/agent-health', name: 'agent-health', component: () => import('@/views/TextDocView.vue') },
  ],
})

export default router
