import { useState } from 'preact/hooks'
import * as S from '../../data/store'
import type { Day, Task } from '../../data/model'
import { Card } from '../kit'
import { DayKey, duration, fmtTime, pluralDays, addDays, todayKey, fmtDay } from '../../core/time'
import { occurrences } from '../../core/periods'
import { ruleTitle } from '../../core/advisor'
import { openSheet } from '../sheets'
import { ReminderEditor, FocusStart } from '../sheets/more'
import { TaskEditor } from '../sheets/editors'

export function PlanStatusCard(props: { day?: Day; planned: number }) {
  const d = props.day
  const blocks = S.activeBlocks(d)
  const byCat = new Map<string, { name: string; color: string; minutes: number }>()
  for (const b of blocks) {
    const c = S.category(b.categoryId)
    const k = b.categoryId ?? 'none'
    const e = byCat.get(k) ?? { name: c?.name ?? 'Без категории', color: c?.color ?? '#95A5A6', minutes: 0 }
    e.minutes += Math.round((b.end - b.start) / 60000)
    byCat.set(k, e)
  }
  const items = [...byCat.values()].sort((a, b) => b.minutes - a.minutes)
  const total = Math.max(1, items.reduce((a, i) => a + i.minutes, 0))
  return (
    <Card>
      {d?.lockedAt != null ? (
        <>
          <div class="card-head"><b>🔒 План зафиксирован в {fmtTime(d.lockedAt)}</b>
            {S.canUnlock(d) && <button class="link small" onClick={() => S.unlock(d)}>Снять фиксацию</button>}</div>
          <p class="muted small">Запланировано {duration(props.planned)}. Правки остаются возможны и попадают в журнал.</p>
        </>
      ) : blocks.length ? (
        <>
          <div class="card-head"><b>✏️ План — черновик</b><button class="primary small" onClick={() => S.lock(d!)}>План готов</button></div>
          <p class="muted small">Запланировано {duration(props.planned)}. После фиксации правки будут видны в отчёте.</p>
        </>
      ) : <p class="muted">Плана на этот день пока нет. Нажми «+» или на шкалу.</p>}
      {items.length > 0 && (
        <>
          <div class="bar">{items.map((i) => <span style={{ background: i.color, width: `${(i.minutes / total) * 100}%` }} />)}</div>
          <div class="legend">{items.map((i) => <span><i style={{ background: i.color }} />{i.name} {duration(i.minutes)}</span>)}</div>
        </>
      )}
    </Card>
  )
}

export function FocusStrip(props: { dayKey: DayKey }) {
  const list = S.getState().focuses.filter((f) => S.focusAvailable(f, props.dayKey) && f.status === 'active')
    .sort((a, b) => (a.period === b.period ? a.order - b.order : a.period === 'week' ? -1 : 1))
  if (!list.length) return null
  return <div class="focus-strip">🎯 {list.map((f) => <span class={`pill ${f.period}`}>{f.title}</span>)}</div>
}

export function StreakLine() {
  const r = S.streak()
  if (!r.last30) return null
  return <div class="streak">🔥 {r.streak ? `Серия: ${pluralDays(r.streak)}` : 'Серия начнётся с сегодняшнего разбора'} <span class="muted">· за 30 дней: {r.last30}</span></div>
}

export function AdviceCard(props: { dayKey: DayKey; now: number }) {
  const st = S.getState()
  const items = S.adviceFor(props.dayKey, props.now)
  const [why, setWhy] = useState<string | null>(null)
  if (!items.length) return null
  const collapsed = st.settings.adviceCollapsed
  return (
    <Card class="advice">
      <div class="card-head tappable" onClick={() => { st.settings.adviceCollapsed = !collapsed; S.commit() }}>
        <b>💡 Подсказки: {items.length}</b><span class="muted">{collapsed ? '▾' : '▴'}</span>
      </div>
      {!collapsed && items.map((a) => (
        <div class="advice-item">
          <span class="muted small strong">{ruleTitle(a.rule)}</span>
          <p>{a.text}</p>
          {why === a.rule && <p class="muted small">{a.why}<br /><i>{a.basis}</i></p>}
          <div class="row-buttons">
            {a.action && <button class="primary small" onClick={() => S.applyAdvice(a.action!, props.dayKey)}>{a.actionTitle}</button>}
            <button class="secondary small" onClick={() => setWhy(why === a.rule ? null : a.rule)}>{why === a.rule ? 'Скрыть объяснение' : 'Почему?'}</button>
            <button class="link small muted push" onClick={() => S.dismissAdvice(a.rule, props.dayKey)}>Не сейчас</button>
          </div>
        </div>
      ))}
    </Card>
  )
}

