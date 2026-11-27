import { useRef } from 'preact/hooks'

/**
 * Горизонтальный свайп: влево — `onNext`, вправо — `onPrev`.
 * Вертикальная прокрутка не мешает: свайп засчитывается, только если движение в основном горизонтальное.
 * После свайпа ближайшее нажатие гасится, чтобы не открылся день под пальцем.
 */
export function useSwipe(onPrev: () => void, onNext: () => void) {
  const start = useRef<{ x: number; y: number; t: number } | null>(null)
  const swipedAt = useRef(0)
  return {
    onTouchStart: (e: TouchEvent) => {
      if (e.touches.length !== 1) { start.current = null; return }
      start.current = { x: e.touches[0].clientX, y: e.touches[0].clientY, t: Date.now() }
    },
    onTouchEnd: (e: TouchEvent) => {
      const s = start.current
      start.current = null
      if (!s || !e.changedTouches.length) return
      const dx = e.changedTouches[0].clientX - s.x
      const dy = e.changedTouches[0].clientY - s.y
      if (Math.abs(dx) < 50 || Math.abs(dx) < Math.abs(dy) * 1.5 || Date.now() - s.t > 800) return
      swipedAt.current = Date.now()
      if (dx < 0) onNext()
      else onPrev()
    },
    onClickCapture: (e: MouseEvent) => {
      if (Date.now() - swipedAt.current < 400) { e.stopPropagation(); e.preventDefault() }
    },
  }
}
