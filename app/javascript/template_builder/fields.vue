<template>
  <div
    :class="withStickySubmitters ? 'sticky top-0 z-[1]' : ''"
    :style="withStickySubmitters ? { backgroundColor } : {}"
    class="flex items-center gap-1"
  >
    <FieldSubmitter
      :model-value="selectedSubmitter.uuid"
      class="roles-dropdown w-full rounded-lg roles-dropdown"
      :submitters="submitters"
      :menu-style="{ overflow: 'auto', display: 'flex', flexDirection: 'row', maxHeight: 'calc(100vh - 120px)', backgroundColor: ['', null, 'transparent'].includes(backgroundColor) ? 'white' : backgroundColor }"
      :editable="editable && !defaultSubmitters.length"
      @new-submitter="save"
      @remove="removeSubmitter"
      @name-change="save"
      @update:model-value="[$emit('change-submitter', submitters.find((s) => s.uuid === $event)), isShowVariables = false]"
    />
    <button
      v-if="hasDynamicDocuments"
      class="flex-shrink-0 rounded-md border hover:border-content flex items-center justify-center self-stretch"
      :class="isShowVariables ? 'border-base-content bg-base-content text-base-100' : 'border-base-300'"
      style="width: 44px"
      :title="t('variables')"
      @click.prevent="toggleVariables"
    >
      <IconBracketsContain
        :width="22"
        :height="22"
        :stroke-width="1.6"
      />
    </button>
  </div>
  <DynamicVariables
    v-if="isShowVariables"
    :editable="editable"
    class="mt-1"
  />
  <div v-if="editable && !isShowVariables && submitterFields.length >= 2" class="flex items-center justify-end mt-2 mb-1">
    <button v-if="!isOrderMode" class="btn btn-xs btn-outline" @click.prevent="startOrderMode">{{ t('order_fields') }}</button>
    <div v-else class="flex gap-1">
      <button class="btn btn-xs btn-primary" @click.prevent="applyOrderMode">{{ t('apply_order') }}</button>
      <button class="btn btn-xs btn-outline" @click.prevent="resetOrderMode">{{ t('reset_order') }}</button>
      <button class="btn btn-xs btn-ghost" @click.prevent="cancelOrderMode">{{ t('cancel_order') }}</button>
    </div>
  </div>
  <div v-if="isOrderMode" class="text-xs text-base-content/70 mt-1 mb-2 px-1 text-center">
    {{ t('order_fields_help') }}
  </div>
  <div
    v-if="!isShowVariables"
    ref="fields"
    class="fields"
    :class="{ 'mb-1': !withCustomFields || !customFields.length, 'mt-2': !editable || submitterFields.length < 2 }"
    @dragover.prevent="!isOrderMode && onFieldDragover($event)"
    @drop="!isOrderMode && fieldsDragFieldRef.value ? reorderFields() : null"
  >
    <Field
      v-for="field in submitterFields"
      :key="field.uuid"
      :data-uuid="field.uuid"
      :field="field"
      :type-index="getFieldTypeIndex(field)"
      :editable="editable"
      :with-signature-id="withSignatureId"
      :with-prefillable="withPrefillable"
      :default-field="defaultFieldsIndex[field.name]"
      :draggable="editable && !isOrderMode"
      :with-custom-fields="withCustomFields"
      :is-order-mode="isOrderMode"
      :order-number="fieldOrderUuids.indexOf(field.uuid) + 1"
      :class="{
        'border-t-2 border-t-primary': dragOverFieldUuid === field.uuid && dragInsertPosition === 'before',
        'border-b-2 border-b-primary': dragOverFieldUuid === field.uuid && dragInsertPosition === 'after',
        'mb-1.5': true
      }"
      @add-custom-field="addCustomField"
      @dragstart="[fieldsDragFieldRef.value = field, removeDragOverlay($event), setDragPlaceholder($event)]"
      @save="save"
      @dragend="[fieldsDragFieldRef.value = null, dragOverFieldUuid = null, dragInsertPosition = null, $emit('set-drag-placeholder', null)]"
      @dragleave="[dragOverFieldUuid = null, dragInsertPosition = null]"
      @remove="removeField"
      @scroll-to="$emit('scroll-to-area', $event)"
      @set-draw="$emit('set-draw', $event)"
    />
  </div>
  <div
    v-if="editable && withCustomFieldsTab"
    class="tabs w-full mb-1.5 custom-fields-tabs"
  >
    <a
      class="tab tab-bordered w-1/2 border-base-300 custom-fields-tab"
      :class="{ 'tab-active': !showCustomTab }"
      :style="{ '--tab-border': showCustomTab ? '0px' : '0.5px' }"
      @click="setFieldsTab('default')"
    >{{ t('default') }}</a>
    <a
      class="tab tab-bordered w-1/2 border-base-300 custom-fields-tab"
      :class="{ 'tab-active': showCustomTab }"
      :style="{ '--tab-border': showCustomTab ? '0.5px' : '0px' }"
      @click="setFieldsTab('custom')"
    >{{ t('custom') }}</a>
  </div>
  <div v-if="!isShowVariables && submitterDefaultFields.length && editable && (!withCustomFieldsTab || showCustomTab)">
    <hr
      v-if="!withCustomFieldsTab"
      class="mb-1.5"
    >
    <template v-if="isShowFieldSearch">
      <input
        v-model="defaultFieldsSearch"
        :placeholder="t('search_field')"
        class="input input-ghost input-xs px-0 text-base mb-1.5 !outline-0 !rounded bg-transparent w-full"
      >
      <hr class="mb-2">
    </template>
    <div
      class="overflow-auto relative"
      :style="{
        maxHeight: isShowFieldSearch ? '210px' : '',
        minHeight: isShowFieldSearch ? '210px' : ''
      }"
    >
      <div
        v-if="!filteredSubmitterDefaultFields.length && defaultFieldsSearch"
        class="top-0 bottom-0 text-center absolute flex items-center justify-center w-full flex-col"
      >
        <div>
          {{ t('field_not_found') }}
        </div>
        <a
          href="#"
          class="link"
          @click.prevent="defaultFieldsSearch = ''"
        >
          {{ t('clear') }}
        </a>
      </div>
      <template
        v-for="field in filteredSubmitterDefaultFields"
        :key="field.name"
      >
        <div
          :style="{ backgroundColor }"
          draggable="true"
          class="border border-base-300 rounded relative group mb-2 default-field fields-list-item"
          @dragstart="onDragstart($event, field)"
          @dragend="$emit('drag-end')"
        >
          <div class="flex items-center justify-between relative cursor-grab">
            <div class="flex items-center p-1 space-x-1">
              <IconDrag />
              <FieldType
                :model-value="field.type || 'text'"
                :editable="false"
                :button-width="20"
              />
              <span class="block pl-0.5">
                {{ field.title || field.name }}
              </span>
            </div>
            <span
              v-if="defaultRequiredFields.includes(field)"
              :data-tip="t('required')"
              class="text-red-400 text-3xl pr-1.5 tooltip tooltip-left h-8"
            >
              *
            </span>
          </div>
        </div>
      </template>
    </div>
  </div>
  <div
    v-if="!isShowVariables && editable && withCustomFields && (customFields.length || newCustomField)"
    class="tabs w-full mb-1.5"
  >
    <a
      class="tab tab-bordered w-1/2 border-base-300"
      :class="{ 'tab-active': !showCustomTab }"
      :style="{ '--tab-border': showCustomTab ? '0px' : '0.5px' }"
      @click="setFieldsTab('default')"
    >{{ t('default') }}</a>
    <a
      class="tab tab-bordered w-1/2 border-base-300"
      :class="{ 'tab-active': showCustomTab }"
      :style="{ '--tab-border': showCustomTab ? '0.5px' : '0px' }"
      @click="setFieldsTab('custom')"
    >{{ t('custom') }}</a>
  </div>
  <div
    v-if="!isShowVariables && showCustomTab && editable && (customFields.length || newCustomField)"
    ref="customFields"
    class="custom-fields"
    @dragover.prevent="onCustomFieldDragover"
    @drop="customDragFieldRef.value ? reorderCustomFields() : null"
  >
    <template v-if="isShowCustomFieldSearch">
      <input
        v-model="customFieldsSearch"
        :placeholder="t('search_field')"
        class="input input-ghost input-xs px-0 text-base mb-1 !outline-0 !rounded bg-transparent w-full"
      >
      <hr class="mb-2">
    </template>
    <div
      ref="customFieldsList"
      class="overflow-auto relative"
      :style="{
        maxHeight: isShowCustomFieldSearch ? '320px' : '',
        minHeight: '320px'
      }"
    >
      <div
        v-if="!filteredCustomFields.length && customFieldsSearch"
        class="top-0 bottom-0 text-center absolute flex items-center justify-center w-full flex-col"
      >
        <div>
          {{ t('field_not_found') }}
        </div>
        <a
          href="#"
          class="link"
          @click.prevent="customFieldsSearch = ''"
        >
          {{ t('clear') }}
        </a>
      </div>
      <CustomField
        v-if="newCustomField"
        :key="newCustomField.uuid"
        ref="newCustomField"
        :data-uuid="newCustomField.uuid"
        :is-new="true"
        :field="newCustomField"
        :draggable="false"
        class="mb-1.5"
        @save="onNewCustomFieldSave"
        @remove="newCustomField = null"
      />
      <CustomField
        v-for="field in filteredCustomFields"
        :key="field.uuid"
        :data-uuid="field.uuid"
        :field="field"
        :draggable="true"
        class="mb-1.5"
        :with-signature-id="withSignatureId"
        :with-prefillable="withPrefillable"
        @save="saveCustomFields"
        @click="$emit('set-draw-custom-field', field)"
        @dragstart="[customDragFieldRef.value = field, removeDragOverlay($event), setDragPlaceholder($event)]"
        @dragend="[customDragFieldRef.value = null, $emit('set-drag-placeholder', null)]"
        @remove="removeCustomField"
        @set-draw="$emit('set-draw', $event)"
      />
    </div>
  </div>
  <div
    v-if="!isShowVariables && editable && !onlyDefinedFields && (!showCustomTab || (!customFields.length && !newCustomField)) && (!withCustomFieldsTab || !showCustomTab)"
    id="field-types-grid"
    class="grid grid-cols-3 gap-1 pb-2 fields-grid"
  >
    <template
      v-for="(icon, type) in fieldIconsSorted"
      :key="type"
    >
      <button
        v-if="fieldTypes.includes(type) || ((withPhone || type != 'phone') && (withPayment || type != 'payment') && (withVerification || type != 'verification') && (withKba || type != 'kba'))"
        :id="`${type}_type_field_button`"
        draggable="true"
        class="field-type-button group flex items-center justify-center border border-dashed w-full rounded relative fields-grid-item"
        :style="{ backgroundColor }"
        :class="drawFieldType === type ? 'border-base-content/40' : 'border-base-300 hover:border-base-content/20'"
        @dragstart="onDragstart($event, { type: type })"
        @dragend="$emit('drag-end')"
        @click="['file', 'payment', 'verification', 'kba'].includes(type) ? $emit('add-field', type) : $emit('set-draw-type', type)"
      >
        <div
          class="flex items-console transition-all cursor-grab h-full absolute left-0"
          :class="drawFieldType === type ? 'bg-base-200/50' : 'group-hover:bg-base-200/50'"
        >
          <IconDrag class="my-auto" />
        </div>
        <div class="flex items-center flex-col px-2 py-2">
          <component :is="icon" />
          <span class="text-xs mt-1">
            {{ fieldNames[type] }}
          </span>
        </div>
      </button>
      <div
        v-else-if="type == 'phone' && (fieldTypes.length === 0 || fieldTypes.includes(type))"
        class="tooltip tooltip-bottom flex"
        :class="{'tooltip-bottom-end': withPayment, 'tooltip-bottom': !withPayment }"
        :data-tip="t('unlock_sms_verified_phone_number_field_with_paid_plan_use_text_field_for_phone_numbers_without_verification')"
      >
        <a
          href="https://www.docuseal.com/pricing"
          target="_blank"
          class="opacity-50 flex items-center justify-center border border-dashed border-base-300 w-full rounded relative fields-grid-item"
          :style="{ backgroundColor }"
        >
          <div class="w-0 absolute left-0">
            <IconLock
              width="18"
              height="18"
              stroke-width="1.5"
            />
          </div>
          <div class="flex items-center flex-col px-2 py-2">
            <component :is="icon" />
            <span class="text-xs mt-1">
              {{ fieldNames[type] }}
            </span>
          </div>
        </a>
      </div>
      <div
        v-else-if="withVerification === false && type == 'verification' && (fieldTypes.length === 0 || fieldTypes.includes(type))"
        class="tooltip tooltip-bottom flex tooltip-bottom-start"
        :data-tip="t('obtain_qualified_electronic_signature_with_the_trusted_provider_click_to_learn_more')"
      >
        <a
          href="https://www.docuseal.com/qualified-electronic-signature"
          target="_blank"
          class="opacity-50 flex items-center justify-center border border-dashed border-base-300 w-full rounded relative fields-grid-item"
          :style="{ backgroundColor }"
        >
          <div class="w-0 absolute left-0">
            <IconLock
              width="18"
              height="18"
              stroke-width="1.5"
            />
          </div>
          <div class="flex items-center flex-col px-2 py-2">
            <component :is="icon" />
            <span class="text-xs mt-1">
              {{ fieldNames[type] }}
            </span>
          </div>
        </a>
      </div>
    </template>
  </div>
  <div
    v-if="!isShowVariables && fields.length < 4 && editable && withHelp && !showTourStartForm"
    class="text-xs p-2 border border-base-200 rounded"
  >
    <ul class="list-disc list-outside ml-3">
      <li>
        {{ t('draw_a_text_field_on_the_page_with_a_mouse') }}
      </li>
      <li>
        {{ t('drag_and_drop_any_other_field_type_on_the_page') }}
      </li>
      <li>
        {{ t('click_on_the_field_type_above_to_start_drawing_it') }}
      </li>
    </ul>
  </div>
  <div
    v-if="!isShowVariables && withFieldsDetection && editable && !template.schema.some((item) => item.dynamic)"
    class="my-2"
  >
    <button
      v-if="fields.length < 2"
      class="btn w-full"
      :class="{ 'bg-base-300': fieldPagesLoaded !== null }"
      @click="fieldPagesLoaded !== null ? null : detectFields()"
    >
      <template v-if="fieldPagesLoaded !== null">
        <IconInnerShadowTop
          width="22"
          class="animate-spin"
        />
        <span
          v-if="analyzingProgress"
          class="hidden md:inline"
        >
          {{ Math.round(analyzingProgress * 100) }}% {{ t('analyzing_') }}
        </span>
        <span
          v-else
          class="hidden md:inline"
        >
          {{ fieldPagesLoaded }} / {{ numberOfPages }} {{ t('processing_') }}
        </span>
      </template>
      <template v-else>
        <IconSparkles width="22" />
        <span
          class="hidden md:inline"
        >
          {{ t('autodetect_fields') }}
        </span>
      </template>
    </button>
    <div v-else class="flex flex-col gap-1.5 mt-4">
      <button
        class="btn btn-sm w-full font-normal"
        :class="{ 'bg-base-300': fieldPagesLoaded !== null }"
        @click="fieldPagesLoaded !== null ? null : rerunAutodetect()"
      >
        <template v-if="fieldPagesLoaded !== null">
          <IconInnerShadowTop
            width="16"
            class="animate-spin"
          />
          <span v-if="analyzingProgress">
            {{ Math.round(analyzingProgress * 100) }}% {{ t('analyzing_') }}
          </span>
          <span v-else>
            {{ fieldPagesLoaded }} / {{ numberOfPages }} {{ t('processing_') }}
          </span>
        </template>
        <template v-else>
          <IconSparkles width="16" />
          <span>{{ t('re_run_autodetect') }}</span>
        </template>
      </button>
      <button
        class="btn btn-sm w-full font-normal text-error hover:bg-error hover:text-white"
        :disabled="fieldPagesLoaded !== null"
        @click="promptDeleteAllFields"
      >
        <span>{{ t('delete_all_fields') }}</span>
      </button>
    </div>
  </div>
  <div
    v-show="!isShowVariables && fields.length < 4 && editable && withHelp && showTourStartForm"
    class="rounded py-2 px-4 w-full border border-dashed border-base-300"
  >
    <div class="text-center text-sm">
      {{ t('start_a_quick_tour_to_learn_how_to_create_and_send_your_first_document') }}
    </div>
    <div class="flex justify-center">
      <label
        for="start_tour_button"
        class="btn btn-sm btn-warning w-40 mt-2"
        @click="startTour"
      >
        {{ t('start_tour') }}
      </label>
    </div>
  </div>
