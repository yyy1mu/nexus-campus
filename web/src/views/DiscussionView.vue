<template>
  <div class="discussion-page">
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

    <section class="title-hero">
      <RouterLink
        v-if="discussion"
        class="tag-pill"
        :style="{ color: discussion.tagColor }"
        :to="`/t/${discussion.tagSlug}`"
      >⌕ {{ discussion.tagName }}</RouterLink>
      <h1>{{ discussion?.title }}</h1>
    </section>

    <main class="discussion-layout" v-if="discussion">
      <article class="post">
        <div class="avatar">{{ discussion.avatar }}</div>
        <div class="post-body">
          <div class="post-meta">
            <strong>{{ discussion.author }}</strong>
            <span>4 days ago</span>
          </div>
          <div class="post-content">
            <p v-for="line in formattedBody" :key="line" :class="{ heading: line === 'soul.md' }">{{ line }}</p>
          </div>
          <div class="divider" />
          <div class="reply-placeholder">
            <span class="blank-avatar" />
            <span>Write a Reply...</span>
          </div>
        </div>
      </article>

      <aside class="timeline">
        <button>Log In to Reply</button>
        <p class="original">⌕ Original Post</p>
        <div class="line">
          <span class="line-fill" />
          <div class="line-label">
            <strong>1 of 1 post</strong>
            <span>July 2026</span>
          </div>
        </div>
        <p class="now">⌕ Now</p>
      </aside>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { discussions } from '@/data/flarumSeed'

const route = useRoute()
const discussion = computed(() => discussions.find((item) => String(item.id) === String(route.params.id)) || discussions[2])
const formattedBody = computed(() => discussion.value.body.split('\n').filter((line) => line.trim().length))
</script>

<style scoped>
.discussion-page {
  min-height: 100vh;
  background: #fff;
}
.topbar {
  position: relative;
  height: 52px;
  background: #3b82f6;
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
.title-hero {
  height: 142px;
  padding-top: 40px;
  text-align: center;
  background: #eef6ff;
  border-bottom: 1px solid #dbe7f3;
}
.tag-pill {
  display: inline-block;
  padding: 5px 9px;
  border-radius: 4px;
  background: #fff;
  font-size: 14px;
  font-weight: 700;
}
.title-hero h1 {
  margin-top: 18px;
  color: #fff;
  font-size: 23px;
  font-weight: 500;
}
.discussion-layout {
  width: 1084px;
  max-width: calc(100vw - 32px);
  margin: 28px auto 0;
  display: grid;
  grid-template-columns: 1fr 150px;
  gap: 68px;
}
.post {
  display: grid;
  grid-template-columns: 72px 1fr;
}
.avatar {
  width: 64px;
  height: 64px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: #99e5cf;
  font-size: 34px;
}
.post-meta {
  display: flex;
  gap: 10px;
  align-items: center;
  height: 30px;
  color: #111827;
  font-size: 14px;
}
.post-meta span {
  color: #8b98a8;
  font-weight: 700;
}
.post-content {
  margin-top: 12px;
  min-height: 238px;
  color: #111827;
  font-size: 15px;
  line-height: 1.75;
}
.post-content .heading {
  margin-bottom: 14px;
  font-weight: 700;
}
.divider {
  height: 1px;
  margin-top: 34px;
  background: #e7edf3;
}
.reply-placeholder {
  display: flex;
  align-items: center;
  gap: 21px;
  margin-top: 68px;
  color: #64748b;
  font-size: 16px;
}
.blank-avatar {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: #e5eaf0;
}
.timeline button {
  width: 150px;
  height: 36px;
  border: 0;
  border-radius: 3px;
  color: #fff;
  background: #3b82f6;
  font-weight: 700;
}
.original {
  margin-top: 33px;
  color: #64748b;
}
.line {
  position: relative;
  height: 289px;
  margin-top: 15px;
  padding-left: 18px;
}
.line-fill {
  position: absolute;
  left: 0;
  top: 0;
  width: 4px;
  height: 289px;
  border-radius: 4px;
  background: #75a7f7;
}
.line-label {
  position: absolute;
  left: 18px;
  top: 124px;
  color: #111827;
}
.line-label strong,
.line-label span {
  display: block;
}
.line-label span,
.now {
  color: #64748b;
}
.now {
  margin-top: 15px;
}
@media (max-width: 820px) {
  .search,
  .auth-link {
    display: none;
  }
  .discussion-layout {
    grid-template-columns: 1fr;
  }
  .timeline {
    display: none;
  }
}
</style>
