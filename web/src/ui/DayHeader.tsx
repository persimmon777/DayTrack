import { addDays, DayKey, fmtDay, todayKey } from '../core/time'

export function dayTitle(key: DayKey) {
  const t = todayKey()
  const f = fmtDay(key)
  if (key === t) return `Сегодня, ${f}`
  if (key === addDays(t, -1)) return `Вчера, ${f}`
  if (key === addDays(t, 1)) return `Завтра, ${f}`
  return f
}

/** Шапка с переключением дней. */
export function DayHeader(props: { dayKey: DayKey; onChange: (k: DayKey) => void; onCalendar?: () => void }) {
  const s = String(props.dayKey)
  const t = todayKey()
  return (
    <header class="topbar">
      <button class="icon-btn" aria-label="Предыдущий день" onClick={() => props.onChange(addDays(props.dayKey, -1))}>‹</button>
      <label class="day-title">
        {dayTitle(props.dayKey)}
        <input type="date" class="hidden-date" value={`${s.slice(0, 4)}-${s.slice(4, 6)}-${s.slice(6, 8)}`}
          onInput={(e) => { const v = (e.target as HTMLInputElement).value; if (v) props.onChange(Number(v.replace(/-/g, ''))) }} />
      </label>
      <div class="topbar-right">
        {props.onCalendar && <button class="icon-btn" aria-label="Календарь планов" onClick={props.onCalendar}>📅</button>}
        {props.dayKey !== t && <button class="link small" onClick={() => props.onChange(t)}>Сегодня</button>}
        <button class="icon-btn" aria-label="Следующий день" onClick={() => props.onChange(addDays(props.dayKey, 1))}>›</button>
      </div>
    </header>
  )
}
