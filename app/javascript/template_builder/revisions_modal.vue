<template>
  <div
    class="modal modal-open !animate-none"
    :class="currentView === 'compare' ? 'items-center justify-center p-2 sm:p-4 overflow-hidden' : 'items-start overflow-y-auto'"
  >
    <div
      class="absolute top-0 bottom-0 right-0 left-0"
      @click.prevent="$emit('close')"
    />
    <div
      class="modal-box text-base-content"
      :class="currentView === 'compare'
        ? 'p-0 w-[95vw] max-w-[1600px] h-[90vh] max-h-[90vh] flex flex-col overflow-hidden my-auto shadow-2xl rounded-xl'
        : 'pt-4 pb-6 mt-16 max-w-3xl w-full'"
    >
      <!-- LIST VIEW -->
      <div v-if="currentView === 'list'">
        <!-- HEADER -->
        <div class="flex justify-between items-center border-b pb-3 mb-4">
          <div class="flex items-center space-x-2">
            <span class="text-lg font-bold">
              {{ t('revisions') }}
            </span>
          </div>
          <button
            type="button"
            class="btn btn-ghost btn-sm btn-circle text-lg"
            @click.prevent="$emit('close')"
          >
            &times;
          </button>
        </div>

        <div
          v-if="loadingRevisions"
          class="py-16 flex flex-col items-center justify-center text-base-content/60"
        >
          <IconInnerShadowTop class="w-8 h-8 animate-spin mx-auto text-base-content/50" />
          <div class="text-sm mt-3">
            Loading version history...
          </div>
        </div>

        <ul
          v-else-if="effectiveRevisions.length"
          class="space-y-3"
        >
          <li
            v-for="revision in effectiveRevisions"
            :key="revision.id"
            class="border rounded-lg p-3.5 bg-base-100 shadow-xs hover:border-base-content/30 transition-colors"
          >
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div class="flex flex-col space-y-1">
                <div class="flex items-center space-x-2">
                  <span class="badge badge-neutral font-semibold text-xs text-white">
                    Version {{ revision.version_number }}
                  </span>
                  <span class="text-sm font-medium">{{ formatDate(revision.created_at) }}</span>
                </div>
                <div class="flex items-center space-x-3 text-xs text-base-content/70">
                  <span class="flex items-center space-x-1">
                    <IconUser class="w-3.5 h-3.5" />
                    <span>{{ revision.author.full_name || revision.author.email }}</span>
                  </span>
                  <span
                    v-if="revision.fields_count || revision.documents_count"
                    class="hidden sm:inline-block"
                  >
                    • {{ revision.documents_count || 1 }} doc(s), {{ revision.fields_count || 0 }} field(s)
                  </span>
                </div>
              </div>

              <!-- ACTION BUTTONS -->
              <div class="flex items-center space-x-1.5 self-end sm:self-center">
                <button
                  type="button"
                  class="btn btn-sm btn-outline btn-neutral"
                  :disabled="actionLoading"
                  @click="viewCompare(revision)"
                >
                  <IconInnerShadowTop
                    v-if="loadingVersionId === revision.id && actionType === 'compare'"
                    class="w-3.5 h-3.5 animate-spin"
                  />
                  <span v-else>Compare</span>
                </button>

                <button
                  type="button"
                  class="btn btn-sm btn-neutral text-white"
                  :disabled="actionLoading"
                  @click="promptRestore(revision)"
                >
                  <IconInnerShadowTop
                    v-if="loadingVersionId === revision.id && actionType === 'restore'"
                    class="w-3.5 h-3.5 animate-spin"
                  />
                  <span v-else>Restore</span>
                </button>

                <button
                  type="button"
                  class="btn btn-sm btn-ghost"
                  title="Copy into new template"
                  :disabled="actionLoading"
                  @click="openCopyModal(revision)"
                >
                  Copy
                </button>

                <button
                  type="button"
                  class="btn btn-sm btn-ghost"
                  title="Download historical document(s)"
                  :disabled="actionLoading"
                  @click="downloadVersion(revision)"
                >
                  <IconInnerShadowTop
                    v-if="loadingVersionId === revision.id && actionType === 'download'"
                    class="w-3.5 h-3.5 animate-spin"
                  />
                  <IconDownload
                    v-else
                    class="w-4 h-4"
                  />
                </button>
              </div>
            </div>
          </li>
        </ul>

        <div
          v-else
          class="py-12 text-center text-base-content/60"
        >
          <div class="text-base font-medium">
            {{ t('no_revisions_yet') }}
          </div>
          <div class="text-xs text-base-content/50 mt-1">
            Versions are automatically created when you explicitly click Save.
          </div>
        </div>
      </div>

      <!-- COMPARE VIEW -->
      <div
        v-else-if="currentView === 'compare'"
        class="flex-1 min-h-0 flex flex-col"
      >
        <div
          v-if="loadingCompare"
          class="flex-1 flex flex-col items-center justify-center py-24"
        >
          <IconInnerShadowTop class="w-8 h-8 animate-spin mx-auto text-base-content/50" />
          <div class="text-sm text-base-content/60 mt-2">
            Loading comparison...
          </div>
        </div>

        <RevisionVisualCompare
          v-else-if="compareData"
          class="flex-1 min-h-0"
          :compare-data="compareData"
          :selected-version="selectedVersion"
          :template="template"
          :locale="locale"
          @back="currentView = 'list'"
          @restore="promptRestore(selectedVersion)"
          @close="$emit('close')"
        />
      </div>

      <!-- CONFIRM RESTORE MODAL -->
      <div
        v-if="restoreTarget"
        class="modal modal-open items-center"
      >
        <div class="modal-box max-w-md">
          <h3 class="font-bold text-lg">
            Restore Version {{ restoreTarget.version_number }}?
          </h3>
          <p class="py-3 text-sm text-base-content/80">
            The current template content will be replaced with Version {{ restoreTarget.version_number }}.
            Existing submissions will not be affected.
          </p>
          <div class="modal-action">
            <button
              type="button"
              class="btn btn-sm btn-ghost"
              :disabled="actionLoading"
              @click="restoreTarget = null"
            >
              Cancel
            </button>
            <button
              type="button"
              class="btn btn-sm btn-error text-white"
              :disabled="actionLoading"
              @click="executeRestore"
            >
              <IconInnerShadowTop
                v-if="actionLoading && actionType === 'restore'"
                class="w-3.5 h-3.5 animate-spin"
              />
              <span v-else>Confirm Restore</span>
            </button>
          </div>
        </div>
      </div>

      <!-- COPY MODAL -->
      <div
        v-if="copyTarget"
        class="modal modal-open items-center"
      >
        <div class="modal-box max-w-md">
          <h3 class="font-bold text-lg">
            Copy Version {{ copyTarget.version_number }}
          </h3>
          <p class="py-2 text-sm text-base-content/80">
            Create a new independent template from this version's snapshot.
          </p>
          <div class="form-control w-full my-3">
            <label class="label label-text text-xs font-semibold">New Template Name</label>
            <input
              v-model="copyName"
              type="text"
              class="input input-bordered input-sm w-full"
              placeholder="Template name"
            >
          </div>
          <div class="modal-action">
            <button
              type="button"
              class="btn btn-sm btn-ghost"
              :disabled="actionLoading"
              @click="copyTarget = null"
            >
              Cancel
            </button>
            <button
              type="button"
              class="btn btn-sm btn-primary"
              :disabled="actionLoading || !copyName.trim()"
              @click="executeCopy"
            >
              <IconInnerShadowTop
                v-if="actionLoading && actionType === 'copy'"
                class="w-3.5 h-3.5 animate-spin"
              />
              <span v-else>Create Copy</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { IconUser, IconInnerShadowTop, IconDownload } from '@tabler/icons-vue'
