import { createApp } from 'vue'
import RevisionsModal from '../template_builder/revisions_modal.vue'
import * as i18n from '../template_builder/i18n'
import { downloadUrls } from '../lib/download_urls'

export default class TemplateRevisionsModal extends HTMLElement {
  connectedCallback () {
    this.button = this.querySelector('button')
    if (this.button) {
      this.button.addEventListener('click', this.open)
    }

    document.addEventListener('turbo:before-cache', this.close)
  }

  disconnectedCallback () {
    this.close()

    if (this.button) {
      this.button.removeEventListener('click', this.open)
    }

    document.removeEventListener('turbo:before-cache', this.close)
  }

  open = (e) => {
    e?.preventDefault()
    if (this.app) return

    this.modalContainer = document.createElement('div')
    this.modalContainer.id = 'template_revisions_modal_container'
    document.body.appendChild(this.modalContainer)

    const templateData = JSON.parse(this.dataset.template)
    const locale = this.dataset.locale || 'en'

    this.app = createApp(RevisionsModal, {
      template: templateData,
      locale,
      returnUrl: window.location.href,
      onClose: () => this.close(),
      onDownloadUrls: (urls) => downloadUrls(urls)
    })

    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    this.app.provide('t', (key) => i18n[locale]?.[key] || i18n.en?.[key] || key)
    this.app.provide('baseFetch', (path, options = {}) => {
      return fetch(path, {
        ...options,
        headers: {
          'X-CSRF-Token': token,
          ...options.headers
        }
      })
    })

    this.app.mount(this.modalContainer)
  }

  close = () => {
    if (this.app) {
      this.app.unmount()
      this.app = null
    }

    if (this.modalContainer) {
      this.modalContainer.remove()
      this.modalContainer = null
    }
  }
}
