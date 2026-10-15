export const downloadUrls = (urls) => {
  const fileRequests = urls.map((url) => {
    return () => {
      return fetch(url).then(async (resp) => {
        const blobUrl = URL.createObjectURL(await resp.blob())
        const link = document.createElement('a')

        link.href = blobUrl
        link.setAttribute('download', decodeURI(url.split('/').pop()))

        document.body.appendChild(link)
        link.click()
        document.body.removeChild(link)

        URL.revokeObjectURL(blobUrl)
      })
    }
  })

  return fileRequests.reduce(
    (acc, r) => acc.then(r),
    Promise.resolve()
  )
}
