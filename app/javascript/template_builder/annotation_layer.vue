<template>
  <div
    ref="container"
    class="annotation-layer absolute inset-0 select-none overflow-visible"
    :class="layerClass"
    @pointerdown="onLayerPointerDown"
    @pointermove="onLayerPointerMove"
    @pointerup="onLayerPointerUp"
    @pointercancel="onLayerPointerUp"
  >
    <!-- SVG VECTOR PATHS (PEN & HIGHLIGHTER) -->
    <svg
      class="w-full h-full absolute inset-0 overflow-visible pointer-events-none"
      viewBox="0 0 1000 1000"
      preserveAspectRatio="none"
    >
      <!-- COMPLETED STROKES -->
      <g
        v-for="annot in strokeAnnotations"
        :key="annot.uuid"
        class="annotation-stroke-group"
        :class="{ 'cursor-pointer': activeTool === 'select' && editable }"
        @pointerdown.stop="onStrokePointerDown(annot, $event)"
      >
        <!-- INVISIBLE WIDER HIT AREA FOR EASY SELECTION -->
        <path
          v-if="activeTool === 'select' && editable"
          :d="pointsToPath(annot.points)"
          stroke="transparent"
          :stroke-width="Math.max(annot.width * 1000, 24)"
          stroke-linecap="round"
          stroke-linejoin="round"
          fill="none"
          class="pointer-events-auto"
        />

        <!-- SELECTION OUTLINE GLOW -->
        <path
          v-if="isSelected(annot)"
          :d="pointsToPath(annot.points)"
          stroke="#3B82F6"
          :stroke-width="(annot.width * 1000) + 6"
          stroke-linecap="round"
          stroke-linejoin="round"
          fill="none"
          stroke-dasharray="8 6"
          opacity="0.9"
          class="pointer-events-none animate-pulse"
        />

        <!-- VISIBLE STROKE -->
        <path
          :d="pointsToPath(annot.points)"
          :stroke="annot.color"
          :stroke-width="annot.width * 1000"
          :stroke-opacity="annot.type === 'highlighter' ? (annot.opacity || 0.35) : 1"
          stroke-linecap="round"
          stroke-linejoin="round"
          fill="none"
          :class="activeTool === 'select' && editable ? 'pointer-events-auto' : 'pointer-events-none'"
        />
      </g>

      <!-- ACTIVE IN-PROGRESS TRANSIENT STROKE -->
      <path
        v-if="transientStroke && transientStroke.points.length >= 2"
        :d="pointsToPath(transientStroke.points)"
        :stroke="transientStroke.color"
        :stroke-width="transientStroke.width * 1000"
        :stroke-opacity="transientStroke.type === 'highlighter' ? (transientStroke.opacity || 0.35) : 1"
        stroke-linecap="round"
        stroke-linejoin="round"
        fill="none"
        class="pointer-events-none"
      />
    </svg>

    <!-- SINGLE SELECTED STROKE FLOATING ACTION (WHEN EXACTLY 1 SELECTED) -->
    <div
      v-if="selectedStrokeBox && activeTool === 'select' && editable && effectiveSelectedUuids.length === 1"
      class="absolute z-30 pointer-events-auto flex items-center space-x-1 bg-base-100 border border-base-300 rounded shadow-md px-1.5 py-0.5"
      :style="{ left: `${selectedStrokeBox.x * 100}%`, top: `max(0%, ${(selectedStrokeBox.y * 100) - 4}%)`, transform: 'translateY(-100%)' }"
    >
      <span class="text-[10px] text-base-content/60 font-semibold uppercase">{{ singleSelectedAnnot?.type }}</span>
      <button
        type="button"
        class="btn btn-ghost btn-xs text-error p-0.5 h-auto min-h-0"
        title="Delete Annotation"
        @click.stop="$emit('delete-annotation', singleSelectedAnnot.uuid)"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-3.5 h-3.5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M4 7l16 0" />
          <path d="M10 11l0 6" />
          <path d="M14 11l0 6" />
          <path d="M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2 -2l1 -12" />
        </svg>
      </button>
    </div>

    <!-- TEXT ANNOTATIONS -->
    <div
      v-for="annot in textAnnotations"
      :key="annot.uuid"
      class="annotation-text-item absolute z-20 group"
      :class="[
        (activeTool === 'select' || editingTextUuid === annot.uuid) && editable ? 'pointer-events-auto' : 'pointer-events-none',
        editingTextUuid === annot.uuid ? 'cursor-text ring-2 ring-primary ring-offset-1 shadow-lg bg-base-100/95' : (activeTool === 'select' && editable ? 'cursor-move' : ''),
        isSelected(annot) && editingTextUuid !== annot.uuid ? 'ring-2 ring-primary ring-offset-1 shadow-md bg-base-100/30' : '',
        activeTool === 'select' && editable && !isSelected(annot) ? 'hover:outline hover:outline-dashed hover:outline-primary/50' : ''
      ]"
      :style="getTextAnnotationStyle(annot)"
      @pointerdown.stop="onTextPointerDown(annot, $event)"
      @dblclick.stop="startEditText(annot)"
    >
      <!-- TEXT DRAG HANDLE & DELETE BAR (WHEN SINGLE SELECTED IN SELECT MODE AND NOT EDITING) -->
      <div
        v-if="isSelected(annot) && activeTool === 'select' && editable && editingTextUuid !== annot.uuid && effectiveSelectedUuids.length === 1"
        class="absolute -top-6 left-0 right-0 flex items-center justify-between bg-primary text-primary-content text-[10px] px-1 py-0.5 rounded-t font-mono select-none"
      >
        <span class="flex items-center space-x-1 cursor-move">
          <span>⠿</span>
          <span>Text ({{ annot.font_size || 14 }}pt)</span>
        </span>
        <button
          type="button"
          class="hover:bg-primary-focus rounded px-1 text-white font-bold"
          title="Delete Annotation"
          @click.stop="$emit('delete-annotation', annot.uuid)"
        >
          &times;
        </button>
      </div>

      <!-- TEXTAREA WHEN IN EDITING MODE -->
      <textarea
        v-if="editingTextUuid === annot.uuid"
        ref="textInput"
        :value="annot.text"
        class="w-full h-full bg-transparent border-0 text-base-content rounded p-1 outline-hidden resize-none overflow-hidden select-text"
        :style="{ color: annot.color, fontSize: getTextFontSize(annot), lineHeight: '1.25' }"
        placeholder="Type text annotation..."
        @input="onTextInput(annot, $event)"
        @blur="onTextBlur(annot, $event)"
        @keydown.stop
        @keydown.esc.stop="finishTextEdit(annot)"
      />

      <!-- DISPLAY DIV WHEN NOT EDITING -->
      <div
        v-else
        class="whitespace-pre-wrap px-1 py-0.5 rounded font-sans h-full w-full break-words select-none"
        :style="{ color: annot.color, fontSize: getTextFontSize(annot), lineHeight: '1.25' }"
        :title="editable && activeTool === 'select' ? 'Double-click to edit text' : ''"
      >
        {{ annot.text || '(empty text)' }}
      </div>

      <!-- RESIZE HANDLE FOR TEXT BOX -->
      <span
        v-if="isSelected(annot) && activeTool === 'select' && editable && editingTextUuid !== annot.uuid"
        class="absolute -bottom-1.5 -right-1.5 w-3 h-3 bg-primary border-2 border-white rounded-full cursor-nwse-resize z-30 shadow-xs pointer-events-auto"
        title="Resize text box"
        @pointerdown.stop.prevent="startResizeText(annot, $event)"
      />
    </div>
  </div>
