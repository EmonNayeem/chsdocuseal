<template>
  <div
    class="annotation-toolbar flex items-center space-x-1 bg-base-100/95 backdrop-blur-sm border border-base-300 rounded-lg shadow-md px-2 py-1 text-xs select-none z-20"
  >
    <!-- SELECT / POINTER TOOL -->
    <button
      type="button"
      class="btn btn-xs rounded-md px-2 flex items-center space-x-1"
      :class="activeTool === 'select' ? 'btn-neutral text-white font-semibold' : 'btn-ghost text-base-content/80'"
      title="Select / Move Annotation (Esc to clear selection)"
      @click="$emit('select-tool', 'select')"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="w-3.5 h-3.5"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M3 3l7 18l3 -7l7 -3z" />
      </svg>
      <span class="hidden sm:inline">Select</span>
    </button>

    <!-- PEN TOOL -->
    <button
      type="button"
      class="btn btn-xs rounded-md px-2 flex items-center space-x-1"
      :class="activeTool === 'pen' ? 'btn-neutral text-white font-semibold' : 'btn-ghost text-base-content/80'"
      title="Pen (Draw Freehand)"
      @click="$emit('select-tool', 'pen')"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="w-3.5 h-3.5"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M4 20h4l10.5 -10.5a2.828 2.828 0 1 0 -4 -4l-10.5 10.5v4" />
        <path d="M13.5 6.5l4 4" />
      </svg>
      <span class="hidden sm:inline">Pen</span>
    </button>

    <!-- HIGHLIGHTER TOOL -->
    <button
      type="button"
      class="btn btn-xs rounded-md px-2 flex items-center space-x-1"
      :class="activeTool === 'highlighter' ? 'btn-neutral text-white font-semibold' : 'btn-ghost text-base-content/80'"
      title="Highlighter (Semi-transparent freehand)"
      @click="$emit('select-tool', 'highlighter')"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="w-3.5 h-3.5"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M3 21l18 0" />
        <path d="M4 11l7 -7a2.121 2.121 0 0 1 3 3l-7 7l-4 1l1 -4z" />
        <path d="M10.5 7.5l3 3" />
      </svg>
      <span class="hidden sm:inline">Highlight</span>
    </button>

    <!-- TEXT ANNOTATION TOOL -->
    <button
      type="button"
      class="btn btn-xs rounded-md px-2 flex items-center space-x-1"
      :class="activeTool === 'text' ? 'btn-neutral text-white font-semibold' : 'btn-ghost text-base-content/80'"
      title="Text Annotation (Click to place text)"
      @click="$emit('select-tool', 'text')"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="w-3.5 h-3.5"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M4 7V4h16v3" />
        <path d="M9 20h6" />
        <path d="M12 4v16" />
      </svg>
      <span class="hidden sm:inline">Text</span>
    </button>

    <!-- THICKNESS CONTROL (ONLY FOR PEN & HIGHLIGHTER) -->
    <template v-if="activeTool === 'pen' || activeTool === 'highlighter'">
      <div class="h-4 w-px bg-base-300 mx-1" />
      <div class="relative flex items-center">
        <button
          type="button"
          class="btn btn-xs btn-ghost px-1.5 flex items-center space-x-1"
          :title="`Thickness: ${currentThicknessLabel}`"
          @click="showThicknessMenu = !showThicknessMenu"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="w-3 h-3 text-base-content/70"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M4 6h16M4 12h16M4 18h16" />
          </svg>
          <span class="text-[11px] font-medium hidden sm:inline">{{ currentThicknessLabel }}</span>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="w-2.5 h-2.5 opacity-60"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M6 9l6 6l6 -6" />
          </svg>
        </button>

        <!-- THICKNESS DROPDOWN -->
        <div
          v-if="showThicknessMenu"
          class="absolute top-full left-0 mt-1 p-2 bg-base-100 border border-base-300 rounded-lg shadow-xl flex flex-col space-y-1.5 z-30 min-w-[130px]"
        >
          <div class="text-[10px] font-semibold text-base-content/60 uppercase tracking-wider px-1">
            {{ activeTool === 'pen' ? 'Pen Thickness' : 'Highlighter Thickness' }}
          </div>
          <button
            v-for="preset in currentThicknessPresets"
            :key="preset.label"
            type="button"
            class="btn btn-xs btn-ghost justify-start px-2 py-1 h-auto flex items-center space-x-2 rounded"
            :class="isCurrentThickness(preset.value) ? 'bg-base-200 font-bold text-primary' : ''"
            @click="selectThickness(preset.value)"
          >
            <span
              class="w-4 bg-current rounded-full inline-block"
              :style="{ height: `${Math.max(1.5, preset.value * (activeTool === 'pen' ? 600 : 120))}px` }"
            />
            <span>{{ preset.label }}</span>
          </button>
        </div>
      </div>
    </template>

    <!-- FONT SIZE CONTROL (FOR TEXT TOOL OR TEXT SELECTION) -->
    <template v-if="activeTool === 'text' || isTextSelected">
      <div class="h-4 w-px bg-base-300 mx-1" />
      <div class="relative flex items-center">
        <button
          type="button"
          class="btn btn-xs btn-ghost px-1.5 flex items-center space-x-1"
          :title="`Font Size: ${fontSize} pt`"
          @click="showFontSizeMenu = !showFontSizeMenu"
        >
          <span class="font-serif font-bold text-[11px]">A</span>
          <span class="text-[11px] font-medium">{{ fontSize }} pt</span>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="w-2.5 h-2.5 opacity-60"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path d="M6 9l6 6l6 -6" />
          </svg>
        </button>

        <!-- FONT SIZE DROPDOWN -->
        <div
          v-if="showFontSizeMenu"
          class="absolute top-full left-0 mt-1 p-1.5 bg-base-100 border border-base-300 rounded-lg shadow-xl grid grid-cols-3 gap-1 z-30 min-w-[120px]"
        >
          <button
            v-for="size in fontSizes"
            :key="size"
            type="button"
            class="btn btn-xs btn-ghost px-1.5 py-0.5 rounded text-[11px]"
            :class="fontSize === size ? 'btn-active font-bold text-primary bg-base-200' : ''"
            @click="selectFontSize(size)"
          >
            {{ size }}
          </button>
        </div>
      </div>
    </template>

    <div class="h-4 w-px bg-base-300 mx-1" />

    <!-- COLOR SWATCH PICKER -->
    <div class="relative flex items-center">
      <button
        type="button"
        class="btn btn-xs btn-ghost px-1.5 flex items-center space-x-1"
        title="Annotation Color"
        @click="showColorMenu = !showColorMenu"
      >
        <span
          class="w-3.5 h-3.5 rounded-full border border-base-content/30 shadow-xs inline-block"
          :style="{ backgroundColor: currentColor }"
        />
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-2.5 h-2.5 opacity-60"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M6 9l6 6l6 -6" />
        </svg>
      </button>

      <!-- COLOR DROPDOWN -->
      <div
        v-if="showColorMenu"
        class="absolute top-full left-0 mt-1 p-2 bg-base-100 border border-base-300 rounded-lg shadow-xl grid grid-cols-4 gap-1.5 z-30 min-w-[120px]"
      >
        <button
          v-for="color in presetColors"
          :key="color"
          type="button"
          class="w-5 h-5 rounded-full border transition-transform hover:scale-115 flex items-center justify-center"
          :class="currentColor.toLowerCase() === color.toLowerCase() ? 'border-primary ring-2 ring-primary/40' : 'border-base-content/20'"
          :style="{ backgroundColor: color }"
          :title="color"
          @click="selectPresetColor(color)"
        />
        <label
          class="w-5 h-5 rounded-full border border-base-content/30 cursor-pointer overflow-hidden relative flex items-center justify-center bg-conic hover:scale-115 transition-transform"
          title="Custom Color"
        >
          <input
            type="color"
            :value="currentColor"
            class="opacity-0 absolute inset-0 cursor-pointer"
            @input="onCustomColorInput($event.target.value)"
            @change="onCustomColorChange($event.target.value)"
          >
          <span class="text-[9px] font-bold text-base-content/70">+</span>
        </label>
      </div>
    </div>

    <!-- DELETE SELECTED ANNOTATION(S) -->
    <template v-if="hasSelection">
      <div class="h-4 w-px bg-base-300 mx-1" />
      <button
        type="button"
        class="btn btn-xs btn-ghost text-error px-1.5 flex items-center space-x-1 hover:bg-error/10"
        :title="selectionCount > 1 ? `Delete ${selectionCount} Selected Annotations (Delete/Backspace)` : 'Delete Selected Annotation (Delete/Backspace)'"
        @click="$emit('delete-selected')"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-3.5 h-3.5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M4 7l16 0" />
          <path d="M10 11l0 6" />
          <path d="M14 11l0 6" />
          <path d="M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2 -2l1 -12" />
          <path d="M9 7v-3a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v3" />
        </svg>
        <span class="hidden md:inline">{{ selectionCount > 1 ? `Delete (${selectionCount})` : 'Delete' }}</span>
      </button>
    </template>

    <!-- UNDO / REDO -->
    <div class="h-4 w-px bg-base-300 mx-1" />
    <button
      type="button"
      class="btn btn-xs btn-ghost px-1"
      :disabled="!canUndo"
      title="Undo Annotation (Ctrl+Z)"
      @click="$emit('undo')"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="w-3.5 h-3.5"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M9 14l-4 -4l4 -4" />
        <path d="M5 10h11a4 4 0 1 1 0 8h-1" />
      </svg>
    </button>
    <button
      type="button"
      class="btn btn-xs btn-ghost px-1"
      :disabled="!canRedo"
      title="Redo Annotation (Ctrl+Y / Ctrl+Shift+Z)"
      @click="$emit('redo')"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="w-3.5 h-3.5"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M15 14l4 -4l-4 -4" />
        <path d="M19 10h-11a4 4 0 1 0 0 8h1" />
      </svg>
    </button>
  </div>
