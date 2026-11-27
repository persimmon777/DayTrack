import { useEffect, useState } from 'preact/hooks'
import * as S from '../data/store'
import { useStore } from './hooks'
import { SheetHost, ToastHost, toast } from './sheets'
import { PlanTab } from './plan/PlanTab'
import { FactTab } from './fact/FactTab'
import { FocusTab } from './focus/FocusTab'
import { CalendarTab } from './CalendarTab'
import { AnalyticsTab } from './analytics/AnalyticsTab'
import { SettingsTab, themes } from './settings/SettingsTab'
import { Onboarding } from './Onboarding'
import { todayKey } from '../core/time'
import { setInAppHandler } from '../data/notifications'

type Tab = 'plan' | 'fact' | 'calendar' | 'focus' | 'analytics' | 'settings'
const tabs: { id: Tab; title: string; icon: string }[] = [
  { id: 'plan', title: 'План', icon: '📋' },
  { id: 'fact', title: 'Факт', icon: '✅' },
  { id: 'calendar', title: 'Календарь', icon: '🗓️' },
  { id: 'focus', title: 'Фокусы', icon: '🎯' },
  { id: 'analytics', title: 'Аналитика', icon: '📊' },
  { id: 'settings', title: 'Настройки', icon: '⚙️' },
]

export function App() {
  useStore()
  const st = S.getState()
  const [tab, setTab] = useState<Tab>(() => (location.hash.slice(1) as Tab) || 'plan')
  const [dayKey, setDayKey] = useState(todayKey())
  const [lastToday, setLastToday] = useState(todayKey())

  useEffect(() => { history.replaceState(null, '', `#${tab}`); window.scrollTo(0, 0) }, [tab])
  useEffect(() => {
    setInAppHandler((n) => toast(`${n.title}. ${n.body}`))
    // Если приложение открыли на следующий день и был выбран «сегодня», переходим на новый день.
    const onVisible = () => {
      if (document.visibilityState !== 'visible') return
      const t = todayKey()
      setLastToday((prev) => { if (t !== prev) setDayKey((k) => (k === prev ? t : k)); return t })
    }
    document.addEventListener('visibilitychange', onVisible)
    return () => document.removeEventListener('visibilitychange', onVisible)
  }, [])
  void lastToday

  const theme = themes.find((t) => t.id === st.settings.theme) ?? themes[0]
  useEffect(() => {
    document.documentElement.dataset.theme = theme.id === 'night' ? 'dark' : ''
    document.documentElement.style.setProperty('--accent', theme.accent)
  }, [theme.id])

  if (!st.onboardingDone) return <Onboarding />
  return (
    <>
      <main>
        {tab === 'plan' && <PlanTab dayKey={dayKey} setDayKey={setDayKey} />}
        {tab === 'fact' && <FactTab dayKey={dayKey} setDayKey={setDayKey} />}
        {tab === 'calendar' && <CalendarTab onOpenDay={(k) => { setDayKey(k); setTab('plan') }} />}
        {tab === 'focus' && <FocusTab />}
        {tab === 'analytics' && <AnalyticsTab dayKey={dayKey} setDayKey={setDayKey} />}
        {tab === 'settings' && <SettingsTab />}
      </main>
      <nav class="tabbar">
        {tabs.map((t) => <button class={tab === t.id ? 'on' : ''} onClick={() => setTab(t.id)}><span>{t.icon}</span>{t.title}</button>)}
      </nav>
      <SheetHost />
      <ToastHost />
    </>
  )
}
