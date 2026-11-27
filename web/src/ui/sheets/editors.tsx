import { useState } from 'preact/hooks'
import { Sheet, closeSheet, replaceSheet } from '../sheets'
import { Group, Row, TextRow, TimeRow, DateRow, CategorySelect, FocusSelect, ReasonSelect, DurationChips, Toggle, Select, CategoryBadge } from '../kit'
import * as S from '../../data/store'
import type { Block, Fact, ID, Task } from '../../data/model'
import { DayKey, duration, endAfter, fmtRange, minuteOfDay, minutesBetween, resolve, windowOf } from '../../core/time'
import type { Reason } from '../../core/kinds'

const resolveMinute = (minute: number, key: DayKey) => resolve(Math.floor(minute / 60), minute % 60, key)

// MARK: Блок плана

export function BlockEditor(props: { dayKey: DayKey; block?: Block; start?: number }) {
  const b = props.block
  const initialStart = b?.start ?? props.start ?? resolveMinute(540, props.dayKey)
  const [title, setTitle] = useState(b?.title ?? '')
  const [categoryId, setCategoryId] = useState<ID | null>(b?.categoryId ?? null)
  const [chosen, setChosen] = useState(!!b?.categoryId)
  const [dayKey, setDayKey] = useState(props.dayKey)
  const [startMin, setStartMin] = useState(minuteOfDay(initialStart))
  const [endMin, setEndMin] = useState(minuteOfDay(b?.end ?? initialStart + 3600000))
  const [note, setNote] = useState(b?.note ?? '')
  const [focusId, setFocusId] = useState<ID | null>(b?.focusId ?? null)
  const [frog, setFrog] = useState(b?.isFrog ?? false)
  const d = S.day(props.dayKey)
  const locked = !!b && d?.lockedAt !== null && d?.lockedAt !== undefined
  const start = resolveMinute(startMin, dayKey)
  const end = endAfter(start, endMin)
  const cat = S.category(categoryId)
  const resolvedTitle = title.trim() || cat?.name || ''

  const onTitle = (v: string) => {
    setTitle(v)
    if (!chosen) { const m = S.matchCategory(v); if (m) setCategoryId(m.id) }
  }
  const save = () => {
    const input = { title: resolvedTitle, categoryId, start, end, note, focusId, isFrog: frog }
    if (b && d) S.updateBlock(d, b, input)
    else S.addBlock(dayKey, input)
    closeSheet()
  }
  return (
    <Sheet title={b ? 'Блок плана' : 'Новый блок'} onSave={save} saveDisabled={!resolvedTitle}>
      <Group footer={!title ? 'Название можно не писать: подставится название категории.' : !chosen && cat ? 'Категория подобрана по ключевым словам.' : undefined}>
        <TextRow value={title} onInput={onTitle} placeholder="Название" autofocus={!b} />
        <CategorySelect value={categoryId} onChange={(v) => { setCategoryId(v); setChosen(true) }} />
      </Group>
      <Group footer={end > windowOf(dayKey).end ? 'Блок заканчивается уже на следующий день.' : dayKey !== props.dayKey ? 'Блок попадёт в план другого дня. Так можно планировать заранее: например, приём у врача через неделю.' : undefined}>
        {!b && <DateRow label="День" value={dayKey} onChange={setDayKey} />}
        <TimeRow label="Начало" minute={startMin} onChange={setStartMin} />
        <TimeRow label="Конец" minute={endMin} onChange={setEndMin} />
        <DurationChips onPick={(m) => setEndMin((startMin + m) % 1440)} />
        <Row label="Длительность">{duration(minutesBetween(start, end))}</Row>
      </Group>
      <Group footer="Лягушка — самое сложное или неприятное дело дня. Его лучше ставить первым, пока есть силы.">
        <FocusSelect dayKey={dayKey} value={focusId} onChange={setFocusId} />
        <Toggle label="🐸 Лягушка дня" checked={frog} onChange={setFrog} />
      </Group>
      <Group title="Заметка"><TextRow value={note} onInput={setNote} placeholder="Необязательно" multiline /></Group>
      {locked && <Group><p class="muted small pad">План этого дня уже зафиксирован. Правка сохранится и будет отмечена в журнале правок.</p></Group>}
      {b && d && <Group><button class="danger-row" onClick={() => { if (confirm('Удалить блок?')) { S.deleteBlock(d, b); closeSheet() } }}>Удалить блок</button></Group>}
    </Sheet>
  )
}

