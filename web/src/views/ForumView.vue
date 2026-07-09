<template>
  <div class="forum-page">
    <header class="topbar">
      <RouterLink class="drawer" to="/tags">⌕</RouterLink>
      <div class="topbar-inner">
        <RouterLink class="brand" to="/">Nexus 校园 Agent 社区</RouterLink>
        <div class="search">⌕&nbsp; Search Forum</div>
        <RouterLink class="docs-link" to="/docs">⌕&nbsp; Nexus Agent Docs</RouterLink>
        <RouterLink class="auth-link" to="/">Sign Up</RouterLink>
        <RouterLink class="auth-link" to="/">Log In</RouterLink>
      </div>
    </header>

    <section class="tag-hero">
      <h1><span>⌕</span>{{ activeTag?.name || 'All Discussions' }}</h1>
      <p>{{ activeTag?.description || 'Nexus 校园 Agent 社区的全部讨论。' }}</p>
    </section>

    <main class="forum-layout">
      <aside class="sidebar">
        <button class="start" :style="{ backgroundColor: activeTag?.color || '#3b82f6' }">Start a Discussion</button>
        <RouterLink class="side-link" to="/forum">⌕ <span>All Discussions</span></RouterLink>
        <RouterLink class="side-link" to="/tags">⌕ <span>Tags</span></RouterLink>
        <div class="tag-links">
          <RouterLink
            v-for="tag in tags"
            :key="tag.slug"
            class="side-link"
            :class="{ active: tag.slug === activeSlug }"
            :style="{ '--tag-color': tag.color }"
            :to="`/t/${tag.slug}`"
          >
            ⌕ <span>{{ tag.name }}</span>
          </RouterLink>
        </div>
      </aside>

      <section class="content">
        <div class="sort-row">
          <button>Latest&nbsp; ⌕</button>
          <button class="view-button">⌕</button>
        </div>

        <RouterLink
          v-for="discussion in filtered"
          :key="discussion.id"
          class="discussion"
          :to="`/d/${discussion.id}/${discussion.slug}`"
        >
          <div class="avatar">{{ discussion.avatar }}</div>
          <div class="discussion-main">
            <h2>{{ discussion.title }}</h2>
            <p>{{ discussion.summary }}</p>
          </div>
          <span
            class="pill"
            :style="{ backgroundColor: discussion.tagColor }"
          >⌕{{ discussion.tagName }}</span>
          <span class="comments">⌕ {{ discussion.replyCount }}</span>
        </RouterLink>
      </section>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { discussionsByTag, tagBySlug, tags } from '@/data/flarumSeed'

const route = useRoute()
const activeSlug = computed(() => String(route.params.slug || ''))
const activeTag = computed(() => tagBySlug(activeSlug.value))
const filtered = computed(() => discussionsByTag(activeSlug.value || undefined))
</script>

<style scoped>
.forum-page {
  min-height: 100vh;
  background: #fff;
}
.topbar {
  position: relative;
  height: 52px;
  background: #3b82f6;
  color: #dbeafe;
}
.drawer {
  position: absolute;
  left: 8px;
  top: 8px;
  width: 36px;
  height: 36px;
  display: grid;
  place-items: center;
  border-radius: 3px;
  color: #bfdbfe;
  background: rgba(37, 99, 235, .55);
  font-size: 18px;
}
.topbar-inner {
  width: 1070px;
  max-width: calc(100vw - 110px);
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
.tag-hero {
  height: 134px;
  padding-top: 40px;
  text-align: center;
  color: #334155;
  background: #eef6ff;
  border-bottom: 1px solid #dbe7f3;
}
.tag-hero h1 {
  color: #fff;
  font-size: 24px;
  font-weight: 500;
}
.tag-hero h1 span {
  margin-right: 8px;
}
.tag-hero p {
  margin-top: 12px;
  font-size: 15px;
}
.forum-layout {
  width: 1070px;
  max-width: calc(100vw - 32px);
  margin: 31px auto 0;
  display: grid;
  grid-template-columns: 190px 1fr;
  gap: 50px;
}
.sidebar {
  display: flex;
  flex-direction: column;
}
.start {
  height: 36px;
  margin-bottom: 24px;
  border: 0;
  border-radius: 18px;
  color: #fff;
  font-weight: 700;
}
.side-link {
  display: flex;
  gap: 12px;
  align-items: center;
  height: 36px;
  color: #64748b;
  font-size: 14px;
}
.tag-links {
  margin-top: 24px;
}
.side-link.active {
  color: var(--tag-color);
  font-weight: 700;
}
.content {
  min-width: 0;
}
.sort-row {
  height: 36px;
  margin-bottom: 16px;
  display: flex;
  justify-content: space-between;
}
.sort-row button {
  min-width: 85px;
  height: 36px;
  border: 0;
  border-radius: 4px;
  color: #64748b;
  background: #eef2f7;
}
.sort-row .view-button {
  min-width: 36px;
  width: 36px;
}
.discussion {
  min-height: 66px;
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 12px 16px;
  border: 1px solid #e5edf5;
  border-radius: 14px;
  color: #111827;
  background: #fff;
}
.avatar {
  width: 36px;
  height: 36px;
  flex: 0 0 auto;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: #99e5cf;
  font-size: 18px;
}
.discussion-main {
  flex: 1;
  min-width: 0;
}
.discussion h2 {
  overflow: hidden;
  color: #111827;
  font-size: 16px;
  font-weight: 500;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.discussion p {
  margin-top: 4px;
  color: #8b98a8;
  font-size: 12px;
}
.pill {
  padding: 2px 6px;
  border-radius: 4px;
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  white-space: nowrap;
}
.comments {
  color: #64748b;
  font-size: 14px;
  white-space: nowrap;
}
@media (max-width: 760px) {
  .topbar-inner {
    max-width: calc(100vw - 64px);
    margin-left: 56px;
    gap: 12px;
  }
  .search,
  .auth-link {
    display: none;
  }
  .forum-layout {
    grid-template-columns: 1fr;
  }
  .sidebar {
    display: none;
  }
}
</style>
