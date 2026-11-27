import { render } from 'preact'
import { App } from './ui/App'
import { startScheduler } from './data/notifications'
import { persist } from './data/store'
import './styles.css'

render(<App />, document.getElementById('app')!)

// Сохранение при уходе со страницы и просьба браузеру не удалять данные.
document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'hidden') persist() })
window.addEventListener('pagehide', persist)
navigator.storage?.persist?.().catch(() => {})

startScheduler()

if ('serviceWorker' in navigator && import.meta.env.PROD) {
  navigator.serviceWorker.register('./sw.js').catch(() => {})
}
