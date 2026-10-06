<template>
  <div class="select-step-container">
    <label
      v-if="showFieldNames && (field.name || field.title)"
      :for="field.uuid"
      dir="auto"
      class="label text-xl sm:text-2xl py-0 mb-2 sm:mb-3.5 field-name-label"
      :class="{ 'mb-2': !field.description }"
    >
      <MarkdownContent
        v-if="field.title"
        :string="field.title"
      />
      <template v-else>
        {{ field.name }}
      </template>
      <template v-if="!field.required">
        <span :class="{ 'hidden sm:inline': (field.title || field.name).length > 20 }">
          ({{ t('optional') }})
        </span>
      </template>
    </label>
    <div
      v-else
      class="py-1"
    />
    <div
      v-if="field.description"
      :id="field.uuid + '-desc'"
      dir="auto"
      class="mb-3 px-1 field-description-text"
    >
      <MarkdownContent :string="field.description" />
    </div>
    <AppearsOn :field="field" />

    <template v-if="!allowMultipleValues && !allowCustomValue">
      <!-- Mode A: Existing Single Select -->
      <select
        :id="field.uuid"
        dir="auto"
        :required="field.required"
        :aria-label="showFieldNames && (field.name || field.title) ? undefined : (field.name || field.title || t('select_your_option'))"
        :aria-describedby="field.description ? field.uuid + '-desc' : undefined"
        class="select base-input !text-2xl w-full text-center font-normal"
        :class="{ 'text-gray-300': !modelValue }"
        :name="`values[${field.uuid}]`"
        :value="normalizedSingleValue"
        @change="[updateValue($event.target.value), $emit('focus')]"
        @focus="$emit('focus')"
      >
        <option
          value=""
          class="text-gray-300"
        >
          {{ t('select_your_option') }}
        </option>
        <option
          v-for="option in predefinedOptions"
          :key="option.uuid"
          :value="option.value"
          class="text-base-content"
        >
          {{ option.value }}
        </option>
      </select>
    </template>

    <template v-else-if="!allowMultipleValues && allowCustomValue">
      <!-- Mode B: Single + Custom -->
      <select
        :id="field.uuid"
        dir="auto"
        :required="field.required && !customInputValue"
        :aria-label="showFieldNames && (field.name || field.title) ? undefined : (field.name || field.title || t('select_your_option'))"
        :aria-describedby="field.description ? field.uuid + '-desc' : undefined"
        class="select base-input !text-2xl w-full text-center font-normal mb-2"
        :class="{ 'text-gray-300': !selectedPredefinedOption }"
        :value="selectedPredefinedOption"
        @change="[onPredefinedOptionChange($event.target.value), $emit('focus')]"
        @focus="$emit('focus')"
      >
        <option
          value=""
          class="text-gray-300"
        >
          {{ t('select_your_option') }}
        </option>
        <option
          v-for="option in predefinedOptions"
          :key="option.uuid"
          :value="option.value"
          class="text-base-content"
        >
          {{ option.value }}
        </option>
      </select>
      <input
        type="hidden"
        :name="`values[${field.uuid}]`"
        :value="normalizedSingleValue"
      >
      <input
        v-model="customInputValue"
        type="text"
        dir="auto"
        :required="field.required && !selectedPredefinedOption"
        :placeholder="t('or_enter_custom_value') || 'Or enter a custom value'"
        class="input base-input !text-2xl w-full text-center font-normal"
        @input="onCustomInputChange"
        @keydown.enter.prevent
        @focus="$emit('focus')"
      >
    </template>

    <template v-else>
      <!-- Mode C and D: Multiple Predefined + (Optional Custom) Combobox -->
      <div
        class="relative w-full text-left"
        @keydown.esc="closeDropdown"
      >
        <input
          v-model="searchQuery"
          type="text"
          dir="auto"
          :aria-label="showFieldNames && (field.name || field.title) ? undefined : (field.name || field.title || t('select_your_options'))"
          :aria-describedby="field.description ? field.uuid + '-desc' : undefined"
          class="input base-input !text-2xl w-full text-center font-normal"
          :placeholder="allowCustomValue ? (t('select_or_type_your_option') || 'Select or type your option...') : (t('select_your_options') || 'Select your options')"
          aria-autocomplete="list"
          :aria-expanded="isDropdownOpen"
          aria-controls="dropdown-options"
          @focus="[isDropdownOpen = true, $emit('focus')]"
          @click="[isDropdownOpen = true, $emit('focus')]"
          @keydown.enter.prevent="handleEnter"
        >

        <div
          v-if="isDropdownOpen"
          id="dropdown-options"
          class="w-full mt-1 bg-base-100 border border-base-300 rounded-lg shadow-lg overflow-y-auto"
          style="max-height: min(16rem, 40vh);"
          role="listbox"
          aria-multiselectable="true"
        >
          <div class="p-2 space-y-1">
            <label
              v-for="option in filteredPredefinedOptions"
              :key="option.uuid"
              class="flex items-center space-x-3 p-2 hover:bg-base-200 rounded cursor-pointer checkbox-label"
              role="option"
              :aria-selected="normalizedMultipleValues.includes(option.value)"
            >
              <input
                type="checkbox"
                class="base-checkbox !h-6 !w-6"
                :checked="normalizedMultipleValues.includes(option.value)"
                @change="toggleValue(option.value)"
              >
              <span class="text-xl">{{ option.value }}</span>
            </label>

            <!-- Show selected custom values in the dropdown -->
            <label
              v-for="customVal in filteredCustomValues"
              :key="'custom-' + customVal"
              class="flex items-center space-x-3 p-2 hover:bg-base-200 rounded cursor-pointer checkbox-label"
              role="option"
              aria-selected="true"
            >
              <input
                type="checkbox"
                class="base-checkbox !h-6 !w-6"
                checked
                @change="toggleValue(customVal)"
              >
              <span class="text-xl">{{ customVal }}</span>
              <span class="text-xs text-base-content/50 ml-auto">{{ t('custom') || 'Custom' }}</span>
            </label>

            <!-- Add custom value option -->
            <div
              v-if="allowCustomValue && exactMatchOption === null && searchQuery.trim() !== ''"
              class="p-2 hover:bg-base-200 rounded cursor-pointer text-primary font-semibold text-xl"
              @click="addCustomValue(searchQuery.trim())"
            >
              + {{ t('add_custom_value') || 'Add' }} "{{ searchQuery.trim() }}"
            </div>
            
            <div
              v-if="filteredPredefinedOptions.length === 0 && filteredCustomValues.length === 0 && (!allowCustomValue || exactMatchOption !== null || searchQuery.trim() === '')"
              class="p-2 text-base-content/50 text-center"
            >
              {{ t('no_results_found') || 'No results found' }}
            </div>
          </div>
        </div>
      </div>

      <div class="flex flex-wrap gap-2 mt-3">
        <div
          v-for="(val, index) in normalizedMultipleValues"
          :key="index"
          class="badge badge-lg p-3 sm:p-4 text-sm sm:text-base gap-2 bg-base-200 border-base-300"
        >
          {{ val }}
          <button
            type="button"
            class="btn btn-ghost btn-xs btn-circle"
            :aria-label="t('remove_value') || 'Remove'"
            @click="removeValue(index)"
          >
            ✕
          </button>
        </div>
      </div>

      <!-- Hidden inputs for array values -->
      <template v-if="normalizedMultipleValues.length > 0">
        <input
          v-for="(val, index) in normalizedMultipleValues"
          :key="index"
          type="hidden"
          :name="`values[${field.uuid}][]`"
          :value="val"
        >
      </template>
      <input
        v-else
        type="hidden"
        :name="`values[${field.uuid}][]`"
        value=""
      >
    </template>
  </div>
