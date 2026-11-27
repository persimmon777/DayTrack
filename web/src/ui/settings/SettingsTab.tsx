import { useState } from 'preact/hooks'
import type { JSX } from 'preact'
import * as S from '../../data/store'
import type { Category, ScheduleRule, Template, Theme } from '../../data/model'
import { uid } from '../../data/model'
import { Group, Row, TextRow, Select, Toggle, TimeRow, DateRow, Stepper, CategorySelect, CategoryBadge, Empty } from '../kit'
import { openSheet, closeSheet, Sheet, toast } from '../sheets'
import { ReminderEditor } from '../sheets/more'
import { categoryKinds, kindTitle, CategoryKind } from '../../core/kinds'
import { parities, WeekParity, occurrences, weekNumber } from '../../core/periods'
import { adviceRules } from '../../core/advisor'
import { parseKeywords } from '../../core/keywords'
import { duration, fmtDay, fmtMinute, todayKey, addDays } from '../../core/time'
import { palette, symbols, defaultPrompt } from '../../data/defaults'
import { exportSnapshot, importSnapshot, summaryOf, backupFileName } from '../../data/backup'
import { buildIcs, permission, requestPermission, notificationsSupported } from '../../data/notifications'
import { useEdgeBack } from '../swipe'

type Page = 'categories' | 'schedule' | 'templates' | 'reminders' | 'notifications' | 'target' | 'games' | 'advisor' | 'theme' | 'prompt' | 'backup' | 'install'
const titles: Record<Page, string> = {
  categories: 'Категории', schedule: 'Расписание', templates: 'Шаблоны дня', reminders: 'Напоминания', notifications: 'Уведомления',
  target: 'Цель баланса', games: 'Игры', advisor: 'Советчик', theme: 'Оформление', prompt: 'Запрос для нейросети', backup: 'Резервные копии', install: 'Установка на iPhone',
}

export function SettingsTab() {
  const [page, setPage] = useState<Page | null>(null)
  const backRef = useEdgeBack(page ? () => setPage(null) : null)
  if (page) {
    const Body = pages[page]
    return (
      <div class="tab" ref={backRef}>
        <header class="topbar"><button class="link" onClick={() => setPage(null)}>‹ Настройки</button><span class="day-title">{titles[page]}</span><span class="spacer" /></header>
        <div class="content"><Body /></div>
      </div>
    )
  }
  const item = (p: Page, icon: string) => <Row onClick={() => setPage(p)} chevron label={`${icon}  ${titles[p]}`} />
  return (
    <div class="tab">
      <header class="topbar"><span class="spacer" /><span class="day-title">Настройки</span><span class="spacer" /></header>
      <div class="content">
        <Group title="План">{item('categories', '🗂️')}{item('schedule', '🗓️')}{item('templates', '📋')}{item('reminders', '🔔')}</Group>
        <Group title="Подсказки и вид">{item('advisor', '💡')}{item('theme', '🎨')}</Group>
        <Group title="Напоминания и игры">{item('notifications', '🔕')}{item('target', '🥧')}{item('games', '🎮')}</Group>
        <Group title="Аналитика">{item('prompt', '💬')}</Group>
        <Group title="Данные">{item('backup', '💾')}{item('install', '📱')}</Group>
        <p class="muted small pad">DayTrack, веб-версия. Данные хранятся только в этом браузере на этом устройстве.</p>
      </div>
    </div>
  )
}

// MARK: Категории

