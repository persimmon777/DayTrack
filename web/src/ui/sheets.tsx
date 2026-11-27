import type { ComponentChildren, JSX } from 'preact'
import { useEffect, useState } from 'preact/hooks'
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
  return (
    <div class="sheet-backdrop" onClick={(e) => { if (e.target === e.currentTarget) close() }}>
      <div class="sheet" role="dialog" aria-label={props.title}>
        <header class="sheet-header">
          <button class="link" onClick={close}>{props.leftTitle ?? (props.onSave ? 'Отмена' : 'Закрыть')}</button>
          <h2>{props.title}</h2>
          {props.onSave ? <button class="link strong" disabled={props.saveDisabled} onClick={props.onSave}>{props.saveTitle ?? 'Сохранить'}</button> : <span class="spacer" />}
        </header>
        <div class="sheet-body">{props.children}</div>
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