import RevisionVisualCompare from './revision_visual_compare.vue'
import { formatShortDateTime } from '../lib/date_time'
import { downloadUrls } from '../lib/download_urls'
import * as i18n from './i18n'

export default {
  name: 'RevisionsModal',
  components: { IconUser, IconInnerShadowTop, IconDownload, RevisionVisualCompare },
  inject: {
    t: {
      from: 't',
      default: () => (key) => i18n.en?.[key] || key
    },
    baseFetch: {
      from: 'baseFetch',
      default: () => (path, options = {}) => {
        const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
        return fetch(path, {
          ...options,
          headers: {
            'X-CSRF-Token': token,
            ...options.headers
          }
        })
      }
    }
  },
  props: {
    template: {
      type: Object,
      required: true
    },
    revisions: {
      type: Array,
      default: null
    },
    locale: {
      type: String,
      default: 'en'
    },
    returnUrl: {
      type: String,
      default: null
    }
  },
  emits: ['close', 'download-urls'],
  data () {
    return {
      currentView: 'list',
      localRevisions: this.revisions,
      loadingRevisions: !this.revisions,
      selectedVersion: null,
      compareData: null,
      loadingCompare: false,
      loadingVersionId: null,
      actionType: null,
      actionLoading: false,
      restoreTarget: null,
      copyTarget: null,
      copyName: ''
    }
  },
  computed: {
    effectiveRevisions () {
      return this.localRevisions || this.revisions || []
    }
  },
  watch: {
    revisions (val) {
      if (val) {
        this.localRevisions = val
        this.loadingRevisions = false
      }
    }
  },
  created () {
    if (!this.localRevisions) {
      this.loadRevisions()
    }
  },
  mounted () {
    document.addEventListener('keyup', this.onEscKey)
  },
  unmounted () {
    document.removeEventListener('keyup', this.onEscKey)
  },
  methods: {
    formatDate (string) {
      return formatShortDateTime(string, this.locale)
    },
    loadRevisions () {
      this.loadingRevisions = true
      this.baseFetch(`/templates/${this.template.id}/versions`)
        .then((r) => r.json())
        .then((data) => {
          this.localRevisions = data
        })
        .catch((err) => {
          console.error('Failed to load version history:', err)
          alert('Failed to load version history.')
        })
        .finally(() => {
          this.loadingRevisions = false
        })
    },
    onEscKey (e) {
      if (e.code === 'Escape') {
        if (this.copyTarget) {
          this.copyTarget = null
        } else if (this.restoreTarget) {
          this.restoreTarget = null
        } else if (this.currentView === 'compare') {
          this.currentView = 'list'
        } else {
          this.$emit('close')
        }
      }
    },
    viewCompare (version) {
      this.selectedVersion = version
      this.currentView = 'compare'
      this.loadingCompare = true
      this.compareData = null

      this.baseFetch(`/templates/${this.template.id}/versions/${version.id}/compare`)
        .then((r) => r.json())
        .then((data) => {
          this.compareData = data
        })
        .catch((err) => {
          console.error('Failed to compare version:', err)
          alert('Failed to load version comparison.')
          this.currentView = 'list'
        })
        .finally(() => {
          this.loadingCompare = false
        })
    },
    promptRestore (version) {
      this.restoreTarget = version
    },
    executeRestore () {
      if (!this.restoreTarget) return
      this.actionLoading = true
      this.actionType = 'restore'

      this.baseFetch(`/templates/${this.template.id}/versions/${this.restoreTarget.id}/restore`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })
        .then((r) => r.json())
        .then((data) => {
          if (this.returnUrl) {
            if (this.returnUrl === window.location.href) {
              window.location.reload()
            } else {
              window.location.href = this.returnUrl
            }
          } else if (data && data.redirect_url) {
            window.location.href = data.redirect_url
          } else {
            window.location.reload()
          }
        })
        .catch((err) => {
          console.error('Failed to restore version:', err)
          alert('Failed to restore version.')
          this.actionLoading = false
          this.actionType = null
          this.restoreTarget = null
        })
    },
    openCopyModal (version) {
      this.copyTarget = version
      this.copyName = `${this.template.name} (Version ${version.version_number} Copy)`
    },
    executeCopy () {
      if (!this.copyTarget) return
      this.actionLoading = true
      this.actionType = 'copy'

      this.baseFetch(`/templates/${this.template.id}/versions/${this.copyTarget.id}/copy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: this.copyName })
      })
        .then((r) => r.json())
        .then((data) => {
          if (data && data.url) {
            window.location.href = data.url
          } else {
            alert('Template copied successfully.')
            this.copyTarget = null
            this.$emit('close')
          }
        })
        .catch((err) => {
          console.error('Failed to copy version:', err)
          alert('Failed to copy template version.')
        })
        .finally(() => {
          this.actionLoading = false
          this.actionType = null
        })
    },
    downloadVersion (version) {
      this.loadingVersionId = version.id
      this.actionType = 'download'
      this.actionLoading = true

      this.baseFetch(`/templates/${this.template.id}/versions/${version.id}/documents`)
        .then((r) => r.json())
        .then((urls) => {
          if (urls && urls.length) {
            this.$emit('download-urls', urls)
            if (!this.$attrs['onDownload-urls'] && !this.$attrs.onDownloadUrls) {
              downloadUrls(urls)
            }
          } else {
            alert('No documents found for this version.')
          }
        })
        .catch((err) => {
          console.error('Failed to download version documents:', err)
          alert('Failed to download documents for this version.')
        })
        .finally(() => {
          this.loadingVersionId = null
          this.actionType = null
          this.actionLoading = false
        })
    }
  }
}
</script>