</template>

<script>
import { v4 } from 'uuid'

export default {
  name: 'AnnotationLayer',
  props: {
    annotations: {
      type: Array,
      default: () => []
    },
    attachmentUuid: {
      type: String,
      required: true
    },
    page: {
      type: Number,
      required: true
    },
    activeTool: {
      type: String,
      default: 'select'
    },
    activeColor: {
      type: String,
      default: '#111827'
    },
    penThickness: {
      type: Number,
      default: 0.003
    },
    highlighterThickness: {
      type: Number,
      default: 0.025
    },
    activeFontSize: {
      type: Number,
      default: 14
    },
    selectedAnnotationUuids: {
      type: Array,
      default: () => []
    },
    selectedAnnotationUuid: {
      type: String,
      default: null
    },
    editable: {
      type: Boolean,
      default: true
    },
    readOnly: {
      type: Boolean,
      default: false
    }
  },
  emits: [
    'create-annotation',
    'update-annotation',
    'update-annotations',
    'delete-annotation',
    'select-annotation',
    'select-tool',
    'clear-selection'
  ],
  data () {
    return {
      transientStroke: null,
      isDraggingSelection: false,
      isResizingText: false,
      resizingAnnot: null,
      resizeStart: { clientX: 0, clientY: 0, w: 0, h: 0 },
      dragStartPos: { clientX: 0, clientY: 0 },
      initialAnnotStates: [],
      editingTextUuid: null,
      editingInitialText: ''
    }
  },
  computed: {
    effectiveSelectedUuids () {
      if (this.selectedAnnotationUuids && this.selectedAnnotationUuids.length) {
        return this.selectedAnnotationUuids
      }
      if (this.selectedAnnotationUuid) {
        return [this.selectedAnnotationUuid]
      }
      return []
    },
    layerClass () {
      if (this.readOnly || !this.editable) {
        return 'pointer-events-none'
      }
      if (this.activeTool === 'pen' || this.activeTool === 'highlighter') {
        return 'pointer-events-auto cursor-crosshair'
      }
      if (this.activeTool === 'text') {
        return 'pointer-events-auto cursor-text'
      }
      if (this.activeTool === 'select') {
        return 'pointer-events-auto'
      }
      return 'pointer-events-none'
    },
    pageAnnotations () {
      return this.annotations.filter(
        (a) => a.attachment_uuid === this.attachmentUuid && a.page === this.page
      )
    },
    strokeAnnotations () {
      return this.pageAnnotations.filter(
        (a) => a.type === 'pen' || a.type === 'highlighter'
      )
    },
    textAnnotations () {
      return this.pageAnnotations.filter((a) => a.type === 'text')
    },
    singleSelectedAnnot () {
      if (this.effectiveSelectedUuids.length !== 1) return null
      return this.pageAnnotations.find((a) => a.uuid === this.effectiveSelectedUuids[0])
    },
    selectedStrokeBox () {
      const annot = this.singleSelectedAnnot
      if (!annot || (annot.type !== 'pen' && annot.type !== 'highlighter')) {
        return null
      }
      if (!annot.points || !annot.points.length) return null

      const xs = annot.points.map((p) => p.x)
      const ys = annot.points.map((p) => p.y)
      return {
        x: Math.min(...xs),
        y: Math.min(...ys)
      }
    }
  },
  beforeUnmount () {
    document.removeEventListener('pointermove', this.onGroupDragMove)
    document.removeEventListener('pointerup', this.onGroupDragEnd)
    document.removeEventListener('pointermove', this.onResizeTextMove)
    document.removeEventListener('pointerup', this.onResizeTextEnd)
  },
  methods: {
    isSelected (annot) {
      return this.effectiveSelectedUuids.includes(annot.uuid)
    },
    pointsToPath (points) {
      if (!points || points.length < 2) return ''
      const first = points[0]
      let d = `M ${(first.x * 1000).toFixed(1)} ${(first.y * 1000).toFixed(1)}`
      for (let i = 1; i < points.length; i++) {
        d += ` L ${(points[i].x * 1000).toFixed(1)} ${(points[i].y * 1000).toFixed(1)}`
      }
      return d
    },
    getTextFontSize (annot) {
      const pt = annot.font_size || 14
      return `${((pt / 612) * 100).toFixed(3)}cqw`
    },
    getTextAnnotationStyle (annot) {
      return {
        left: `${(annot.x * 100).toFixed(3)}%`,
        top: `${(annot.y * 100).toFixed(3)}%`,
        width: annot.w ? `${(annot.w * 100).toFixed(3)}%` : 'auto',
        minWidth: '60px',
        maxWidth: `${((1.0 - annot.x) * 100).toFixed(3)}%`,
        height: annot.h ? `${(annot.h * 100).toFixed(3)}%` : 'auto',
        minHeight: '28px'
      }
    },
    getRelativeCoordinates (event) {
      const rect = this.$refs.container.getBoundingClientRect()
      const x = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width))
      const y = Math.max(0, Math.min(1, (event.clientY - rect.top) / rect.height))
      return {
        x: parseFloat(x.toFixed(5)),
        y: parseFloat(y.toFixed(5))
      }
    },
    onLayerPointerDown (e) {
      if (!this.editable || this.readOnly || e.button === 2) return

      if (this.activeTool === 'pen' || this.activeTool === 'highlighter') {
        e.stopPropagation()
        e.preventDefault()

        const coords = this.getRelativeCoordinates(e)
        const isHighlighter = this.activeTool === 'highlighter'
        const strokeWidth = isHighlighter
          ? (this.highlighterThickness || 0.025)
          : (this.penThickness || 0.003)

        this.transientStroke = {
          uuid: v4(),
          type: this.activeTool,
          attachment_uuid: this.attachmentUuid,
          page: this.page,
          color: this.activeColor,
          width: strokeWidth,
          opacity: isHighlighter ? 0.35 : 1.0,
          points: [coords]
        }

        e.target.setPointerCapture?.(e.pointerId)
      } else if (this.activeTool === 'text') {
        e.stopPropagation()
        e.preventDefault()

        const coords = this.getRelativeCoordinates(e)
        const newTextAnnot = {
          uuid: v4(),
          type: 'text',
          attachment_uuid: this.attachmentUuid,
          page: this.page,
          x: Math.min(coords.x, 0.70),
          y: Math.min(coords.y, 0.90),
          w: 0.28,
          h: 0.06,
          text: '',
          color: this.activeColor,
          font_size: this.activeFontSize || 14,
          _isNew: true
        }

        this.$emit('create-annotation', newTextAnnot)
        this.$emit('select-annotation', { uuid: newTextAnnot.uuid, isMulti: false })
        this.$emit('select-tool', 'select')
        this.editingTextUuid = newTextAnnot.uuid
        this.editingInitialText = ''

        this.$nextTick(() => {
          this.focusTextarea()
        })
      } else if (this.activeTool === 'select') {
        // Clicking empty space on layer clears selection
        const isSvg = e.target.tagName && e.target.tagName.toLowerCase() === 'svg'
        if (e.target === this.$refs.container || isSvg) {
          if (!e.ctrlKey && !e.metaKey) {
            this.$emit('clear-selection')
          }
        }
      }
    },
    onLayerPointerMove (e) {
      if (this.transientStroke) {
        e.stopPropagation()
        e.preventDefault()

        const coords = this.getRelativeCoordinates(e)
        const pts = this.transientStroke.points
        const last = pts[pts.length - 1]

        const distSq = ((coords.x - last.x) ** 2) + ((coords.y - last.y) ** 2)
        if (distSq >= 0.000008) {
          pts.push(coords)
        }
      }
    },
    onLayerPointerUp (e) {
      if (this.transientStroke) {
        e.stopPropagation()
        e.preventDefault()

        try {
          e.target.releasePointerCapture?.(e.pointerId)
        } catch {
          // ignore
        }

        if (this.transientStroke.points.length >= 2) {
          this.$emit('create-annotation', { ...this.transientStroke })
        }
        this.transientStroke = null
      }
    },
    onStrokePointerDown (annot, e) {
      if (this.activeTool !== 'select' || !this.editable) return

      e.stopPropagation()
      const isMulti = e.ctrlKey || e.metaKey

      if (isMulti) {
        this.$emit('select-annotation', { uuid: annot.uuid, isMulti: true })
        return
      }

      if (!this.isSelected(annot)) {
        this.$emit('select-annotation', { uuid: annot.uuid, isMulti: false })
      }

      this.startGroupDrag(e)
    },
    onTextPointerDown (annot, e) {
      if (this.activeTool !== 'select' || !this.editable) return

      if (this.editingTextUuid === annot.uuid) {
        // Allow text cursor placement
        e.stopPropagation()
        return
      }

      e.stopPropagation()
      const isMulti = e.ctrlKey || e.metaKey

      if (isMulti) {
        this.$emit('select-annotation', { uuid: annot.uuid, isMulti: true })
        return
      }

      if (!this.isSelected(annot)) {
        this.$emit('select-annotation', { uuid: annot.uuid, isMulti: false })
      }

      this.startGroupDrag(e)
    },
    startEditText (annot) {
      if (!this.editable || this.readOnly) return
      this.editingTextUuid = annot.uuid
      this.editingInitialText = annot.text || ''
      this.$nextTick(() => {
        this.focusTextarea()
      })
    },
    focusTextarea () {
      const el = this.$refs.textInput?.[0] || this.$refs.textInput
      if (el) {
        el.focus()
        if (el.value.length) {
          el.setSelectionRange(el.value.length, el.value.length)
        }
      }
    },
    onTextInput (annot, e) {
      annot.text = e.target.value
    },
    onTextBlur (annot, e) {
      const clean = (e.target.value || '').trim()
      if (!clean) {
        if (annot._isNew || !this.editingInitialText) {
          // Newly created and blank: remove to avoid persistent (empty text) placeholder
          this.$emit('delete-annotation', annot.uuid)
        } else {
          // Previously populated text: preserve previous content
          annot.text = this.editingInitialText
          this.$emit('update-annotation', annot)
        }
      } else {
        annot.text = e.target.value
        delete annot._isNew
        this.$emit('update-annotation', annot)
      }
      this.editingTextUuid = null
      this.editingInitialText = ''
    },
    finishTextEdit (annot) {
      const el = this.$refs.textInput?.[0] || this.$refs.textInput
      el?.blur()
    },
    startResizeText (annot, e) {
      e.stopPropagation()
      this.isResizingText = true
      this.resizingAnnot = annot
      this.resizeStart = {
        clientX: e.clientX,
        clientY: e.clientY,
        w: annot.w || 0.28,
        h: annot.h || 0.06
      }
      document.addEventListener('pointermove', this.onResizeTextMove)
      document.addEventListener('pointerup', this.onResizeTextEnd)
    },
    onResizeTextMove (e) {
      if (!this.isResizingText || !this.resizingAnnot) return
      const rect = this.$refs.container.getBoundingClientRect()
      const dw = (e.clientX - this.resizeStart.clientX) / rect.width
      const dh = (e.clientY - this.resizeStart.clientY) / rect.height

      const newW = Math.max(0.08, Math.min(1.0 - this.resizingAnnot.x, this.resizeStart.w + dw))
      const newH = Math.max(0.03, Math.min(1.0 - this.resizingAnnot.y, this.resizeStart.h + dh))

      this.resizingAnnot.w = parseFloat(newW.toFixed(5))
      this.resizingAnnot.h = parseFloat(newH.toFixed(5))
    },
    onResizeTextEnd () {
      if (!this.isResizingText) return
      this.isResizingText = false
      document.removeEventListener('pointermove', this.onResizeTextMove)
      document.removeEventListener('pointerup', this.onResizeTextEnd)

      if (this.resizingAnnot) {
        this.$emit('update-annotation', this.resizingAnnot)
        this.resizingAnnot = null
      }
    },
    startGroupDrag (e) {
      const selectedOnPage = this.pageAnnotations.filter((a) => this.isSelected(a))
      if (!selectedOnPage.length) return

      this.isDraggingSelection = true
      this.dragStartPos = { clientX: e.clientX, clientY: e.clientY }
      this.initialAnnotStates = selectedOnPage.map((a) => {
        if (a.type === 'text') {
          return {
            uuid: a.uuid,
            type: 'text',
            x: a.x,
            y: a.y,
            w: a.w || 0.28,
            h: a.h || 0.06
          }
        }
        const xs = a.points.map((p) => p.x)
        const ys = a.points.map((p) => p.y)
        return {
          uuid: a.uuid,
          type: a.type,
          points: a.points.map((p) => ({ x: p.x, y: p.y })),
          minX: Math.min(...xs),
          maxX: Math.max(...xs),
          minY: Math.min(...ys),
          maxY: Math.max(...ys)
        }
      })

      document.addEventListener('pointermove', this.onGroupDragMove)
      document.addEventListener('pointerup', this.onGroupDragEnd)
    },
    onGroupDragMove (e) {
      if (!this.isDraggingSelection) return
      const rect = this.$refs.container.getBoundingClientRect()
      const dx = (e.clientX - this.dragStartPos.clientX) / rect.width
      const dy = (e.clientY - this.dragStartPos.clientY) / rect.height

      let clampedDx = dx
      let clampedDy = dy

      this.initialAnnotStates.forEach((state) => {
        if (state.type === 'text') {
          const maxLeft = -state.x
          const maxRight = 1 - state.w - state.x
          const maxTop = -state.y
          const maxBottom = 1 - state.h - state.y

          if (dx < maxLeft) clampedDx = Math.max(clampedDx, maxLeft)
          if (dx > maxRight) clampedDx = Math.min(clampedDx, maxRight)
          if (dy < maxTop) clampedDy = Math.max(clampedDy, maxTop)
          if (dy > maxBottom) clampedDy = Math.min(clampedDy, maxBottom)
        } else {
          const maxLeft = -state.minX
          const maxRight = 1 - state.maxX
          const maxTop = -state.minY
          const maxBottom = 1 - state.maxY

          if (dx < maxLeft) clampedDx = Math.max(clampedDx, maxLeft)
          if (dx > maxRight) clampedDx = Math.min(clampedDx, maxRight)
          if (dy < maxTop) clampedDy = Math.max(clampedDy, maxTop)
          if (dy > maxBottom) clampedDy = Math.min(clampedDy, maxBottom)
        }
      })

      this.initialAnnotStates.forEach((state) => {
        const annot = this.pageAnnotations.find((a) => a.uuid === state.uuid)
        if (!annot) return

        if (annot.type === 'text') {
          annot.x = parseFloat((state.x + clampedDx).toFixed(5))
          annot.y = parseFloat((state.y + clampedDy).toFixed(5))
        } else {
          annot.points = state.points.map((p) => ({
            x: parseFloat((p.x + clampedDx).toFixed(5)),
            y: parseFloat((p.y + clampedDy).toFixed(5))
          }))
        }
      })
    },
    onGroupDragEnd (e) {
      if (!this.isDraggingSelection) return
      this.isDraggingSelection = false
      document.removeEventListener('pointermove', this.onGroupDragMove)
      document.removeEventListener('pointerup', this.onGroupDragEnd)

      const moved = Math.abs(e.clientX - this.dragStartPos.clientX) > 3 ||
                    Math.abs(e.clientY - this.dragStartPos.clientY) > 3

      if (moved) {
        const updated = this.pageAnnotations.filter((a) => this.isSelected(a))
        this.$emit('update-annotations', updated)
      }
    }
  }
}
</script>
