document.addEventListener('change', (event) => {
  const companySelect = event.target.closest('[data-template-copy-company]')
  if (!companySelect) return

  const form = companySelect.closest('[data-template-copy-form]')
  if (!form) return

  updateTemplateCopyForm(form, companySelect.value)
})

const updateTemplateCopyForm = (form, companyId) => {
  const parsedCompanyId = parseInt(companyId, 10)
  if (isNaN(parsedCompanyId)) return

  const allDepartments = JSON.parse(form.dataset.templateCopyDepartments || '[]')
  const allFolders = JSON.parse(form.dataset.templateCopyFolders || '[]')
  const defaultFolders = JSON.parse(form.dataset.templateCopyDefaultFolders || '{}')

  const deptSelect = form.querySelector('[data-template-copy-departments-select]')
  const folderSelect = form.querySelector('[data-template-copy-folder-select]')
  const deptWrapper = form.querySelector('[data-template-copy-departments-wrapper]')
  const folderWrapper = form.querySelector('[data-template-copy-folder-wrapper]')

  if (deptSelect) {
    deptSelect.innerHTML = ''
    const companyDepts = allDepartments.filter(d => d.company_id === parsedCompanyId)
    companyDepts.forEach(d => {
      const option = document.createElement('option')
      option.value = d.id
      option.text = d.name
      deptSelect.appendChild(option)
    })

    if (deptWrapper) {
      if (companyDepts.length > 0) {
        deptWrapper.style.display = ''
      } else {
        deptWrapper.style.display = 'none'
      }
    }
  }

  if (folderSelect) {
    folderSelect.innerHTML = '<option value=""></option>'
    const companyFolders = allFolders.filter(f => f.company_id === parsedCompanyId)
    const defaultFolderId = defaultFolders[parsedCompanyId]

    companyFolders.forEach(f => {
      const option = document.createElement('option')
      option.value = f.id
      option.text = f.name
      if (f.id === defaultFolderId) {
        option.selected = true
      }
      folderSelect.appendChild(option)
    })

    if (folderWrapper) {
      if (companyFolders.length > 0) {
        folderWrapper.style.display = ''
      } else {
        folderWrapper.style.display = 'none'
      }
    }
  }
}

const initializeTemplateCopyForms = () => {
  document.querySelectorAll('[data-template-copy-form]').forEach(form => {
    const companySelect = form.querySelector('[data-template-copy-company]')
    if (companySelect && form.dataset.templateCopyInitialized !== 'true') {
      form.dataset.templateCopyInitialized = 'true'
      updateTemplateCopyForm(form, companySelect.value)
    }
  })
}

document.addEventListener('turbo:load', initializeTemplateCopyForms)
document.addEventListener('turbo:frame-load', initializeTemplateCopyForms)
document.addEventListener('DOMContentLoaded', initializeTemplateCopyForms)