function Categories() {
  const st = S.getState()
  const active = st.categories.filter((c) => !c.archived).sort((a, b) => a.order - b.order)
  const archived = st.categories.filter((c) => c.archived)
  const move = (c: Category, dir: number) => {
    const i = active.indexOf(c), j = i + dir
    if (j < 0 || j >= active.length) return
    ;[active[i].order, active[j].order] = [active[j].order, active[i].order]
    S.commit()
  }
  return (
    <>
      <Group footer="Категорию, которая уже использовалась, удалить нельзя: она уходит в архив, а старые записи сохраняют её название и цвет.">
        {active.map((c) => (
          <div class="row">
            <span class="grow tappable cat-line" onClick={() => openSheet(() => <CategoryEditor category={c} />)}>
              <CategoryBadge color={c.color} symbol={c.symbol} />
              <span class="stack"><span>{c.name}</span><span class="muted small ellipsis">{kindTitle(c.kind)}{c.keywords ? ` · ${parseKeywords(c.keywords).slice(0, 4).join(', ')}` : ''}</span></span>
            </span>
            <button class="link small" onClick={() => move(c, -1)}>↑</button><button class="link small" onClick={() => move(c, 1)}>↓</button>
          </div>
        ))}
        <button class="link-row" onClick={() => openSheet(() => <CategoryEditor />)}>＋ Новая категория</button>
      </Group>
      {archived.length > 0 && <Group title="Архив">{archived.map((c) => <Row label={`${c.symbol} ${c.name}`}><button class="link small" onClick={() => { c.archived = false; c.order = st.categories.length; S.commit() }}>Вернуть</button></Row>)}</Group>}
    </>
  )
}

function CategoryEditor(props: { category?: Category }) {
  const c = props.category
  const [name, setName] = useState(c?.name ?? '')
  const [kind, setKind] = useState<CategoryKind>(c?.kind ?? 'study')
  const [color, setColor] = useState(c?.color ?? palette[0])
  const [symbol, setSymbol] = useState(c?.symbol ?? symbols[0])
  const [keywords, setKeywords] = useState(c?.keywords ?? '')
  const save = () => {
    const st = S.getState()
    if (c) Object.assign(c, { name: name.trim(), kind, color, symbol, keywords })
    else st.categories.push({ id: uid(), name: name.trim(), kind, color, symbol, keywords, archived: false, order: Math.max(-1, ...st.categories.map((x) => x.order)) + 1 })
    S.commit(); closeSheet()
  }
  const remove = () => {
    if (!c || !confirm('Удалить категорию?')) return
    if (S.categoryInUse(c.id)) c.archived = true
    else S.getState().categories = S.getState().categories.filter((x) => x.id !== c.id)
    S.commit(); closeSheet()
  }
  return (
    <Sheet title={c ? 'Категория' : 'Новая категория'} onSave={save} saveDisabled={!name.trim()}>
      <Group footer="По типу считается баланс: например, «Пары» и «Самообразование» вместе идут в учёбу.">
        <div class="row"><CategoryBadge color={color} symbol={symbol} size={36} /><input class="row-input grow" value={name} placeholder="Название" onInput={(e) => setName((e.target as HTMLInputElement).value)} /></div>
        <Select label="Тип" value={kind} onChange={setKind} options={categoryKinds.map((k) => ({ value: k.id, title: k.title }))} />
      </Group>
      <Group title="Ключевые слова" footer="Через запятую. Если слово есть в названии дела, категория выберется сама. Окончания можно не писать: «трениров» подходит к «тренировка» и «тренировки».">
        <TextRow value={keywords} onInput={setKeywords} placeholder="Например: трениров, зал, бег" multiline />
      </Group>
      <Group title="Цвет"><div class="swatches">{palette.map((p) => <button class={`swatch ${p === color ? 'on' : ''}`} style={{ background: p }} onClick={() => setColor(p)} />)}</div></Group>
      <Group title="Значок"><div class="swatches">{symbols.map((s) => <button class={`sym ${s === symbol ? 'on' : ''}`} onClick={() => setSymbol(s)}>{s}</button>)}</div></Group>
      {c && <Group><button class="danger-row" onClick={remove}>Удалить или убрать в архив</button></Group>}
    </Sheet>
  )
}

// MARK: Расписание

const weekdays = [[2, 'Понедельник'], [3, 'Вторник'], [4, 'Среда'], [5, 'Четверг'], [6, 'Пятница'], [7, 'Суббота'], [1, 'Воскресенье']] as const

