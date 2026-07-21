<template>
  <div class="discussion-page">
    <AppHeader />

    <section class="title-hero">
      <RouterLink
        v-if="discussion"
        class="tag-pill"
        :style="{ color: discussion.tagColor }"
        :to="`/t/${discussion.tagSlug}`"
      ><span :style="{ backgroundColor: discussion.tagColor }" />{{ discussion.tagName }}</RouterLink>
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
        <button>登录后回复</button>
        <p class="original"><FileText :size="14" />原始帖子</p>
        <div class="line">
          <span class="line-fill" />
          <div class="line-label">
            <strong>1 of 1 post</strong>
            <span>July 2026</span>
          </div>
        </div>
        <p class="now"><Clock3 :size="14" />现在</p>
      </aside>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { Clock3, FileText } from '@lucide/vue'
import { RouterLink, useRoute } from 'vue-router'
import AppHeader from '@/components/AppHeader.vue'
import { discussions } from '@/data/nexusSeed'

const route = useRoute()
const discussion = computed(() => discussions.find((item) => String(item.id) === String(route.params.id)) || discussions[2])
const formattedBody = computed(() => discussion.value.body.split('\n').filter((line) => line.trim().length))
</script>

<style scoped>
.discussion-page {
  min-height: 100vh;
  background: var(--nx-bg-base);
}
.title-hero {
  width: 1084px;
  max-width: calc(100vw - 32px);
  margin: var(--nx-space-6) auto 0;
  padding: 22px 24px;
  border: 1px solid var(--nx-border-subtle);
  border-radius: var(--nx-radius-lg);
  background: var(--nx-bg-raised);
}
.tag-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--nx-fs-11);
  font-weight: 700;
}
.tag-pill span { width: 7px; height: 7px; border-radius: 2px; }
.title-hero h1 {
  margin-top: 10px;
  color: var(--nx-text-primary);
  font-size: 22px;
  font-weight: 700;
  line-height: 1.35;
}
.discussion-layout {
  width: 1084px;
  max-width: calc(100vw - 32px);
  margin: 28px auto 0;
  padding-bottom: 64px;
  display: grid;
  grid-template-columns: 1fr 150px;
  gap: 68px;
}
.post {
  padding: 22px;
  display: grid;
  grid-template-columns: 72px 1fr;
  border: 1px solid var(--nx-border-subtle);
  border-radius: var(--nx-radius-lg);
  background: var(--nx-bg-raised);
  align-self: start;
}
.avatar {
  width: 64px;
  height: 64px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: var(--nx-on-accent);
  background: var(--nx-accent-dim);
  font-size: 34px;
}
.post-meta {
  display: flex;
  gap: 10px;
  align-items: center;
  height: 30px;
  color: var(--nx-text-primary);
  font-size: var(--nx-fs-14);
}
.post-meta span {
  color: var(--nx-text-tertiary);
  font-weight: 700;
}
.post-content {
  margin-top: 12px;
  min-height: 238px;
  color: var(--nx-text-secondary);
  font-size: 15px;
  line-height: 1.75;
}
.post-content .heading {
  margin-bottom: 14px;
  color: var(--nx-text-primary);
  font-weight: 700;
}
.divider {
  height: 1px;
  margin-top: 34px;
  background: var(--nx-border-subtle);
}
.reply-placeholder {
  display: flex;
  align-items: center;
  gap: 21px;
  margin-top: 68px;
  color: var(--nx-text-tertiary);
  font-size: var(--nx-fs-16);
}
.blank-avatar {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: var(--nx-bg-active);
}
.timeline button {
  width: 150px;
  height: 38px;
  border: 0;
  border-radius: var(--nx-radius-md);
  color: var(--nx-on-accent);
  background: var(--nx-accent);
  font-weight: 700;
  cursor: pointer;
}
.timeline button:hover { background: var(--nx-accent-strong); }
.timeline button:active { background: var(--nx-accent-dim); }
.original {
  margin-top: 33px;
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--nx-text-tertiary);
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
  background: var(--nx-accent);
}
.line-label {
  position: absolute;
  left: 18px;
  top: 124px;
  color: var(--nx-text-primary);
}
.line-label strong,
.line-label span {
  display: block;
}
.line-label span,
.now {
  color: var(--nx-text-tertiary);
}
.now {
  margin-top: 15px;
  display: flex;
  align-items: center;
  gap: 6px;
}
@media (max-width: 820px) {
  .discussion-layout {
    grid-template-columns: 1fr;
  }
  .timeline {
    display: none;
  }
  .discussion-page { padding-bottom: 58px; }
}
</style>
