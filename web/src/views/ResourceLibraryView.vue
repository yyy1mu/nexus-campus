<template>
  <div class="resources-page">
    <AppHeader />
    <main class="resource-main">
      <PageIntro :title="kind === 'skill' ? 'Skill 资源库' : 'MCP 连接目录'" :eyebrow="kind === 'skill' ? 'DISCOVER / SKILLS' : 'CONNECT / MCP'" :description="kind === 'skill' ? '发现可复用的知识、方法与工具包，把好的工作方式留下来。' : '让工具与数据触手可及。选择服务，查看协议与鉴权方式，开始连接。'"><button class="btn btn-primary" @click="create"><Plus :size="16" />收录{{ kind === 'skill' ? ' Skill' : ' MCP' }}</button></PageIntro>
      <div class="resource-context"><span><component :is="kind === 'skill' ? Blocks : Plug" :size="14" />{{ kind === 'skill' ? '能力，从这里扩展' : '工具，从这里连接' }}</span><span class="context-line" /><small>EXPLORE THE POSSIBILITIES</small></div>
      <section class="resource-toolbar" aria-label="搜索与筛选">
        <label class="resource-search"><Search :size="18" /><input v-model="query" type="search" maxlength="100" placeholder="搜索名称、介绍或分类" aria-label="搜索资源" /></label>
        <div class="resource-scopes" aria-label="收录范围"><button v-for="s in scopes" :key="s.value" :class="{ active: scope === s.value }" :aria-pressed="scope === s.value" @click="changeScope(s.value)">{{ s.label }}</button></div>
      </section>
      <div class="category-filters" aria-label="资源分类"><button :class="{ active: !category }" :aria-pressed="!category" @click="category = ''">全部分类</button><button v-for="c in categories" :key="c" :class="{ active: category === c }" :aria-pressed="category === c" @click="category = c">{{ c }}</button></div>
      <div class="results-heading"><span><strong>{{ total }}</strong> 个结果 <span v-if="category"> / {{ category }}</span></span><div class="results-options"><span>最新收录</span><div class="view-toggle" aria-label="展示方式"><button :class="{ active: view === 'grid' }" :aria-pressed="view === 'grid'" aria-label="网格视图" @click="view = 'grid'"><LayoutGrid :size="16" /></button><button :class="{ active: view === 'list' }" :aria-pressed="view === 'list'" aria-label="列表视图" @click="view = 'list'"><List :size="16" /></button></div></div></div>
      <p v-if="notice" class="resource-notice" role="status">{{ notice }}</p>
      <div v-if="loading" class="resource-empty" role="status">正在加载资源…</div>
      <div v-else-if="error" class="resource-empty"><p class="resource-error" role="alert">{{ error }}</p><button class="btn btn-secondary" @click="load">重新加载</button></div>
      <div v-else-if="!items.length" class="resource-empty"><component :is="kind === 'skill' ? Blocks : Plug" :size="36" /><h2>{{ (query || category) ? '没有找到匹配的资源' : scope === 'favorites' ? '收藏夹还是空的' : '从收录第一个资源开始' }}</h2><p>{{ (query || category) ? '试试其他名称或分类。' : '保存值得推荐的工具，也让其他人发现它。' }}</p><button v-if="query || category" class="btn btn-secondary" @click="query = ''; category = ''">清除筛选</button><button v-else class="btn btn-secondary" @click="create"><Plus :size="16" />收录{{ kind === 'skill' ? ' Skill' : ' MCP' }}</button></div>
      <div v-else class="resource-grid" :class="{ 'list-view': view === 'list' }"><ResourceCard v-for="item in items" :key="item.id" :resource="item" :busy="pendingFavorites.has(item.id)" @open="open" @favorite="favorite" /></div>
      <nav v-if="totalPages > 1" class="resource-pagination" aria-label="资源分页"><button class="btn btn-secondary" :disabled="page === 0 || loading" @click="page--">上一页</button><span>{{ page + 1 }} / {{ totalPages }}</span><button class="btn btn-secondary" :disabled="page + 1 >= totalPages || loading" @click="page++">下一页</button></nav>
    </main>
    <ResourceForm v-if="showForm" :kind="kind" :resource="editing" @close="closeForm" @saved="saved" />
    <ResourceDetail v-if="selected" :resource="selected" @close="closeDetail" @edit="edit" @deleted="deleted" />
  </div>