export function BlockDetail(props: { dayKey: DayKey; blockId: ID }) {
  const d = S.day(props.dayKey)
  const b = S.blockOf(d, props.blockId)
  if (!d || !b) return <Sheet title="Блок плана"><p class="pad">Блок удалён.</p></Sheet>
  const cat = S.category(b.categoryId)
  const r = S.summary(d).status(b.id)
  const facts = d.facts.filter((f) => f.blockId === b.id).sort((x, y) => x.start - y.start)
  let status = ''
  if (r?.status === 'done') status = r.factMinutes - r.plannedMinutes > 15 ? `✅ Выполнено, заняло на ${duration(r.factMinutes - r.plannedMinutes)} больше` : '✅ Выполнено'
  else if (r?.status === 'partial') status = `◐ Частично: ${duration(r.factMinutes)} из ${duration(r.plannedMinutes)}`
  else if (r?.status === 'missed') status = '❌ Не выполнено'
  else status = '🕒 Ещё впереди'
  return (
    <Sheet title="Блок плана" leftTitle="Готово">
      <Group>
        <div class="row"><CategoryBadge color={cat?.color} symbol={cat?.symbol} size={36} /><div class="stack"><b>{b.isFrog ? '🐸 ' : ''}{b.title}</b><span class="muted small">{fmtRange(b.start, b.end)} · {duration(minutesBetween(b.start, b.end))}</span></div></div>
        {b.note && <div class="row">{b.note}</div>}
        <div class="row">{status}</div>
        {r?.isShifted && r.startShiftMinutes !== null && <div class="row muted small">{r.startShiftMinutes > 0 ? `Начато позже на ${duration(r.startShiftMinutes)}` : `Начато раньше на ${duration(-r.startShiftMinutes)}`}</div>}
      </Group>
      <Group title="Факт">
        {facts.map((f) => <Row onClick={() => replaceSheet(() => <FactEditor dayKey={props.dayKey} fact={f} />)} chevron label={fmtRange(f.start, f.end)}>{duration(minutesBetween(f.start, f.end))}</Row>)}
        <button class="link-row" onClick={() => replaceSheet(() => <FactEditor dayKey={props.dayKey} block={b} />)}>＋ {facts.length ? 'Внести ещё одну запись' : 'Внести факт'}</button>
      </Group>
      {!facts.length && (
        <Group footer="Если блок не получился, выбери причину. Это не упрёк, а данные: по ним видно, что мешает чаще всего.">
          <ReasonSelect label="Не сделал" value={b.missReason} onChange={(v) => S.markMissed(b, v)} noneTitle="Не отмечено" />
        </Group>
      )}
      <Group>
        <button class="link-row" onClick={() => replaceSheet(() => <BlockEditor dayKey={props.dayKey} block={b} />)}>✏️ Изменить блок</button>
        <button class="danger-row" onClick={() => { if (confirm('Удалить блок?')) { S.deleteBlock(d, b); closeSheet() } }}>Удалить блок</button>
      </Group>
    </Sheet>
  )
}

// MARK: Факт

function suggestBlock(blocks: Block[], start: number, end: number): Block | undefined {
  let best: Block | undefined, overlap = 0
  for (const b of blocks) { const o = Math.min(end, b.end) - Math.max(start, b.start); if (o > overlap) { overlap = o; best = b } }
  return best
}

