import { useState } from 'preact/hooks'
import * as S from '../data/store'
import { Group, TimeRow, Stepper } from './kit'
import { requestPermission } from '../data/notifications'

export function Onboarding() {
  const [page, setPage] = useState(0)
  const st = S.getState()
  const s = st.settings
  const f = (v: number) => `${(v / 60).toFixed(1).replace('.', ',')} ч`
  const finish = () => { st.onboardingDone = true; S.commit() }
  const pages = [
    <>
      <div class="ob-icon">📅</div>
      <h1>DayTrack: план и факт</h1>
      <p>Утром составляешь план, днём отмечаешь, что было на самом деле, вечером видишь разницу. Без оценок и упрёков: процент выполнения — это данные, по которым план становится реалистичнее.</p>
      <p class="muted">Приложение подсказывает, где добавить отдых, резерв и перерывы, и учится на твоей статистике: например, заметит, что на учёбу обычно уходит больше времени, чем ты закладываешь.</p>
    </>,
    <>
      <div class="ob-icon">🛏️</div>
      <h1>Режим и цель</h1>
      <Group>
        <TimeRow label="Обычно встаю" minute={s.wakeMinute} onChange={(v) => { s.wakeMinute = v; S.commit() }} />
        <TimeRow label="Обычно ложусь" minute={s.bedMinute % 1440} onChange={(v) => { s.bedMinute = v; S.commit() }} />
      </Group>
      <Group title="Сколько в день хочется уделять">
        <Stepper label="Учёбе" value={s.target.study} step={30} min={30} max={840} format={f} onChange={(v) => { s.target.study = v; S.commit() }} />
        <Stepper label="Отдыху" value={s.target.rest} step={30} min={30} max={600} format={f} onChange={(v) => { s.target.rest = v; S.commit() }} />
        <Stepper label="Сну" value={s.target.sleep} step={30} min={300} max={660} format={f} onChange={(v) => { s.target.sleep = v; S.commit() }} />
      </Group>
      <p class="muted small">Всё это можно поменять потом в настройках.</p>
    </>,
    <>
      <div class="ob-icon">🔔</div>
      <h1>Уведомления</h1>
      <p>Утром — заглянуть в план, вечером — подвести итоги, днём — отметить факт и вовремя сделать перерыв.</p>
      <p class="muted">На iPhone уведомления веб-приложения работают, если открыть его со значка на экране «Домой» (Safari → «Поделиться» → «На экран „Домой“»). Для напоминаний о событиях есть экспорт в Календарь.</p>
      <button class="secondary" onClick={() => requestPermission()}>Разрешить уведомления</button>
    </>,
    <>
      <div class="ob-icon">👆</div>
      <h1>Как пользоваться</h1>
      <ul class="tips">
        <li><b>План</b> — кнопка «+» или нажатие на шкалу. Постоянные занятия — в «Настройки» → «Расписание».</li>
        <li><b>Факт</b> — «+» добавляет запись с конца предыдущей. Обязательно только время.</li>
        <li><b>Фокусы</b> — главные цели недели и месяца и большие дела с шагами.</li>
        <li><b>Аналитика</b> — графики, календарь и отчёт для нейросети.</li>
        <li><b>Копии</b> — данные живут в этом браузере. Сохраняй копию в «Настройки» → «Резервные копии».</li>
      </ul>
    </>,
  ]
  return (
    <div class="onboarding">
      <div class="ob-skip"><button class="link" onClick={finish}>Пропустить</button></div>
      <div class="ob-page">{pages[page]}</div>
      <div class="ob-dots">{pages.map((_, i) => <i class={i === page ? 'on' : ''} />)}</div>
      <button class="primary wide" onClick={() => (page === pages.length - 1 ? finish() : setPage(page + 1))}>{page === pages.length - 1 ? 'Начать' : 'Дальше'}</button>
    </div>
  )
}
