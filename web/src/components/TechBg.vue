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
 * - 左右边缘渐隐淡出（CSS mask，由合成器处理，不占绘制帧）
 * - prefers-reduced-motion 降级为静态一帧
 * - pointer-events: none，不拦截任何交互；fixed 定位铺满视口
 *
 * 性能设计：
 * - 每行字符在初始化/换主题时预渲染到离屏 canvas，帧内只做 drawImage
 * - 鼠标辉光用预渲染的径向渐变精灵图，避免每帧 createRadialGradient + 全屏填充
 * - 限制 30fps（环境氛围层无需 60fps），DPR 上限 1.5
 */
const canvasRef = ref<HTMLCanvasElement | null>(null)

const CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789{}[]()<>/\\=+*$#@%&:;._-'
const LINE_HEIGHT = 20
const FONT = '500 14px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace'
const FRAME_MS = 1000 / 30
const MAX_DPR = 1.5
const GLOW_SPRITE_SIZE = 256
let CHAR_RGB = '84, 110, 52'
let GLOW_RGB = '101, 163, 13'

interface FlowLine {
  strip: HTMLCanvasElement
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
let themeObserver: MutationObserver | null = null
let lines: FlowLine[] = []
let ctx: CanvasRenderingContext2D | null = null
let glowSprite: HTMLCanvasElement | null = null
let dpr = 1
let W = 0
let H = 0
let speedMul = 0.85
let targetMul = 0.85
let mouseX = -10000
let mouseY = -10000
let lastFrame = 0
let resizeTimer = 0

function buildText(cols: number): string {
  let s = ''
  for (let i = 0; i < cols; i++) {
    s += Math.random() < 0.13 ? ' ' : CHARS[(Math.random() * CHARS.length) | 0]
  }
  return s
}

/** 将一行字符光栅化到离屏画布，后续帧内仅 drawImage。 */
function buildStrip(text: string, tw: number): HTMLCanvasElement {
  const strip = document.createElement('canvas')
  strip.width = Math.ceil(tw * dpr)
  strip.height = Math.ceil(LINE_HEIGHT * dpr)
  const sctx = strip.getContext('2d')
  if (sctx) {
    sctx.scale(dpr, dpr)
    sctx.font = FONT
    sctx.fillStyle = 'rgb(' + CHAR_RGB + ')'
    sctx.fillText(text, 0, 15)
  }
  return strip
}

/** 鼠标辉光精灵图：预渲染径向渐变，帧内缩放 drawImage 到鼠标位置。 */
function buildGlowSprite(): HTMLCanvasElement {
  const sprite = document.createElement('canvas')
  sprite.width = GLOW_SPRITE_SIZE
  sprite.height = GLOW_SPRITE_SIZE
  const sctx = sprite.getContext('2d')
  if (sctx) {
    const half = GLOW_SPRITE_SIZE / 2
    const g = sctx.createRadialGradient(half, half, 0, half, half, half)
    g.addColorStop(0, 'rgba(' + GLOW_RGB + ', 0.09)')
    g.addColorStop(0.5, 'rgba(' + GLOW_RGB + ', 0.035)')
    g.addColorStop(1, 'rgba(' + GLOW_RGB + ', 0)')
    sctx.fillStyle = g
    sctx.fillRect(0, 0, GLOW_SPRITE_SIZE, GLOW_SPRITE_SIZE)
  }
  return sprite
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
    const text = buildText(cols)
    lines.push({
      strip: buildStrip(text, tw),
      text,
      x: -Math.random() * tw,
      y: i * LINE_HEIGHT,
      speed: 0.30 + Math.random() * 0.39,
      alpha: 0.08 + Math.random() * 0.22,
      tw,
    })
  }
}

function resize() {
  const canvas = canvasRef.value
  if (!canvas) return
  dpr = Math.min(window.devicePixelRatio || 1, MAX_DPR)
  W = window.innerWidth
  H = window.innerHeight
  canvas.width = Math.floor(W * dpr)
  canvas.height = Math.floor(H * dpr)
  canvas.style.width = W + 'px'
  canvas.style.height = H + 'px'
  ctx = canvas.getContext('2d')
  if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
  initLines()
  if (!running) render()
}

function onResize() {
  // 窗口拖动期间防抖，避免频繁重建离屏字符条。
  window.clearTimeout(resizeTimer)
  resizeTimer = window.setTimeout(resize, 150)
}

function render() {
  if (!ctx) return
  ctx.clearRect(0, 0, W, H)
  speedMul += (targetMul - speedMul) * 0.055
  for (const line of lines) {
    if (!reduced) {
      line.x -= line.speed * speedMul
      if (line.x <= -line.tw) line.x += line.tw
    }
    ctx.globalAlpha = line.alpha
    ctx.drawImage(line.strip, line.x, line.y, line.tw, LINE_HEIGHT)
    ctx.drawImage(line.strip, line.x + line.tw, line.y, line.tw, LINE_HEIGHT)
  }
  ctx.globalAlpha = 1
  if (mouseX > -9000 && glowSprite) {
    const r = Math.max(W, H) * 0.34
    ctx.drawImage(glowSprite, mouseX - r, mouseY - r, r * 2, r * 2)
  }
}

function loop(now: number) {
  if (now - lastFrame >= FRAME_MS) {
    lastFrame = now
    render()
  }
  raf = requestAnimationFrame(loop)
}

function start() {
  if (running || reduced) return
  running = true
  lastFrame = 0
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

function syncTheme() {
  const cs = getComputedStyle(document.documentElement)
  const charToken = cs.getPropertyValue('--nx-techbg-char').trim()
  const glowToken = cs.getPropertyValue('--nx-techbg-glow').trim()
  if (charToken) CHAR_RGB = charToken
  if (glowToken) GLOW_RGB = glowToken
  // 主题色变化后重建离屏字符条与辉光精灵图。
  glowSprite = buildGlowSprite()
  for (const line of lines) {
    line.strip = buildStrip(line.text, line.tw)
  }
  // 减少动态效果时没有动画循环，需要立即重绘静态背景。
  if (!running) render()
}

onMounted(() => {
  themeObserver = new MutationObserver(syncTheme)
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] })
  glowSprite = buildGlowSprite()
  syncTheme()
  reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  resize()
  if (reduced) render()
  else start()
  window.addEventListener('resize', onResize)
  window.addEventListener('mousemove', onMouseMove)
  document.documentElement.addEventListener('mouseleave', onMouseLeave)
  document.addEventListener('visibilitychange', onVisibility)
})

onBeforeUnmount(() => {
  stop()
  window.clearTimeout(resizeTimer)
  themeObserver?.disconnect()
  window.removeEventListener('resize', onResize)
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
  /* 左右边缘渐隐：由合成器处理，替代原先每帧一次的全屏 destination-in 合成 */
  mask-image: linear-gradient(to right, transparent, black max(10vw, 72px), black calc(100% - max(10vw, 72px)), transparent);
  -webkit-mask-image: linear-gradient(to right, transparent, black max(10vw, 72px), black calc(100% - max(10vw, 72px)), transparent);
}
</style>
