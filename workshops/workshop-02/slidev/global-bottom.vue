<script setup lang="ts">
// Auto-play v-clicks on slide entry so the user doesn't need to
// step through each fragment manually. Advances one click every
// DELAY_MS until all fragments on the current slide are revealed.
// Stops at the slide boundary so it does not auto-advance across slides.
// The user can still press left/right to navigate manually at any time.
import { watch, onUnmounted, onMounted } from 'vue'
import { useSlideContext } from '@slidev/client/context.ts'

const DELAY_MS = 220
const INITIAL_DELAY_MS = 280

const { $nav } = useSlideContext()

let timer: number | undefined

function clear() {
  if (timer) {
    clearTimeout(timer)
    timer = undefined
  }
}

function tick() {
  clear()
  const nav = $nav.value
  if (!nav) return
  const current = nav.clicks
  const total = nav.clicksTotal
  // Strict less-than: once clicks === total, we have revealed everything
  // on this slide. Do NOT call next() which would cross into next slide.
  if (current < total) {
    timer = window.setTimeout(async () => {
      // Re-read state inside the callback in case the user pressed arrows
      const nav2 = $nav.value
      if (!nav2) return
      if (nav2.clicks < nav2.clicksTotal) {
        try { await nav2.next() }
        catch (e) { console.warn('[autoplay] next failed', e) }
      }
      tick()
    }, DELAY_MS)
  }
}

function start() {
  clear()
  timer = window.setTimeout(tick, INITIAL_DELAY_MS)
}

onMounted(start)

watch(() => $nav.value?.currentSlideNo, () => start())

onUnmounted(clear)
</script>

<template>
  <div style="display:none" data-autoplay="1" />
</template>
