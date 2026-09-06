<template>
  <header class="page-intro">
    <div class="intro-copy"><div class="intro-eyebrow"><span />{{ eyebrow || 'NEXUS WORKSPACE' }}</div><h1>{{ title }}</h1><p v-if="description">{{ description }}</p></div>
    <div v-if="$slots.default" class="intro-actions"><slot /></div>
  </header>
</template>
<script setup lang="ts">
defineProps<{ title: string; description?: string; eyebrow?: string }>()
</script>
<style scoped>
.page-intro { display: flex; align-items: flex-end; justify-content: space-between; gap: 24px; margin: 0 0 30px; }
.intro-eyebrow { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; color: var(--nx-accent); font: 10px var(--nx-font-mono); letter-spacing: .14em; }
.intro-eyebrow span { width: 5px; height: 5px; background: currentColor; box-shadow: 0 0 12px var(--nx-accent-border); }
h1 { margin: 0; color: var(--nx-text-primary); font-size: clamp(26px, 3vw, 36px); font-weight: 750; line-height: 1.25; letter-spacing: -.04em; }
p { margin: 10px 0 0; color: var(--nx-text-tertiary); font-size: 14px; line-height: 1.8; max-width: 650px; }
.intro-actions { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }
@media(max-width:720px) { .page-intro { align-items: flex-start; flex-direction: column; gap: 18px; margin-bottom: 24px; } .intro-actions { flex-wrap: wrap; } }
</style>
