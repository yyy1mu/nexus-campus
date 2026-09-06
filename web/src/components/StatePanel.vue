<template>
  <div class="state-panel" :class="tone" :role="tone === 'error' ? 'alert' : 'status'">
    <span class="state-symbol"><component :is="tone === 'error' ? TriangleAlert : tone === 'loading' ? LoaderCircle : Inbox" :size="26" :class="{ spin: tone === 'loading' }" /></span>
    <strong>{{ title }}</strong><p v-if="description">{{ description }}</p><div v-if="$slots.default" class="state-actions"><slot /></div>
  </div>
</template>
<script setup lang="ts">
import { Inbox, LoaderCircle, TriangleAlert } from '@lucide/vue'
withDefaults(defineProps<{ title: string; description?: string; tone?: 'empty'|'error'|'loading' }>(), { tone: 'empty' })
</script>
<style scoped>
.state-panel { min-height: 260px; padding: 36px 24px; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 12px; border: 1px solid var(--nx-border-default); border-radius: 16px; background: var(--nx-bg-raised); }
.state-symbol { display: grid; place-items: center; width: 56px; height: 56px; border: 1px solid var(--nx-border-default); border-radius: 16px; color: var(--nx-accent); background: var(--nx-accent-subtle); margin-bottom: 5px; }
strong { color: var(--nx-text-primary); font-size: 17px; } p { max-width: 380px; color: var(--nx-text-tertiary); line-height: 1.8; font-size: 13px; } .error .state-symbol { color: var(--nx-danger); } .state-actions { margin-top: 8px; } .spin { animation: spin 1.4s linear infinite; } @keyframes spin { to {transform: rotate(360deg)} } @media(prefers-reduced-motion:reduce) { .spin {animation:none} }
</style>
