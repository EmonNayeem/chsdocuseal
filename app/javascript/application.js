import '@hotwired/turbo'
import { encodeMethodIntoRequestBody } from '@hotwired/turbo-rails/app/javascript/turbo/fetch_requests'

import { createApp, reactive } from 'vue'
import TemplateBuilder from './template_builder/builder'
import ImportList from './template_builder/import_list'

import ToggleVisible from './elements/toggle_visible'
import ToggleCookies from './elements/toggle_cookies'
import DisableHidden from './elements/disable_hidden'
import TurboModal from './elements/turbo_modal'
import FileDropzone from './elements/file_dropzone'
import MenuActive from './elements/menu_active'
import ClipboardCopy from './elements/clipboard_copy'
import DynamicList from './elements/dynamic_list'
import DownloadButton from './elements/download_button'
import SetOriginUrl from './elements/set_origin_url'
import SetTimezone from './elements/set_timezone'
import AutoresizeTextarea from './elements/autoresize_textarea'
import SubmittersAutocomplete from './elements/submitter_autocomplete'
import FolderAutocomplete from './elements/folder_autocomplete'
import SignatureForm from './elements/signature_form'
import SubmitForm from './elements/submit_form'
import ConvertUpload from './elements/convert_upload'
import PromptPassword from './elements/prompt_password'
import EmailsTextarea from './elements/emails_textarea'
import ToggleSubmit from './elements/toggle_submit'
import ToggleOnSubmit from './elements/toggle_on_submit'
import CheckOnClick from './elements/check_on_click'
import PasswordInput from './elements/password_input'
import SearchInput from './elements/search_input'
import ToggleAttribute from './elements/toggle_attribute'
import LinkedInput from './elements/linked_input'
import CheckboxGroup from './elements/checkbox_group'
import MaskedInput from './elements/masked_input'
import SetDateButton from './elements/set_date_button'
import IndeterminateCheckbox from './elements/indeterminate_checkbox'
import AppTour from './elements/app_tour'
import AppTourStart from './elements/app_tour_start'
import DashboardDropzone from './elements/dashboard_dropzone'
import RequiredCheckboxGroup from './elements/required_checkbox_group'
import PageContainer from './elements/page_container'
import EmailEditor from './elements/email_editor'
import MarkdownEditor from './elements/markdown_editor'
import HtmlEditor from './elements/html_editor'
import MountOnClick from './elements/mount_on_click'
import RemoveOnEvent from './elements/remove_on_event'
import ScrollTo from './elements/scroll_to'
import SetValue from './elements/set_value'
import ReviewForm from './elements/review_form'
import ShowOnValue from './elements/show_on_value'
import ToggleClasses from './elements/toggle_classes'
import AutosizeField from './elements/autosize_field'
import GoogleDriveFilePicker from './elements/google_drive_file_picker'
import OpenModal from './elements/open_modal'
import BarChart from './elements/bar_chart'
import FieldCondition from './elements/field_condition'
import ConfirmUpload from './elements/confirm_upload'
import UserDepartmentsForm from './elements/user_departments_form'

import flatpickr from 'flatpickr'
import 'flatpickr/dist/flatpickr.css'

import * as TurboInstantClick from './lib/turbo_instant_click'

TurboInstantClick.start()

document.addEventListener('turbo:before-cache', () => {
  window.flash?.remove()
})

document.addEventListener('keyup', (e) => {
  if (e.code === 'Escape') {
    document.activeElement?.blur()
  }
})

document.addEventListener('turbo:before-fetch-request', encodeMethodIntoRequestBody)
document.addEventListener('turbo:before-fetch-request', (event) => {
  event.detail.fetchOptions.headers['X-Turbo'] = 'true'
})
document.addEventListener('turbo:submit-end', async (event) => {
  const resp = event.detail?.formSubmission?.result?.fetchResponse?.response

  if (!resp?.headers?.get('content-disposition')?.includes('attachment')) {
    return
  }

  const url = URL.createObjectURL(await resp.blob())
  const link = document.createElement('a')

  link.href = url
  link.setAttribute('download', decodeURIComponent(resp.headers.get('content-disposition').split('"')[1]))

  document.body.appendChild(link)

  link.click()

  document.body.removeChild(link)

  URL.revokeObjectURL(url)
})

