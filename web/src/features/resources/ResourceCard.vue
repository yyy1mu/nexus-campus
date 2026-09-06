<template>
  <article class="resource-card" :class="{ 'mcp-card': resource.kind === 'mcp' }">
    <div class="resource-card-top"><span class="resource-icon"><component :is="icon" :size="22" /></span><span class="category-chip">{{ resource.category }}</span><span v-if="demo" class="demo-chip">DEMO</span></div>
    <div class="resource-card-body"><button class="resource-title" @click="$emit('open', resource)">{{ resource.name.replace(/ · 演示$/, '') }}</button><span class="resource-origin">{{ demo ? 'NEXUS / 演示资源' : host }}</span><p class="resource-card-summary">{{ resource.summary }}</p></div>
    <div class="resource-labels"><span v-if="resource.kind === 'mcp'" class="protocol-tag">{{ resource.transport === 'streamable-http' ? 'HTTP' : resource.transport.toUpperCase() }}</span><span v-if="resource.authType === 'bearer'"><KeyRound :size="12" />Token 鉴权</span><span v-else-if="resource.kind === 'mcp'"><ShieldCheck :size="12" />{{ resource.transport === 'stdio' ? '本地运行' : '公开访问' }}</span><span v-else><Terminal :size="12" />{{ resource.installCommand ? '含安装说明' : '查看使用文档' }}</span><span v-if="resource.editable">我的收录</span></div>
    <footer><button class="resource-detail-link" @click="$emit('open', resource)">{{ resource.kind === 'skill' ? '探索 Skill' : '查看接入' }}<ArrowUpRight :size="15" /></button><button v-if="!compact" class="favorite-button" :class="{ saved: resource.favorited }" :disabled="busy" :aria-pressed="resource.favorited" :aria-label="`${resource.favorited ? '取消收藏' : '收藏'} ${resource.name}`" @click="$emit('favorite', resource)"><Bookmark :size="16" :fill="resource.favorited ? 'currentColor' : 'none'" />{{ resource.favoriteCount }}</button><span v-else class="compact-count"><Bookmark :size="13" />{{ resource.favoriteCount }}</span></footer>
  </article>
</template>
<script setup lang="ts">
import { computed } from 'vue'
import { ArrowUpRight, Bookmark, BookOpen, Code2, Database, KeyRound, Palette, Plug, ShieldCheck, Terminal, Workflow, Boxes } from '@lucide/vue'
import type { Resource } from './api'
const props = defineProps<{ resource: Resource; busy?: boolean; compact?: boolean }>()
defineEmits<{ open: [resource: Resource]; favorite: [resource: Resource] }>()
const demo = computed(() => props.resource.description.startsWith('【MOCK 演示数据】'))
const host = computed(() => { try { return new URL(props.resource.sourceUrl).hostname } catch { return '项目文档' } })
const icon = computed(() => props.resource.kind === 'mcp' ? Plug : ({ '开发工具': Code2, '设计体验': Palette, '数据处理': Database, '学习研究': BookOpen, '效率工具': Workflow } as Record<string, typeof Code2>)[props.resource.category] || Boxes)
</script>