function Schedule() {
  const st = S.getState()
  const week = weekNumber(todayKey(), S.firstWeekKey())
  return (
    <>
      <Group footer="От этой даты считаются чётные и нечётные недели: неделя с ней — первая, нечётная. Занятия из расписания сами появляются в плане сегодняшнего и будущих дней.">
        <DateRow label="Начало учёбы" value={S.firstWeekKey()} onChange={(k) => { st.settings.firstWeekKey = k; S.commit() }} />
        {week > 0 && <Row label="Сейчас">{week}-я неделя, {week % 2 === 1 ? 'нечётная' : 'чётная'}</Row>}
      </Group>
      {weekdays.map(([wd, title]) => (
        <Group title={title}>
          {st.scheduleRules.filter((r) => r.weekday === wd).sort((a, b) => a.startMinute - b.startMinute).map((r) => (
            <Row onClick={() => openSheet(() => <RuleEditor rule={r} weekday={wd} />)} label={<span class={r.enabled ? '' : 'muted'}>{r.title}{r.parity !== 'every' && <span class="muted small"> · {parities.find((p) => p.id === r.parity)!.title}</span>}</span>}>
              <span class="muted mono">{fmtMinute(r.startMinute)}–{fmtMinute(r.endMinute)}</span>
            </Row>
          ))}
          <button class="link-row" onClick={() => openSheet(() => <RuleEditor weekday={wd} />)}>＋ Добавить занятие</button>
        </Group>
      ))}
    </>
  )
}

function RuleEditor(props: { rule?: ScheduleRule; weekday: number }) {
  const r = props.rule
  const [title, setTitle] = useState(r?.title ?? '')
  const [categoryId, setCategoryId] = useState(r?.categoryId ?? null)
  const [chosen, setChosen] = useState(!!r?.categoryId)
  const [weekday, setWeekday] = useState(r?.weekday ?? props.weekday)
  const [start, setStart] = useState(r?.startMinute ?? 540)
  const [end, setEnd] = useState(r?.endMinute ?? 630)
  const [parity, setParity] = useState<WeekParity>(r?.parity ?? 'every')
  const [until, setUntil] = useState(r?.validUntil ?? null)
  const [enabled, setEnabled] = useState(r?.enabled ?? true)
  const save = () => {
    const st = S.getState()
    const v: ScheduleRule = { id: r?.id ?? uid(), title: title.trim(), categoryId, weekday, startMinute: start, endMinute: end, parity, validFrom: r?.validFrom ?? null, validUntil: until, enabled }
    st.scheduleRules = r ? st.scheduleRules.map((x) => (x.id === r.id ? v : x)) : [...st.scheduleRules, v]
    S.commit(); closeSheet()
  }
  return (
    <Sheet title={r ? 'Занятие' : 'Новое занятие'} onSave={save} saveDisabled={!title.trim()}>
      <Group>
        <TextRow value={title} onInput={(v) => { setTitle(v); if (!chosen) { const m = S.matchCategory(v); if (m) setCategoryId(m.id) } }} placeholder="Например: Матанализ, лекция" autofocus={!r} />
        <CategorySelect value={categoryId} onChange={(v) => { setCategoryId(v); setChosen(true) }} />
      </Group>
      <Group>
        <Select label="День недели" value={weekday} onChange={setWeekday} options={weekdays.map(([v, t]) => ({ value: v as number, title: t }))} />
        <TimeRow label="Начало" minute={start} onChange={setStart} />
        <TimeRow label="Конец" minute={end} onChange={setEnd} />
        <Select label="Недели" value={parity} onChange={setParity} options={parities.map((p) => ({ value: p.id, title: p.title }))} />
      </Group>
      <Group footer="Изменения касаются дней, в которые расписание ещё не подставлено. В уже созданный план занятие можно добавить кнопкой «+» → «Подставить расписание».">
        <Toggle label="До определённой даты" checked={until !== null} onChange={(v) => setUntil(v ? addDays(todayKey(), 120) : null)} />
        {until !== null && <DateRow label="Последний день" value={until} onChange={setUntil} />}
        <Toggle label="Действует" checked={enabled} onChange={setEnabled} />
      </Group>
      {r && <Group><button class="danger-row" onClick={() => { const st = S.getState(); st.scheduleRules = st.scheduleRules.filter((x) => x.id !== r.id); S.commit(); closeSheet() }}>Удалить занятие</button></Group>}
    </Sheet>
  )
}