const safeRegisterElement = (name, element, options = {}) => !window.customElements.get(name) && window.customElements.define(name, element, options)

safeRegisterElement('toggle-visible', ToggleVisible)
safeRegisterElement('disable-hidden', DisableHidden)
safeRegisterElement('turbo-modal', TurboModal)
safeRegisterElement('file-dropzone', FileDropzone)
safeRegisterElement('menu-active', MenuActive)
safeRegisterElement('clipboard-copy', ClipboardCopy)
safeRegisterElement('dynamic-list', DynamicList)
safeRegisterElement('download-button', DownloadButton)
safeRegisterElement('set-origin-url', SetOriginUrl)
safeRegisterElement('set-timezone', SetTimezone)
safeRegisterElement('autoresize-textarea', AutoresizeTextarea)
safeRegisterElement('submitters-autocomplete', SubmittersAutocomplete)
safeRegisterElement('folder-autocomplete', FolderAutocomplete)
safeRegisterElement('signature-form', SignatureForm)
safeRegisterElement('submit-form', SubmitForm)
safeRegisterElement('convert-upload', ConvertUpload)
safeRegisterElement('prompt-password', PromptPassword)
safeRegisterElement('emails-textarea', EmailsTextarea)
safeRegisterElement('toggle-cookies', ToggleCookies)
safeRegisterElement('toggle-submit', ToggleSubmit)
safeRegisterElement('toggle-on-submit', ToggleOnSubmit)
safeRegisterElement('password-input', PasswordInput)
safeRegisterElement('search-input', SearchInput)
safeRegisterElement('toggle-attribute', ToggleAttribute)
safeRegisterElement('linked-input', LinkedInput)
safeRegisterElement('checkbox-group', CheckboxGroup)
safeRegisterElement('masked-input', MaskedInput)
safeRegisterElement('set-date-button', SetDateButton)
safeRegisterElement('indeterminate-checkbox', IndeterminateCheckbox)
safeRegisterElement('app-tour', AppTour)
safeRegisterElement('app-tour-start', AppTourStart)
safeRegisterElement('dashboard-dropzone', DashboardDropzone)
safeRegisterElement('check-on-click', CheckOnClick)
safeRegisterElement('required-checkbox-group', RequiredCheckboxGroup)
safeRegisterElement('page-container', PageContainer)
safeRegisterElement('email-editor', EmailEditor)
safeRegisterElement('markdown-editor', MarkdownEditor)
safeRegisterElement('html-editor', HtmlEditor)
safeRegisterElement('mount-on-click', MountOnClick)
safeRegisterElement('remove-on-event', RemoveOnEvent)
safeRegisterElement('scroll-to', ScrollTo)
safeRegisterElement('set-value', SetValue)
safeRegisterElement('review-form', ReviewForm)
safeRegisterElement('show-on-value', ShowOnValue)
safeRegisterElement('toggle-classes', ToggleClasses)
safeRegisterElement('autosize-field', AutosizeField)
safeRegisterElement('google-drive-file-picker', GoogleDriveFilePicker)
safeRegisterElement('open-modal', OpenModal)
safeRegisterElement('bar-chart', BarChart)
safeRegisterElement('field-condition', FieldCondition)
safeRegisterElement('confirm-upload', ConfirmUpload)
safeRegisterElement('user-departments-form', UserDepartmentsForm)

