import type { ComponentChildren, JSX } from 'preact'
import { useEffect, useRef, useState } from 'preact/hooks'
import { useStore } from './hooks'

// Окна поверх экрана (как sheet в iOS): стек, верхнее показывается.
type Entry = { id: number; node: () => JSX.Element }
let stack: Entry[] = []
let nextId = 1
const listeners = new Set<() => void>()
const emit = () => listeners.forEach((l) => l())

export function openSheet(node: () => JSX.Element) { stack = [...stack, { id: nextId++, node }]; emit() }
export function closeSheet() { stack = stack.slice(0, -1); emit() }
export function replaceSheet(node: () => JSX.Element) { stack = [...stack.slice(0, -1), { id: nextId++, node }]; emit() }
export function closeAllSheets() { stack = []; emit() }

export function SheetHost() {
  useStore()
  const [, set] = useState(0)
  useEffect(() => { const l = () => set((x) => x + 1); listeners.add(l); return () => { listeners.delete(l) } }, [])
  return <>{stack.map((e, i) => <div key={e.id} class={`sheet-layer ${i === stack.length - 1 ? 'top' : ''}`}>{e.node()}</div>)}</>
}

export function Sheet(props: { title: string; onClose?: () => void; onSave?: () => void; saveTitle?: string; saveDisabled?: boolean; children: ComponentChildren; leftTitle?: string }) {
  const close = props.onClose ?? closeSheet
  const sheet = useRef<HTMLDivElement>(null)
  const backdrop = useRef<HTMLDivElement>(null)
  const body = useRef<HTMLDivElement>(null)
  const drag = useRef<{ y: number; t: number; dy: number; active: boolean; allowed: boolean } | null>(null)

  // Свайп вниз закрывает окно. Если содержимое прокручено, сначала оно прокручивается к началу.
  const onTouchStart = (e: TouchEvent) => {
    if (e.touches.length !== 1) { drag.current = null; return }
    const inHeader = !!(e.target as HTMLElement).closest('.sheet-header')
    const atTop = (body.current?.scrollTop ?? 0) <= 0
    drag.current = { y: e.touches[0].clientY, t: Date.now(), dy: 0, active: false, allowed: inHeader || atTop }
  }
  const onTouchMove = (e: TouchEvent) => {
    const d = drag.current
    if (!d || !d.allowed) return
    d.dy = e.touches[0].clientY - d.y
    if (!d.active) {
      if (d.dy < 8) { if (d.dy < -4) d.allowed = false; return }
      d.active = true
    }
    e.preventDefault()
    if (sheet.current) { sheet.current.style.transition = 'none'; sheet.current.style.transform = `translateY(${Math.max(0, d.dy)}px)` }
    if (backdrop.current) backdrop.current.style.background = `rgba(0, 0, 0, ${Math.max(0, 0.35 * (1 - d.dy / 500))})`
  }
  const onTouchEnd = () => {
    const d = drag.current
    drag.current = null
    if (!d || !d.active) return
    const fast = d.dy > 40 && d.dy / Math.max(1, Date.now() - d.t) > 0.6
    if (d.dy > 110 || fast) {
      if (sheet.current) { sheet.current.style.transition = 'transform 0.18s ease-in'; sheet.current.style.transform = 'translateY(100%)' }
      if (backdrop.current) { backdrop.current.style.transition = 'background 0.18s'; backdrop.current.style.background = 'rgba(0,0,0,0)' }
      setTimeout(close, 170)
    } else {
      if (sheet.current) { sheet.current.style.transition = 'transform 0.2s ease-out'; sheet.current.style.transform = '' }
      if (backdrop.current) backdrop.current.style.background = ''
    }
  }

  return (
    <div class="sheet-backdrop" ref={backdrop} onClick={(e) => { if (e.target === e.currentTarget) close() }}>
      <div class="sheet" role="dialog" aria-label={props.title} ref={sheet} onTouchStart={onTouchStart} onTouchMove={onTouchMove} onTouchEnd={onTouchEnd} onTouchCancel={onTouchEnd}>
        <div class="sheet-grabber" />
        <header class="sheet-header">
          <button class="link" onClick={close}>{props.leftTitle ?? (props.onSave ? 'Отмена' : 'Закрыть')}</button>
          <h2>{props.title}</h2>
          {props.onSave ? <button class="link strong" disabled={props.saveDisabled} onClick={props.onSave}>{props.saveTitle ?? 'Сохранить'}</button> : <span class="spacer" />}
        </header>
        <div class="sheet-body" ref={body}>{props.children}</div>
      </div>
    </div>
  )
}

// MARK: Всплывающие сообщения

let toastText: string | null = null
let toastTimer: number | undefined
const toastListeners = new Set<() => void>()
export function toast(text: string) {
  toastText = text
  toastListeners.forEach((l) => l())
  clearTimeout(toastTimer)
  toastTimer = window.setTimeout(() => { toastText = null; toastListeners.forEach((l) => l()) }, 4500)
}
export function ToastHost() {
  const [, set] = useState(0)
  useEffect(() => { const l = () => set((x) => x + 1); toastListeners.add(l); return () => { toastListeners.delete(l) } }, [])
  return toastText ? <div class="toast" onClick={() => { toastText = null; set((x) => x + 1) }}>{toastText}</div> : null
}
