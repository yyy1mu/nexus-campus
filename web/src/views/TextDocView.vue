<template><AppHeader /><main class="text-shell"><PageIntro eyebrow="DEVELOPER / 技术文档" :title="title" :description="route.path"><button class="btn btn-secondary" :disabled="loading || !!error" @click="copy">{{ copied ? '已复制' : '复制内容' }}</button></PageIntro><StatePanel v-if="loading" tone="loading" title="正在读取文档" /><StatePanel v-else-if="error" tone="error" title="暂时无法读取文档" :description="error"><button class="btn btn-secondary" @click="load">重试</button></StatePanel><pre v-else class="text-page" tabindex="0">{{ content }}</pre><p role="status">{{ copyError }}</p></main></template>
<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import PageIntro from '@/components/PageIntro.vue'
import StatePanel from '@/components/StatePanel.vue'
const route = useRoute()
const content = ref(''), error = ref(''), copyError = ref(''), copied = ref(false), loading = ref(false)
let sequence = 0
const title = computed(() => route.path === '/llms.txt' ? '工具接入入口' : route.path === '/api/nexus/agent-health' ? '服务健康检查' : 'Nexus Skill 使用手册')
async function load() {
  const current = ++sequence; loading.value = true; error.value = ''; copied.value = false
  try {
    const response = await fetch(route.path, { headers: { Accept: 'text/plain, application/json' }, signal: AbortSignal.timeout(15000) })
    if (!response.ok) throw new Error(`读取失败（${response.status}）`)
    const text = await response.text()
    if (response.headers.get('content-type')?.includes('text/html')) throw new Error('此环境尚未提供该文档。')
    if (current === sequence) content.value = response.headers.get('content-type')?.includes('application/json') ? JSON.stringify(JSON.parse(text), null, 2) : text
  } catch (e) { if (current === sequence) error.value = e instanceof Error ? e.message : '请稍后重试。' }
  finally { if (current === sequence) loading.value = false }
}
async function copy() { try { await navigator.clipboard.writeText(content.value); copied.value = true; copyError.value = '' } catch { copyError.value = '无法访问剪贴板，请选择文档内容后手动复制。' } }
watch(() => route.path, load, { immediate:true })
</script>
<style scoped>.text-shell { max-width:1240px; padding:40px 36px 90px; margin:auto; }.text-page { padding:28px; background:var(--nx-bg-raised); color:var(--nx-text-secondary); border:1px solid var(--nx-border-default); border-radius:16px; font:13px/1.85 var(--nx-font-mono); white-space:pre-wrap; overflow-wrap:anywhere; }.text-shell>p { color:var(--nx-text-tertiary); margin-top:12px; }@media(max-width:720px) { .text-shell { padding:28px 16px 90px; }.text-page { padding:18px; font-size:12px; } }</style>
