import type { ComponentChildren, JSX } from 'preact'
import { useState } from 'preact/hooks'
import { getState, focusAvailable } from '../data/store'
import type { ID } from '../data/model'
import { reasons, Reason } from '../core/kinds'
import { DayKey, duration } from '../core/time'

export function Card(props: { children: ComponentChildren; class?: string; style?: JSX.CSSProperties }) {
  return <section class={`card ${props.class ?? ''}`} style={props.style}>{props.children}</section>
}

export function Group(props: { title?: string; footer?: ComponentChildren; children: ComponentChildren }) {
  return (
    <div class="group">
      {props.title && <div class="group-title">{props.title}</div>}
      <div class="group-body">{props.children}</div>
      {props.footer && <div class="group-footer">{props.footer}</div>}
    </div>
  )
}

export function Row(props: { label?: ComponentChildren; children?: ComponentChildren; onClick?: () => void; chevron?: boolean; class?: string }) {
  return (
    <div class={`row ${props.onClick ? 'tappable' : ''} ${props.class ?? ''}`} onClick={props.onClick}>
      {props.label !== undefined && <span class="row-label">{props.label}</span>}
      <span class="row-value">{props.children}</span>
      {props.chevron && <span class="chevron">›</span>}
    </div>
  )
}

export function Toggle(props: { label: ComponentChildren; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label class="row toggle-row">
      <span class="row-label">{props.label}</span>
      <input type="checkbox" class="switch" checked={props.checked} onChange={(e) => props.onChange((e.target as HTMLInputElement).checked)} />
    </label>
  )
}

export function TextRow(props: { value: string; onInput: (v: string) => void; placeholder?: string; multiline?: boolean; autofocus?: boolean }) {
  return props.multiline
    ? <textarea class="row-input" rows={3} value={props.value} placeholder={props.placeholder} onInput={(e) => props.onInput((e.target as HTMLTextAreaElement).value)} />
    : <input class="row-input" value={props.value} placeholder={props.placeholder} autofocus={props.autofocus} onInput={(e) => props.onInput((e.target as HTMLInputElement).value)} />
}

export function Select<T extends string | number | null>(props: { label: ComponentChildren; value: T; options: { value: T; title: string }[]; onChange: (v: T) => void }) {
  const idx = Math.max(0, props.options.findIndex((o) => o.value === props.value))
  return (
    <label class="row">
      <span class="row-label">{props.label}</span>
      <select class="row-select" value={String(idx)} onChange={(e) => props.onChange(props.options[Number((e.target as HTMLSelectElement).value)].value)}>
        {props.options.map((o, i) => <option value={String(i)}>{o.title}</option>)}
      </select>
    </label>
  )
}

export function TimeRow(props: { label: string; minute: number; onChange: (m: number) => void }) {
  const v = `${String(Math.floor(props.minute / 60) % 24).padStart(2, '0')}:${String(props.minute % 60).padStart(2, '0')}`
  return (
    <label class="row">
      <span class="row-label">{props.label}</span>
      <input type="time" class="row-time" value={v} onInput={(e) => {
        const [h, m] = (e.target as HTMLInputElement).value.split(':').map(Number)
        if (!Number.isNaN(h)) props.onChange(h * 60 + (m || 0))
      }} />
    </label>
  )
}

export function DateRow(props: { label: string; value: DayKey; onChange: (k: DayKey) => void }) {
  const s = String(props.value)
  return (
    <label class="row">
      <span class="row-label">{props.label}</span>
      <input type="date" class="row-time" value={`${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6, 8)}`} onInput={(e) => {
        const v = (e.target as HTMLInputElement).value
        if (v) props.onChange(Number(v.replace(/-/g, '')))
      }} />
    </label>
  )
}

export function Stepper(props: { label: ComponentChildren; value: number; step: number; min: number; max: number; onChange: (v: number) => void; format?: (v: number) => string }) {
  return (
    <div class="row">
      <span class="row-label">{props.label}</span>
      <span class="row-value stepper">
        <span class="muted">{props.format ? props.format(props.value) : props.value}</span>
        <button class="step" onClick={() => props.onChange(Math.max(props.min, props.value - props.step))}>−</button>
        <button class="step" onClick={() => props.onChange(Math.min(props.max, props.value + props.step))}>+</button>
      </span>
    </div>
  )
}

