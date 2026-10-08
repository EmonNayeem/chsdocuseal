function isEmpty (val) {
  return val === null || val === undefined || val === '' || val === false || (Array.isArray(val) && val.length === 0)
}

function normalizeString (val) {
  if (val == null) return ''
  return String(val).trim().toLowerCase()
}

export function evaluateCondition (condition, field, actualValue, optionNameFn) {
  if (['empty', 'unchecked'].includes(condition.action)) {
    return isEmpty(actualValue)
  } else if (['not_empty', 'checked'].includes(condition.action)) {
    return !isEmpty(actualValue)
  } else if (field?.type === 'number' && ['equal', 'not_equal', 'greater_than', 'greater_than_or_equal', 'less_than', 'less_than_or_equal'].includes(condition.action)) {
    if (isEmpty(actualValue) || isEmpty(condition.value)) return false

    const actual = parseFloat(actualValue)
    const expected = parseFloat(condition.value)

    if (Number.isNaN(actual) || Number.isNaN(expected)) return false

    if (condition.action === 'equal') return Math.abs(actual - expected) < Number.EPSILON
    if (condition.action === 'not_equal') return Math.abs(actual - expected) > Number.EPSILON
    if (condition.action === 'greater_than') return actual > expected
    if (condition.action === 'greater_than_or_equal') return actual >= expected
    if (condition.action === 'less_than') return actual < expected
    if (condition.action === 'less_than_or_equal') return actual <= expected

    return false
  } else if (['equal', 'not_equal', 'contains', 'does_not_contain', 'starts_with', 'ends_with'].includes(condition.action) && field) {
    let expected = condition.value

    if (field.options) {
      const optionIndex = field.options.findIndex((o) => o.uuid === condition.value)
      if (optionIndex !== -1) {
        const option = field.options[optionIndex]
        expected = optionNameFn ? optionNameFn(option, optionIndex) : (option.value || `Option ${optionIndex + 1}`)
      }
    }

    if (field.type === 'date' && ['equal', 'not_equal'].includes(condition.action)) {
      const actualStr = normalizeString(actualValue)
      const expectedStr = normalizeString(expected)
      if (condition.action === 'equal') return actualStr === expectedStr
      if (condition.action === 'not_equal') return actualStr !== expectedStr
      return false
    }

    const actualValues = [actualValue].flat().map(normalizeString)
    const expectedStr = normalizeString(expected)

    if (condition.action === 'equal') return actualValues.some(v => v === expectedStr)
    if (condition.action === 'not_equal') return actualValues.every(v => v !== expectedStr)
    if (condition.action === 'contains') return actualValues.some(v => v.includes(expectedStr))
    if (condition.action === 'does_not_contain') return actualValues.every(v => !v.includes(expectedStr))
    if (condition.action === 'starts_with') return actualValues.some(v => v.startsWith(expectedStr))
    if (condition.action === 'ends_with') return actualValues.some(v => v.endsWith(expectedStr))

    return false
  }

  return true
}

export function isFieldHiddenByConditions (field, fieldsUuidIndex, getFieldValue, optionNameFn, visited = new Set(), cache = {}) {
  if (!field || !field.conditions || !field.conditions.length) {
    return false
  }

  const cacheKey = field.uuid || field.attachment_uuid
  if (cacheKey && cache[cacheKey] !== undefined) {
    return !cache[cacheKey]
  }

  if (visited.has(field.uuid)) {
    return true // Cycle detected
  }

  visited.add(field.uuid)

  const result = field.conditions.reduce((acc, cond) => {
    let isSatisfied = true

    const sourceField = fieldsUuidIndex[cond.field_uuid]

    if (!sourceField) {
      isSatisfied = false
    } else if (isFieldHiddenByConditions(sourceField, fieldsUuidIndex, getFieldValue, optionNameFn, new Set(visited), cache)) {
      const emptyValue = sourceField.type === 'multiple' || sourceField.preferences?.allow_multiple_values ? [] : null
      isSatisfied = evaluateCondition(cond, sourceField, emptyValue, optionNameFn)
    } else {
      isSatisfied = evaluateCondition(cond, sourceField, getFieldValue(sourceField), optionNameFn)
    }

    if (cond.operation === 'or') {
      acc.push(acc.pop() || isSatisfied)
    } else {
      acc.push(isSatisfied)
    }

    return acc
  }, [])

  visited.delete(field.uuid)

  const isHidden = result.includes(false)
  if (cacheKey) cache[cacheKey] = !isHidden
  return isHidden
}
