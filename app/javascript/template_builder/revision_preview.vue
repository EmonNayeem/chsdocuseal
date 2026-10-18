<template>
  <div class="flex flex-col h-full min-h-0 bg-base-200/40 select-none">
    <!-- PANE HEADER -->
    <div class="sticky top-0 z-20 flex items-center justify-between px-3 py-2 bg-base-100 border-b border-base-300 shadow-xs">
      <div class="flex items-center space-x-2">
        <span
          class="badge font-semibold text-xs text-white"
          :class="isHistorical ? 'badge-neutral' : 'badge-primary'"
        >
          {{ versionLabel }}
        </span>
        <span class="text-xs text-base-content/70 font-medium">
          {{ subLabel }}
        </span>
      </div>
      <div class="text-xs font-mono text-base-content/60">
        {{ activePageLabel }}
      </div>
    </div>

    <!-- SCROLL CONTAINER -->
    <div
      ref="scrollContainer"
      class="flex-1 overflow-y-auto p-4 flex flex-col items-center space-y-6"
      @scroll="handleScroll"
    >
      <template
        v-for="(schemaItem, docIndex) in schemaList"
        :key="schemaItem.attachment_uuid"
      >
        <!-- DYNAMIC DOCUMENT -->
        <div
          v-if="schemaItem.dynamic"
          :ref="setPageRef"
          :data-doc-index="docIndex"
          :data-page-index="0"
          class="page-wrapper w-full bg-base-100 rounded-lg shadow-sm border border-base-300 p-4"
          :style="pageContainerStyle"
        >
          <div class="flex items-center justify-between text-xs text-base-content/60 border-b pb-2 mb-3 font-mono">
            <span>Doc {{ docIndex + 1 }} • {{ schemaItem.name || 'Dynamic Document' }}</span>
            <span class="badge badge-ghost badge-xs">Dynamic HTML</span>
          </div>

          <div class="relative min-h-[300px]">
            <!-- eslint-disable vue/no-v-html -->
            <div
              class="prose prose-sm max-w-none dynamic-preview-content"
              v-html="renderDynamicHtml(schemaItem.attachment_uuid)"
            />
            <!-- eslint-enable vue/no-v-html -->

            <!-- FIELD OVERLAYS FOR DYNAMIC DOCUMENT -->
            <div
              v-for="item in getAreasForDocument(schemaItem.attachment_uuid, 0)"
              :key="item.areaKey"
              class="absolute rounded border pointer-events-none p-1 flex items-start overflow-hidden text-xs"
              :class="[item.bgClass, item.borderClass, item.textClass]"
              :style="item.style"
              :title="item.tooltip"
            >
              <div class="font-semibold truncate">
                {{ item.label }}
              </div>
            </div>
          </div>
        </div>

        <!-- PDF SOURCE DOCUMENT -->
        <template v-else>
          <div
            v-for="(page, pageIndex) in getDocumentPages(schemaItem.attachment_uuid)"
            :key="`${schemaItem.attachment_uuid}_${page.page}`"
            :ref="setPageRef"
            :data-doc-index="docIndex"
            :data-page-index="page.page"
            class="page-wrapper flex flex-col items-center w-full"
            :style="pageContainerStyle"
          >
            <!-- PAGE LABEL -->
            <div class="w-full flex items-center justify-between text-xs text-base-content/60 px-1 py-1 font-mono">
              <span>Doc {{ docIndex + 1 }} • Page {{ pageIndex + 1 }} of {{ getDocumentPages(schemaItem.attachment_uuid).length }}</span>
              <span class="truncate max-w-[200px]">{{ schemaItem.name || 'Document' }}</span>
            </div>

            <!-- PAGE CANVAS -->
            <div
              class="relative w-full rounded border border-base-300 bg-white shadow-xs overflow-hidden"
              :style="{ aspectRatio: `${page.width} / ${page.height}` }"
            >
              <img
                v-if="page.url"
                :src="page.url"
                :width="page.width"
                :height="page.height"
                loading="lazy"
                class="w-full h-full object-contain pointer-events-none select-none block"
                alt="Page preview"
              >
              <div
                v-else
                class="w-full h-full flex flex-col items-center justify-center bg-base-200/50 text-base-content/40 text-xs"
              >
                <span>Page {{ page.page + 1 }}</span>
                <span class="text-[10px] mt-1">(Image preview unavailable)</span>
              </div>

              <!-- ANNOTATION OVERLAYS -->
              <AnnotationPreviewLayer
                :annotations="payload.annotations || []"
                :attachment-uuid="schemaItem.attachment_uuid"
                :page="page.page"
              />

              <!-- FIELD OVERLAYS -->
              <div class="absolute inset-0 pointer-events-none">
                <div
                  v-for="item in getAreasForDocument(schemaItem.attachment_uuid, page.page)"
                  :key="item.areaKey"
                  class="absolute rounded border-1.5 pointer-events-auto p-1 flex flex-col justify-between overflow-hidden cursor-default transition-opacity hover:opacity-95"
                  :class="[item.bgClass, item.borderClass, item.textClass]"
                  :style="item.style"
                  :title="item.tooltip"
                >
                  <div class="flex items-center justify-between w-full leading-tight font-semibold text-[11px] truncate">
                    <span class="truncate">{{ item.label }}</span>
                    <span
                      v-if="item.partyName"
                      class="text-[9px] opacity-80 ml-1 font-normal uppercase"
                    >
                      {{ item.partyName }}
                    </span>
                  </div>
                  <div
                    v-if="item.typeBadge"
                    class="text-[9px] opacity-75 font-mono truncate"
                  >
                    {{ item.typeBadge }}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </template>
      </template>

      <!-- EMPTY STATE -->
      <div
        v-if="schemaList.length === 0"
        class="py-16 text-center text-base-content/50 text-sm"
      >
        No documents in this version.
      </div>
    </div>
  </div>
