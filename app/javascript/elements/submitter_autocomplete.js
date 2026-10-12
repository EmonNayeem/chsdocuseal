import autocomplete from 'autocompleter'

export default class extends HTMLElement {
  connectedCallback () {
    autocomplete({
      input: this.input,
      preventSubmit: 1,
      minLength: 1,
      showOnFocus: true,
      debounceWaitMs: 200,
      onSelect: this.onSelect,
      render: this.render,
      fetch: this.fetch
    })
  }

  onSelect = (item) => {
    const fields = ['email', 'name', 'phone']
    const submitterItemEl = this.closest('submitter-item')

    fields.forEach((field) => {
      const input = submitterItemEl.querySelector(`submitters-autocomplete[data-field="${field}"] input`)
      const textarea = submitterItemEl.querySelector(`submitters-autocomplete[data-field="${field}"] textarea`)

      if (input && item[field]) {
        input.value = item[field]
        input.dispatchEvent(new CustomEvent('linked-input.update', { bubbles: true }))
      }

      if (textarea && item[field]) {
        textarea.value = textarea.value.replace(/[^;,\s]+$/, item[field] + ' ')

        textarea.dispatchEvent(new Event('input', { bubbles: true }))
      }
    })

    const mappedFields = submitterItemEl.querySelectorAll('[data-recipient-mapping]')
    mappedFields.forEach((el) => {
      const key = el.dataset.recipientMapping
      if (item[key] != null) {
        if (el.tagName === 'SELECT' || el.type === 'radio') {
          // Check if option exists
          const options = el.tagName === 'SELECT' ? Array.from(el.options).map(o => o.value) : Array.from(document.querySelectorAll(`input[name="${el.name}"]`)).map(o => o.value)
          if (options.includes(item[key])) {
            el.value = item[key]
            el.dispatchEvent(new Event('change', { bubbles: true }))
          }
        } else {
          el.value = item[key]
          el.dispatchEvent(new Event('input', { bubbles: true }))
          el.dispatchEvent(new Event('change', { bubbles: true }))
        }
      }
    })
  }

  fetch = (text, resolve) => {
    const q = this.dataset.field === 'email'
      ? text.split(/[;,\s]+/).pop().trim()
      : text

    if (q) {
      const queryParams = new URLSearchParams({ q, field: this.dataset.field })

      this.currentFetch ||= fetch('/submitters_autocomplete?' + queryParams)

      this.currentFetch.then(async (resp) => {
        const items = await resp.json()

        resolve(items)
      }).catch(() => {
        resolve([])
      }).finally(() => {
        this.currentFetch = null
      })
    } else {
      resolve([])
    }
  }

  render = (item) => {
    const div = document.createElement('div')

    div.setAttribute('dir', 'auto')

    if (item.source === 'directory') {
      const visibility = item.visibility === 'shared' ? 'Shared' : item.company_name
      const extraFields = []

      if (item.name && this.dataset.field !== 'name') extraFields.push(item.name)
      if (item.email && this.dataset.field !== 'email') extraFields.push(item.email)

      const subtext = extraFields.join(' - ')

      const metaFields = []
      if (item.job_title) metaFields.push(item.job_title)
      if (item.department) metaFields.push(item.department)
      const metaText = metaFields.length > 0 ? `<div class="text-xs mt-0.5 opacity-80">${metaFields.join(' &middot; ')}</div>` : ''

      const badge = visibility ? ` <span class="opacity-70">(${visibility})</span>` : ''

      div.innerHTML = `
        <div>${item[this.dataset.field] || ''}</div>
        <div class="text-xs mt-0.5">${subtext}${subtext ? badge : badge.trim()}</div>
        ${metaText}
      `
    } else {
      div.textContent = item[this.dataset.field]
    }

    return div
  }

  get input () {
    return this.querySelector('input') || this.querySelector('textarea')
  }
}
