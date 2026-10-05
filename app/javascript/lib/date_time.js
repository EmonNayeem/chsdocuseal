export const DEFAULT_DATE_FIELD_FORMAT = 'DD MMM YY'

export function formatShortDateTime (value, locale) {
  const formatter = new Intl.DateTimeFormat(locale || undefined, {
    day: '2-digit',
    month: 'short',
    year: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  })

  const parts = Object.fromEntries(
    formatter
      .formatToParts(new Date(value))
      .filter(({ type }) => type !== 'literal')
      .map(({ type, value }) => [type, value])
  )

  const dayPeriod = parts.dayPeriod ? ` ${parts.dayPeriod}` : ''

  return `${parts.day} ${parts.month} ${parts.year} ${parts.hour}:${parts.minute}${dayPeriod}`
}