export function FactEditor(props: { dayKey: DayKey; fact?: Fact; block?: Block; start?: number; end?: number }) {
  const f = props.fact
  const d = S.day(props.dayKey)
  const blocks = S.activeBlocks(d).sort((a, b) => a.start - b.start)
  const s0 = f?.start ?? props.start ?? props.block?.start ?? windowOf(props.dayKey).start
  const e0 = f?.end ?? props.end ?? props.block?.end ?? s0 + 3600000
  const [startMin, setStartMin] = useState(minuteOfDay(s0))
  const [endMin, setEndMin] = useState(minuteOfDay(e0))
  const start = resolveMinute(startMin, props.dayKey)
  const end = endAfter(start, endMin)
  const initialBlock = f ? S.blockOf(d, f.blockId) : props.block ?? suggestBlock(blocks, s0, e0)
  const [blockId, setBlockId] = useState<ID | null>(initialBlock?.id ?? null)
  const [blockChosen, setBlockChosen] = useState(!!f || !!props.block)
  const [title, setTitle] = useState(f?.title ?? '')
  const [categoryId, setCategoryId] = useState<ID | null>(f?.categoryId ?? initialBlock?.categoryId ?? null)
  const [catChosen, setCatChosen] = useState(!!f)
  const [reason, setReason] = useState<Reason | null>(f?.reason ?? null)
  const [note, setNote] = useState(f?.note ?? '')
  const [focusId, setFocusId] = useState<ID | null>(f?.focusId ?? null)
  const block = blocks.find((b) => b.id === blockId) ?? (f ? S.blockOf(d, blockId) : undefined)
  const fallback = block?.title ?? S.category(categoryId)?.name ?? ''
  const resolvedTitle = title.trim() || fallback
  const unplanned = !blockId

  const recalc = (sMin: number, eMin: number, t = title, bChosen = blockChosen) => {
    let bid = blockId
    if (!bChosen) {
      const st = resolveMinute(sMin, props.dayKey)
      bid = suggestBlock(blocks, st, endAfter(st, eMin))?.id ?? null
      setBlockId(bid)
    }
    if (!catChosen) {
      const m = t.trim() ? S.matchCategory(t) : undefined
      setCategoryId(m?.id ?? blocks.find((b) => b.id === bid)?.categoryId ?? null)
    }
  }
  const save = () => {
    const input = { title: resolvedTitle, categoryId, start, end, reason: reason ?? (unplanned ? 'other' as Reason : null), note, blockId, focusId }
    if (f && d) S.updateFact(d, f, input)
    else S.addFact(props.dayKey, input)
    closeSheet()
  }
  return (
    <Sheet title={f ? 'Запись факта' : 'Новая запись'} onSave={save} saveDisabled={!resolvedTitle}>
      <Group>
        <TimeRow label="Начало" minute={startMin} onChange={(m) => { setStartMin(m); recalc(m, endMin) }} />
        <TimeRow label="Конец" minute={endMin} onChange={(m) => { setEndMin(m); recalc(startMin, m) }} />
        <DurationChips onPick={(m) => { const e = (startMin + m) % 1440; setEndMin(e); recalc(startMin, e) }} />
        <Row label="Длительность">{duration(minutesBetween(start, end))}</Row>
      </Group>
      <Group footer={blocks.length && !blockChosen ? 'Блок плана подобран по времени. Если делал другое, выбери «Вне плана».' : undefined}>
        <TextRow value={title} onInput={(v) => { setTitle(v); recalc(startMin, endMin, v) }} placeholder={fallback || 'Что делал'} />
        <CategorySelect value={categoryId} onChange={(v) => { setCategoryId(v); setCatChosen(true) }} />
        {blocks.length > 0 && <Select label="По плану" value={blockId} onChange={(v) => { setBlockId(v); setBlockChosen(true); if (!catChosen) setCategoryId((title.trim() && S.matchCategory(title)?.id) || blocks.find((b) => b.id === v)?.categoryId || null) }}
          options={[{ value: null, title: 'Вне плана' }, ...blocks.map((b) => ({ value: b.id as ID | null, title: `${fmtRange(b.start, b.end).slice(0, 5)} ${b.title}` }))]} />}
      </Group>
      <Group><FocusSelect dayKey={props.dayKey} value={focusId} onChange={setFocusId} noneTitle={block?.focusId ? 'Как у блока плана' : 'Без фокуса'} /></Group>
      <Group title={unplanned ? 'Почему это появилось' : 'Если пошло не по плану'} footer={unplanned ? 'Необязательно. Если причину не выбрать, сохранится «Другое».' : undefined}>
        <ReasonSelect value={reason} onChange={setReason} noneTitle="Не указывать" />
        <TextRow value={note} onInput={setNote} placeholder="Заметка, необязательно" multiline />
      </Group>
      {f && d && <Group><button class="danger-row" onClick={() => { if (confirm('Удалить запись?')) { S.deleteFact(d, f); closeSheet() } }}>Удалить запись</button></Group>}
    </Sheet>
  )
}

// MARK: Задача без времени

export function TaskEditor(props: { dayKey: DayKey; task: Task }) {
  const t = props.task
  const [title, setTitle] = useState(t.title)
  const [categoryId, setCategoryId] = useState<ID | null>(t.categoryId)
  const [estimate, setEstimate] = useState(t.estimate)
  const [done, setDone] = useState(t.done)
  const [focusId, setFocusId] = useState<ID | null>(t.focusId)
  const save = () => { Object.assign(t, { title: title.trim() || 'Задача', categoryId, estimate, done, focusId }); S.commit(); closeSheet() }
  const d = S.day(props.dayKey)
  return (
    <Sheet title="Задача" onSave={save} saveTitle="Готово">
      <Group footer="Оценка времени пригодится советчику: он сравнит её с тем, сколько уходит на самом деле.">
        <TextRow value={title} onInput={setTitle} placeholder="Название" />
        <CategorySelect value={categoryId} onChange={setCategoryId} />
        <Select label="Займёт примерно" value={estimate} onChange={setEstimate} options={[0, 10, 15, 30, 45, 60, 90, 120, 180].map((m) => ({ value: m, title: m ? duration(m) : 'Не знаю' }))} />
        <Toggle label="Сделано" checked={done} onChange={setDone} />
        <FocusSelect dayKey={props.dayKey} value={focusId} onChange={setFocusId} />
      </Group>
      {d && <Group><button class="danger-row" onClick={() => { if (confirm('Удалить задачу?')) { S.deleteTask(d, t); closeSheet() } }}>Удалить задачу</button></Group>}
    </Sheet>
  )
}