export function ProjectNudge() {
  const p = S.getState().projects.filter((x) => !x.archived && !S.workedToday(x) && S.daysIdle(x) >= 1).sort((a, b) => a.order - b.order)[0]
  if (!p) return null
  const idle = S.daysIdle(p)
  return (
    <Card class="nudge">
      <b>↩️ {p.title}</b>
      <p class="small">{idle >= 2 ? `${idle} дн. без движения. Не нужно наверстывать — достаточно ${p.minimum} минут сегодня, чтобы цепочка снова началась.` : `Вчера не получилось — сегодня главное не пропустить второй день подряд. ${p.minimum} минут достаточно.`}</p>
      {p.ifThen && <p class="muted small">Твой план: {p.ifThen}</p>}
      <button class="primary small" onClick={() => openSheet(() => <FocusStart projectId={p.id} minutes={p.minimum} />)}>▶ {p.minimum} минут сейчас</button>
    </Card>
  )
}

export function RemindersCard(props: { dayKey: DayKey; showUpcoming: boolean }) {
  const st = S.getState()
  const today = st.reminders.filter((r) => occurrences(r.firstDay, r.repeat, props.dayKey, props.dayKey).length)
    .sort((a, b) => (a.minute ?? -1) - (b.minute ?? -1))
  const upcoming = props.showUpcoming
    ? st.reminders.flatMap((r) => occurrences(r.firstDay, r.repeat, addDays(props.dayKey, 1), addDays(props.dayKey, 7)).map((k) => ({ k, r })))
      .sort((a, b) => a.k - b.k || (a.r.minute ?? -1) - (b.r.minute ?? -1))
    : []
  if (!today.length && !upcoming.length) return null
  const time = (m: number | null) => (m === null ? 'весь день' : `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`)
  return (
    <Card>
      {today.length > 0 && <b>Напоминания</b>}
      {today.map((r) => <div class="list-row tappable" onClick={() => openSheet(() => <ReminderEditor reminder={r} dayKey={props.dayKey} />)}>🔔 {r.title} <span class="muted small">· {time(r.minute)}</span>{r.repeat !== 'none' && ' 🔁'}</div>)}
      {upcoming.length > 0 && <b class={today.length ? 'mt' : ''}>Скоро</b>}
      {upcoming.map(({ k, r }) => <div class="list-row tappable" onClick={() => openSheet(() => <ReminderEditor reminder={r} dayKey={props.dayKey} />)}>🔔 {r.title} <span class="muted small">· {k === addDays(todayKey(), 1) ? 'завтра' : fmtDay(k)} · {time(r.minute)}</span></div>)}
    </Card>
  )
}

export function TasksCard(props: { dayKey: DayKey; day?: Day }) {
  const [text, setText] = useState('')
  const tasks: Task[] = [...(props.day?.tasks ?? [])].sort((a, b) => a.order - b.order)
  const add = () => { const t = text.trim(); if (t) { S.addTask(props.dayKey, t); setText('') } }
  return (
    <Card>
      <div class="card-head"><b>Задачи без времени</b>{tasks.length > 0 && <span class="muted small">{tasks.filter((t) => t.done).length} из {tasks.length}</span>}</div>
      {tasks.map((t) => {
        const c = S.category(t.categoryId)
        return (
          <div class="task">
            <button class={`check ${t.done ? 'on' : ''}`} onClick={() => S.toggleTask(t)}>{t.done ? '✓' : ''}</button>
            <span class={`grow tappable ${t.done ? 'done' : ''}`} onClick={() => openSheet(() => <TaskEditor dayKey={props.dayKey} task={t} />)}>
              {c && <i class="dot" style={{ background: c.color }} />}{t.title}{t.estimate > 0 && <span class="muted small"> {duration(t.estimate)}</span>}
            </span>
          </div>
        )
      })}
      <div class="task"><span class="check ghost">+</span><input class="inline-input" value={text} placeholder="Новая задача" onInput={(e) => setText((e.target as HTMLInputElement).value)} onKeyDown={(e) => { if (e.key === 'Enter') add() }} onBlur={add} /></div>
    </Card>
  )
}

export function ChangesCard(props: { day?: Day }) {
  if (!props.day?.changes.length) return null
  return (
    <Card>
      <b>Правки плана после фиксации</b>
      {[...props.day.changes].sort((a, b) => a.at - b.at).map((c) => <div class="small list-row"><span class="muted">{fmtTime(c.at)}</span> {c.text}</div>)}
    </Card>
  )
}