// MARK: Шаблоны

function Templates() {
  const st = S.getState()
  if (!st.templates.length) return <Empty>Шаблонов пока нет. Составь план дня и на вкладке «План» нажми «+» → «Сохранить день как шаблон».</Empty>
  return <Group>{st.templates.map((t) => <Row onClick={() => openSheet(() => <TemplateEditor template={t} />)} chevron label={t.name}><span class="muted small">блоков: {t.items.length}</span></Row>)}</Group>
}

function TemplateEditor(props: { template: Template }) {
  const t = props.template
  const [name, setName] = useState(t.name)
  const [items, setItems] = useState(t.items)
  return (
    <Sheet title="Шаблон" onSave={() => { t.name = name.trim() || t.name; t.items = items; S.commit(); closeSheet() }}>
      <Group title="Название"><TextRow value={name} onInput={setName} /></Group>
      <Group title="Блоки">{items.map((i, k) => {
        const c = S.category(i.categoryId)
        return <Row label={<span class="cat-line"><CategoryBadge color={c?.color} symbol={c?.symbol} size={22} /> {i.title}</span>}><span class="muted mono small">{fmtMinute(i.startMinute)}–{fmtMinute(i.startMinute + i.durationMinutes)}</span> <button class="link small muted" onClick={() => setItems(items.filter((_, j) => j !== k))}>✕</button></Row>
      })}</Group>
      <Group><button class="danger-row" onClick={() => { const st = S.getState(); st.templates = st.templates.filter((x) => x.id !== t.id); S.commit(); closeSheet() }}>Удалить шаблон</button></Group>
    </Sheet>
  )
}

// MARK: Напоминания

function Reminders() {
  const st = S.getState()
  const today = todayKey()
  const next = (r: (typeof st.reminders)[number]) => (r.repeat === 'none' ? r.firstDay : occurrences(r.firstDay, r.repeat, Math.max(today, r.firstDay), addDays(today, 400))[0] ?? r.firstDay)
  const row = (r: (typeof st.reminders)[number]) => (
    <Row onClick={() => openSheet(() => <ReminderEditor reminder={r} dayKey={today} />)} label={`🔔 ${r.title}${r.repeat !== 'none' ? ' 🔁' : ''}`}>
      <span class="muted small">{r.repeat !== 'none' ? 'ближайшее ' : ''}{fmtDay(next(r))} · {r.minute === null ? 'весь день' : fmtMinute(r.minute)}</span>
    </Row>
  )
  const upcoming = st.reminders.filter((r) => r.repeat === 'none' && r.firstDay >= today).sort((a, b) => a.firstDay - b.firstDay)
  const repeating = st.reminders.filter((r) => r.repeat !== 'none')
  const past = st.reminders.filter((r) => r.repeat === 'none' && r.firstDay < today).sort((a, b) => b.firstDay - a.firstDay)
  return (
    <>
      {!st.reminders.length && <Empty>Напоминаний пока нет. Их можно добавить здесь или кнопкой «+» на вкладке «План».</Empty>}
      {upcoming.length > 0 && <Group title="Предстоящие">{upcoming.map(row)}</Group>}
      {repeating.length > 0 && <Group title="Повторяющиеся">{repeating.map(row)}</Group>}
      {past.length > 0 && <Group title="Прошедшие">{past.map(row)}</Group>}
      <Group><button class="link-row" onClick={() => openSheet(() => <ReminderEditor dayKey={today} />)}>＋ Новое напоминание</button></Group>
    </>
  )
}