</template>

<script>
export default {
  name: 'AnnotationToolbar',
  props: {
    activeTool: {
      type: String,
      default: 'select'
    },
    currentColor: {
      type: String,
      default: '#111827'
    },
    hasSelection: {
      type: Boolean,
      default: false
    },
    selectionCount: {
      type: Number,
      default: 0
    },
    penThickness: {
      type: Number,
      default: 0.003
    },
    highlighterThickness: {
      type: Number,
      default: 0.025
    },
    fontSize: {
      type: Number,
      default: 14
    },
    isTextSelected: {
      type: Boolean,
      default: false
    },
    canUndo: {
      type: Boolean,
      default: false
    },
    canRedo: {
      type: Boolean,
      default: false
    }
  },
  emits: [
    'select-tool',
    'change-color',
    'change-pen-thickness',
    'change-highlighter-thickness',
    'change-font-size',
    'delete-selected',
    'undo',
    'redo'
  ],
  data () {
    return {
      showColorMenu: false,
      showThicknessMenu: false,
      showFontSizeMenu: false,
      presetColors: [
        '#111827', // Black/dark gray
        '#2563EB', // Blue
        '#DC2626', // Red
        '#16A34A', // Green
        '#EAB308', // Yellow
        '#F97316', // Orange
        '#9333EA' // Purple
      ],
      penPresets: [
        { label: 'Thin', value: 0.0015 },
        { label: 'Normal', value: 0.003 },
        { label: 'Thick', value: 0.006 },
        { label: 'Extra Thick', value: 0.010 }
      ],
      highlighterPresets: [
        { label: 'Thin', value: 0.015 },
        { label: 'Normal', value: 0.025 },
        { label: 'Thick', value: 0.040 },
        { label: 'Extra Thick', value: 0.060 }
      ],
      fontSizes: [8, 10, 12, 14, 16, 18, 20, 24, 28, 36, 48, 72]
    }
  },
  computed: {
    currentThicknessPresets () {
      return this.activeTool === 'highlighter' ? this.highlighterPresets : this.penPresets
    },
    currentThicknessLabel () {
      if (this.activeTool === 'pen') {
        const found = this.penPresets.find((p) => Math.abs(p.value - this.penThickness) < 0.0005)
        return found ? found.label : 'Custom'
      }
      if (this.activeTool === 'highlighter') {
        const found = this.highlighterPresets.find((p) => Math.abs(p.value - this.highlighterThickness) < 0.003)
        return found ? found.label : 'Custom'
      }
      return 'Normal'
    }
  },
  mounted () {
    document.addEventListener('click', this.handleOutsideClick)
  },
  beforeUnmount () {
    document.removeEventListener('click', this.handleOutsideClick)
  },
  methods: {
    selectPresetColor (color) {
      this.$emit('change-color', color)
      this.showColorMenu = false
    },
    onCustomColorInput (color) {
      // Keep menu open during continuous drag so native picker is not unmounted
      this.$emit('change-color', color)
    },
    onCustomColorChange (color) {
      this.$emit('change-color', color)
    },
    isCurrentThickness (val) {
      if (this.activeTool === 'pen') {
        return Math.abs(this.penThickness - val) < 0.0005
      }
      return Math.abs(this.highlighterThickness - val) < 0.003
    },
    selectThickness (val) {
      if (this.activeTool === 'pen') {
        this.$emit('change-pen-thickness', val)
      } else {
        this.$emit('change-highlighter-thickness', val)
      }
      this.showThicknessMenu = false
    },
    selectFontSize (size) {
      this.$emit('change-font-size', size)
      this.showFontSizeMenu = false
    },
    handleOutsideClick (e) {
      if (!this.$el.contains(e.target)) {
        this.showColorMenu = false
        this.showThicknessMenu = false
        this.showFontSizeMenu = false
      }
    }
  }
}
</script>