</template>

<script>
import Field from './field'
import CustomField from './custom_field'
import FieldType from './field_type'
import FieldSubmitter from './field_submitter'
import { defineAsyncComponent } from 'vue'
import { IconLock, IconCirclePlus, IconInnerShadowTop, IconSparkles, IconBracketsContain } from '@tabler/icons-vue'
import IconDrag from './icon_drag'
import { v4 } from 'uuid'

export default {
  name: 'TemplateFields',
  components: {
    Field,
    CustomField,
    FieldType,
    IconCirclePlus,
    IconSparkles,
    IconInnerShadowTop,
    FieldSubmitter,
    IconDrag,
    IconLock,
    IconBracketsContain,
    DynamicVariables: defineAsyncComponent(() => import(/* webpackChunkName: "dynamic-editor" */ './dynamic_variables'))
  },
  inject: ['save', 'backgroundColor', 'withPhone', 'withVerification', 'withKba', 'withPayment', 't', 'fieldsDragFieldRef', 'customDragFieldRef', 'baseFetch', 'selectedAreasRef', 'getFieldTypeIndex', 'fieldOrderStateRef'],
  props: {
    fields: {
      type: Array,
      required: true
    },
    customFields: {
      type: Array,
      required: false,
      default: () => []
    },
    withCustomFields: {
      type: Boolean,
      required: false,
      default: false
    },
    withCustomFieldsTab: {
      type: Boolean,
      required: false,
      default: false
    },
    withFieldsSearch: {
      type: Boolean,
      required: false,
      default: null
    },
    withFieldsDetection: {
      type: Boolean,
      required: false,
      default: false
    },
    withDetectExistingFields: {
      type: Boolean,
      required: false,
      default: false
    },
    withSignatureId: {
      type: Boolean,
      required: false,
      default: null
    },
    withPrefillable: {
      type: Boolean,
      required: false,
      default: false
    },
    template: {
      type: Object,
      required: true
    },
    withHelp: {
      type: Boolean,
      required: false,
      default: true
    },
    editable: {
      type: Boolean,
      required: false,
      default: true
    },
    defaultFields: {
      type: Array,
      required: false,
      default: () => []
    },
    defaultRequiredFields: {
      type: Array,
      required: false,
      default: () => []
    },
    onlyDefinedFields: {
      type: Boolean,
      required: false,
      default: true
    },
    drawFieldType: {
      type: String,
      required: false,
      default: ''
    },
    defaultSubmitters: {
      type: Array,
      required: false,
      default: () => []
    },
    withStickySubmitters: {
      type: Boolean,
      required: false,
      default: true
    },
    fieldTypes: {
      type: Array,
      required: false,
      default: () => []
    },
    submitters: {
      type: Array,
      required: true
    },
    selectedSubmitter: {
      type: Object,
      required: true
    },
    detectCustomFieldsIndex: {
      type: Object,
      required: false,
      default: () => ({})
    },
    showTourStartForm: {
      type: Boolean,
      required: false,
      default: false
    }
  },
  emits: ['add-field', 'set-draw', 'set-draw-type', 'set-draw-custom-field', 'set-drag', 'drag-end', 'scroll-to-area', 'change-submitter', 'set-drag-placeholder', 'select-submitter', 'rebuild-variables-schema', 'remove-field', 'remove-submitter'],
  data () {
    return {
      fieldPagesLoaded: null,
      analyzingProgress: 0,
      newCustomField: null,
      showCustomTab: false,
      defaultFieldsSearch: '',
      customFieldsSearch: '',
      isShowVariables: false,
      dragOverFieldUuid: null,
      dragInsertPosition: null
    }
  },
  computed: {
    isOrderMode () {
      return this.fieldOrderStateRef.value.active && this.fieldOrderStateRef.value.submitterUuid === this.selectedSubmitter.uuid
    },
    fieldOrderUuids () {
      return this.fieldOrderStateRef.value.fieldUuids
    },
    fieldNames: FieldType.computed.fieldNames,
    fieldIcons: FieldType.computed.fieldIcons,
    hasDynamicDocuments () {
      return this.template.schema.some((item) => item.dynamic)
    },
    numberOfPages () {
      return this.template.documents.reduce((acc, doc) => {
        return acc + doc.metadata?.pdf?.number_of_pages || doc.preview_images.length
      }, 0)
    },
    isShowFieldSearch () {
      if (this.withFieldsSearch === false) {
        return false
      } else {
        return this.submitterDefaultFields.length > 15
      }
    },
    defaultFieldsIndex () {
      return this.defaultFields.reduce((acc, field) => {
        acc[field.name] = field

        return acc
      }, {})
    },
    skipTypes () {
      return ['heading', 'datenow', 'strikethrough']
    },
    fieldIconsSorted () {
      if (this.fieldTypes.length) {
        return this.fieldTypes.reduce((acc, type) => {
          acc[type] = this.fieldIcons[type]

          return acc
        }, {})
      } else {
        return Object.fromEntries(Object.entries(this.fieldIcons).filter(([key]) => !this.skipTypes.includes(key)))
      }
    },
    submitterFields () {
      return this.fields.filter((f) => f.submitter_uuid === this.selectedSubmitter.uuid)
    },
    submitterDefaultFields () {
      return this.defaultFields.filter((f) => {
        return (this.withCustomFieldsTab ? true : !this.submitterFields.find((field) => field.name === f.name)) &&
          (!f.role || f.role === this.selectedSubmitter.name)
      })
    },
    filteredSubmitterDefaultFields () {
      if (this.defaultFieldsSearch) {
        return this.submitterDefaultFields.filter((f) => (f.title || f.name).toLowerCase().includes(this.defaultFieldsSearch.toLowerCase()))
      } else {
        return this.submitterDefaultFields
      }
    },
    isShowCustomFieldSearch () {
      return this.customFields.length > 8
    },
    filteredCustomFields () {
      if (this.customFieldsSearch) {
        return this.customFields.filter((f) => f.name.toLowerCase().includes(this.customFieldsSearch.toLowerCase()))
      } else {
        return this.customFields
      }
    }
  },
  watch: {
    'selectedAreasRef.value': {
      handler (areas) {
        if (!areas || areas.length !== 1) return

        const area = areas[0]
        const field = this.fields.find(f => f.areas?.includes(area))

        if (!field) return

        if (this.selectedSubmitter.uuid !== field.submitter_uuid) {
          const submitter = this.submitters.find(s => s.uuid === field.submitter_uuid)
          if (submitter) {
            this.$emit('select-submitter', submitter)
          }
        }

        if (this.isShowVariables) {
          this.isShowVariables = false
        }

        this.$nextTick(() => {
          const el = this.$refs.fields?.querySelector(`[data-uuid="${field.uuid}"]`)
          if (el) {
            el.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
          }
        })
      },
      deep: true
    }
  },
  mounted () {
    try {
      this.showCustomTab = localStorage.getItem('docuseal_builder_tab') === 'custom'
    } catch (e) {
      console.error(e)
    }
  },
  methods: {
    toggleVariables () {
      this.$emit('rebuild-variables-schema')
      this.isShowVariables = !this.isShowVariables
    },
    onDragstart (event, field) {
      this.removeDragOverlay(event)

      this.setDragPlaceholder(event)

      this.$emit('set-drag', field)
    },
    onNewCustomFieldSave () {
      if (this.newCustomField.name) {
        this.customFields.unshift(this.newCustomField)
        this.newCustomField = null

        this.saveCustomFields()
      } else {
        this.newCustomField = null
      }
    },
    addCustomField (field) {
      const customField = JSON.parse(JSON.stringify(field))

      customField.uuid = v4()

      delete customField.submitter_uuid
      delete customField.prefillable
      delete customField.conditions

      if (Array.isArray(customField.areas)) {
        customField.areas = customField.areas.filter((area) => area.page !== null && area.page !== undefined)
      }

      customField.areas?.forEach((area) => {
        delete area.attachment_uuid
        delete area.page
      })

      if (customField.name) {
        this.customFields.unshift(customField)
        this.saveCustomFields()
      } else {
        this.newCustomField = customField
      }

      this.setFieldsTab('custom')
    },
    setFieldsTab (type) {
      try {
        localStorage.setItem('docuseal_builder_tab', type)
      } catch (e) {
        console.error(e)
      }

      this.showCustomTab = type === 'custom'
    },
    saveCustomFields () {
      return this.baseFetch('/account_custom_fields', {
        method: 'POST',
        body: JSON.stringify({
          value: this.customFields
        }),
        headers: { 'Content-Type': 'application/json' }
      }).then(async (resp) => {
        const fields = await resp.json()

        this.customFields.splice(0, this.customFields.length, ...fields)
      })
    },
    buildExistingFields () {
      const existing = []
      const seen = new Set()

      const submittersByUuid = this.template.submitters.reduce((acc, s) => {
        acc[s.uuid] = s

        return acc
      }, {})

      const add = (field, role) => {
        if (!field?.name) return

        const key = field.name.toLowerCase() + ':' + (role || '').toLowerCase()

        if (seen.has(key)) return

        seen.add(key)

        const item = { name: field.name, type: field.type || 'text' }

        if (role) item.role = role

        const optionValues = Array.isArray(field.options)
          ? field.options.map((o) => (typeof o === 'string' ? o : o?.value)).filter(Boolean)
          : []

        if (optionValues.length) item.options = optionValues

        existing.push(item)
      }

      this.template.fields.forEach((f) => add(f, submittersByUuid[f.submitter_uuid]?.name))
      this.defaultRequiredFields.forEach((f) => add(f, f.role))
      this.defaultFields.forEach((f) => add(f, f.role))
      this.customFields.forEach((f) => add(f, f.role))

      return existing
    },
    enrichDetectedField (field) {
      if (!this.withDetectExistingFields || !field.name) return field

      const role = this.template.submitters.find((s) => s.uuid === field.submitter_uuid)?.name
      const nameKey = field.name.toLowerCase()
      const indexKey = [field.name, role].filter(Boolean).join(':').toLowerCase()

      const customField = this.detectCustomFieldsIndex[indexKey] || this.detectCustomFieldsIndex[nameKey]

      if (customField) this.applyCustomFieldAttributes(field, customField)

      return field
    },
    applyCustomFieldAttributes (field, customField) {
      const skipKeys = new Set(['uuid', 'areas', 'submitter_uuid', 'conditions', 'prefillable', 'role'])

      Object.entries(customField).forEach(([key, value]) => {
        if (skipKeys.has(key)) return
        if (value === null || value === undefined) return

        if (key === 'options') {
          if (Array.isArray(value) && !Array.isArray(field.options)) {
            field.options = value.map((o) => (
              typeof o === 'string' ? { value: o, uuid: v4() } : { ...o, uuid: v4() }
            ))
          }
        } else if (value && typeof value === 'object' && !Array.isArray(value)) {
          field[key] = JSON.parse(JSON.stringify(value))
        } else {
          field[key] = value
        }
      })
    },
    promptDeleteAllFields () {
      if (confirm(this.t('delete_all_fields_confirmation'))) {
        this.performRemoveAllFields({ save: true })
      }
    },
    performRemoveAllFields ({ save = true } = {}) {
      [...this.fields].forEach((field) => {
        this.removeField(field, false)
      })
      this.selectedAreasRef.value = []
      if (save) this.save()
    },
    rerunAutodetect () {
      if (confirm(this.t('re_run_autodetect_confirmation'))) {
        this.detectFields({ fresh: true })
      }
    },
    calculateIoU (area1, area2) {
      const x1 = Math.max(area1.x, area2.x)
      const y1 = Math.max(area1.y, area2.y)
      const x2 = Math.min(area1.x + area1.w, area2.x + area2.w)
      const y2 = Math.min(area1.y + area1.h, area2.y + area2.h)

      const intersectionArea = Math.max(0, x2 - x1) * Math.max(0, y2 - y1)
      const area1Size = area1.w * area1.h
      const area2Size = area2.w * area2.h
      const unionArea = area1Size + area2Size - intersectionArea

      return unionArea > 0 ? intersectionArea / unionArea : 0
    },
    reconcileDetectedFields (detectedFields, detectedSubmitters) {
      const oldFields = this.fields
      const unmatchedDetectedAreas = []

      detectedFields.forEach((df) => {
        (df.areas || []).forEach((da) => {
          unmatchedDetectedAreas.push({
            field: df,
            area: da,
            consumed: false
          })
        })
      })

      oldFields.forEach((oldField) => {
        (oldField.areas || []).forEach((oldArea) => {
          let bestMatch = null
          let bestIoU = 0

          unmatchedDetectedAreas.forEach((uda) => {
            if (uda.consumed) return
            if (uda.area.attachment_uuid !== oldArea.attachment_uuid) return
            if (uda.area.page !== oldArea.page) return

            const iou = this.calculateIoU(oldArea, uda.area)
            if (iou >= 0.1 && iou > bestIoU) {
              bestMatch = uda
              bestIoU = iou
            }
          })

          if (bestMatch) {
            oldArea.x = bestMatch.area.x
            oldArea.y = bestMatch.area.y
            oldArea.w = bestMatch.area.w
            oldArea.h = bestMatch.area.h
            bestMatch.consumed = true
          }
        })
      })

      const newFieldsToAdd = []
      detectedFields.forEach((df) => {
        const remainingAreas = unmatchedDetectedAreas
          .filter((uda) => uda.field === df && !uda.consumed)
          .map((uda) => uda.area)

        if (remainingAreas.length > 0) {
          const newField = JSON.parse(JSON.stringify(df))
          newField.areas = remainingAreas
          newFieldsToAdd.push(newField)
        }
      })

      if (newFieldsToAdd.length > 0) {
        const submittersMap = {}
        if (detectedSubmitters) {
          detectedSubmitters.forEach(ds => {
            const existing = this.template.submitters.find(s => s.name?.toLowerCase() === ds.name?.toLowerCase())
            if (existing) {
              submittersMap[ds.uuid] = existing.uuid
            } else {
              submittersMap[ds.uuid] = this.selectedSubmitter?.uuid || this.template.submitters[0]?.uuid
            }
          })
        }

        newFieldsToAdd.forEach(f => {
          if (submittersMap[f.submitter_uuid]) {
            f.submitter_uuid = submittersMap[f.submitter_uuid]
          } else if (!f.submitter_uuid) {
            f.submitter_uuid = this.selectedSubmitter?.uuid || this.template.submitters[0]?.uuid
          }
        })

        const enrichedNewFields = newFieldsToAdd.map((f) => this.enrichDetectedField(f))
        this.template.fields.push(...enrichedNewFields)
      }

      this.selectedAreasRef.value = []
      this.save()
    },
    detectFields ({ fresh = false } = {}) {
      const fields = []

      this.fieldPagesLoaded = 0

      this.baseFetch(`/templates/${this.template.id}/detect_fields`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        ...(this.withDetectExistingFields && !fresh
          ? { body: JSON.stringify({ fields: this.buildExistingFields() }) }
          : {})
      }).then(async (response) => {
        const reader = response.body.getReader()
        const decoder = new TextDecoder('utf-8')
        let buffer = ''

        while (true) {
          const { value, done } = await reader.read()

          buffer += decoder.decode(value, { stream: true })

          const lines = buffer.split('\n\n')

          buffer = lines.pop()

          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const jsonStr = line.replace(/^data: /, '')
              const data = JSON.parse(jsonStr)

              if (data.error) {
                if (!fresh) {
                  if ((data.fields || fields).length) {
                    this.template.fields = (data.fields || fields).map((f) => this.enrichDetectedField(f))
                    this.save()
                  } else {
                    alert(data.error)
                  }
                } else {
                  alert(data.error)
                }
                break
              } else if (data.analyzing) {
                this.analyzingProgress = data.progress
              } else if (data.completed) {
                this.fieldPagesLoaded = null

                const detectedFields = data.fields || fields

                if (fresh) {
                  if (detectedFields.length === 0) {
                    alert(this.t('no_fields_detected'))
                    return
                  }

                  this.reconcileDetectedFields(detectedFields, data.submitters)
                } else {
                  if (data.submitters) {
                    this.template.submitters = data.submitters
                    this.$emit('select-submitter', this.template.submitters[0])
                  }

                  this.template.fields = detectedFields.map((f) => this.enrichDetectedField(f))
                  this.save()
                }

                break
              } else if (data.fields) {
                data.fields.forEach((f) => {
                  if (!f.submitter_uuid) {
                    f.submitter_uuid = this.template.submitters[0].uuid
                  }
                })

                this.fieldPagesLoaded += 1

                fields.push(...data.fields)
              }
            }
          }

          if (done) break
        }
      }).catch(error => {
        console.error('Error in streaming message: ', error)
      }).finally(() => {
        this.fieldPagesLoaded = null
        this.analyzingProgress = null
        this.isFieldsLoading = false
      })
    },
    setDragPlaceholder (event) {
      this.$emit('set-drag-placeholder', {
        offsetX: event.offsetX,
        offsetY: event.offsetY,
        x: event.clientX - event.offsetX,
        y: event.clientY - event.offsetY,
        w: event.currentTarget.clientWidth + 2,
        h: event.currentTarget.clientHeight + 2
      })
    },
    removeDragOverlay (event) {
      const root = this.$el.getRootNode()
      const hiddenEl = document.createElement('div')

      hiddenEl.style.width = '1px'
      hiddenEl.style.height = '1px'
      hiddenEl.style.opacity = '0'
      hiddenEl.style.position = 'fixed'

      root.querySelector('#docuseal_modal_container').appendChild(hiddenEl)

      event.dataTransfer.setDragImage(hiddenEl, 0, 0)

      setTimeout(() => { hiddenEl.remove() }, 1000)
    },
    startTour () {
      document.querySelector('app-tour').start()
    },
    onFieldDragover (e) {
      if (this.fieldsDragFieldRef.value) {
        const targetField = e.target.closest('[data-uuid]')

        if (targetField) {
          const targetUuid = targetField.dataset.uuid
          if (targetUuid !== this.fieldsDragFieldRef.value.uuid) {
            const rect = targetField.getBoundingClientRect()
            const midY = rect.top + rect.height / 2
            this.dragOverFieldUuid = targetUuid
            this.dragInsertPosition = e.clientY < midY ? 'before' : 'after'
          } else {
            this.dragOverFieldUuid = null
            this.dragInsertPosition = null
          }
        }
      }
    },
    applySubmitterFieldOrder (orderedFieldUuids) {
      const orderedPartyFields = orderedFieldUuids.map(uuid => this.fields.find(f => f.uuid === uuid)).filter(Boolean)
      let partyIndex = 0

      const reordered = this.fields.map((field) => {
        if (field.submitter_uuid !== this.selectedSubmitter.uuid) return field

        return orderedPartyFields[partyIndex++]
      })

      this.fields.splice(0, this.fields.length, ...reordered)
    },
    reorderFields () {
      if (this.fieldsDragFieldRef.value && this.dragOverFieldUuid) {
        const orderedPartyFields = [...this.submitterFields]
        
        const dragField = this.fieldsDragFieldRef.value
        const targetFieldUuid = this.dragOverFieldUuid
        const position = this.dragInsertPosition
        
        const dragIndex = orderedPartyFields.findIndex(f => f.uuid === dragField.uuid)
        if (dragIndex > -1) {
          orderedPartyFields.splice(dragIndex, 1)
        }
        
        const targetIndex = orderedPartyFields.findIndex(f => f.uuid === targetFieldUuid)
        if (targetIndex > -1) {
          orderedPartyFields.splice(position === 'before' ? targetIndex : targetIndex + 1, 0, dragField)
        }
        
        const orderedFieldUuids = orderedPartyFields.map(f => f.uuid)
        
        this.applySubmitterFieldOrder(orderedFieldUuids)
        this.save()
      }
      
      this.dragOverFieldUuid = null
      this.dragInsertPosition = null
    },
    removeSubmitter (submitter) {
      [...this.fields].forEach((field) => {
        if (field.submitter_uuid === submitter.uuid) {
          this.removeField(field, false)
        }
      })

      this.submitters.splice(this.submitters.indexOf(submitter), 1)

      if (this.selectedSubmitter === submitter) {
        this.$emit('change-submitter', this.submitters[0])
      }

      this.$emit('remove-submitter', submitter)

      this.save()
    },
    startOrderMode () {
      this.fieldOrderStateRef.value.active = true
      this.fieldOrderStateRef.value.submitterUuid = this.selectedSubmitter.uuid
      this.fieldOrderStateRef.value.fieldUuids = []
    },
    applyOrderMode () {
      if (this.fieldOrderStateRef.value.fieldUuids.length > 0) {
        const clickedUuids = this.fieldOrderStateRef.value.fieldUuids
        const unclickedUuids = this.submitterFields.map(f => f.uuid).filter(uuid => !clickedUuids.includes(uuid))
        this.applySubmitterFieldOrder([...clickedUuids, ...unclickedUuids])
        this.save()
      }
      this.cancelOrderMode()
    },
    resetOrderMode () {
      this.fieldOrderStateRef.value.fieldUuids = []
    },
    cancelOrderMode () {
      this.fieldOrderStateRef.value.active = false
      this.fieldOrderStateRef.value.submitterUuid = null
      this.fieldOrderStateRef.value.fieldUuids = []
    },
    removeField (field, save = true) {
      this.fields.splice(this.fields.indexOf(field), 1)

      this.fields.forEach((f) => {
        (f.conditions || []).forEach((c) => {
          if (c.field_uuid === field.uuid) {
            f.conditions.splice(f.conditions.indexOf(c), 1)
          }
        })
      })

      this.template.schema.forEach((item) => {
        (item.conditions || []).forEach((c) => {
          if (c.field_uuid === field.uuid) {
            item.conditions.splice(item.conditions.indexOf(c), 1)
          }
        })
      })

      field.areas?.forEach((area) => {
        this.selectedAreasRef.value.splice(this.selectedAreasRef.value.indexOf(area), 1)
      })

      this.$emit('remove-field', field)

      if (save) {
        this.save()
      }
    },
    removeCustomField (field) {
      this.customFields.splice(this.customFields.indexOf(field), 1)

      if (!this.customFields.length) {
        this.setFieldsTab('default')
      }

      this.saveCustomFields()
    },
    onCustomFieldDragover (e) {
      if (this.customDragFieldRef.value && this.customFields.includes(this.customDragFieldRef.value)) {
        const container = this.$refs.customFieldsList
        const targetField = e.target.closest('[data-uuid]')
        const dragField = container.querySelector(`[data-uuid="${this.customDragFieldRef.value.uuid}"]`)

        if (dragField && targetField && targetField !== dragField) {
          const fields = Array.from(container.children)
          const currentIndex = fields.indexOf(dragField)
          const targetIndex = fields.indexOf(targetField)

          if (currentIndex < targetIndex) {
            targetField.after(dragField)
          } else {
            targetField.before(dragField)
          }
        }
      }
    },
    reorderCustomFields () {
      if (!this.customFields.includes(this.customDragFieldRef.value)) {
        return
      }

      const reorderedFields = Array.from(this.$refs.customFieldsList.children).map((el) => {
        return this.customFields.find((f) => f.uuid === el.dataset.uuid)
      }).filter(Boolean)

      this.customFields.splice(0, this.customFields.length, ...reorderedFields)

      this.saveCustomFields()
    }
  }
}
</script>
