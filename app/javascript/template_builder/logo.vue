<template>
  <img
    :src="src"
    :alt="alt"
    class="w-9 h-9 md:w-12 md:h-12"
  >
</template>

<script>
export default {
  name: 'TemplateBuilderLogo',
  props: {
    src: {
      type: String,
      default: '/chs-icon.svg'
    },
    alt: {
      type: String,
      default: 'eDocument Centre'
    }
  }
}
</script>