// MARK: Уведомления

function download(name: string, text: string, type: string) {
  const blob = new Blob([text], { type })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = name
  document.body.appendChild(a)
  a.click()
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove() }, 1000)
}

function Notifications() {
  const st = S.getState()
  const n = st.settings.notify
  const set = (patch: Partial<typeof n>) => { Object.assign(n, patch); S.commit() }
  const perm = permission()
  return (
    <>
      <Group footer="Браузер присылает уведомления, только пока приложение открыто или недавно свёрнуто. Чтобы напоминания приходили всегда, добавь их в Календарь iPhone кнопкой ниже.">
        <Row label="Разрешение">{perm === 'granted' ? 'разрешены' : perm === 'denied' ? 'запрещены' : perm === 'unsupported' ? 'не поддерживаются' : 'не спрашивали'}</Row>
        {notificationsSupported() && perm !== 'granted' && <button class="link-row" onClick={async () => { await requestPermission(); S.commit() }}>Разрешить уведомления</button>}
        {!notificationsSupported() && <p class="muted small pad">На iPhone уведомления работают, только если приложение добавлено на экран «Домой» (см. «Установка на iPhone»).</p>}
        <button class="link-row" onClick={() => { download('DayTrack-calendar.ics', buildIcs(), 'text/calendar'); toast('Открой файл и нажми «Добавить все»: Календарь сам напомнит о событиях') }}>📆 Добавить напоминания и планы в Календарь</button>
      </Group>
      <Group>
        <Toggle label="Утром: проверить план" checked={n.morningOn} onChange={(v) => set({ morningOn: v })} />
        {n.morningOn && <TimeRow label="Время" minute={n.morning} onChange={(v) => set({ morning: v })} />}
        <Toggle label="Вечером: подвести итоги" checked={n.eveningOn} onChange={(v) => set({ eveningOn: v })} />
        {n.eveningOn && <TimeRow label="Время" minute={n.evening} onChange={(v) => set({ evening: v })} />}
      </Group>
      <Group footer="Приходит вечером перед днём, в который ты заранее поставил дела. Занятия из расписания не перечисляются.">
        <Toggle label="Накануне: что запланировано на завтра" checked={n.eveBeforeOn} onChange={(v) => set({ eveBeforeOn: v })} />
        {n.eveBeforeOn && <TimeRow label="Время" minute={n.eveBefore} onChange={(v) => set({ eveBefore: v })} />}
      </Group>
      <Group footer="Напоминание не придёт, если факт уже внесён почти до этого времени.">
        <Toggle label="Напоминать внести факт" checked={n.factOn} onChange={(v) => set({ factOn: v })} />
        {n.factOn && n.factTimes.map((m, i) => <TimeRow label={i === 0 ? 'Первое' : 'Второе'} minute={m} onChange={(v) => set({ factTimes: n.factTimes.map((x, j) => (j === i ? v : x)) })} />)}
      </Group>
      <Group footer="Срабатывает по плану: если блоки учёбы идут подряд дольше выбранного времени. Короткие перерывы снижают усталость; конкретный интервал — удобное значение, а не научная норма.">
        <Toggle label="Напоминать о перерыве" checked={n.breakOn} onChange={(v) => set({ breakOn: v })} />
        {n.breakOn && <Select label="После учёбы без паузы" value={n.breakInterval} onChange={(v) => set({ breakInterval: v })} options={[{ value: 50, title: '50 минут' }, { value: 90, title: '1,5 часа' }, { value: 120, title: '2 часа' }]} />}
      </Group>
    </>
  )
}

