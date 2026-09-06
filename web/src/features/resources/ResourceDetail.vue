<template>
  <dialog ref="dialog" class="resource-dialog" @close="$emit('close')" @click="backdrop">
    <header class="dialog-heading"><div><span class="eyebrow">{{ resource.kind === 'skill' ? 'SKILL' : 'MCP' }} / {{ resource.category }}</span><h2>{{ resource.name }}</h2></div><button class="icon-action" aria-label="关闭详情" @click="dialog?.close()"><X :size="20" /></button></header>
    <p class="resource-summary">{{ resource.summary }}</p>
    <div class="detail-meta"><span>{{ resource.favoriteCount }} 人收藏</span><span>更新于 {{ new Date(resource.updatedAt).toLocaleDateString() }}</span></div>
    <p v-if="resource.description.startsWith('【MOCK 演示数据】')" class="demo-notice">DEMO · 用于预览收录效果，地址与安装说明为演示内容。</p>
    <a v-else class="resource-source" :href="resource.sourceUrl" target="_blank" rel="noopener noreferrer">项目 / 文档 <ArrowUpRight :size="16" /></a>
    <section v-if="resource.kind === 'mcp'" class="connection-section">
      <h3>连接信息</h3>
      <dl><div><dt>协议</dt><dd>{{ resource.transport }}</dd></div><div><dt>鉴权</dt><dd>{{ resource.authType === 'bearer' ? 'Bearer Token' : '无需 HTTP 鉴权' }}</dd></div><div v-if="resource.endpoint"><dt>服务地址</dt><dd>{{ resource.endpoint }}</dd></div></dl>
      <template v-if="resource.transport !== 'stdio'">
        <h3>VS Code 接入配置</h3>
        <a class="resource-source" href="https://code.visualstudio.com/docs/agents/reference/mcp-configuration" target="_blank" rel="noopener noreferrer">客户端配置文档 <ArrowUpRight :size="14" /></a>
        <p class="muted">合并到项目的 .vscode/mcp.json。{{ resource.authType === 'bearer' ? '首次连接时，客户端会提示输入此服务的 Token。' : '连接及可用性以客户端结果为准。' }}</p>
        <pre tabindex="0">{{ configuration }}</pre>
        <button class="btn btn-secondary" @click="copy(configuration)"><Copy :size="15" />复制配置</button>
      </template>
    </section>
    <section v-if="resource.installCommand"><h3>{{ resource.kind === 'skill' ? '安装方式' : '启动说明' }}</h3><pre tabindex="0">{{ resource.installCommand }}</pre><button class="btn btn-secondary" @click="copy(resource.installCommand)"><Copy :size="15" />复制{{ resource.kind === 'skill' ? '安装方式' : '启动说明' }}</button></section>
    <section><h3>使用说明</h3><p class="description-text">{{ resource.description || '收录者尚未填写详细说明，请查看项目文档。' }}</p></section>
    <p class="muted" role="status">{{ status }}</p>
    <footer v-if="resource.editable" class="dialog-footer">
      <template v-if="confirmDelete"><span>删除后将同时移除收藏关系。</span><button class="btn btn-secondary" :disabled="busy" @click="confirmDelete = false">取消</button><button class="btn btn-secondary danger" :disabled="busy" @click="remove">确认删除</button></template>
      <template v-else><button class="btn btn-secondary danger" @click="confirmDelete = true">删除资源</button><button class="btn btn-primary" @click="$emit('edit', resource)">编辑资源</button></template>
    </footer>
  </dialog>
</template>
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { ArrowUpRight, Copy, X } from '@lucide/vue'
import { deleteResource, errorMessage, type Resource } from './api'
const props = defineProps<{ resource: Resource }>()
const emit = defineEmits<{ close: []; edit: [resource: Resource]; deleted: [] }>()
const dialog = ref<HTMLDialogElement>()
const status = ref('')
const confirmDelete = ref(false)
const busy = ref(false)
onMounted(() => dialog.value?.showModal())
function backdrop(event: MouseEvent) { if (event.target === dialog.value) dialog.value?.close() }
const configuration = computed(() => {
  const r = props.resource
  const tokenId = `nexus_resource_${r.id}_token`
  return JSON.stringify({ servers: { [`nexus-resource-${r.id}`]: {
    type: r.transport === 'sse' ? 'sse' : 'http', url: r.endpoint,
    ...(r.authType === 'bearer' ? { headers: { Authorization: `Bearer \${input:${tokenId}}` } } : {}),
  } }, ...(r.authType === 'bearer' ? { inputs: [{ type: 'promptString', id: tokenId,
    description: `${r.name} Token`, password: true }] } : {}) }, null, 2)
})
async function copy(value: string) {
  try { await navigator.clipboard.writeText(value); status.value = '已复制' }
  catch { status.value = '无法访问剪贴板，请手动选择上面的文本复制。' }
}
async function remove() {
  busy.value = true
  try { await deleteResource(props.resource.id); emit('deleted') }
  catch (e) { status.value = errorMessage(e) }
  finally { busy.value = false }
}
</script>