safeRegisterElement('template-builder', class extends HTMLElement {
  connectedCallback () {
    document.addEventListener('turbo:submit-end', this.onSubmit)

    this.appElem = document.createElement('div')
    this.appElem.classList.add('md:h-screen')

    const template = reactive(JSON.parse(this.dataset.template))
    const isDarkTheme = document.documentElement.getAttribute('data-theme') === 'chs-dark'
    const backgroundColor = (isDarkTheme && this.dataset.darkBackgroundColor)
      ? this.dataset.darkBackgroundColor
      : (this.dataset.backgroundColor || '#faf7f5')

    this.app = createApp(TemplateBuilder, {
      template,
      customFields: reactive(JSON.parse(this.dataset.customFields || '[]')),
      dateFormats: JSON.parse(this.dataset.dateFormats || '[]'),
      dynamicDocuments: reactive(JSON.parse(this.dataset.dynamicDocuments || '[]')),
      backgroundColor,
      locale: this.dataset.locale,
      withPhone: this.dataset.withPhone === 'true',
      withPrefillable: template.fields?.some((f) => f.prefillable),
      withVerification: ['true', 'false'].includes(this.dataset.withVerification) ? this.dataset.withVerification === 'true' : null,
      withKba: ['true', 'false'].includes(this.dataset.withKba) ? this.dataset.withKba === 'true' : null,
      withLogo: this.dataset.withLogo !== 'false',
      withFieldsDetection: this.dataset.withFieldsDetection === 'true',
      withDetectExistingFields: this.dataset.withDetectExistingFields === 'true',
      withRevisions: true,
      withRevisionsMenu: this.dataset.withRevisionsMenu === 'true',
      editable: this.dataset.editable !== 'false',
      authenticityToken: document.querySelector('meta[name="csrf-token"]')?.content,
      withCustomFields: true,
      withPayment: this.dataset.withPayment === 'true',
      isPaymentConnected: this.dataset.isPaymentConnected === 'true',
      withFormula: this.dataset.withFormula === 'true',
      withSendButton: this.dataset.withSendButton !== 'false',
      withSignYourselfButton: this.dataset.withSignYourselfButton !== 'false',
      withConditions: this.dataset.withConditions === 'true',
      withDynamicDocuments: this.dataset.withDynamicDocuments === 'true',
      withGoogleDrive: this.dataset.withGoogleDrive === 'true',
      pagePreviewFormat: this.dataset.pagePreviewFormat || '.jpg',
      withReplaceAndCloneUpload: true,
      withDownload: true,
      currencies: (this.dataset.currencies || '').split(',').filter(Boolean),
      acceptFileTypes: this.dataset.acceptFileTypes,
      showTourStartForm: this.dataset.showTourStartForm === 'true'
    })

    this.component = this.app.mount(this.appElem)

    this.appendChild(this.appElem)
  }

  onSubmit = (e) => {
    if (e.detail.success) {
      if (e.detail?.formSubmission?.formElement?.id === 'submitters_form') {
        e.detail.fetchResponse.response.json().then((data) => {
          this.component.template.submitters = data.submitters
        })
      }

      if (e.detail?.formSubmission?.formElement?.action?.endsWith('/prefillable_fields')) {
        e.detail.fetchResponse.response.text().then((data) => {
          const doc = new DOMParser().parseFromString(data, 'text/html')
          const fragment = doc.querySelector('turbo-stream template').content

          const prefillableUuidsIndex = {}

          fragment.querySelectorAll('[name="field_uuid"]').forEach((field) => {
            prefillableUuidsIndex[field.value] = true
          })

          this.component.template.fields.forEach((field) => {
            if (prefillableUuidsIndex[field.uuid]) {
              field.prefillable = true
              field.readonly = true
            } else if (field.prefillable) {
              delete field.prefillable
              delete field.readonly
            }
          })
        })
      }
    }
  }

  disconnectedCallback () {
    document.removeEventListener('turbo:submit-end', this.onSubmit)

    this.app?.unmount()
    this.appElem?.remove()
  }
})

safeRegisterElement('import-list', class extends HTMLElement {
  connectedCallback () {
    this.appElem = document.createElement('div')

    this.app = createApp(ImportList, {
      template: JSON.parse(this.dataset.template),
      multitenant: this.dataset.multitenant === 'true',
      authenticityToken: document.querySelector('meta[name="csrf-token"]')?.content,
      i18n: JSON.parse(this.dataset.i18n || '{}')
    })

    this.app.mount(this.appElem)

    this.appendChild(this.appElem)
  }

  disconnectedCallback () {
    this.app?.unmount()
    this.appElem?.remove()
  }
})

const updateUserDepartmentState = (roleSelect) => {
  const form = roleSelect.closest('form')

  if (!form) return

  const wrapper = form.querySelector('[data-user-departments-wrapper]')
  const checkboxes = form.querySelectorAll('[data-user-department-checkbox]')
  const adminMessage = form.querySelector('[data-admin-departments-message]')

  if (!wrapper || checkboxes.length === 0) return

  const isAdmin = roleSelect.value === 'admin'

  wrapper.classList.toggle('opacity-50', isAdmin)
  
  if (adminMessage) {
    adminMessage.classList.toggle('hidden', !isAdmin)
  }

  checkboxes.forEach((checkbox) => {
    checkbox.disabled = isAdmin
    checkbox.checked = isAdmin
  })
}

