// Page-aware scroll synchronization helper for Template Version Visual Comparison

export function findActivePageAndProgress (container, pageElements) {
  if (!container || !pageElements || pageElements.length === 0) {
    const scrollRatio = container && (container.scrollHeight - container.clientHeight) > 0
      ? container.scrollTop / (container.scrollHeight - container.clientHeight)
      : 0
    return { docIndex: 0, pageIndex: 0, progress: Math.max(0, Math.min(1, scrollRatio)) }
  }

  const anchorY = container.scrollTop + (container.clientHeight / 2)

  // Check if above the first page
  if (anchorY <= pageElements[0].top) {
    return { docIndex: pageElements[0].docIndex, pageIndex: pageElements[0].pageIndex, progress: 0 }
  }

  // Check if below the last page
  const last = pageElements[pageElements.length - 1]
  if (anchorY >= last.bottom) {
    return { docIndex: last.docIndex, pageIndex: last.pageIndex, progress: 1 }
  }

  // Find page that contains anchorY
  for (let i = 0; i < pageElements.length; i++) {
    const p = pageElements[i]
    if (anchorY >= p.top && anchorY <= p.bottom) {
      const pageH = p.height || 1
      const progress = Math.max(0, Math.min(1, (anchorY - p.top) / pageH))
      return { docIndex: p.docIndex, pageIndex: p.pageIndex, progress }
    }
  }

  // Fallback to closest page
  let closest = pageElements[0]
  let minDiff = Math.abs(anchorY - (closest.top + closest.height / 2))
  for (let i = 1; i < pageElements.length; i++) {
    const p = pageElements[i]
    const diff = Math.abs(anchorY - (p.top + p.height / 2))
    if (diff < minDiff) {
      minDiff = diff
      closest = p
    }
  }

  return { docIndex: closest.docIndex, pageIndex: closest.pageIndex, progress: 0.5 }
}

export function calculateTargetScroll (targetContainer, targetPageElements, activeState, sourceFallbackProgress) {
  if (!targetContainer) return 0

  const maxScroll = Math.max(0, targetContainer.scrollHeight - targetContainer.clientHeight)
  if (maxScroll <= 0) return 0

  if (!targetPageElements || targetPageElements.length === 0) {
    return Math.round(sourceFallbackProgress * maxScroll)
  }

  // 1. Try to find exact document and page match
  let targetPage = targetPageElements.find(
    (p) => p.docIndex === activeState.docIndex && p.pageIndex === activeState.pageIndex
  )

  // 2. Try to find matching pageIndex in any document
  if (!targetPage) {
    targetPage = targetPageElements.find((p) => p.pageIndex === activeState.pageIndex)
  }

  // 3. Fallback: nearest page by global order
  if (!targetPage) {
    targetPage = targetPageElements[targetPageElements.length - 1]
  }

  if (!targetPage) {
    return Math.round(sourceFallbackProgress * maxScroll)
  }

  const targetAnchorY = targetPage.top + (activeState.progress * targetPage.height)
  const targetScrollTop = targetAnchorY - (targetContainer.clientHeight / 2)

  return Math.max(0, Math.min(maxScroll, Math.round(targetScrollTop)))
}
