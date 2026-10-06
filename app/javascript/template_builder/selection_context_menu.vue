<template>
  <div>
    <div
      v-if="!isShowFontModal && !isShowConditionsModal"
      ref="menu"
      class="fixed z-50 p-1 bg-white shadow-lg rounded-lg border border-neutral-200 cursor-default"
      style="min-width: 170px"
      :style="menuStyle"
      @mousedown.stop
      @pointerdown.stop
    >
      <label
        v-if="requiredFields.length"
        class="field-settings-required w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center space-x-2 text-sm cursor-pointer"
        @click.stop
      >
        <input
          :checked="isAllRequired"
          :indeterminate="isMixedRequired"
          type="checkbox"
          class="toggle toggle-xs"
          :disabled="!editable"
          @change="handleToggleRequired($event.target.checked)"
          @click.stop
        >
        <span>{{ t('required') }}</span>
      </label>
      <label
        v-if="readOnlyFields.length"
        class="field-settings-read-only w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center space-x-2 text-sm cursor-pointer"
        @click.stop
      >
        <input
          :checked="isAllReadOnly"
          :indeterminate="isMixedReadOnly"
          type="checkbox"
          class="toggle toggle-xs"
          :disabled="!editable"
          @change="handleToggleReadOnly($event.target.checked)"
          @click.stop
        >
        <span>{{ t('read_only') }}</span>
      </label>
      <hr
        v-if="requiredFields.length || readOnlyFields.length"
        class="my-1 border-neutral-200"
      >
      <button
        v-if="showFont"
        class="w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center space-x-2 text-sm"
        @click.stop="openFontModal"
      >
        <IconTypography class="w-4 h-4" />
        <span>{{ t('font') }}</span>
      </button>
      <button
        v-if="showCondition"
        class="w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center space-x-2 text-sm"
        @click.stop="openConditionModal"
      >
        <IconRouteAltLeft class="w-4 h-4" />
        <span>{{ t('condition') }}</span>
      </button>
      <hr
        v-if="showFont || showCondition"
        class="my-1 border-neutral-200"
      >
      <ContextSubmenu
        :icon="IconLayoutAlignMiddle"
        :label="t('align')"
      >
        <button
          class="w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center space-x-2 text-sm"
          @click.stop="alignSelectedAreas('left')"
        >
          <IconLayoutAlignLeft class="w-4 h-4" />
          <span>{{ t('align_left') }}</span>
        </button>
        <button
          class="w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center space-x-2 text-sm"
          @click.stop="alignSelectedAreas('right')"
        >
          <IconLayoutAlignRight class="w-4 h-4" />
          <span>{{ t('align_right') }}</span>
        </button>
        <button
          class="w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center space-x-2 text-sm"
          @click.stop="alignSelectedAreas('top')"
        >
          <IconLayoutAlignTop class="w-4 h-4" />
          <span>{{ t('align_top') }}</span>
        </button>
        <button
          class="w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center space-x-2 text-sm"
          @click.stop="alignSelectedAreas('bottom')"
        >
          <IconLayoutAlignBottom class="w-4 h-4" />
          <span>{{ t('align_bottom') }}</span>
        </button>
      </ContextSubmenu>
      <ContextSubmenu
        :icon="IconAspectRatio"
        :label="t('resize')"
      >
        <button
          class="w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center space-x-2 text-sm"
          @click.stop="resizeSelectedAreas('width')"
        >
          <IconArrowsHorizontal class="w-4 h-4" />
          <span>{{ t('width') }}</span>
        </button>
        <button
          class="w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center space-x-2 text-sm"
          @click.stop="resizeSelectedAreas('height')"
        >
          <IconArrowsVertical class="w-4 h-4" />
          <span>{{ t('height') }}</span>
        </button>
      </ContextSubmenu>
      <hr
        v-if="canGroupCheckboxes"
        class="my-1 border-neutral-200"
      >
      <button
        v-if="canGroupCheckboxes"
        class="w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center justify-between text-sm"
        @click.stop="handleGroupCheckboxes"
      >
        <span class="flex items-center space-x-2">
          <IconListCheck class="w-4 h-4" />
          <span>{{ t('group_checkboxes') }}</span>
        </span>
      </button>
      <hr class="my-1 border-neutral-200">
      <button
        class="w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center justify-between text-sm"
        @click.stop="$emit('copy')"
      >
        <span class="flex items-center space-x-2">
          <IconCopy class="w-4 h-4" />
          <span>{{ t('copy') }}</span>
        </span>
        <span class="text-xs text-base-content/60 ml-4">{{ isMac ? '⌘C' : 'Ctrl+C' }}</span>
      </button>
      <button
        class="w-full px-2 py-1 rounded-md hover:bg-neutral-100 flex items-center justify-between text-sm text-red-600"
        @click.stop="$emit('delete')"
      >
        <span class="flex items-center space-x-2">
          <IconTrashX class="w-4 h-4" />
          <span>{{ t('remove') }}</span>
        </span>
        <span class="text-xs text-base-content/60 ml-4">Del</span>
      </button>
    </div>
    <Teleport
      v-if="isShowFontModal"
      :to="modalContainerEl"
    >
      <FontModal
        :field="multiSelectField"
        :area="contextMenu.area"
        :editable="editable"
        :build-default-name="buildDefaultName"
        @save="handleSaveMultiSelectFontModal"
        @close="closeModal"
      />
    </Teleport>
    <Teleport
      v-if="isShowConditionsModal"
      :to="modalContainerEl"
    >
      <ConditionsModal
        :item="multiSelectField"
        :build-default-name="buildDefaultName"
        :exclude-field-uuids="selectedFields.map(f => f.uuid)"
        @save="handleSaveMultiSelectConditionsModal"
        @close="closeModal"
      />
    </Teleport>
  </div>
