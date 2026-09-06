<template>
  <dialog ref="dialog" class="resource-dialog" @close="$emit('close')" @click="backdrop">
    <form @submit.prevent="submit">
      <header class="dialog-heading">
        <div><span class="eyebrow">{{ form.kind === 'skill' ? 'SKILL' : 'MCP' }}</span><h2>{{ resource ? '编辑资源' : '收录新资源' }}</h2></div>
        <button type="button" class="icon-action" aria-label="关闭表单" @click="dialog?.close()"><X :size="20" /></button>
      </header>
      <p class="muted">这些内容会公开展示。请填写资源说明，凭据请在自己的客户端配置。</p>
      <label>名称<input v-model.trim="form.name" required maxlength="100" placeholder="给资源一个清晰的名称" /></label>
      <label>分类<select v-model="form.category"><option v-for="c in categories" :key="c">{{ c }}</option></select></label>
      <label>一句话介绍<textarea v-model.trim="form.summary" required maxlength="300" rows="2" placeholder="它能帮助别人解决什么问题？" /></label>
      <label>项目 / 文档地址<input v-model.trim="form.sourceUrl" type="url" pattern="https://.*" required maxlength="1000" placeholder="https://github.com/owner/repo" /><small>HTTPS 公开链接，请勿包含账号密码或查询参数。</small></label>
      <template v-if="form.kind === 'mcp'">
        <div class="form-columns">
          <label>传输协议<select v-model="form.transport" @change="transportChanged"><option value="streamable-http">Streamable HTTP</option><option value="sse">SSE</option><option value="stdio">本地 stdio</option></select></label>
          <label>鉴权方式<select v-model="form.authType" :disabled="form.transport === 'stdio'"><option value="bearer">Bearer Token</option><option value="none">无需 HTTP 鉴权</option></select></label>
        </div>
        <label v-if="form.transport !== 'stdio'">MCP 服务地址<input v-model.trim="form.endpoint" type="url" pattern="https://.*" required maxlength="1000" placeholder="https://example.com/mcp" /></label>
        <p v-if="form.authType === 'bearer'" class="auth-note"><KeyRound :size="16" />连接时由客户端输入 Token；目录不会收集或公开真实 Token。</p>
      </template>
      <label>{{ form.kind === 'skill' ? '安装命令（可选）' : form.transport === 'stdio' ? '本地启动方式' : '补充说明（可选）' }}<textarea v-model.trim="form.installCommand" :required="form.transport === 'stdio'" maxlength="1000" rows="2" :placeholder="form.kind === 'skill' ? 'npx skills add owner/repo' : '本地启动命令或依赖说明，不含真实凭据'" /><small>仅展示文本，网站不会执行命令。</small></label>
      <label>使用说明<textarea v-model.trim="form.description" maxlength="12000" rows="5" placeholder="适用场景、使用步骤、依赖条件，以及如何获取 Token（如需要）" /></label>
      <p v-if="error" class="resource-error" role="alert">{{ error }}</p>
      <footer class="dialog-footer"><button type="button" class="btn btn-secondary" @click="dialog?.close()">取消</button><button class="btn btn-primary" :disabled="busy">{{ busy ? '保存中…' : resource ? '保存修改' : '公开收录' }}</button></footer>
    </form>
  </dialog>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { X, KeyRound } from '@lucide/vue'
import { categories, emptyResource, errorMessage, saveResource, type Resource, type ResourceKind } from './api'
const props = defineProps<{ kind: ResourceKind; resource?: Resource }>()
const emit = defineEmits<{ close: []; saved: [resource: Resource] }>()
const dialog = ref<HTMLDialogElement>()
const form = reactive(emptyResource(props.kind))
if (props.resource) for (const key of Object.keys(form) as (keyof typeof form)[]) Object.assign(form, { [key]: props.resource[key] })
const busy = ref(false)
const error = ref('')
onMounted(() => dialog.value?.showModal())
function backdrop(event: MouseEvent) { if (event.target === dialog.value) dialog.value?.close() }
function transportChanged() { if (form.transport === 'stdio') { form.authType = 'none'; form.endpoint = '' } }
async function submit() {
  busy.value = true; error.value = ''
  try { emit('saved', await saveResource({ ...form }, props.resource?.id)) }
  catch (e) { error.value = errorMessage(e) }
  finally { busy.value = false }
}
</script>
