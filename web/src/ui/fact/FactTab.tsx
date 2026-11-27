import * as S from '../../data/store'
import { DayHeader } from '../DayHeader'
import { Fab, Card, CategoryBadge, Empty } from '../kit'
import { openSheet } from '../sheets'
import { FactEditor } from '../sheets/editors'
import { EnergySheet, ReflectionSheet, RestStart, FocusStart, GameStart } from '../sheets/more'
import { SessionBanner } from '../SessionBanner'
import { addDays, DayKey, duration, fmtRange, fmtTime, minutesBetween, todayKey, windowOf } from '../../core/time'
import { reasonTitle } from '../../core/kinds'
import type { Fact } from '../../data/model'

export function FactTab(props: { dayKey: DayKey; setDayKey: (k: DayKey) => void }) {
  const { dayKey } = props
  const st = S.getState()
  const d = S.day(dayKey)
  const win = windowOf(dayKey)
  const own = [...(d?.facts ?? [])].sort((a, b) => a.start - b.start)
  const carried = [...(S.day(addDays(dayKey, -1))?.facts ?? [])].filter((f) => f.end > win.start).sort((a, b) => a.start - b.start)
  type RowT = { type: 'carried' | 'fact'; f: Fact } | { type: 'gap'; start: number; end: number }
  const rows: RowT[] = carried.map((f) => ({ type: 'carried' as const, f }))
  if (own.length) {
    let cursor = Math.max(win.start, ...carried.map((f) => f.end))
    for (const f of own) {
      if (f.start - cursor >= 60000) rows.push({ type: 'gap', start: cursor, end: f.start })
      rows.push({ type: 'fact', f })
      cursor = Math.max(cursor, f.end)
    }
  }
  const total = own.reduce((a, f) => a + minutesBetween(f.start, f.end), 0)
  const unplanned = own.filter((f) => !f.blockId).reduce((a, f) => a + minutesBetween(f.start, f.end), 0)
  const marks = st.energy.filter((m) => m.day === dayKey).sort((a, b) => a.at - b.at)
  const addNext = () => {
    const lastEnd = Math.max(win.start, ...own.map((f) => f.end), ...carried.map((f) => f.end))
    const start = Math.min(lastEnd, win.end - 300000)
    const rounded = Math.floor(Date.now() / 300000) * 300000
    const end = dayKey === todayKey() && rounded - start >= 300000 ? rounded : start + 3600000
    openSheet(() => <FactEditor dayKey={dayKey} start={start} end={end} />)
  }
  const factRow = (f: Fact, faded = false) => {
    const c = S.category(f.categoryId)
    const block = S.blockOf(f.blockId ? S.day(dayKey) ?? S.day(addDays(dayKey, -1)) : undefined, f.blockId)
    return (
      <div class={`fact-row ${faded ? 'faded' : 'tappable'}`} onClick={faded ? undefined : () => openSheet(() => <FactEditor dayKey={dayKey} fact={f} />)}>
        <CategoryBadge color={c?.color} symbol={c?.symbol} />
        <div class="stack grow"><span>{f.title}</span><span class="muted small">{block ? `по плану: ${block.title}` : `вне плана · ${reasonTitle(f.reason)}`}</span></div>
        <div class="stack right"><span class="mono small">{fmtRange(f.start, f.end)}</span><span class="muted small">{duration(minutesBetween(f.start, f.end))}</span></div>
      </div>
    )
  }
  return (
    <div class="tab">
      <DayHeader dayKey={dayKey} onChange={props.setDayKey} />
      <div class="content">
        <SessionBanner />
        {own.length > 0 && <Card><b>Отмечено {duration(total)}</b>{unplanned > 0 && <p class="muted small">Из них вне плана {duration(unplanned)}</p>}</Card>}
        <Card class="list">
          {!own.length && !carried.length && <Empty>Записей пока нет. Нажми «+», чтобы отметить, что ты делал.</Empty>}
          {rows.map((r) => r.type === 'gap'
            ? <div class="fact-row gap tappable" onClick={() => openSheet(() => <FactEditor dayKey={dayKey} start={r.start} end={r.end} />)}>
              <span class="gap-icon">＋</span><span class="grow">Не отмечено</span>
              <div class="stack right"><span class="mono small">{fmtRange(r.start, r.end)}</span><span class="small">{duration(minutesBetween(r.start, r.end))}</span></div>
            </div>
            : factRow(r.f, r.type === 'carried'))}
        </Card>
        {marks.length > 0 && (
          <Card>
            <b>Энергия и настроение</b>
            {marks.map((m) => <div class="list-row"><span class="muted mono">{fmtTime(m.at)}</span><span class="grow" />⚡ {m.energy} · 🙂 {m.mood}
              <button class="link small muted" onClick={() => { st.energy = st.energy.filter((x) => x.id !== m.id); S.commit() }}>✕</button></div>)}
          </Card>
        )}
        <button class="card link-row" onClick={() => openSheet(() => <ReflectionSheet dayKey={dayKey} />)}>
          {S.isReflectionEmpty(dayKey) ? '🌙 Вечерний разбор' : '✅ Вечерний разбор заполнен'}
        </button>
      </div>
      <Fab items={[
        { title: 'Запись факта', icon: '➕', onClick: addNext },
        { title: 'Только начать: 5 минут', icon: '🚶', onClick: () => openSheet(() => <FocusStart />) },
        { title: 'Начать отдых', icon: '☕', onClick: () => openSheet(() => <RestStart dayKey={dayKey} />) },
        { title: 'Игра по таймеру', icon: '🎮', onClick: () => openSheet(() => <GameStart />) },
        { title: 'Энергия и настроение', icon: '⚡', onClick: () => openSheet(() => <EnergySheet dayKey={dayKey} />) },
        { title: 'Вечерний разбор', icon: '🌙', onClick: () => openSheet(() => <ReflectionSheet dayKey={dayKey} />) },
      ]} />
    </div>
  )
}
