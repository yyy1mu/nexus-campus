<template>
  <AppHeader /><main class="docs-page">
    <PageIntro eyebrow="GUIDE / 使用指南" title="从探索到协作" description="了解如何收集资源、连接工具，以及与其他人一起完成任务。" />
    <section class="guide-grid"><RouterLink v-for="guide in guides" :key="guide.to" :to="guide.to" class="guide-card"><component :is="guide.icon" :size="26" /><span>{{ guide.label }}</span><h2>{{ guide.title }}</h2><p>{{ guide.description }}</p><ArrowUpRight class="guide-arrow" :size="18" /></RouterLink></section>
    <section class="integration"><div><span class="section-label">BUILD WITH NEXUS</span><h2>开发与工具接入</h2><p>查阅接口、配置和使用文档，把 Nexus 接入自己的工作流程。</p></div><div class="link-grid"><a v-for="link in links" :key="link[1]" :href="link[1]">{{ link[0] }}<ArrowUpRight :size="15" /></a></div></section>
    <div class="guide-note"><BookOpen :size="20" /><p>MCP 目录展示连接信息。需要 Token 的资源会在客户端连接时提示输入，资源页面无需保存服务 Token。</p></div>
  </main>
</template>
<script setup lang="ts">
import { RouterLink } from 'vue-router'
import { ArrowUpRight, BookOpen, Layers3, Plug, Users } from '@lucide/vue'
import AppHeader from '@/components/AppHeader.vue'
import PageIntro from '@/components/PageIntro.vue'
const guides = [
  { icon: Layers3, label:'01 / COLLECT', title:'构建你的 Skill 收藏', description:'搜索与筛选资源，查看安装说明；登录后收藏常用 Skill，或收录新的发现。', to:'/skills' },
  { icon: Plug, label:'02 / CONNECT', title:'连接 MCP 工具', description:'了解传输协议和鉴权方式，复制接入配置，在自己的客户端完成连接。', to:'/mcp-servers' },
  { icon: Users, label:'03 / COLLABORATE', title:'找到一起解决问题的人', description:'发布求助、确认匹配，在协作工作台推进任务、沟通决策与验收交付。', to:'/help-requests' },
]
const links = [['快速接入指南','/docs/agent-quickstart.md'],['完整使用文档','/docs/index.md'],['Skill 使用手册','/docs/nexus-skill.md'],['长期记忆指南','/docs/agent-memory.md'],['任务操作示例','/docs/agent-recipes.md'],['工具接口契约','/docs/agent-tools.json'],['OpenAPI 定义','/v3/api-docs'],['Swagger 接口调试','/swagger-ui.html'],['服务健康检查','/api/nexus/agent-health'],['工具发现清单','/.well-known/nexus-agent.json'],['接入入口','/llms.txt'],['清单数据格式','/schemas/nexus-agent-manifest.v1.json']]
</script>
<style scoped>
.docs-page { max-width:1240px; margin:auto; padding:40px 36px 90px; }.guide-grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:16px; }.guide-card { position:relative; padding:26px; border:1px solid var(--nx-border-default); border-radius:16px; background:var(--nx-hero-bg); transition:transform .2s,border-color .2s; }.guide-card:hover { transform:translateY(-3px); border-color:var(--nx-accent); }.guide-card>svg { color:var(--nx-accent); }.guide-card>span { display:block; margin:25px 0 12px; color:var(--nx-text-tertiary); font:10px var(--nx-font-mono); letter-spacing:.1em; }.guide-card h2 { font-size:19px; line-height:1.5; }.guide-card p { color:var(--nx-text-secondary); line-height:1.9; font-size:13px; margin-top:14px; }.guide-card .guide-arrow { position:absolute; right:24px; top:26px; color:var(--nx-text-tertiary); }.integration { margin-top:40px; padding:30px; border:1px solid var(--nx-border-subtle); border-radius:16px; background:var(--nx-bg-raised); }.section-label { font:10px var(--nx-font-mono); color:var(--nx-accent); letter-spacing:.12em; }.integration h2 { font-size:22px; margin:10px 0; }.integration p { color:var(--nx-text-tertiary); font-size:13px; line-height:1.8; }.link-grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:8px 24px; margin-top:24px; }.link-grid a { display:flex; justify-content:space-between; align-items:center; padding:14px 0; border-bottom:1px solid var(--nx-border-subtle); font-size:13px; color:var(--nx-text-secondary); }.link-grid a:hover { color:var(--nx-accent); }.guide-note { display:flex; gap:14px; align-items:center; padding:24px 0; color:var(--nx-text-tertiary); font-size:12px; line-height:1.8; }.guide-note svg { flex-shrink:0; }@media(max-width:1000px) { .guide-grid { grid-template-columns:1fr; }.guide-card { padding:24px; }.guide-card>span { margin-top:18px; }.link-grid { grid-template-columns:repeat(2,minmax(0,1fr)); } }@media(max-width:720px) { .docs-page { padding:28px 16px 90px; }.integration { padding:22px; }.link-grid { grid-template-columns:1fr; } }
</style>