function Target() {
  const t = S.getState().settings.target
  const f = (v: number) => `${(v / 60).toFixed(1).replace('.', ',')} ч`
  return (
    <Group footer="Цель на один день. Используется в советах и в балансе недели. Взрослым рекомендуют спать не меньше 7 часов.">
      <Stepper label="Учёба" value={t.study} step={30} min={30} max={840} format={f} onChange={(v) => { t.study = v; S.commit() }} />
      <Stepper label="Отдых" value={t.rest} step={30} min={30} max={600} format={f} onChange={(v) => { t.rest = v; S.commit() }} />
      <Stepper label="Сон" value={t.sleep} step={30} min={300} max={660} format={f} onChange={(v) => { t.sleep = v; S.commit() }} />
    </Group>
  )
}

function Games() {
  const g = S.getState().settings.games
  const s = S.gameWeekStats()
  return (
    <>
      <Group><Row label="Сыграно за неделю">{duration(s.played)}</Row><Row label="Учёба за неделю">{duration(s.studied)}</Row></Group>
      <Group footer="С заработком: сколько выучил, столько можно играть, но не больше бюджета. Так игра становится наградой после дела, а не побегом от него. Жёстко заблокировать игры приложение не может — для этого есть «Экранное время» в настройках iPhone.">
        <Stepper label="Бюджет в неделю" value={g.budget} step={60} min={60} max={2400} format={(v) => `${v / 60} ч`} onChange={(v) => { g.budget = v; S.commit() }} />
        <Toggle label="Игровое время зарабатывается учёбой" checked={g.earnByStudy} onChange={(v) => { g.earnByStudy = v; S.commit() }} />
      </Group>
    </>
  )
}

function Advisor() {
  const s = S.getState().settings
  const a = s.advisor
  return (
    <>
      <Group title="Правила" footer="Подсказки появляются в плане дня. У каждой есть кнопка «Почему?»: там видно, исследование это или практический приём.">
        {adviceRules.map((r) => <Toggle label={r.title} checked={!a.disabled.includes(r.id)} onChange={(v) => { a.disabled = v ? a.disabled.filter((x) => x !== r.id) : [...a.disabled, r.id]; S.commit() }} />)}
      </Group>
      <Group title="Пороги">
        <Stepper label="Лимит загрузки" value={a.loadPercent} step={5} min={50} max={90} format={(v) => `${v}%`} onChange={(v) => { a.loadPercent = v; S.commit() }} />
        <Stepper label="Резерв" value={a.buffer} step={15} min={15} max={120} format={duration} onChange={(v) => { a.buffer = v; S.commit() }} />
        <Stepper label="Потолок учёбы" value={a.ceiling} step={30} min={180} max={720} format={(v) => `${(v / 60).toFixed(1).replace('.', ',')} ч`} onChange={(v) => { a.ceiling = v; S.commit() }} />
      </Group>
      <Group footer="По времени подъёма и отбоя считается, какая доля дня занята планом.">
        <TimeRow label="Подъём" minute={s.wakeMinute} onChange={(v) => { s.wakeMinute = v; S.commit() }} />
        <TimeRow label="Отбой" minute={s.bedMinute % 1440} onChange={(v) => { s.bedMinute = v; S.commit() }} />
      </Group>
    </>
  )
}

export const themes: { id: Theme; title: string; subtitle: string; accent: string }[] = [
  { id: 'system', title: 'Системная', subtitle: 'Светлая и тёмная по настройке телефона', accent: '#3A5AC8' },
  { id: 'calm', title: 'Спокойная', subtitle: 'Приглушённый зелёный акцент, ничего не давит', accent: '#5E8C74' },
  { id: 'bright', title: 'Яркая', subtitle: 'Насыщенный акцент, крупные цифры заметнее', accent: '#E8455B' },
  { id: 'night', title: 'Ночная', subtitle: 'Всегда тёмная, мягкий фиолетовый акцент', accent: '#8C7BFF' },
]

function ThemePage() {
  const s = S.getState().settings
  return <Group>{themes.map((t) => <Row onClick={() => { s.theme = t.id; S.commit() }} label={<span class="cat-line"><i class="swatch-dot" style={{ background: t.accent }} /><span class="stack"><span>{t.title}</span><span class="muted small">{t.subtitle}</span></span></span>}>{s.theme === t.id ? '✓' : ''}</Row>)}</Group>
}

