<template>
  <div class="flex flex-col h-full min-h-0 bg-base-100 text-base-content select-none">
    <!-- TOP TOOLBAR -->
    <div class="flex flex-wrap items-center justify-between px-4 py-2.5 border-b border-base-300 bg-base-100 gap-2 flex-shrink-0">
      <!-- LEFT: BACK & TITLE -->
      <div class="flex items-center space-x-2">
        <button
          type="button"
          class="btn btn-ghost btn-sm btn-circle"
          title="Back to Versions"
          @click="$emit('back')"
        >
          ❮
        </button>
        <div>
          <div class="text-sm font-bold flex items-center space-x-2">
            <span>Compare Version {{ compareData.version_number }}</span>
            <span
              v-if="compareData.identical"
              class="badge badge-info badge-xs text-white"
            >
              Identical
            </span>
          </div>
          <div class="text-xs text-base-content/60">
            Side-by-side visual comparison with current template
          </div>
        </div>
      </div>

      <!-- CENTER: CONTROLS -->
      <div class="flex items-center space-x-3">
        <!-- SYNC SCROLL TOGGLE -->
        <button
          type="button"
          class="btn btn-xs font-medium space-x-1"
          :class="syncScrolling ? 'btn-neutral text-white' : 'btn-outline border-base-300 text-base-content/70'"
          :title="syncScrolling ? 'Synchronized scrolling is ON' : 'Synchronized scrolling is OFF'"
          @click="toggleSync"
        >
          <span>Sync Scroll:</span>
          <span class="font-bold">{{ syncScrolling ? 'ON' : 'OFF' }}</span>
        </button>

        <!-- ZOOM CONTROLS -->
        <div class="join border border-base-300 rounded-md">
          <button
            type="button"
            class="btn btn-xs join-item btn-ghost px-2"
            title="Zoom out"
            :disabled="zoomLevel === 0.75"
            @click="setZoom(0.75)"
          >
            −
          </button>
          <button
            type="button"
            class="btn btn-xs join-item px-2 font-mono"
            :class="zoomLevel === 'fit' ? 'btn-active btn-ghost font-bold' : 'btn-ghost'"
            title="Fit to width"
            @click="setZoom('fit')"
          >
            Fit
          </button>
          <button
            type="button"
            class="btn btn-xs join-item px-2 font-mono"
            :class="zoomLevel === 1 ? 'btn-active btn-ghost font-bold' : 'btn-ghost'"
            title="100% Size"
            @click="setZoom(1)"
          >
            100%
          </button>
          <button
            type="button"
            class="btn btn-xs join-item btn-ghost px-2"
            title="Zoom in"
            :disabled="zoomLevel === 1.25"
            @click="setZoom(1.25)"
          >
            +
          </button>
        </div>
      </div>

      <!-- RIGHT: CLOSE BUTTON -->
      <div class="flex items-center space-x-2">
        <button
          type="button"
          class="btn btn-ghost btn-sm btn-circle text-lg"
          @click="$emit('close')"
        >
          &times;
        </button>
      </div>
    </div>

    <!-- MAIN COMPARISON VIEWPORT (SIDE-BY-SIDE PANES) -->
    <div class="flex-1 min-h-0 flex flex-col md:flex-row divide-y md:divide-y-0 md:divide-x divide-base-300 overflow-hidden">
      <!-- LEFT PANE: HISTORICAL VERSION -->
      <div class="w-full md:w-1/2 h-1/2 md:h-full flex flex-col min-h-0">
        <RevisionPreview
          ref="leftPreview"
          :payload="historicalPayload"
          :version-label="`Version ${compareData.version_number}`"
          :sub-label="formattedVersionDate"
          :zoom="zoomLevel"
          :is-historical="true"
          class="flex-1 min-h-0"
          @scroll="onLeftScroll"
        />
      </div>

      <!-- RIGHT PANE: CURRENT TEMPLATE -->
      <div class="w-full md:w-1/2 h-1/2 md:h-full flex flex-col min-h-0">
        <RevisionPreview
          ref="rightPreview"
          :payload="currentPayload"
          version-label="Current Template"
          sub-label="Persisted State"
          :zoom="zoomLevel"
          :is-historical="false"
          class="flex-1 min-h-0"
          @scroll="onRightScroll"
        />
      </div>
    </div>

    <!-- DETAILED CHANGES COLLAPSIBLE (TEXT DIFF) -->
    <details class="border-t border-base-300 bg-base-100 flex-shrink-0 group">
      <summary class="px-4 py-2 font-semibold text-xs uppercase tracking-wider text-base-content/70 cursor-pointer flex items-center justify-between hover:bg-base-200/50">
        <span>Detailed Changes (Structured Text Diff)</span>
        <span class="text-[11px] font-mono lowercase opacity-75">Click to toggle</span>
      </summary>
      <div class="p-4 max-h-60 overflow-y-auto space-y-3 bg-base-200/30 text-xs">
        <!-- IDENTICAL NOTICE -->
        <div
          v-if="compareData.identical"
          class="p-2 bg-info/10 text-info rounded border border-info/20 font-medium"
        >
          No differences found between Version {{ compareData.version_number }} and the current template.
        </div>

        <template v-else>
          <!-- NAME DIFF -->
          <div
            v-if="compareData.name && compareData.name.changed"
            class="p-2.5 bg-base-100 rounded border border-base-300"
          >
            <div class="font-bold mb-1 text-base-content/70">
              Template Name
            </div>
            <div class="flex items-center space-x-2">
              <span class="line-through text-base-content/60">{{ compareData.name.current }}</span>
              <span>→</span>
              <span class="font-semibold text-success">{{ compareData.name.version }}</span>
            </div>
          </div>

          <!-- DOCUMENTS DIFF -->
          <div
            v-if="hasDocDiff"
            class="p-2.5 bg-base-100 rounded border border-base-300 space-y-1"
          >
            <div class="font-bold text-base-content/70">
              Documents
            </div>
            <div
              v-if="compareData.documents.added.length"
              class="text-success"
            >
              + Added in version: {{ compareData.documents.added.map(d => d.name).join(', ') }}
            </div>
            <div
              v-if="compareData.documents.removed.length"
              class="text-error"
            >
              - Removed in version: {{ compareData.documents.removed.map(d => d.name).join(', ') }}
            </div>
            <div
              v-if="compareData.documents.changed.length"
              class="text-warning"
            >
              ~ Modified: {{ compareData.documents.changed.map(d => d.name).join(', ') }}
            </div>
            <div
              v-if="compareData.documents.reordered"
              class="text-base-content/60"
            >
              • Document order differs from current template
            </div>
          </div>

          <!-- PARTIES DIFF -->
          <div
            v-if="hasPartyDiff"
            class="p-2.5 bg-base-100 rounded border border-base-300 space-y-1"
          >
            <div class="font-bold text-base-content/70">
              Parties
            </div>
            <div
              v-if="compareData.parties.added.length"
              class="text-success"
            >
              + Added: {{ compareData.parties.added.map(p => p.name).join(', ') }}
            </div>
            <div
              v-if="compareData.parties.removed.length"
              class="text-error"
            >
              - Removed: {{ compareData.parties.removed.map(p => p.name).join(', ') }}
            </div>
            <div
              v-if="compareData.parties.changed.length"
              class="text-warning"
            >
              ~ Modified: {{ compareData.parties.changed.map(p => p.name).join(', ') }}
            </div>
          </div>

          <!-- FIELDS DIFF -->
          <div
            v-if="hasFieldDiff"
            class="p-2.5 bg-base-100 rounded border border-base-300 space-y-1"
          >
            <div class="font-bold text-base-content/70">
              Fields
            </div>
            <div
              v-if="compareData.fields.added.length"
              class="text-success"
            >
              + Added: {{ compareData.fields.added.map(f => f.name).join(', ') }}
            </div>
            <div
              v-if="compareData.fields.removed.length"
              class="text-error"
            >
              - Removed: {{ compareData.fields.removed.map(f => f.name).join(', ') }}
            </div>
            <div
              v-if="compareData.fields.changed.length"
              class="text-warning"
            >
              ~ Modified: {{ compareData.fields.changed.map(f => f.name).join(', ') }}
            </div>
          </div>

          <!-- PREFERENCES / SETTINGS DIFF -->
          <div
            v-if="compareData.preferences && compareData.preferences.changed"
            class="p-2.5 bg-base-100 rounded border border-base-300"
          >
            <span class="font-bold text-base-content/70">Settings & Preferences:</span>
            <span class="ml-2 text-warning font-semibold">Settings differ between versions</span>
          </div>
        </template>
      </div>
    </details>

    <!-- STICKY FOOTER -->
    <div class="flex items-center justify-between px-4 py-3 border-t border-base-300 bg-base-100 flex-shrink-0">
      <button
        type="button"
        class="btn btn-sm btn-ghost"
        @click="$emit('back')"
      >
        ❮ Back to Versions
      </button>

      <div class="text-xs text-base-content/60 hidden sm:inline-block">
        {{ compareData.identical ? 'Version matches current template' : 'Differences detected between versions' }}
      </div>

      <button
        type="button"
        class="btn btn-sm btn-neutral text-white"
        @click="$emit('restore')"
      >
        Restore Version {{ compareData.version_number }}
      </button>
    </div>
  </div>
