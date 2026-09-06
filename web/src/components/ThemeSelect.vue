<template>
  <label class="theme-select" :title="`外观：${labels[theme.preference]}`">
    <component :is="icons[theme.preference]" :size="18" aria-hidden="true" />
    <select aria-label="外观主题" :value="theme.preference" @change="selectTheme">
      <option value="system">跟随系统</option>
      <option value="light">浅色</option>
      <option value="dark">深色</option>
    </select>
  </label>
</template>

<script setup lang="ts">
import { Monitor, Moon, Sun } from '@lucide/vue'
import { useThemeStore, type ThemePreference } from '@/stores/theme'

const theme = useThemeStore()
const labels = { system: '跟随系统', light: '浅色', dark: '深色' }
const icons = { system: Monitor, light: Sun, dark: Moon }

function selectTheme(event: Event) {
  theme.setPreference((event.target as HTMLSelectElement).value as ThemePreference)
}
</script>

<style scoped>
.theme-select {
  grid-column: 1 / -1;
  position: relative;
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  height: 38px;
  padding: 0 10px;
  color: var(--nx-text-secondary);
  background: var(--nx-bg-raised);
  border: 1px solid var(--nx-border-default);
  border-radius: var(--nx-radius-md);
}
.theme-select:focus-within { outline: 2px solid var(--nx-accent); outline-offset: 2px; }
.theme-select svg { flex-shrink: 0; }
select {
  width: 100%;
  min-width: 0;
  height: 100%;
  border: 0;
  outline: none;
  background: transparent;
  color: inherit;
  cursor: pointer;
}
option { background: var(--nx-bg-overlay); color: var(--nx-text-primary); }
@media (max-width: 720px) {
  .theme-select { width: 36px; flex: 0 0 36px; justify-content: center; padding: 0; }
  /* 保留原生选择器的键盘和手机选择交互，窄屏仅展示当前模式图标。 */
  select { position: absolute; inset: 0; opacity: 0; }
}
</style>