</template>

<script>
import MarkdownContent from './markdown_content'
import AppearsOn from './appears_on'

export default {
  name: 'SelectStep',
  components: {
    MarkdownContent,
    AppearsOn
  },
  inject: ['t'],
  props: {
    modelValue: {
      type: [String, Array],
      required: false,
      default: ''
    },
    field: {
      type: Object,
      required: true
    },
    showFieldNames: {
      type: Boolean,
      required: false,
      default: false
    }
  },
  emits: ['update:modelValue', 'focus'],
  data () {
    return {
      customInputValue: '',
      searchQuery: '',
      isDropdownOpen: false
    }
  },
  computed: {
    allowCustomValue () {
      return !!this.field.preferences?.allow_custom_value
    },
    allowMultipleValues () {
      return !!this.field.preferences?.allow_multiple_values
    },
    predefinedOptions () {
      return (this.field.options || []).map((opt, index) => {
        return {
          ...opt,
          value: opt.value || `${this.t('option') || 'Option'} ${index + 1}`
        }
      })
    },
    normalizedSingleValue () {
      if (Array.isArray(this.modelValue)) {
        return this.modelValue.find(val => typeof val === 'string' && val.trim() !== '') || ''
      }
      return typeof this.modelValue === 'string' ? this.modelValue.trim() : ''
    },
    normalizedMultipleValues () {
      if (Array.isArray(this.modelValue)) {
        return this.modelValue.filter(val => typeof val === 'string' && val.trim() !== '')
      }
      if (typeof this.modelValue === 'string' && this.modelValue.trim() !== '') {
        return [this.modelValue.trim()]
      }
      return []
    },
    selectedPredefinedOption () {
      const val = this.normalizedSingleValue
      const found = this.predefinedOptions.find(o => o.value === val)
      return found ? found.value : ''
    },
    filteredPredefinedOptions () {
      if (!this.searchQuery) return this.predefinedOptions
      const q = this.searchQuery.toLowerCase()
      return this.predefinedOptions.filter(o => o.value.toLowerCase().includes(q))
    },
    selectedCustomValues () {
      const predefinedValues = this.predefinedOptions.map(o => o.value.toLowerCase())
      return this.normalizedMultipleValues.filter(v => !predefinedValues.includes(v.toLowerCase()))
    },
    filteredCustomValues () {
      let custom = this.selectedCustomValues
      if (this.searchQuery) {
        const q = this.searchQuery.toLowerCase()
        custom = custom.filter(v => v.toLowerCase().includes(q))
      }
      return custom
    },
    exactMatchOption () {
      const q = this.searchQuery.trim().toLowerCase()
      if (!q) return null

      const predefined = this.predefinedOptions.find(o => o.value.toLowerCase() === q)
      if (predefined) return predefined.value

      const custom = this.selectedCustomValues.find(v => v.toLowerCase() === q)
      if (custom) return custom

      return null
    }
  },
  watch: {
    modelValue: {
      immediate: true,
      handler () {
        if (!this.allowMultipleValues && this.allowCustomValue) {
          if (!this.selectedPredefinedOption && this.normalizedSingleValue) {
            this.customInputValue = this.normalizedSingleValue
          } else {
            this.customInputValue = ''
          }
        }
      }
    }
  },
  mounted () {
    document.addEventListener('click', this.handleClickOutside)
  },
  beforeUnmount () {
    document.removeEventListener('click', this.handleClickOutside)
  },
  methods: {
    handleClickOutside (e) {
      if (this.allowMultipleValues && this.isDropdownOpen && this.$el && !this.$el.contains(e.target)) {
        this.isDropdownOpen = false
      }
    },
    closeDropdown () {
      this.isDropdownOpen = false
    },
    updateValue (val) {
      this.$emit('update:modelValue', val)
    },
    onPredefinedOptionChange (val) {
      this.customInputValue = ''
      this.updateValue(val)
    },
    onCustomInputChange () {
      this.updateValue(this.customInputValue.trim())
    },
    toggleValue (val) {
      const valueToToggle = (val || '').trim()
      if (!valueToToggle) return

      const current = [...this.normalizedMultipleValues]
      const index = current.findIndex(existing => existing.toLowerCase() === valueToToggle.toLowerCase())
      
      if (index >= 0) {
        current.splice(index, 1)
      } else {
        current.push(valueToToggle)
      }
      
      this.updateValue(current)
    },
    addCustomValue (val) {
      const valueToAdd = (val || '').trim()
      if (!valueToAdd) return

      const current = [...this.normalizedMultipleValues]
      const isDuplicate = current.some(existing => existing.toLowerCase() === valueToAdd.toLowerCase())
      
      if (!isDuplicate) {
        current.push(valueToAdd)
        this.updateValue(current)
      }
      
      this.searchQuery = ''
    },
    handleEnter () {
      const q = this.searchQuery.trim()
      if (!q) return

      if (this.exactMatchOption) {
        this.toggleValue(this.exactMatchOption)
        this.searchQuery = ''
      } else if (this.allowCustomValue) {
        this.addCustomValue(q)
      }
    },
    removeValue (index) {
      const current = [...this.normalizedMultipleValues]
      current.splice(index, 1)
      this.updateValue(current)
    }
  }
}
</script>
