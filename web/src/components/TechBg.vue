<template>
  <canvas ref="canvasRef" class="tech-bg" aria-hidden="true"></canvas>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'

/**
 * TechBg —— 全屏流动代码字符背景（科技感氛围层）
 * 设计参考：横向缓慢漂移的低透明度代码字符流（非纵向下落代码雨）。
 * - 字符集：大写字母 + 数字 + 代码符号，14px 等宽字体，约 13% 空格留白
 * - 淡绿白字符（呼应荧光绿主题），单行透明度 0.08~0.30，整体克制不干扰阅读
 * - 各行以不同速度向左漂移形成视差；同行双绘实现无缝循环铺满
 * - 鼠标跟随淡绿辉光，鼠标水平位移加速字符流动（带缓动插值）
 * - 左右边缘渐隐淡出；prefers-reduced-motion 降级为静态一帧
 * - pointer-events: none，不拦截任何交互；fixed 定位铺满视口
 */
const canvasRef = ref<HTMLCanvasElement | null>(null)

const CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789{}[]()<>/\\=+*$#@%&:;._-'
const LINE_HEIGHT = 20
const FONT = '500 14px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace'
let CHAR_RGB = '84, 110, 52'
let GLOW_RGB = '101, 163, 13'

interface FlowLine {
  text: string
  x: number
  y: number
  speed: number
  alpha: number
  tw: number
}

let raf = 0
let running = false
let reduced = false
let lines: FlowLine[] = []
let ctx: CanvasRenderingContext2D | null = null
let W = 0
let H = 0
let speedMul = 0.85
let targetMul = 0.85
let mouseX = -10000
let mouseY = -10000

function buildText(cols: number): string {
  let s = ''
  for (let i = 0; i < cols; i++) {
    s += Math.random() < 0.13 ? ' ' : CHARS[(Math.random() * CHARS.length) | 0]
  }
  return s
}

function initLines() {
  if (!ctx) return
  ctx.font = FONT
  const charW = ctx.measureText('M').width || 8.4
  const cols = Math.ceil(W / charW) + 2
  const tw = cols * charW
  const count = Math.ceil(H / LINE_HEIGHT) + 1
  lines = []
  for (let i = 0; i < count; i++) {
    lines.push({
      text: buildText(cols),
      x: -Math.random() * tw,
      y: i * LINE_HEIGHT + 15,
      speed: 0.30 + Math.random() * 0.39,
      alpha: 0.08 + Math.random() * 0.22,
      tw,
    })
  }
}

function resize() {
  const canvas = canvasRef.value
  if (!canvas) return
  const dpr = Math.min(window.devicePixelRatio || 1, 2)
  W = window.innerWidth
  H = window.innerHeight
  canvas.width = Math.floor(W * dpr)
  canvas.height = Math.floor(H * dpr)
  canvas.style.width = W + 'px'
  canvas.style.height = H + 'px'
  ctx = canvas.getContext('2d')
  if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
  initLines()
}

function render() {
  if (!ctx) return
  ctx.clearRect(0, 0, W, H)
  ctx.font = FONT
  speedMul += (targetMul - speedMul) * 0.055
  for (const line of lines) {
    if (!reduced) {
      line.x -= line.speed * speedMul
      if (line.x <= -line.tw) line.x += line.tw
    }
    ctx.fillStyle = 'rgba(' + CHAR_RGB + ', ' + line.alpha.toFixed(3) + ')'
    ctx.fillText(line.text, line.x, line.y)
    ctx.fillText(line.text, line.x + line.tw, line.y)
  }
  if (mouseX > -9000) {
    const r = Math.max(W, H) * 0.34
    const g = ctx.createRadialGradient(mouseX, mouseY, 0, mouseX, mouseY, r)
    g.addColorStop(0, 'rgba(' + GLOW_RGB + ', 0.09)')
    g.addColorStop(0.5, 'rgba(' + GLOW_RGB + ', 0.035)')
    g.addColorStop(1, 'rgba(' + GLOW_RGB + ', 0)')
    ctx.fillStyle = g
    ctx.fillRect(0, 0, W, H)
  }
  const fade = Math.max(W * 0.1, 72)
  const mask = ctx.createLinearGradient(0, 0, W, 0)
  mask.addColorStop(0, 'rgba(0,0,0,0)')
  mask.addColorStop(fade / W, 'rgba(0,0,0,1)')
  mask.addColorStop(1 - fade / W, 'rgba(0,0,0,1)')
  mask.addColorStop(1, 'rgba(0,0,0,0)')
  ctx.globalCompositeOperation = 'destination-in'
  ctx.fillStyle = mask
  ctx.fillRect(0, 0, W, H)
  ctx.globalCompositeOperation = 'source-over'
}

function loop() {
  render()
  raf = requestAnimationFrame(loop)
}

function start() {
  if (running || reduced) return
  running = true
  raf = requestAnimationFrame(loop)
}

function stop() {
  running = false
  cancelAnimationFrame(raf)
}

function onMouseMove(e: MouseEvent) {
  mouseX = e.clientX
  mouseY = e.clientY
  const offset = Math.abs(e.clientX / (W || 1) - 0.5) * 2
  targetMul = 0.55 + 2.6 * offset
}

function onMouseLeave() {
  mouseX = -10000
  mouseY = -10000
  targetMul = 0.85
}

function onVisibility() {
  if (document.hidden) stop()
  else start()
}

onMounted(() => {
  const cs = getComputedStyle(document.documentElement)
  const charToken = cs.getPropertyValue('--nx-techbg-char').trim()
  const glowToken = cs.getPropertyValue('--nx-techbg-glow').trim()
  if (charToken) CHAR_RGB = charToken
  if (glowToken) GLOW_RGB = glowToken
  reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  resize()
  if (reduced) render()
  else start()
  window.addEventListener('resize', resize)
  window.addEventListener('mousemove', onMouseMove)
  document.documentElement.addEventListener('mouseleave', onMouseLeave)
  document.addEventListener('visibilitychange', onVisibility)
})

onBeforeUnmount(() => {
  stop()
  window.removeEventListener('resize', resize)
  window.removeEventListener('mousemove', onMouseMove)
  document.documentElement.removeEventListener('mouseleave', onMouseLeave)
  document.removeEventListener('visibilitychange', onVisibility)
})
</script>

<style scoped>
.tech-bg {
  position: fixed;
  inset: 0;
  z-index: 0;
  pointer-events: none;
  opacity: 0.8;
}
</style>
