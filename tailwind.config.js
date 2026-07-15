module.exports = {
  plugins: [
    require('daisyui')
  ],
  daisyui: {
    themes: [
      {
        chs: {
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
      },
      {
        'chs-dark': {
          'color-scheme': 'dark',
          primary: '#1FA9E5',
          secondary: '#75C7E8',
          accent: '#A6CE39',
          neutral: '#1F4E79',
          'base-100': '#0F2F46',
          'base-200': '#0B263A',
          'base-300': '#173F5F',
          'base-content': '#F2FAFE',
          info: '#1FA9E5',
          success: '#A6CE39',
          warning: '#FBBF24',
          error: '#EF4444',
          '--rounded-btn': '1.9rem',
          '--tab-border': '2px',
          '--tab-radius': '.5rem'
        }
      }
    ]
  }
}