<template>
  <div
    class="modal modal-open items-start !animate-none overflow-y-auto"
  >
    <div
      class="absolute top-0 bottom-0 right-0 left-0"
      @click.prevent="$emit('close')"
    />
    <div class="modal-box pt-4 pb-6 px-6 mt-20 w-full max-w-xl">
      <div class="flex justify-between items-center border-b pb-2 mb-2 font-medium">
        <span class="modal-title">
          {{ t('condition') }} - {{ (defaultField ? (defaultField.title || item.title || item.name) : item.name) || buildDefaultName(item) }}
        </span>
        <a
          href="#"
          class="text-xl modal-close-button"
          @click.prevent="$emit('close')"
        >&times;</a>
      </div>
      <div>
        <div
          v-if="!withConditions"
          class="bg-base-300 rounded-xl py-2 px-3 text-center"
        >
          <a
            href="https://www.docuseal.com/pricing"
            target="_blank"
            class="link"
          >{{ t('available_in_pro') }}</a>
        </div>
        <form @submit.prevent="validateSaveAndClose">
          <div class="my-4">
            <div
              v-for="(condition, cindex) in conditions"
              :key="cindex"
              class="space-y-4 relative"
            >
              <div
                v-if="cindex > 0"
                class="divider -mb-2 mx-1"
              >
                <button
                  class="btn btn-xs btn-primary w-24"
                  @click.prevent="condition.operation === 'or' ? delete condition.operation : condition.operation = 'or'"
                >
                  {{ condition.operation === 'or' ? t('or') : t('and') }}
                </button>
              </div>
              <div
                v-if="conditions.length > 1"
                class="flex justify-between mx-1"
              >
                <label class="text-sm">
                  {{ t('condition') }} {{ cindex + 1 }}
                </label>
                <a
                  href="#"
                  class="link text-sm"
                  @click.prevent="conditions.splice(cindex, 1)"
                > {{ t('remove') }}</a>
              </div>
              <select
                class="select select-bordered select-sm w-full bg-white h-11 pl-4 text-base font-normal"
                :class="{ 'text-gray-300': !condition.field_uuid }"
                required
                @change="[
                  condition.field_uuid = $event.target.value,
                  delete condition.value,
                  (conditionActions(condition).includes(condition.action) ? '' : condition.action = conditionActions(condition)[0])
                ]"
              >
                <option
                  value=""
                  disabled
                  :selected="!condition.field_uuid"
                >
                  {{ t('select_field_') }}
                </option>
                <option
                  v-for="f in fields"
                  :key="f.uuid"
                  :value="f.uuid"
                  class="text-base-content"
                  :selected="condition.field_uuid === f.uuid"
                >
                  {{ fieldLabel(f) }}
                </option>
              </select>
              <select
                v-model="condition.action"
                class="select select-bordered select-sm w-full h-11 pl-4 text-base font-normal"
                :class="{ 'bg-white': condition.field_uuid, 'bg-base-300': !condition.field_uuid }"
                :required="condition.field_uuid"
              >
                <option
                  v-for="action in conditionActions(condition)"
                  :key="action"
                  :value="action"
                >
                  {{ t(action) }}
                </option>
              </select>

              <div
                v-if="['checked', 'unchecked', 'empty', 'not_empty'].includes(condition.action)"
                class="hidden"
              />
              <template v-else-if="['radio', 'select', 'multiple'].includes(conditionField(condition)?.type)">
                <div
                  v-if="conditionField(condition)?.preferences?.allow_custom_value"
                  class="w-full"
                >
                  <input
                    v-model="condition.value"
                    type="text"
                    :list="'options-' + condition.field_uuid + '-' + cindex"
                    class="input input-bordered input-sm w-full bg-white h-11 pl-4 text-base font-normal"
                    :class="{ 'text-gray-300': !condition.value }"
                    :placeholder="t('select_value_')"
                    required
                  >
                  <datalist :id="'options-' + condition.field_uuid + '-' + cindex">
                    <option
                      v-for="(option, index) in conditionField(condition).options"
                      :key="option.uuid"
                      :value="option.value || `${t('option')} ${index + 1}`"
                    />
                  </datalist>
                </div>
                <select
                  v-else
                  v-model="condition.value"
                  class="select select-bordered select-sm w-full bg-white h-11 pl-4 text-base font-normal"
                  :class="{ 'text-gray-300': !condition.value }"
                  required
                >
                  <option
                    value=""
                    disabled
                    :selected="!condition.value"
                  >
                    {{ t('select_value_') }}
                  </option>
                  <option
                    v-for="(option, index) in conditionField(condition).options"
                    :key="option.uuid"
                    :value="option.uuid"
                    :selected="condition.value === option.uuid"
                    class="text-base-content"
                  >
                    {{ option.value || `${t('option')} ${index + 1}` }}
                  </option>
                </select>
              </template>
              <input
                v-else-if="conditionField(condition)?.type === 'number'"
                v-model="condition.value"
                type="number"
                step="any"
                class="input input-bordered input-sm w-full bg-white h-11 pl-4 text-base font-normal"
                :class="{ 'text-gray-300': !condition.value }"
                :placeholder="t('type_value')"
                required
              >
              <input
                v-else
                v-model="condition.value"
                type="text"
                class="input input-bordered input-sm w-full bg-white h-11 pl-4 text-base font-normal"
                :class="{ 'text-gray-300': !condition.value }"
                :placeholder="t('type_value')"
                required
              >
            </div>
          </div>
          <a
            href="#"
            class="inline float-right link text-right mb-3 px-2"
            @click.prevent="conditions.push({})"
          > + {{ t('add_condition') }}</a>
          <button class="base-button w-full mt-2 modal-save-button">
            {{ t('save') }}
          </button>
        </form>
        <div
          v-if="item.conditions?.[0]?.field_uuid"
          class="text-center w-full mt-4"
        >
          <button
            class="link"
            @click="[conditions = [], delete item.conditions, validateSaveAndClose()]"
          >
            {{ t('remove_condition') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'ConditionModal',
  inject: ['t', 'template', 'withConditions'],
  props: {
    item: {
      type: Object,
      required: true
    },
    defaultField: {
      type: Object,
      required: false,
      default: null
    },
    buildDefaultName: {
      type: Function,
      required: true
    },
    excludeFieldUuids: {
      type: Array,
      required: false,
      default: () => []
    }
  },
  emits: ['close', 'save'],
  data () {
    return {
      conditions: this.item.conditions?.[0] ? JSON.parse(JSON.stringify(this.item.conditions)) : [{}]
    }
  },
  computed: {
    excludeTypes () {
      return ['heading', 'strikethrough']
    },
    fields () {
      if (this.item.submitter_uuid) {
        return this.template.fields.reduce((acc, f) => {
          if (f !== this.item && !this.excludeTypes.includes(f.type) && !this.excludeFieldUuids.includes(f.uuid)) {
            if (!this.hasCycle(f, this.item.uuid)) {
              acc.push(f)
            }
          }

          return acc
        }, [])
      } else {
        return this.template.fields.filter((f) => !this.excludeFieldUuids.includes(f.uuid))
      }
    }
  },
  created () {
    this.item.conditions ||= []
    this.conditions.forEach(c => {
      const field = this.conditionField(c)
      if (field && field.options && field.preferences?.allow_custom_value) {
        const matchedOption = field.options.find(o => o.uuid === c.value)
        if (matchedOption) {
          c.value = matchedOption.value || `${this.t('option')} ${field.options.indexOf(matchedOption) + 1}`
        }
      }
    })
  },
  methods: {
    hasCycle (candidateField, targetUuid) {
      const visited = new Set()
      const queue = [candidateField]

      while (queue.length > 0) {
        const current = queue.shift()
        if (!current || !current.conditions) continue

        for (const condition of current.conditions) {
          if (!condition.field_uuid) continue
          if (condition.field_uuid === targetUuid) return true

          if (!visited.has(condition.field_uuid)) {
            visited.add(condition.field_uuid)
            const nextField = this.template.fields.find(f => f.uuid === condition.field_uuid)
            if (nextField) queue.push(nextField)
          }
        }
      }
      return false
    },
    fieldLabel (f) {
      const name = f.name || this.buildDefaultName(f)
      if (this.template.submitters && this.template.submitters.length > 1) {
        const submitter = this.template.submitters.find(s => s.uuid === f.submitter_uuid)
        if (submitter && submitter.name) {
          return `${submitter.name} — ${name}`
        }
      }
      return name
    },
    conditionField (condition) {
      return this.fields.find((f) => f.uuid === condition.field_uuid)
    },
    conditionActions (condition) {
      return this.fieldActions(this.conditionField(condition))
    },
    fieldActions (field) {
      const actions = []

      if (!field) {
        return actions
      }

      if (field.type === 'checkbox') {
        actions.push('checked', 'unchecked')
      } else if (field.type === 'radio') {
        actions.push('equal', 'not_equal')
      } else if (field.type === 'multiple') {
        actions.push('contains', 'does_not_contain', 'empty', 'not_empty')
      } else if (field.type === 'select') {
        if (field.preferences?.allow_multiple_values) {
          actions.push('contains', 'does_not_contain', 'empty', 'not_empty')
        } else {
          actions.push('equal', 'not_equal', 'empty', 'not_empty')
        }
      } else if (field.type === 'number') {
        actions.push('empty', 'not_empty', 'equal', 'not_equal', 'greater_than', 'greater_than_or_equal', 'less_than', 'less_than_or_equal')
      } else if (['text', 'cells', 'phone'].includes(field.type)) {
        actions.push('empty', 'not_empty', 'equal', 'not_equal', 'contains', 'does_not_contain', 'starts_with', 'ends_with')
      } else if (field.type === 'date') {
        actions.push('empty', 'not_empty', 'equal', 'not_equal')
      } else {
        actions.push('empty', 'not_empty')
      }

      return actions
    },
    validateSaveAndClose () {
      this.conditions.forEach(c => {
        const field = this.conditionField(c)
        if (field && field.options && field.preferences?.allow_custom_value) {
          const matchedOption = field.options.find((o, i) => (o.value || `${this.t('option')} ${i + 1}`) === c.value)
          if (matchedOption) {
            c.value = matchedOption.uuid
          }
        }
      })

      if (this.conditions.find((f) => f.field_uuid)) {
        this.item.conditions = this.conditions
      } else {
        delete this.item.conditions
      }

      this.$emit('save')
      this.$emit('close')
    }
  }
}
</script>
