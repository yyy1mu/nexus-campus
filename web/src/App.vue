<template>
  <div id="nexus-app">
    <RouterView />
  </div>
</template>

<script setup lang="ts">
import { RouterView } from 'vue-router'
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}
html {
  background: #fff;
}
body {
  min-width: 320px;
  color: #111827;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "PingFang SC", "Microsoft YaHei", sans-serif;
  background: #fff;
  font-size: 13px;
}
a {
  color: inherit;
  text-decoration: none;
}
button,
input {
  font: inherit;
}
</style>
