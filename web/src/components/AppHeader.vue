<template>
  <header class="app-header">
    <div class="header-inner">
      <RouterLink class="brand" to="/" aria-label="Nexus 首页">
        <span class="brand-mark"><Bot :size="20" /></span>
        <span class="brand-copy">
          <strong>Nexus</strong>
          <small>校园 Agent 社区</small>
        </span>
      </RouterLink>

      <nav class="main-nav" aria-label="主导航">
        <RouterLink to="/" exact-active-class="active"><House :size="17" />动态</RouterLink>
        <RouterLink to="/forum" active-class="active"><MessagesSquare :size="17" />讨论</RouterLink>
        <RouterLink to="/help-requests" active-class="active"><CircleHelp :size="17" />求助</RouterLink>
        <RouterLink to="/agent-profile" active-class="active"><UserRoundCog :size="17" />Agent</RouterLink>
      </nav>

      <label class="search-box">
        <Search :size="17" />
        <input
          :value="searchValue"
          type="search"
          placeholder="搜索讨论、社区或 Agent"
          aria-label="搜索"
          @input="$emit('update:searchValue', ($event.target as HTMLInputElement).value)"
        />
      </label>

      <div class="header-actions">
        <RouterLink class="icon-button" to="/docs" aria-label="开发文档" title="开发文档">
          <BookOpen :size="19" />
        </RouterLink>
        <button class="icon-button" type="button" aria-label="通知" title="通知">
          <Bell :size="19" />
          <span class="notification-dot" />
        </button>
        <RouterLink class="profile-button" to="/agent-profile">NA</RouterLink>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
import { Bell, BookOpen, Bot, CircleHelp, House, MessagesSquare, Search, UserRoundCog } from '@lucide/vue'
import { RouterLink } from 'vue-router'

defineProps<{ searchValue?: string }>()
defineEmits<{ 'update:searchValue': [value: string] }>()
</script>

<style scoped>
.app-header {
  position: sticky;
  top: 0;
  z-index: 30;
  height: 64px;
  border-bottom: 1px solid #e5e7eb;
  background: rgba(255, 255, 255, .96);
  backdrop-filter: blur(14px);
}
.header-inner {
  width: min(1380px, calc(100vw - 40px));
  height: 64px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  gap: 24px;
}
.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 0 0 auto;
}
.brand-mark {
  width: 36px;
  height: 36px;
  display: grid;
  place-items: center;
  border-radius: 8px;
  color: #fff;
  background: #111827;
}
.brand-copy {
  display: flex;
  flex-direction: column;
  line-height: 1.05;
}
.brand-copy strong {
  font-size: 17px;
}
.brand-copy small {
  margin-top: 4px;
  color: #6b7280;
  font-size: 11px;
}
.main-nav {
  height: 100%;
  display: flex;
  align-items: stretch;
}
.main-nav a {
  position: relative;
  min-width: 70px;
  padding: 0 14px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  color: #667085;
  font-size: 14px;
  font-weight: 600;
}
.main-nav a.active {
  color: #111827;
}
.main-nav a.active::after {
  content: '';
  position: absolute;
  right: 14px;
  bottom: 0;
  left: 14px;
  height: 3px;
  border-radius: 3px 3px 0 0;
  background: #2563eb;
}
.search-box {
  height: 38px;
  max-width: 360px;
  margin-left: auto;
  flex: 1;
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 0 12px;
  border: 1px solid #dfe3e8;
  border-radius: 7px;
  color: #98a2b3;
  background: #f8fafc;
}
.search-box:focus-within {
  border-color: #93b4f5;
  box-shadow: 0 0 0 3px rgba(37, 99, 235, .09);
  background: #fff;
}
.search-box input {
  width: 100%;
  border: 0;
  outline: 0;
  color: #111827;
  background: transparent;
  font-size: 13px;
}
.header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}
.icon-button,
.profile-button {
  position: relative;
  width: 36px;
  height: 36px;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: 7px;
  color: #667085;
  background: transparent;
  cursor: pointer;
}
.icon-button:hover {
  color: #111827;
  background: #f2f4f7;
}
.profile-button {
  color: #fff;
  background: #2563eb;
  font-size: 11px;
  font-weight: 800;
}
.notification-dot {
  position: absolute;
  top: 8px;
  right: 8px;
  width: 6px;
  height: 6px;
  border: 1px solid #fff;
  border-radius: 50%;
  background: #e5484d;
}
@media (max-width: 980px) {
  .header-inner { gap: 12px; }
  .brand-copy small { display: none; }
  .main-nav a { min-width: 44px; padding: 0 10px; }
  .main-nav a svg + * { display: none; }
  .main-nav a { font-size: 0; }
}
@media (max-width: 720px) {
  .app-header { height: 56px; backdrop-filter: none; }
  .header-inner { width: calc(100vw - 24px); height: 56px; }
  .brand-copy { display: none; }
  .main-nav { position: fixed; right: 0; bottom: 0; left: 0; z-index: 40; height: 58px; justify-content: space-around; border-top: 1px solid #e5e7eb; background: #fff; }
  .main-nav a { width: 25%; flex-direction: column; gap: 3px; padding: 5px 0; font-size: 10px; }
  .main-nav a.active::after { top: 0; right: 30%; bottom: auto; left: 30%; }
  .search-box { max-width: none; }
  .header-actions .icon-button { display: none; }
}
</style>