function Prompt() {
  const s = S.getState().settings
  return (
    <>
      <Group footer="Этот текст копируется перед отчётом. В нём можно рассказать нейросети о себе и о том, какой разбор тебе нужен.">
        <textarea class="row-input big" value={s.prompt ?? defaultPrompt} onInput={(e) => { s.prompt = (e.target as HTMLTextAreaElement).value; S.commit() }} />
      </Group>
      <Group><button class="link-row" onClick={() => { s.prompt = null; S.commit() }}>Вернуть текст по умолчанию</button></Group>
    </>
  )
}

// MARK: Копии

function Backup() {
  const st = S.getState()
  const days = st.lastBackupAt ? Math.floor((Date.now() - st.lastBackupAt) / 86400000) : null
  const save = () => {
    download(backupFileName(), JSON.stringify(exportSnapshot(st), null, 2), 'application/json')
    st.lastBackupAt = Date.now(); S.commit()
    toast('Копия сохранена. На iPhone выбери «Сохранить в Файлы», лучше в iCloud Drive.')
  }
  const restore = (file: File) => {
    file.text().then((text) => {
      try {
        const j = JSON.parse(text)
        if (!confirm(`Заменить все данные копией?\n${summaryOf(j)}.\nТекущие данные будут удалены.`)) return
        S.replaceState(importSnapshot(j, st))
        toast('Данные восстановлены')
      } catch { toast('Это не копия DayTrack или файл повреждён') }
    })
  }
  return (
    <>
      <Group footer="Данные веб-версии живут только в этом браузере. Если очистить данные Safari или удалить значок с экрана «Домой», они пропадут. Сохраняй копию хотя бы раз в неделю.">
        <Row label="Последняя копия">{days === null ? 'ещё не было' : days === 0 ? 'сегодня' : `${days} дн. назад`}</Row>
        <button class="link-row" onClick={save}>💾 Сохранить копию в файл</button>
        <label class="link-row">📂 Восстановить из копии<input type="file" accept="application/json,.json" hidden onChange={(e) => { const f = (e.target as HTMLInputElement).files?.[0]; if (f) restore(f) }} /></label>
      </Group>
      <Group footer="Формат копии совпадает с приложением DayTrack для iPhone: копию оттуда можно загрузить сюда, а эту — обратно в приложение, когда установка снова заработает.">
        <span />
      </Group>
    </>
  )
}

function Install() {
  return (
    <Group>
      <div class="pad">
        <p><b>Как поставить на iPhone</b></p>
        <ol class="steps">
          <li>Открой эту страницу в <b>Safari</b>.</li>
          <li>Нажми кнопку «Поделиться» (квадрат со стрелкой вверх).</li>
          <li>Выбери «На экран „Домой“» и нажми «Добавить».</li>
          <li>Открывай DayTrack значком с экрана «Домой»: так он работает как приложение, без адресной строки, и умеет присылать уведомления.</li>
        </ol>
        <p class="muted small">Подпись раз в 7 дней не нужна: веб-приложение не устанавливается через iloader и не истекает.</p>
        <p><b>Чем отличается от версии для iPhone</b></p>
        <ul class="steps">
          <li>Нет виджета и таймера на экране блокировки: веб-приложениям iOS это не разрешает.</li>
          <li>Уведомления приходят, пока приложение открыто или недавно свёрнуто. Для надёжных напоминаний — «Уведомления» → «Добавить в Календарь».</li>
          <li>Автокопии в папку нет: копию нужно сохранять вручную в «Резервных копиях».</li>
        </ul>
      </div>
    </Group>
  )
}

const pages: Record<Page, () => JSX.Element> = {
  categories: Categories, schedule: Schedule, templates: Templates, reminders: Reminders, notifications: Notifications,
  target: Target, games: Games, advisor: Advisor, theme: ThemePage, prompt: Prompt, backup: Backup, install: Install,
}
