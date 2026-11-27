import { useEffect, useState } from 'preact/hooks'
import * as S from '../../data/store'
import { openSheet } from '../sheets'
import { BlockEditor } from '../sheets/editors'
import { ReminderEditor } from '../sheets/more'
import { DayKey, fmtDay, fmtMonth, fmtTime, resolve, todayKey, windowOf } from '../../core/time'
import { daysIn, occurs, periodRange, shiftPeriod } from '../../core/periods'

interface Entry { id: string; start: number | null; title: string; color: string; reminder: boolean; rule: boolean }

function entries(key: DayKey): Entry[] {
  const st = S.getState()
  const d = st.days[key]
  const out: Entry[] = S.activeBlocks(d).map((b) => ({ id: b.id, start: b.start, title: b.title, color: S.category(b.categoryId)?.color ?? '#7F8C8D', reminder: false, rule: false }))
  if (key >= todayKey() && !d?.scheduleApplied && !d?.lockedAt) {
    for (const r of S.rulesFor(key)) out.push({ id: `rule-${r.id}`, start: resolve(Math.floor(r.startMinute / 60), r.startMinute % 60, key), title: r.title, color: S.category(r.categoryId)?.color ?? '#7F8C8D', reminder: false, rule: true })
  }
  for (const r of st.reminders) if (occurs(key, r.firstDay, r.repeat)) out.push({ id: `rem-${r.id}`, start: r.minute === null ? null : resolve(Math.floor(r.minute / 60), r.minute % 60, key), title: r.title, color: '#F0932B', reminder: true, rule: false })
  return out.sort((a, b) => (a.start ?? 0) - (b.start ?? 0))
}

/** Календарь планов: над числом — сколько дел, под ним — начало первых двух. */
export function PlanCalendar(props: { dayKey: DayKey; onOpenDay: (k: DayKey) => void; onClose: () => void }) {
  const [month, setMonth] = useState(props.dayKey)
  const [selected, setSelected] = useState(props.dayKey)
  useEffect(() => window.scrollTo(0, 0), [])
  const range = periodRange('month', month)
  const keys = daysIn(range)
  const blanks = (new Date(Math.floor(range[0] / 10000), Math.floor(range[0] / 100) % 100 - 1, 1).getDay() + 6) % 7
  const today = todayKey()
  const sel = entries(selected)
  const nextStart = () => {
    const last = Math.max(0, ...S.activeBlocks(S.day(selected)).map((b) => b.end))
    return last && last < windowOf(selected).end ? last : resolve(9, 0, selected)
  }
  return (
    <div class="tab">
      <header class="topbar">
        <button class="link" onClick={props.onClose}>Закрыть</button>
        <span class="day-title">{fmtMonth(month)}</span>
        <div class="topbar-right">
          <button class="icon-btn" onClick={() => setMonth(shiftPeriod(month, 'month', -1))}>‹</button>
          <button class="icon-btn" onClick={() => setMonth(shiftPeriod(month, 'month', 1))}>›</button>
        </div>
      </header>
      <div class="content">
        <div class="cal-grid">
          {['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'].map((w) => <span class="cal-wd">{w}</span>)}
          {Array.from({ length: blanks }, () => <span />)}
          {keys.map((k) => {
            const e = entries(k)
            const timed = e.filter((x) => x.start !== null && !x.reminder)
            return (
              <button class={`cal-cell ${k === selected ? 'sel' : ''} ${k === today ? 'today' : ''} ${k < today ? 'past' : ''}`} onClick={() => setSelected(k)}>
                <span class="cal-count">{e.length || ''}</span>
                <span class="cal-num">{k % 100}</span>
                <span class="cal-times">
                  {timed.slice(0, 2).map((x) => <span style={{ color: x.color }}>{fmtTime(x.start!)}</span>)}
                  {e.some((x) => x.reminder) && timed.length < 2 && <span class="bell">🔔</span>}
                </span>
              </button>
            )
          })}
        </div>
        <section class="card">
          <div class="card-head"><b>{fmtDay(selected)}</b><button class="link small" onClick={() => props.onOpenDay(selected)}>Открыть день</button></div>
          {!sel.length && <p class="muted small">На этот день ничего не запланировано.</p>}
          {sel.map((x) => (
            <div class="list-row">
              {x.reminder ? '🔔' : <i class="dot" style={{ background: x.color }} />}
              <span class="muted mono">{x.start === null ? 'весь день' : fmtTime(x.start)}</span> {x.title} {x.rule && <span class="muted small">· расписание</span>}
            </div>
          ))}
          <div class="row-buttons">
            <button class="primary small" onClick={() => openSheet(() => <BlockEditor dayKey={selected} start={nextStart()} />)}>＋ Блок плана</button>
            <button class="secondary small" onClick={() => openSheet(() => <ReminderEditor dayKey={selected} />)}>🔔 Напоминание</button>
          </div>
        </section>
      </div>
    </div>
  )
}
