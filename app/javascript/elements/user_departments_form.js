export default class extends HTMLElement {
  connectedCallback () {
    const form = this.closest('form')
    this.companySelect = form ? form.querySelector('#user_company_id') : null
    this.departmentLabels = this.querySelectorAll('.department-checkbox-label')
    this.noDepsMsg = this.querySelector('#no-departments-message')

    this.updateDepartmentsHandler = this.updateDepartments.bind(this)

    this.restoreInitialCheckedState()
    requestAnimationFrame(() => this.restoreInitialCheckedState())
    setTimeout(() => this.restoreInitialCheckedState(), 0)
    setTimeout(() => this.restoreInitialCheckedState(), 100)

    if (this.companySelect) {
      this.companySelect.addEventListener('change', this.updateDepartmentsHandler)
    }
  }

  restoreInitialCheckedState () {
    this.departmentLabels.forEach(label => {
      const checkbox = label.querySelector('.department-checkbox')
      if (checkbox && label.dataset.selected === 'true') {
        checkbox.checked = true
      }
    })
  }

  disconnectedCallback () {
    if (this.companySelect && this.updateDepartmentsHandler) {
      this.companySelect.removeEventListener('change', this.updateDepartmentsHandler)
    }
  }

  updateDepartments () {
    if (!this.companySelect) return

    const companyId = this.companySelect.value
    let visibleCount = 0

    this.departmentLabels.forEach(label => {
      const labelCompanyId = label.dataset.companyId

      if (labelCompanyId === companyId) {
        label.classList.remove('hidden')
        visibleCount++
      } else {
        label.classList.add('hidden')
        const checkbox = label.querySelector('.department-checkbox')
        if (checkbox) checkbox.checked = false
      }
    })

    if (this.noDepsMsg) {
      if (visibleCount === 0) {
        this.noDepsMsg.classList.remove('hidden')
      } else {
        this.noDepsMsg.classList.add('hidden')
      }
    }
  }
}