document.addEventListener('change', (event) => {
  const roleSelect = event.target.closest('[data-user-role-select]')

  if (!roleSelect) return

  updateUserDepartmentState(roleSelect)
})

document.addEventListener('turbo:load', () => {
  document.querySelectorAll('[data-user-role-select]').forEach(updateUserDepartmentState)
})

document.addEventListener('turbo:frame-load', () => {
  document.querySelectorAll('[data-user-role-select]').forEach(updateUserDepartmentState)
})

const applyChsTheme = (theme) => {
  document.documentElement.setAttribute('data-theme', theme)
  localStorage.setItem('chs-docuseal-theme', theme)

  document.querySelectorAll('[data-theme-toggle-icon]').forEach((icon) => {
    icon.textContent = theme === 'chs-dark' ? '☀️' : '🌙'
  })
}

const initializeChsThemeToggle = () => {
  const savedTheme = localStorage.getItem('chs-docuseal-theme') || 'chs'

  applyChsTheme(savedTheme)

  document.querySelectorAll('[data-theme-toggle]').forEach((button) => {
    if (button.dataset.themeToggleReady === 'true') return

    button.dataset.themeToggleReady = 'true'

    button.addEventListener('click', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme') || 'chs'
      const nextTheme = currentTheme === 'chs-dark' ? 'chs' : 'chs-dark'

      applyChsTheme(nextTheme)
    })
  })
}

document.addEventListener('turbo:load', initializeChsThemeToggle)
document.addEventListener('turbo:frame-load', initializeChsThemeToggle)
document.addEventListener('DOMContentLoaded', initializeChsThemeToggle)

// CHS DocuSeal: show/hide password buttons for all password fields
const passwordEyeIcon = `
  <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 pointer-events-none" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
    <path d="M2 12s3.5-7 10-7s10 7 10 7s-3.5 7-10 7s-10-7-10-7z"></path>
    <circle cx="12" cy="12" r="3"></circle>
  </svg>
`

const passwordEyeOffIcon = `
  <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 pointer-events-none" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
    <path d="M3 3l18 18"></path>
    <path d="M10.6 10.6a2 2 0 0 0 2.8 2.8"></path>
    <path d="M9.9 4.2A10.6 10.6 0 0 1 12 4c6.5 0 10 8 10 8a18.4 18.4 0 0 1-2.2 3.3"></path>
    <path d="M6.6 6.6C3.7 8.5 2 12 2 12s3.5 8 10 8a10.5 10.5 0 0 0 5.4-1.5"></path>
  </svg>
`

function setupPasswordToggles () {
  document.querySelectorAll('input[type="password"]:not([data-password-toggle-ready])').forEach((input) => {
    input.dataset.passwordToggleReady = 'true'

    const wrapper = document.createElement('div')
    wrapper.className = 'password-toggle-wrapper'

    input.parentNode.insertBefore(wrapper, input)
    wrapper.appendChild(input)

    input.classList.add('password-toggle-input')

    const button = document.createElement('button')
    button.type = 'button'
    button.className = 'password-toggle-button'
    button.setAttribute('aria-label', 'Show password')
    button.setAttribute('title', 'Show password')
    button.innerHTML = passwordEyeIcon

    button.addEventListener('click', () => {
      const isPassword = input.type === 'password'

      input.type = isPassword ? 'text' : 'password'
      button.setAttribute('aria-label', isPassword ? 'Hide password' : 'Show password')
      button.setAttribute('title', isPassword ? 'Hide password' : 'Show password')
      button.innerHTML = isPassword ? passwordEyeOffIcon : passwordEyeIcon

      input.focus()
    })

    wrapper.appendChild(button)
  })
}

document.addEventListener('turbo:load', setupPasswordToggles)
document.addEventListener('turbo:frame-load', setupPasswordToggles)
document.addEventListener('DOMContentLoaded', setupPasswordToggles)

