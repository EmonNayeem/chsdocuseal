<template>
  <div class="annotation-preview-layer absolute inset-0 pointer-events-none select-none overflow-hidden">
    <!-- SVG VECTOR PATHS (PEN & HIGHLIGHTER) -->
    <svg
      v-if="strokeAnnotations.length"
      class="w-full h-full absolute inset-0 overflow-visible pointer-events-none"
      viewBox="0 0 1000 1000"
      preserveAspectRatio="none"
    >
      <path
        v-for="annot in strokeAnnotations"
        :key="annot.uuid"
        :d="pointsToPath(annot.points)"
        :stroke="annot.color"
        :stroke-width="annot.width * 1000"
        :stroke-opacity="annot.type === 'highlighter' ? (annot.opacity || 0.35) : 1"
        stroke-linecap="round"
        stroke-linejoin="round"
        fill="none"
      />
    </svg>

    <!-- TEXT ANNOTATIONS -->
    <div
      v-for="annot in textAnnotations"
      :key="annot.uuid"
      class="absolute pointer-events-none whitespace-pre-wrap px-1 py-0.5 font-sans"
      :style="getTextAnnotationStyle(annot)"
    >
      {{ annot.text }}
    </div>
  </div>
</template>

<script>
export default {
  name: 'AnnotationPreviewLayer',
  props: {
    annotations: {
      type: Array,
      default: () => []
    },
    attachmentUuid: {
      type: String,
      default: ''
    },
    page: {
      type: Number,
      default: 0
    }
  },
  computed: {
    filteredAnnotations () {
      if (!this.attachmentUuid) {
        return this.annotations.filter((a) => a.page === this.page)
      }
      return this.annotations.filter(
        (a) => a.attachment_uuid === this.attachmentUuid && a.page === this.page
      )
    },
    strokeAnnotations () {
      return this.filteredAnnotations.filter(
        (a) => a.type === 'pen' || a.type === 'highlighter'
      )
    },
    textAnnotations () {
      return this.filteredAnnotations.filter(
        (a) => a.type === 'text' && a.text
      )
    }
  },
  methods: {
    pointsToPath (points) {
      if (!points || points.length < 2) return ''
      const first = points[0]
      let d = `M ${(first.x * 1000).toFixed(1)} ${(first.y * 1000).toFixed(1)}`
      for (let i = 1; i < points.length; i++) {
        d += ` L ${(points[i].x * 1000).toFixed(1)} ${(points[i].y * 1000).toFixed(1)}`
      }
      return d
    },
    getTextAnnotationStyle (annot) {
      const pt = annot.font_size || 14
      return {
        left: `${(annot.x * 100).toFixed(3)}%`,
        top: `${(annot.y * 100).toFixed(3)}%`,
        maxWidth: `${((annot.w || 0.4) * 100).toFixed(3)}%`,
        color: annot.color,
        fontSize: `${((pt / 612) * 100).toFixed(3)}cqw`
      }
    }
  }
}
</script>
