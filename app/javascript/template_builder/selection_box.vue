<template>
  <div
    class="absolute outline-dashed outline-gray-400 cursor-move"
    :class="[isResizing || isCmdKeyRef.value ? 'z-0' : 'z-20', { 'pointer-events-none': isDrawing || fieldsDragFieldRef.value || isDrag }]"
    :style="positionStyle"
    @pointerdown.stop.prevent="onPointerDown"
    @contextmenu.stop.prevent="openContextMenu"
  />
</template>

<script>
export default {
  name: 'SelectionBox',
  inject: ['save', 'selectedAreasRef', 'isCmdKeyRef', 'fieldsDragFieldRef'],
  props: {
    selectionBox: {
      type: Object,
      required: true
    },
    pageWidth: {
      type: Number,
      required: true
    },
    pageHeight: {
      type: Number,
      required: true
    },
    isResizing: {
      type: Boolean,
      default: false
    },
    isDrag: {
      type: Boolean,
      default: false
    },
    isDrawing: {
      type: Boolean,
      default: false
    }
  },
  emits: ['move', 'contextmenu', 'close-context-menu'],
  data () {
    return {
      isDragging: false,
      dragStart: { x: 0, y: 0 },
      dragStartPointer: null,
      shiftConstraintAxis: null
    }
  },
  computed: {
    positionStyle () {
      const { x, y, w, h } = this.selectionBox

      return {
        top: y * 100 + '%',
        left: x * 100 + '%',
        width: w * 100 + '%',
        height: h * 100 + '%'
      }
    }
  },
  methods: {
    openContextMenu (e) {
      this.$emit('contextmenu', e)
    },
    onPointerDown (e) {
      this.$emit('close-context-menu')

      this.startDrag(e)
    },
    startDrag (e) {
      this.isDragging = true
      this.dragStart = { x: e.clientX, y: e.clientY }
      this.dragStartPointer = { clientX: e.clientX, clientY: e.clientY }
      this.shiftConstraintAxis = null

      document.addEventListener('pointermove', this.onDrag)
      document.addEventListener('pointerup', this.stopDrag)
    },
    onDrag (e) {
      if (!this.isDragging) return

      const parent = this.$el.parentElement

      const rect = parent.getBoundingClientRect()

      let targetClientX = e.clientX
      let targetClientY = e.clientY

      if (e.shiftKey && this.dragStartPointer) {
        if (!this.shiftConstraintAxis) {
          const totalDx = Math.abs(e.clientX - this.dragStartPointer.clientX)
          const totalDy = Math.abs(e.clientY - this.dragStartPointer.clientY)

          if (totalDx > 3 || totalDy > 3) {
            this.shiftConstraintAxis = totalDx > totalDy ? 'x' : 'y'
          }
        }

        if (this.shiftConstraintAxis === 'x') {
          targetClientY = this.dragStartPointer.clientY
        } else if (this.shiftConstraintAxis === 'y') {
          targetClientX = this.dragStartPointer.clientX
        }
      }

      const dx = (targetClientX - this.dragStart.x) / rect.width
      const dy = (targetClientY - this.dragStart.y) / rect.height

      if (dx !== 0 || dy !== 0) {
        this.$emit('move', dx, dy)
        this.dragStart = { x: targetClientX, y: targetClientY }
      }
    },
    stopDrag () {
      this.isDragging = false
      this.shiftConstraintAxis = null

      document.removeEventListener('pointermove', this.onDrag)
      document.removeEventListener('pointerup', this.stopDrag)

      this.save()
    }
  }
}
</script>
