module.exports = {
  plugins: [
    require('daisyui')
  ],
  daisyui: {
    themes: [
      {
        docuseal: {
          'color-scheme': 'light',
          primary: '#1FA9E5',
          secondary: '#75C7E8',
          accent: '#A6CE39',
          neutral: '#1F4E79',
          'base-100': '#F7FAFC',
          'base-200': '#EEF3F7',
          'base-300': '#DCE8F1',
          'base-content': '#12324A',
          '--rounded-btn': '1.9rem',
          '--tab-border': '2px',
          '--tab-radius': '.5rem'
        }
      }
    ]
  }
}