</template>

<script>
import { v4 } from 'uuid'
import { IconListCheck, IconCopy, IconTrashX, IconTypography, IconRouteAltLeft, IconLayoutAlignLeft, IconLayoutAlignRight, IconLayoutAlignTop, IconLayoutAlignBottom, IconLayoutAlignMiddle, IconAspectRatio, IconArrowsHorizontal, IconArrowsVertical } from '@tabler/icons-vue'
import FontModal from './font_modal'
import ConditionsModal from './conditions_modal'
import ContextSubmenu from './field_context_submenu'
import Field from './field'
import FieldType from './field_type'

export default {
  name: 'SelectionContextMenu',
  components: {
    IconListCheck,
    IconCopy,
    IconTrashX,
    IconTypography,
    IconRouteAltLeft,
    IconLayoutAlignLeft,
    IconLayoutAlignRight,
    IconLayoutAlignTop,
    IconLayoutAlignBottom,
    FontModal,
    IconArrowsHorizontal,
    IconArrowsVertical,
    ConditionsModal,
    ContextSubmenu
  },
  inject: ['t', 'save', 'selectedAreasRef', 'getFieldTypeIndex'],
  props: {
    contextMenu: {
      type: Object,
      required: true
    },
    editable: {
      type: Boolean,
      default: true
    },
    template: {
      type: Object,
      required: true
    },
    withCondition: {
      type: Boolean,
      default: true
    }
  },
  emits: ['copy', 'delete', 'close'],
  data () {
    return {
      isShowFontModal: false,
      isShowConditionsModal: false,
      multiSelectField: null
    }
  },
  computed: {
    modalContainerEl () {
      return this.$el.getRootNode().querySelector('#docuseal_modal_container')
    },
    selectedFields () {
      return this.selectedAreasRef.value.map((area) => {
        return this.template.fields.find((f) => f.areas?.includes(area))
      }).filter(Boolean)
    },
    uniqueSelectedFields () {
      const uniqueFields = []
      const uuids = new Set()
      this.selectedFields.forEach(f => {
        if (!uuids.has(f.uuid)) {
          uuids.add(f.uuid)
          uniqueFields.push(f)
        }
      })
      return uniqueFields
    },
    canGroupCheckboxes () {
      if (this.uniqueSelectedFields.length < 2) return false
      if (this.uniqueSelectedFields.some(f => f.type !== 'checkbox')) return false
      if (this.uniqueSelectedFields.some(f => !f.areas || f.areas.length !== 1)) return false
      const submitterUuid = this.uniqueSelectedFields[0].submitter_uuid
      if (this.uniqueSelectedFields.some(f => f.submitter_uuid !== submitterUuid)) return false
      return true
    },
    requiredFields () {
      return this.selectedFields.filter((f) => !['phone', 'stamp', 'verification', 'strikethrough', 'heading'].includes(f.type))
    },
    readOnlyFields () {
      return this.selectedFields.filter((f) => ['text', 'number', 'radio', 'multiple', 'select'].includes(f.type))
    },
    isAllRequired () {
      return this.requiredFields.every((f) => f.required)
    },
    isMixedRequired () {
      return !this.isAllRequired && this.requiredFields.some((f) => f.required)
    },
    isAllReadOnly () {
      return this.readOnlyFields.every((f) => f.readonly)
    },
    isMixedReadOnly () {
      return !this.isAllReadOnly && this.readOnlyFields.some((f) => f.readonly)
    },
    isMac () {
      return (navigator.userAgentData?.platform || navigator.platform)?.toLowerCase()?.includes('mac')
    },
    menuStyle () {
      return {
        left: this.contextMenu.x + 'px',
        top: this.contextMenu.y + 'px'
      }
    },
    showFont () {
      return true
    },
    showCondition () {
      return this.withCondition
    },
    fieldNames: FieldType.computed.fieldNames,
    fieldLabels: FieldType.computed.fieldLabels
  },
  mounted () {
    document.addEventListener('keydown', this.onKeyDown)
    document.addEventListener('mousedown', this.handleClickOutside)

    this.$nextTick(() => this.checkMenuPosition())
  },
  beforeUnmount () {
    document.removeEventListener('keydown', this.onKeyDown)
    document.removeEventListener('mousedown', this.handleClickOutside)
  },
  methods: {
    IconLayoutAlignMiddle,
    IconAspectRatio,
    buildDefaultName: Field.methods.buildDefaultName,
    checkMenuPosition () {
      if (this.$refs.menu) {
        const rect = this.$refs.menu.getBoundingClientRect()
        const overflow = rect.bottom - window.innerHeight

        if (overflow > 0) {
          this.contextMenu.y = this.contextMenu.y - overflow - 4
        }
      }
    },
    handleToggleRequired (value) {
      this.requiredFields.forEach((field) => { field.required = value })

      this.save()
    },
    handleToggleReadOnly (value) {
      this.readOnlyFields.forEach((field) => { field.readonly = value })

      this.save()
    },
    onKeyDown (event) {
      if (event.key === 'Escape') {
        event.preventDefault()
        event.stopPropagation()

        this.$emit('close')
      }
    },
    handleClickOutside (event) {
      if (this.$refs.menu && !this.$refs.menu.contains(event.target)) {
        this.$emit('close')
      }
    },
    openFontModal () {
      this.multiSelectField = {
        name: this.t('fields_selected').replace('{count}', this.selectedFields.length),
        preferences: {}
      }

      const preferencesStrings = this.selectedFields.map((f) => JSON.stringify(f.preferences || {}))

      if (preferencesStrings.every((s) => s === preferencesStrings[0])) {
        this.multiSelectField.preferences = JSON.parse(preferencesStrings[0])
      }

      this.isShowFontModal = true
    },
    openConditionModal () {
      this.multiSelectField = {
        name: this.t('fields_selected').replace('{count}', this.selectedFields.length),
        conditions: []
      }

      const conditionStrings = this.selectedFields.map((f) => JSON.stringify(f.conditions || []))

      if (conditionStrings.every((s) => s === conditionStrings[0])) {
        this.multiSelectField.conditions = JSON.parse(conditionStrings[0])
      }

      this.isShowConditionsModal = true
    },
    closeModal () {
      this.isShowFontModal = false
      this.isShowConditionsModal = false
      this.multiSelectField = null

      this.$emit('close')
    },
    alignSelectedAreas (direction) {
      const areas = this.selectedAreasRef.value

      let targetValue

      if (direction === 'left') {
        targetValue = Math.min(...areas.map(a => a.x))
        areas.forEach((area) => { area.x = targetValue })
      } else if (direction === 'right') {
        targetValue = Math.max(...areas.map(a => a.x + a.w))
        areas.forEach((area) => { area.x = targetValue - area.w })
      } else if (direction === 'top') {
        targetValue = Math.min(...areas.map(a => a.y))
        areas.forEach((area) => { area.y = targetValue })
      } else if (direction === 'bottom') {
        targetValue = Math.max(...areas.map(a => a.y + a.h))
        areas.forEach((area) => { area.y = targetValue - area.h })
      }

      this.save()

      this.$emit('close')
    },
    resizeSelectedAreas (dimension) {
      const areas = this.selectedAreasRef.value

      const values = areas.map(a => dimension === 'width' ? a.w : a.h).sort((a, b) => a - b)
      const medianValue = values[Math.floor(values.length / 2)]

      if (dimension === 'width') {
        areas.forEach((area) => { area.w = medianValue })
      } else if (dimension === 'height') {
        areas.forEach((area) => {
          const diff = medianValue - area.h
          area.y = area.y - diff
          area.h = medianValue
        })
      }

      this.save()

      this.$emit('close')
    },
    handleSaveMultiSelectFontModal () {
      this.selectedFields.forEach((field) => {
        field.preferences = { ...field.preferences, ...this.multiSelectField.preferences }
      })

      this.save()

      this.closeModal()
    },
    handleSaveMultiSelectConditionsModal () {
      this.selectedFields.forEach((field) => {
        field.conditions = JSON.parse(JSON.stringify(this.multiSelectField.conditions))
      })

      this.save()

      this.closeModal()
    },
    handleGroupCheckboxes () {
      if (!this.canGroupCheckboxes) return

      const fieldUuids = this.uniqueSelectedFields.map(f => f.uuid)

      let hasCondition = false
      if (this.uniqueSelectedFields.some(f => f.conditions && f.conditions.length > 0)) {
        hasCondition = true
      }

      if (!hasCondition) {
        hasCondition = this.template.fields.some(f =>
          f.conditions && f.conditions.some(c => fieldUuids.includes(c.field_uuid))
        )
      }

      if (!hasCondition && this.template.schema) {
        hasCondition = this.template.schema.some(item =>
          item.conditions && item.conditions.some(c => fieldUuids.includes(c.field_uuid))
        )
      }

      if (!hasCondition) {
        hasCondition = this.template.fields.some(f => {
          const formula = f.preferences?.formula
          if (!formula) return false

          return [...formula.matchAll(/{{(.*?)}}/g)]
            .some(([, uuid]) => fieldUuids.includes(uuid))
        })
      }

      if (hasCondition) {
        alert(this.t('checkbox_group_conditions_warning'))
        return
      }

      const commonSubmitterUuid = this.uniqueSelectedFields[0].submitter_uuid

      const attachmentOrder = (this.template.schema || []).reduce((acc, item, index) => {
        acc[item.attachment_uuid] = index
        return acc
      }, {})

      const sortedFields = [...this.uniqueSelectedFields].sort((fA, fB) => {
        const a = fA.areas[0] || {}
        const b = fB.areas[0] || {}

        const idxA = attachmentOrder[a.attachment_uuid] ?? Number.MAX_SAFE_INTEGER
        const idxB = attachmentOrder[b.attachment_uuid] ?? Number.MAX_SAFE_INTEGER

        if (idxA !== idxB) return idxA - idxB
        if (a.page !== b.page) return (a.page || 0) - (b.page || 0)
        if (Math.abs((a.y || 0) - (b.y || 0)) > 0.01) return (a.y || 0) - (b.y || 0)
        return (a.x || 0) - (b.x || 0)
      })

      const newField = {
        uuid: v4(),
        type: 'multiple',
        name: '',
        submitter_uuid: commonSubmitterUuid,
        required: false,
        options: [],
        areas: []
      }

      sortedFields.forEach(f => {
        const option = {
          uuid: v4(),
          value: f.name && f.name !== this.buildDefaultName(f) ? f.name : ''
        }
        newField.options.push(option)

        f.areas.forEach(a => {
          const newArea = { ...a, option_uuid: option.uuid }
          newField.areas.push(newArea)
        })
      })

      const originalIndices = sortedFields.map(f => this.template.fields.indexOf(f)).filter(i => i > -1)
      const insertIndex = originalIndices.length > 0 ? Math.min(...originalIndices) : this.template.fields.length

      sortedFields.forEach(f => {
        const index = this.template.fields.indexOf(f)
        if (index > -1) {
          this.template.fields.splice(index, 1)
        }
      })

      this.template.fields.splice(insertIndex, 0, newField)

      this.selectedAreasRef.value = newField.areas
      this.save()
      this.$emit('close')
    }
  }
}
</script>
