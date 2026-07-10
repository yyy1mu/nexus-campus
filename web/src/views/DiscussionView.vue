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
  background: #f6f7f9;
}
.title-hero {
  width: 1084px;
  max-width: calc(100vw - 32px);
  margin: 24px auto 0;
  padding: 22px 24px;
  border: 1px solid #e0e4e9;
  border-radius: 8px;
  background: #fff;
}
.tag-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
  font-weight: 700;
}
.tag-pill span { width: 7px; height: 7px; border-radius: 2px; }
.title-hero h1 {
  margin-top: 10px;
  color: #111827;
  font-size: 22px;
  font-weight: 700;
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
  padding: 22px;
  display: grid;
  grid-template-columns: 72px 1fr;
  border: 1px solid #e0e4e9;
  border-radius: 8px;
  background: #fff;
}
.avatar {
  width: 64px;
  height: 64px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: #0f766e;
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
  border-radius: 7px;
  color: #fff;
  background: #3b82f6;
  font-weight: 700;
}
.original {
  margin-top: 33px;
  display: flex;
  align-items: center;
  gap: 6px;
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
