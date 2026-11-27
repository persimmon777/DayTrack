import { render } from 'preact'
import { App } from './ui/App'
import { startScheduler } from './data/notifications'
import { persist } from './data/store'
import './styles.css'

render(<App />, document.getElementById('app')!)

// Запрет увеличения: щипок двумя пальцами и двойное касание.
// Safari в обычной вкладке может игнорировать запрет из meta viewport, поэтому жесты гасятся и здесь.
const stop = (e: Event) => e.preventDefault()
document.addEventListener('gesturestart', stop, { passive: false })
document.addEventListener('gesturechange', stop, { passive: false })
document.addEventListener('gestureend', stop, { passive: false })
document.addEventListener('touchmove', (e) => { if (e.touches.length > 1) e.preventDefault() }, { passive: false })
let lastTouchEnd = 0
document.addEventListener('touchend', (e) => {
  const now = Date.now()
  const target = e.target as HTMLElement
  // Быстрое второе касание приближало бы страницу; поля ввода не трогаем, чтобы работал выбор текста.
  if (now - lastTouchEnd < 300 && !target.closest('input, textarea, select')) e.preventDefault()
  lastTouchEnd = now
}, { passive: false })

// Сохранение при уходе со страницы и просьба браузеру не удалять данные.
document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'hidden') persist() })
window.addEventListener('pagehide', persist)
navigator.storage?.persist?.().catch(() => {})

startScheduler()

if ('serviceWorker' in navigator && import.meta.env.PROD) {
  navigator.serviceWorker.register('./sw.js').catch(() => {})
}