</template>

<script>
import AnnotationPreviewLayer from './annotation_preview_layer'

const BG_COLORS = [
  'bg-red-100/80',
  'bg-sky-100/80',
  'bg-emerald-100/80',
  'bg-yellow-100/80',
  'bg-purple-100/80',
  'bg-pink-100/80',
  'bg-cyan-100/80',
  'bg-orange-100/80',
  'bg-lime-100/80',
  'bg-indigo-100/80'
]

const BORDER_COLORS = [
  'border-red-500',
  'border-sky-500',
  'border-emerald-500',
  'border-yellow-500',
  'border-purple-500',
  'border-pink-500',
  'border-cyan-500',
  'border-orange-500',
  'border-lime-500',
  'border-indigo-500'
]

const TEXT_COLORS = [
  'text-red-900',
  'text-sky-900',
  'text-emerald-900',
  'text-yellow-900',
  'text-purple-900',
  'text-pink-900',
  'text-cyan-900',
  'text-orange-900',
  'text-lime-900',
  'text-indigo-900'
]

export default {
  name: 'RevisionPreview',
  components: {
    AnnotationPreviewLayer
  },
  props: {
    payload: {
      type: Object,
      required: true
    },
    versionLabel: {
      type: String,
      required: true
    },
    subLabel: {
      type: String,
      default: ''
    },
    zoom: {
      type: [String, Number],
      default: 'fit'
    },
    isHistorical: {
      type: Boolean,
      default: false
    }
  },
  emits: ['scroll'],
  data () {
    return {
      pageRefs: [],
      activePageLabel: ''
    }
  },
  computed: {
    schemaList () {
      return Array.isArray(this.payload?.schema) ? this.payload.schema : []
    },
    submittersList () {
      return Array.isArray(this.payload?.submitters) ? this.payload.submitters : []
    },
    fieldsList () {
      return Array.isArray(this.payload?.fields) ? this.payload.fields : []
    },
    documentsMap () {
      const docs = Array.isArray(this.payload?.documents) ? this.payload.documents : []
      return docs.reduce((acc, d) => {
        acc[d.uuid] = d
        return acc
      }, {})
    },
    dynamicDocsMap () {
      const dyns = Array.isArray(this.payload?.dynamic_documents) ? this.payload.dynamic_documents : []
      return dyns.reduce((acc, d) => {
        acc[d.uuid] = d
        return acc
      }, {})
    },
    pageContainerStyle () {
      if (this.zoom === 'fit') {
        return { width: '100%', maxWidth: '100%' }
      }
      if (typeof this.zoom === 'number') {
        return { width: `${Math.round(800 * this.zoom)}px`, maxWidth: 'none' }
      }
      return { width: '100%', maxWidth: '100%' }
    }
  },
  beforeUpdate () {
    this.pageRefs = []
  },
  methods: {
    setPageRef (el) {
      if (el && !this.pageRefs.includes(el)) {
        this.pageRefs.push(el)
      }
    },
    handleScroll (event) {
      this.updateActiveLabel()
      this.$emit('scroll', event)
    },
    updateActiveLabel () {
      const container = this.$refs.scrollContainer
      if (!container || this.pageRefs.length === 0) return

      const anchorY = container.scrollTop + 60
      let active = this.pageRefs[0]

      for (let i = 0; i < this.pageRefs.length; i++) {
        const el = this.pageRefs[i]
        if (el.offsetTop <= anchorY) {
          active = el
        } else {
          break
        }
      }

      if (active) {
        const docIdx = parseInt(active.getAttribute('data-doc-index') || 0, 10)
        const pageIdx = parseInt(active.getAttribute('data-page-index') || 0, 10)
        this.activePageLabel = `Doc ${docIdx + 1} • Page ${pageIdx + 1}`
      }
    },
    getPageElements () {
      return this.pageRefs.map((el) => {
        const docIndex = parseInt(el.getAttribute('data-doc-index') || 0, 10)
        const pageIndex = parseInt(el.getAttribute('data-page-index') || 0, 10)
        const top = el.offsetTop
        const height = el.offsetHeight
        return {
          element: el,
          docIndex,
          pageIndex,
          top,
          height,
          bottom: top + height
        }
      })
    },
    scrollToPosition (scrollTop) {
      if (this.$refs.scrollContainer) {
        this.$refs.scrollContainer.scrollTop = scrollTop
      }
    },
    getDocumentPages (uuid) {
      const doc = this.documentsMap[uuid]
      if (!doc || !Array.isArray(doc.preview_images) || doc.preview_images.length === 0) {
        return [{ page: 0, width: 1400, height: 1812, url: null }]
      }
      return doc.preview_images
    },
    renderDynamicHtml (uuid) {
      const dyn = this.dynamicDocsMap[uuid]
      if (!dyn) return '<p class="text-base-content/40">Dynamic document not found.</p>'

      let body = dyn.body || ''
      const attachments = Array.isArray(dyn.attachments) ? dyn.attachments : []

      attachments.forEach((att) => {
        if (att.uuid && att.url) {
          body = body.split(`blob:${att.uuid}`).join(att.url)
        }
      })

      return body
    },
    getAreasForDocument (attachmentUuid, pageIndex) {
      const items = []

      this.fieldsList.forEach((field) => {
        const areas = Array.isArray(field.areas) ? field.areas : []
        const submitterIndex = this.submittersList.findIndex((s) => s.uuid === field.submitter_uuid)
        const submitter = submitterIndex > -1 ? this.submittersList[submitterIndex] : null
        const colorIdx = submitterIndex > -1 ? submitterIndex % BG_COLORS.length : 0

        areas.forEach((area, aIdx) => {
          if (area.attachment_uuid === attachmentUuid && parseInt(area.page, 10) === parseInt(pageIndex, 10)) {
            const x = Math.max(0, Math.min(1, area.x || 0))
            const y = Math.max(0, Math.min(1, area.y || 0))
            const w = Math.max(0.01, Math.min(1 - x, area.w || 0.1))
            const h = Math.max(0.01, Math.min(1 - y, area.h || 0.05))

            items.push({
              areaKey: `${field.uuid}_${aIdx}`,
              label: field.name || field.type || 'Field',
              typeBadge: field.type,
              partyName: submitter?.name || '',
              bgClass: BG_COLORS[colorIdx],
              borderClass: BORDER_COLORS[colorIdx],
              textClass: TEXT_COLORS[colorIdx],
              style: {
                top: `${y * 100}%`,
                left: `${x * 100}%`,
                width: `${w * 100}%`,
                height: `${h * 100}%`
              },
              tooltip: `${field.name || field.type} (${field.type}) • Party: ${submitter?.name || 'Unassigned'}`
            })
          }
        })
      })

      return items
    }
  }
}
</script>

<style scoped>
.dynamic-preview-content :deep(img) {
  max-width: 100%;
  height: auto;
}
</style>
