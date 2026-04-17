<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue'

const props = defineProps<{
  src: string
  alt?: string
  caption?: string
  width?: string
  invertOnDark?: boolean
}>()

const expanded = ref(false)
const scale = ref(1)
const tx = ref(0)
const ty = ref(0)
const MIN = 0.5
const MAX = 4
const STEP = 0.25

const isDragging = ref(false)
let dragStart = { x: 0, y: 0, tx: 0, ty: 0 }

function open() {
  scale.value = 1
  tx.value = 0
  ty.value = 0
  expanded.value = true
}

function close() { expanded.value = false }

function zoomIn() { scale.value = Math.min(MAX, +(scale.value + STEP).toFixed(2)) }
function zoomOut() { scale.value = Math.max(MIN, +(scale.value - STEP).toFixed(2)) }
function zoomReset() {
  scale.value = 1
  tx.value = 0
  ty.value = 0
}

function onKey(e: KeyboardEvent) {
  if (!expanded.value) return
  if (e.key === 'Escape') close()
  if (e.key === '+' || e.key === '=') zoomIn()
  if (e.key === '-' || e.key === '_') zoomOut()
  if (e.key === '0') zoomReset()
}

function onWheel(e: WheelEvent) {
  if (!(e.ctrlKey || e.metaKey)) return
  e.preventDefault()
  if (e.deltaY < 0) zoomIn()
  else zoomOut()
}

// Drag to pan
function onPanDown(e: MouseEvent) {
  isDragging.value = true
  dragStart = { x: e.clientX, y: e.clientY, tx: tx.value, ty: ty.value }
  e.preventDefault()
}
function onPanMove(e: MouseEvent) {
  if (!isDragging.value) return
  tx.value = dragStart.tx + (e.clientX - dragStart.x)
  ty.value = dragStart.ty + (e.clientY - dragStart.y)
}
function onPanUp() { isDragging.value = false }

onMounted(() => {
  window.addEventListener('keydown', onKey)
  window.addEventListener('mousemove', onPanMove)
  window.addEventListener('mouseup', onPanUp)
})
onUnmounted(() => {
  window.removeEventListener('keydown', onKey)
  window.removeEventListener('mousemove', onPanMove)
  window.removeEventListener('mouseup', onPanUp)
})

watch(expanded, (v) => {
  if (typeof document === 'undefined') return
  document.body.style.overflow = v ? 'hidden' : ''
})
</script>

<template>
  <div class="zoom-image-wrapper">
    <img
      :src="props.src"
      :alt="props.alt || ''"
      :class="['zoom-trigger', { 'invert-dark': props.invertOnDark }]"
      :style="{ maxWidth: props.width || '100%' }"
      @click="open"
    />
    <div class="zoom-hint-small">click to zoom</div>
    <div v-if="props.caption" class="zoom-caption">{{ props.caption }}</div>

    <Teleport to="body">
      <Transition name="zoom-fade">
        <div
          v-if="expanded"
          class="zoom-overlay"
          :class="{ 'is-dragging': isDragging }"
          @click="close"
          @wheel="onWheel"
          @mousedown="onPanDown"
        >
          <div class="zoom-stage" @click.stop>
            <img
              :src="props.src"
              :alt="props.alt || ''"
              :class="['zoom-expanded', { 'invert-dark': props.invertOnDark }]"
              :style="{
                transform: `translate(${tx}px, ${ty}px) scale(${scale})`,
              }"
              draggable="false"
              @click.stop
              @mousedown.stop="onPanDown"
            />
          </div>

          <div class="zoom-controls" @click.stop @mousedown.stop>
            <button class="zbtn" @click="zoomOut" title="Zoom out (-)">−</button>
            <button class="zbtn zbtn-reset" @click="zoomReset" title="Reset (0)">
              {{ Math.round(scale * 100) }}%
            </button>
            <button class="zbtn" @click="zoomIn" title="Zoom in (+)">+</button>
            <span class="zbtn-sep"></span>
            <button class="zbtn zbtn-close" @click="close" title="Close (Esc)">×</button>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<style scoped>
.zoom-image-wrapper {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
}

.zoom-trigger {
  cursor: zoom-in;
  transition: transform 0.25s cubic-bezier(0.2, 0.7, 0.2, 1),
              box-shadow 0.3s ease,
              border-color 0.3s ease;
  border-radius: 10px;
  border: 1px solid rgba(255, 140, 66, 0.15);
  background: #ffffff;
  padding: 4px;
}

.zoom-trigger:hover {
  transform: scale(1.015);
  border-color: rgba(255, 140, 66, 0.5);
  box-shadow: 0 10px 40px rgba(255, 140, 66, 0.18);
}

.zoom-trigger.invert-dark {
  background: #0a0a0a;
  border-color: rgba(255, 140, 66, 0.25);
}

.zoom-hint-small {
  color: #6f6f6f;
  font-size: 0.45em;
  letter-spacing: 0.04em;
  font-weight: 500;
  text-transform: uppercase;
  margin-top: 2px;
}

.zoom-caption {
  color: #909090;
  font-size: 0.58em;
  text-align: center;
  margin-top: 2px;
}

.zoom-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.96);
  z-index: 9999;
  cursor: grab;
  overflow: hidden;
  user-select: none;
}
.zoom-overlay.is-dragging { cursor: grabbing; }

.zoom-stage {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.zoom-expanded {
  display: block;
  max-width: 92vw;
  max-height: 88vh;
  width: auto;
  height: auto;
  object-fit: contain;
  background: #ffffff;
  padding: 14px;
  border-radius: 12px;
  box-shadow: 0 24px 80px rgba(0, 0, 0, 0.5);
  transform-origin: center center;
  transition: transform 0.22s cubic-bezier(0.16, 1, 0.3, 1);
  pointer-events: auto;
  cursor: grab;
  -webkit-user-drag: none;
}
.zoom-overlay.is-dragging .zoom-expanded {
  cursor: grabbing;
  transition: none;
}

.zoom-expanded.invert-dark { background: #0a0a0a; }

/* Bottom-center floating controls */
.zoom-controls {
  position: fixed;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%);
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: rgba(20, 20, 20, 0.94);
  border: 1px solid rgba(255, 140, 66, 0.35);
  border-radius: 999px;
  padding: 5px 7px;
  box-shadow: 0 10px 32px rgba(0, 0, 0, 0.5);
  z-index: 10001;
  cursor: default;
}

.zbtn {
  min-width: 36px;
  height: 34px;
  padding: 0 12px;
  border: none;
  outline: none;
  background: transparent;
  color: #e5e5e5;
  font-family: 'Sora', sans-serif;
  font-size: 15px;
  font-weight: 600;
  border-radius: 999px;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}

.zbtn:hover {
  background: rgba(255, 140, 66, 0.22);
  color: #ff8c42;
}

.zbtn-reset {
  min-width: 58px;
  font-size: 12px;
  letter-spacing: 0.02em;
}

.zbtn-sep {
  width: 1px;
  height: 22px;
  background: rgba(255, 255, 255, 0.12);
  margin: 0 4px;
}

.zbtn-close {
  font-size: 20px;
  color: #bbbbbb;
}

.zbtn-close:hover {
  background: rgba(255, 90, 90, 0.22);
  color: #ff6a6a;
}

.zoom-fade-enter-active,
.zoom-fade-leave-active { transition: opacity 0.22s ease; }
.zoom-fade-enter-from,
.zoom-fade-leave-to { opacity: 0; }
</style>