</template>
<script setup lang="ts">
import { onBeforeUnmount, ref, watch, toRef } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Blocks, Plug, Plus, Search, LayoutGrid, List } from '@lucide/vue'
import AppHeader from '@/components/AppHeader.vue'
import PageIntro from '@/components/PageIntro.vue'
import { requestLogin } from '@/utils/authUi'
import ResourceCard from '@/features/resources/ResourceCard.vue'
import { useAuthStore } from '@/stores/auth'
import ResourceForm from '@/features/resources/ResourceForm.vue'
import ResourceDetail from '@/features/resources/ResourceDetail.vue'
import { categories, errorMessage, getResource, listResources, setFavorite, type Resource, type ResourceKind } from '@/features/resources/api'
import '@/features/resources/resources.css'
const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
const props = defineProps<{ kind: ResourceKind }>()
const kind = toRef(props, 'kind')
const query = ref('')
const category = ref('')
const view = ref<'grid'|'list'>('grid')
try { if (localStorage.getItem('nexus_resource_view') === 'list') view.value = 'list' } catch {}
watch(view, value => { try { localStorage.setItem('nexus_resource_view', value) } catch {} })
const scope = ref('all')
const page = ref(0)
const items = ref<Resource[]>([])
const total = ref(0)
const totalPages = ref(0)
const loading = ref(false)
const error = ref('')
const notice = ref('')
const showForm = ref(false)
const editing = ref<Resource>()
const selected = ref<Resource>()
const pendingFavorites = ref(new Set<number>())
const scopes = [{ value: 'all', label: '全部资源' }, { value: 'favorites', label: '我的收藏' }, { value: 'mine', label: '我的收录' }]
let controller: AbortController | undefined
let timer: ReturnType<typeof setTimeout> | undefined
let detailRequest = 0
async function load() {
  controller?.abort()
  const request = new AbortController(); controller = request
  loading.value = true; error.value = ''
  try {
    const result = await listResources({ kind: kind.value, q: query.value, scope: scope.value, category: category.value, page: page.value }, request.signal)
    if (request.signal.aborted) return
    items.value = result.items; total.value = result.total; totalPages.value = result.totalPages
    if (page.value > 0 && !result.items.length) page.value = Math.max(0, result.totalPages - 1)
  } catch (e) { if (!request.signal.aborted) error.value = errorMessage(e) }
  finally { if (!request.signal.aborted) loading.value = false }
}
function requireLogin() { if (auth.isLoggedIn) return true; requestLogin(); return false }
function changeScope(value: string) { if (value !== 'all' && !requireLogin()) return; scope.value = value }
function create() { if (!requireLogin()) return; editing.value = undefined; showForm.value = true }
function closeForm() { showForm.value = false; editing.value = undefined }
function closeDetail() { detailRequest++; selected.value = undefined; if (route.query.resource) void router.replace({ query: { ...route.query, resource: undefined } }) }
function open(item: Resource) { void router.replace({ query: { ...route.query, resource: item.id } }) }
function edit(item: Resource) { closeDetail(); editing.value = item; showForm.value = true }
async function saved(resource: Resource) { closeForm(); notice.value = '资源已保存。'; await load(); open(resource) }
async function deleted() { closeDetail(); notice.value = '资源已删除。'; await load() }
async function favorite(item: Resource) {
  if (!requireLogin() || pendingFavorites.value.has(item.id)) return
  pendingFavorites.value.add(item.id)
  try { const updated = await setFavorite(item); Object.assign(item, updated); if (scope.value === 'favorites') await load() }
  catch (e) { notice.value = errorMessage(e) }
  finally { pendingFavorites.value.delete(item.id) }
}
watch([() => route.query.resource, kind], async ([value]) => {
  const sequence = ++detailRequest
  selected.value = undefined
  if (typeof value !== 'string' || !/^\d+$/.test(value)) return
  try { const resource = await getResource(Number(value)); if (sequence === detailRequest) selected.value = resource }
  catch (e) { if (sequence === detailRequest) notice.value = errorMessage(e) }
}, { immediate: true })
watch(kind, () => { closeForm(); query.value = ''; category.value = ''; scope.value = 'all'; page.value = 0; notice.value = ''; void load() })
watch([scope, category], () => { page.value = 0; void load() })
watch(page, () => void load())
watch(query, () => { clearTimeout(timer); controller?.abort(); timer = setTimeout(() => { page.value = 0; void load() }, 250) })
watch(() => auth.token, () => { closeForm(); closeDetail(); scope.value = 'all'; notice.value = ''; void load() })
onBeforeUnmount(() => { controller?.abort(); clearTimeout(timer); detailRequest++ })
void load()
</script>