const passwordToggleObserver = new MutationObserver(() => {
  setupPasswordToggles()
})

document.addEventListener('DOMContentLoaded', () => {
  if (document.body) {
    passwordToggleObserver.observe(document.body, {
      childList: true,
      subtree: true
    })
  }
})

// CHS DocuSeal: dashboard template live search dropdown
let templateSearchTimer = null

const hideTemplateSearchResults = (resultsBox) => {
  if (!resultsBox) return

  resultsBox.classList.add('hidden')
  resultsBox.innerHTML = ''
}

const renderTemplateSearchResults = (input, resultsBox, results) => {
  if (!resultsBox) return

  if (!input.value.trim()) {
    hideTemplateSearchResults(resultsBox)
    return
  }

  if (results.length === 0) {
    resultsBox.innerHTML = `
      <div class="px-4 py-3 text-sm opacity-70">
        No templates found
      </div>
    `
    resultsBox.classList.remove('hidden')
    return
  }

  resultsBox.innerHTML = results.map((template) => {
    const departments = template.departments.length > 0
      ? template.departments.map((name) => `<span class="badge badge-info badge-outline badge-xs">${name}</span>`).join(' ')
      : '<span class="badge badge-outline badge-xs opacity-60">No department</span>'

    return `
      <a href="${template.url}" class="block px-4 py-3 hover:bg-base-200 border-b border-base-300 last:border-b-0">
        <div class="font-semibold text-sm">${template.name}</div>
        <div class="text-xs opacity-70 mt-1">${template.author}</div>
        <div class="flex flex-wrap gap-1 mt-2">${departments}</div>
      </a>
    `
  }).join('')

  resultsBox.classList.remove('hidden')
}

const initializeTemplateLiveSearch = () => {
  document.querySelectorAll('[data-template-search-input]').forEach((input) => {
    if (input.dataset.templateSearchReady === 'true') return

    input.dataset.templateSearchReady = 'true'

    const wrapper = input.closest('.form-control')
    const resultsBox = wrapper?.querySelector('[data-template-search-results]')
    const url = input.dataset.templateSearchUrl

    input.addEventListener('input', () => {
      clearTimeout(templateSearchTimer)

      const query = input.value.trim()

      if (query.length < 2) {
        hideTemplateSearchResults(resultsBox)
        return
      }

      templateSearchTimer = setTimeout(() => {
        fetch(`${url}?q=${encodeURIComponent(query)}`, {
          headers: {
            Accept: 'application/json'
          }
        })
          .then((response) => response.json())
          .then((results) => renderTemplateSearchResults(input, resultsBox, results))
          .catch(() => hideTemplateSearchResults(resultsBox))
      }, 250)
    })

    input.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        hideTemplateSearchResults(resultsBox)
      }
    })
  })
}

document.addEventListener('click', (event) => {
  document.querySelectorAll('[data-template-search-results]').forEach((resultsBox) => {
    const wrapper = resultsBox.closest('.form-control')

    if (wrapper && !wrapper.contains(event.target)) {
      hideTemplateSearchResults(resultsBox)
    }
  })
})

document.addEventListener('turbo:load', initializeTemplateLiveSearch)
document.addEventListener('turbo:frame-load', initializeTemplateLiveSearch)
document.addEventListener('DOMContentLoaded', initializeTemplateLiveSearch)

// CHS DocuSeal: consistent custom date picker for all date fields
const initializeChsDatePickers = () => {
  document.querySelectorAll('input[type="date"]:not([data-chs-date-picker-ready])').forEach((input) => {
    input.dataset.chsDatePickerReady = 'true'

    // Disable browser-native date UI so all users see the same date picker
    input.type = 'text'
    input.placeholder = 'dd/mm/yyyy'
    input.autocomplete = 'off'

    flatpickr(input, {
      allowInput: true,
      dateFormat: 'Y-m-d',
      altInput: true,
      altFormat: 'd/m/Y',
      disableMobile: true,
      monthSelectorType: 'dropdown'
    })
  })
}

document.addEventListener('turbo:load', initializeChsDatePickers)
document.addEventListener('turbo:frame-load', initializeChsDatePickers)
document.addEventListener('DOMContentLoaded', initializeChsDatePickers)

initializeChsDatePickers()