export function Segmented<T extends string | number>(props: { value: T; options: { value: T; title: string }[]; onChange: (v: T) => void }) {
  return (
    <div class="segmented">
      {props.options.map((o) => <button class={o.value === props.value ? 'on' : ''} onClick={() => props.onChange(o.value)}>{o.title}</button>)}
    </div>
  )
}

export function CategoryBadge(props: { color?: string; symbol?: string; size?: number }) {
  const size = props.size ?? 28
  return <span class="badge" style={{ background: props.color ?? '#7F8C8D', width: size, height: size, fontSize: size * 0.55 }}>{props.symbol ?? '⚪'}</span>
}

export function CategorySelect(props: { value: ID | null; onChange: (id: ID | null) => void }) {
  const cats = getState().categories.filter((c) => !c.archived || c.id === props.value).sort((a, b) => a.order - b.order)
  return <Select label="Категория" value={props.value} onChange={props.onChange}
    options={[{ value: null, title: 'Без категории' }, ...cats.map((c) => ({ value: c.id as ID | null, title: `${c.symbol} ${c.name}` }))]} />
}

export function FocusSelect(props: { dayKey: DayKey; value: ID | null; onChange: (id: ID | null) => void; noneTitle?: string }) {
  const options = getState().focuses.filter((f) => focusAvailable(f, props.dayKey) || f.id === props.value)
    .sort((a, b) => (a.period === b.period ? a.order - b.order : a.period === 'week' ? -1 : 1))
  if (!options.length) return null
  return <Select label="Фокус" value={props.value} onChange={props.onChange}
    options={[{ value: null, title: props.noneTitle ?? 'Без фокуса' }, ...options.map((f) => ({ value: f.id as ID | null, title: `${f.period === 'week' ? 'Неделя' : 'Месяц'}: ${f.title}` }))]} />
}

export function ReasonSelect(props: { value: Reason | null; onChange: (r: Reason | null) => void; noneTitle: string; label?: string }) {
  return <Select label={props.label ?? 'Причина'} value={props.value} onChange={props.onChange}
    options={[{ value: null, title: props.noneTitle }, ...reasons.map((r) => ({ value: r.id as Reason | null, title: r.title }))]} />
}

export function DurationChips(props: { onPick: (minutes: number) => void }) {
  return (
    <div class="chips">
      {[15, 30, 45, 60, 90, 120].map((m) => <button class="chip" onClick={() => props.onPick(m)}>{m === 90 ? '1,5 ч' : duration(m)}</button>)}
    </div>
  )
}

export function ScalePicker(props: { value: number; onChange: (v: number) => void; low: string; high: string }) {
  return (
    <div class="scale">
      <div class="scale-buttons">{[1, 2, 3, 4, 5].map((l) => <button class={l === props.value ? 'on' : ''} onClick={() => props.onChange(l)}>{l}</button>)}</div>
      <div class="scale-labels"><span>{props.low}</span><span>{props.high}</span></div>
    </div>
  )
}

export function Fab(props: { items: { title: string; icon: string; onClick: () => void; divider?: boolean }[] }) {
  const [open, setOpen] = useState(false)
  return (
    <>
      {open && <div class="fab-backdrop" onClick={() => setOpen(false)} />}
      {open && (
        <div class="fab-menu">
          {props.items.map((i) => (
            <>
              {i.divider && <div class="fab-divider" />}
              <button onClick={() => { setOpen(false); i.onClick() }}><span class="fab-icon">{i.icon}</span>{i.title}</button>
            </>
          ))}
        </div>
      )}
      <button class="fab" aria-label="Добавить" onClick={() => setOpen(!open)}>{open ? '×' : '+'}</button>
    </>
  )
}

export function Empty(props: { children: ComponentChildren }) {
  return <p class="empty">{props.children}</p>
}
