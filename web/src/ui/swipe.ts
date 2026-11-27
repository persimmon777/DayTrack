import { useEffect, useRef } from 'preact/hooks'

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
      if (e.touches.length !== 1 || e.touches[0].clientX <= EDGE) { start.current = null; return }
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

/** Ширина полосы у левого края, с которой начинается жест «назад» (как в iOS). */
export const EDGE = 28

/**
 * «Назад» свайпом вправо от левого края: экран едет за пальцем,
 * если отпустить дальше трети ширины или быстро — вызывается `onBack`, иначе возвращается на место.
 */
export function useEdgeBack(onBack: (() => void) | null) {
  const ref = useRef<HTMLDivElement>(null)
  const back = useRef(onBack)
  back.current = onBack
  useEffect(() => {
    if (!onBack) return
    let start: { x: number; y: number; t: number } | null = null
    let active = false
    const el = () => ref.current
    const reset = (animate: boolean) => {
      const e = el()
      if (!e) return
      e.style.transition = animate ? 'transform 0.2s ease-out' : ''
      e.style.transform = ''
    }
    const down = (ev: TouchEvent) => {
      if (ev.touches.length !== 1 || ev.touches[0].clientX > EDGE || document.querySelector('.sheet-layer')) { start = null; return }
      start = { x: ev.touches[0].clientX, y: ev.touches[0].clientY, t: Date.now() }
      active = false
    }
    const move = (ev: TouchEvent) => {
      if (!start) return
      const dx = ev.touches[0].clientX - start.x
      const dy = ev.touches[0].clientY - start.y
      if (!active) {
        if (Math.abs(dy) > 12 && Math.abs(dy) > dx) { start = null; return }
        if (dx < 10) return
        active = true
      }
      ev.preventDefault()
      const e = el()
      if (e) { e.style.transition = 'none'; e.style.transform = `translateX(${Math.max(0, dx)}px)` }
    }
    const up = (ev: TouchEvent) => {
      if (!start) return
      const dx = (ev.changedTouches[0]?.clientX ?? start.x) - start.x
      const fast = dx > 40 && dx / Math.max(1, Date.now() - start.t) > 0.5
      start = null
      if (!active) return
      active = false
      if (dx > window.innerWidth / 3 || fast) {
        const e = el()
        if (e) { e.style.transition = 'transform 0.18s ease-out'; e.style.transform = 'translateX(100%)' }
        setTimeout(() => { reset(false); back.current?.() }, 180)
      } else reset(true)
    }
    window.addEventListener('touchstart', down, { passive: true })
    window.addEventListener('touchmove', move, { passive: false })
    window.addEventListener('touchend', up)
    window.addEventListener('touchcancel', up)
    return () => {
      window.removeEventListener('touchstart', down)
      window.removeEventListener('touchmove', move)
      window.removeEventListener('touchend', up)
      window.removeEventListener('touchcancel', up)
      reset(false)
    }
  }, [!!onBack])
  return ref
}
