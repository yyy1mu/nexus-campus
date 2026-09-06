import { computed, onScopeDispose, ref, watch } from 'vue'
import { defineStore } from 'pinia'

export type ThemePreference = 'system' | 'light' | 'dark'
const STORAGE_KEY = 'nexus_theme'

function normalizePreference(value: string | null | undefined): ThemePreference {
  return value === 'light' || value === 'dark' ? value : 'system'
}

export const useThemeStore = defineStore('theme', () => {
  const media = window.matchMedia('(prefers-color-scheme: dark)')
  const preference = ref<ThemePreference>(normalizePreference(document.documentElement.dataset.themePreference))
  const systemDark = ref(media.matches)
  const resolvedTheme = computed(() => preference.value === 'system'
    ? (systemDark.value ? 'dark' : 'light')
    : preference.value)

  function applyTheme() {
    document.documentElement.dataset.theme = resolvedTheme.value
    document.documentElement.dataset.themePreference = preference.value
    document.documentElement.style.colorScheme = resolvedTheme.value
    document.querySelector('meta[name="theme-color"]')?.setAttribute(
      'content', resolvedTheme.value === 'dark' ? '#080e18' : '#f3f6fa',
    )
  }

  function setPreference(value: ThemePreference) {
    preference.value = normalizePreference(value)
    try {
      localStorage.setItem(STORAGE_KEY, preference.value)
    } catch { /* 存储不可用时仍可在当前页面切换。 */ }
  }

  function onSystemChange(event: MediaQueryListEvent) {
    systemDark.value = event.matches
  }

  function onStorage(event: StorageEvent) {
    if (event.key === STORAGE_KEY || event.key === null) {
      preference.value = normalizePreference(event.newValue)
    }
  }

  watch([preference, resolvedTheme], applyTheme, { immediate: true, flush: 'sync' })
  media.addEventListener('change', onSystemChange)
  window.addEventListener('storage', onStorage)
  onScopeDispose(() => {
    media.removeEventListener('change', onSystemChange)
    window.removeEventListener('storage', onStorage)
  })

  return { preference, resolvedTheme, setPreference }
})
