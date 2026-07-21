<template>
  <div id="nexus-app">
    <RouterView />
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { RouterView } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
onMounted(() => auth.loadContext())
</script>

<style>
/* 全局设计系统：设计令牌 + 基础样式 + 公共组件样式 */
/* main.ts 不在可修改范围，因此通过 App.vue 引入全局样式 */
@import './styles/tokens.css';
@import './styles/base.css';
@import './styles/components.css';
</style>