</template>

<script>
import RevisionPreview from './revision_preview.vue'
import { findActivePageAndProgress, calculateTargetScroll } from './revision_scroll_sync.js'
import { formatShortDateTime } from '../lib/date_time'

export default {
  name: 'RevisionVisualCompare',
  components: {
    RevisionPreview
  },
  props: {
    compareData: {
      type: Object,
      required: true
    },
    selectedVersion: {
      type: Object,
      required: true
    },
    template: {
      type: Object,
      required: true
    },
    locale: {
      type: String,
      required: true
    }
  },
  emits: ['back', 'restore', 'close'],
  data () {
    return {
      syncScrolling: true,
      zoomLevel: 'fit',
      syncingPane: null,
      isProgrammaticScroll: false,
      scrollRafId: null
    }
  },
  computed: {
    formattedVersionDate () {
      return formatShortDateTime(this.compareData.created_at, this.locale)
    },
    historicalPayload () {
      return this.compareData.visual?.historical || {}
    },
    currentPayload () {
      return this.compareData.visual?.current || {}
    },
    hasDocDiff () {
      if (!this.compareData.documents) return false
      const { added, removed, changed, reordered } = this.compareData.documents
      return (added && added.length > 0) || (removed && removed.length > 0) || (changed && changed.length > 0) || reordered
    },
    hasPartyDiff () {
      if (!this.compareData.parties) return false
      const { added, removed, changed, order_changed: orderChanged } = this.compareData.parties
      return (added && added.length > 0) || (removed && removed.length > 0) || (changed && changed.length > 0) || orderChanged
    },
    hasFieldDiff () {
      if (!this.compareData.fields) return false
      const { added, removed, changed } = this.compareData.fields
      return (added && added.length > 0) || (removed && removed.length > 0) || (changed && changed.length > 0)
    }
  },
  methods: {
    toggleSync () {
      this.syncScrolling = !this.syncScrolling
      this.syncingPane = null
      this.isProgrammaticScroll = false
    },
    setZoom (level) {
      this.zoomLevel = level
    },
    onLeftScroll (event) {
      if (!this.syncScrolling || this.isProgrammaticScroll || this.syncingPane === 'right') {
        return
      }
      this.syncPane('left', 'right', event.target)
    },
    onRightScroll (event) {
      if (!this.syncScrolling || this.isProgrammaticScroll || this.syncingPane === 'left') {
        return
      }
      this.syncPane('right', 'left', event.target)
    },
    syncPane (sourceName, targetName, sourceContainer) {
      this.syncingPane = sourceName

      if (this.scrollRafId) {
        cancelAnimationFrame(this.scrollRafId)
      }

      this.scrollRafId = requestAnimationFrame(() => {
        const sourcePreview = sourceName === 'left' ? this.$refs.leftPreview : this.$refs.rightPreview
        const targetPreview = sourceName === 'left' ? this.$refs.rightPreview : this.$refs.leftPreview

        if (!sourcePreview || !targetPreview) {
          this.syncingPane = null
          return
        }

        const targetContainer = targetPreview.$refs.scrollContainer
        if (!targetContainer) {
          this.syncingPane = null
          return
        }

        const sourcePages = sourcePreview.getPageElements()
        const targetPages = targetPreview.getPageElements()

        const activeState = findActivePageAndProgress(sourceContainer, sourcePages)
        const fallbackProgress = (sourceContainer.scrollHeight - sourceContainer.clientHeight) > 0
          ? sourceContainer.scrollTop / (sourceContainer.scrollHeight - sourceContainer.clientHeight)
          : 0

        const targetY = calculateTargetScroll(targetContainer, targetPages, activeState, fallbackProgress)

        this.isProgrammaticScroll = true
        targetPreview.scrollToPosition(targetY)

        requestAnimationFrame(() => {
          this.isProgrammaticScroll = false
          this.syncingPane = null
        })
      })
    }
  }
}
</script>
