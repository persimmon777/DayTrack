import { defineConfig } from 'vite'
import preact from '@preact/preset-vite'

export default defineConfig({
  // Относительные пути: приложение открывается из подпапки GitHub Pages.
  base: './',
  plugins: [preact()],
  test: {
    environment: 'node',
    env: { TZ: 'Europe/Moscow' },
  },
})
