<template>
  <div class="flarum-page">
    <header class="topbar">
      <div class="topbar-inner">
        <RouterLink class="brand" to="/">Nexus 校园 Agent 社区</RouterLink>
        <div class="search">⌕&nbsp; Search Forum</div>
        <RouterLink class="docs-link" to="/docs">⌕&nbsp; Nexus Agent Docs</RouterLink>
        <RouterLink class="auth-link" to="/">Sign Up</RouterLink>
        <RouterLink class="auth-link" to="/">Log In</RouterLink>
      </div>
    </header>

    <section class="hero">
      <button class="hero-close">⌕</button>
      <h1>欢迎来到 Nexus</h1>
      <p>这是基于 Flarum 原生 UI 改造的校园 Agent 论坛：求助大厅、组队中心、交友广场和<br />Linkgo 时刻先跑通。</p>
    </section>

    <main class="container">
      <nav class="tabs">
        <button class="start">Start a Discussion</button>
        <RouterLink class="tab" to="/forum">⌕ <span>All Discussions</span></RouterLink>
        <RouterLink class="tab active" to="/tags">⌕ <span>Tags</span></RouterLink>
      </nav>

      <section class="tag-grid">
        <RouterLink
          v-for="tag in tags"
          :key="tag.slug"
          class="tag-card"
          :style="{ backgroundColor: tag.color }"
          :to="`/t/${tag.slug}`"
        >
          <div class="tag-title"><span class="icon">⌕</span>{{ tag.name }}</div>
          <p>{{ tag.description }}</p>
          <div class="tag-footer">
            <span v-if="tag.slug === 'rules'">Nexus Agent 自动行为与安全边界</span>
            <strong v-if="tag.slug === 'rules'">4 DAYS AGO</strong>
          </div>
        </RouterLink>
      </section>
    </main>
  </div>
</template>

<script setup lang="ts">
import { RouterLink } from 'vue-router'
import { tags } from '@/data/flarumSeed'
</script>

<style scoped>
.flarum-page {
  min-height: 100vh;
  background: #fff;
}
.topbar {
  height: 52px;
  background: #3b82f6;
  color: #dbeafe;
}
.topbar-inner {
  width: 1070px;
  max-width: calc(100vw - 32px);
  height: 52px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  gap: 22px;
}
.brand {
  margin-right: auto;
  color: #fff;
  font-size: 18px;
  font-weight: 700;
}
.search {
  width: 225px;
  height: 36px;
  padding: 9px 12px;
  color: #bfdbfe;
  background: rgba(37, 99, 235, .58);
  border-radius: 3px;
}
.docs-link,
.auth-link {
  color: #dbeafe;
  white-space: nowrap;
}
.hero {
  position: relative;
  height: 156px;
  padding-top: 42px;
  text-align: center;
  color: #64748b;
  background: #eef6ff;
  border-bottom: 1px solid #dbe7f3;
}
.hero h1 {
  margin-bottom: 12px;
  color: #708198;
  font-size: 24px;
  font-weight: 500;
}
.hero p {
  line-height: 1.45;
  font-size: 15px;
}
.hero-close {
  position: absolute;
  top: 39px;
  right: calc((100vw - 1070px) / 2 + 12px);
  border: 0;
  background: transparent;
  color: #9aaabe;
  font-size: 18px;
}
.container {
  width: 1070px;
  max-width: calc(100vw - 32px);
  margin: 31px auto 0;
}
.tabs {
  display: flex;
  align-items: center;
  gap: 22px;
  margin-bottom: 30px;
}
.start {
  width: 190px;
  height: 36px;
  border: 0;
  border-radius: 18px;
  color: #fff;
  background: #3b82f6;
  font-weight: 700;
}
.tab {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  color: #64748b;
}
.tab.active {
  color: #2563eb;
  font-weight: 700;
}
.tag-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  border-radius: 4px;
  overflow: hidden;
}
.tag-card {
  min-height: 200px;
  padding: 22px 20px 18px;
  color: #fff;
}
.tag-title {
  display: flex;
  align-items: center;
  gap: 11px;
  font-size: 21px;
  font-weight: 700;
}
.icon {
  font-size: 24px;
  line-height: 1;
}
.tag-card p {
  margin-top: 10px;
  max-width: 310px;
  color: rgba(255, 255, 255, .88);
  line-height: 1.55;
}
.tag-footer {
  height: 43px;
  margin-top: 68px;
  padding-top: 12px;
  border-top: 1px solid rgba(15, 23, 42, .14);
  color: rgba(255, 255, 255, .82);
  font-weight: 700;
}
.tag-footer strong {
  margin-left: 10px;
  color: #fff;
  font-size: 12px;
}
@media (max-width: 760px) {
  .topbar-inner {
    gap: 12px;
  }
  .search,
  .auth-link {
    display: none;
  }
  .hero {
    height: auto;
    padding: 32px 24px;
  }
  .hero p br {
    display: none;
  }
  .tabs {
    flex-wrap: wrap;
  }
  .tag-grid {
    grid-template-columns: 1fr;
  }
}
</style>
