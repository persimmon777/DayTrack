import type { CategoryKind, Reason } from '../core/kinds'
import type { RepeatRule, WeekParity } from '../core/periods'
import type { AdviceRule } from '../core/advisor'
import type { DayKey } from '../core/time'

export type ID = string

export interface Category { id: ID; name: string; color: string; symbol: string; kind: CategoryKind; order: number; archived: boolean; keywords: string }

export interface Block {
  id: ID; title: string; start: number; end: number; note: string; categoryId: ID | null
  baselineStart: number | null; baselineEnd: number | null; addedAfterLock: boolean; removedAt: number | null
  missReason: Reason | null; source: 'manual' | 'schedule' | 'template'; focusId: ID | null; isFrog: boolean
}
export interface Task { id: ID; title: string; estimate: number; done: boolean; order: number; createdAt: number; addedAfterLock: boolean; categoryId: ID | null; focusId: ID | null }
export interface Fact { id: ID; title: string; start: number; end: number; note: string; reason: Reason | null; categoryId: ID | null; blockId: ID | null; focusId: ID | null; projectId: ID | null }
export interface Change { id: ID; at: number; kind: 'added' | 'removed' | 'edited'; text: string; blockId: ID | null }

export interface Day {
  key: DayKey; lockedAt: number | null; planEditedAt: number | null; scheduleApplied: boolean
  blocks: Block[]; tasks: Task[]; facts: Fact[]; changes: Change[]
}

export interface Reminder { id: ID; title: string; note: string; firstDay: DayKey; minute: number | null; repeat: RepeatRule; notify: boolean; leadDays: number; createdAt: number }
export interface ScheduleRule { id: ID; title: string; categoryId: ID | null; weekday: number; startMinute: number; endMinute: number; parity: WeekParity; validFrom: DayKey | null; validUntil: DayKey | null; enabled: boolean }
export interface TemplateItem { title: string; categoryId: ID | null; startMinute: number; durationMinutes: number }
export interface Template { id: ID; name: string; items: TemplateItem[]; createdAt: number }

export type FocusPeriod = 'week' | 'month'
export type FocusStatus = 'active' | 'done' | 'dropped'
export const focusStatuses: { id: FocusStatus; title: string }[] = [
  { id: 'active', title: 'В работе' }, { id: 'done', title: 'Получилось' }, { id: 'dropped', title: 'Отложено' },
]
export interface Focus { id: ID; title: string; why: string; period: FocusPeriod; periodStart: DayKey; parentId: ID | null; status: FocusStatus; result: string; order: number; createdAt: number }

export interface EnergyMark { id: ID; at: number; day: DayKey; energy: number; mood: number }
export interface Reflection { day: DayKey; wentWell: string; hindered: string; changeTomorrow: string; rating: number; updatedAt: number }

export interface ProjectStep { id: ID; title: string; minutes: number; done: boolean }
export interface Project {
  id: ID; title: string; why: string; categoryId: ID | null; minimum: number; ifThen: string; steps: ProjectStep[]
  createdAt: number; lastWorkedAt: number | null; archived: boolean; nudgeOn: boolean; nudgeMinute: number; order: number
}

export type SessionMode = 'rest' | 'focus' | 'game'
export interface Session { mode: SessionMode; startedAt: number; endsAt: number; label: string; projectId: ID | null }

export type Theme = 'system' | 'calm' | 'bright' | 'night'

export interface Settings {
  firstWeekKey: DayKey | null
  wakeMinute: number; bedMinute: number
  target: { study: number; rest: number; sleep: number }
  notify: {
    morningOn: boolean; morning: number; eveningOn: boolean; evening: number
    factOn: boolean; factTimes: number[]; breakOn: boolean; breakInterval: number
    eveBeforeOn: boolean; eveBefore: number
  }
  advisor: { disabled: AdviceRule[]; loadPercent: number; buffer: number; ceiling: number }
  games: { budget: number; earnByStudy: boolean }
  theme: Theme
  prompt: string | null
  adviceCollapsed: boolean
}

export interface State {
  version: 1
  categories: Category[]
  days: Record<string, Day>
  reminders: Reminder[]
  scheduleRules: ScheduleRule[]
  templates: Template[]
  focuses: Focus[]
  energy: EnergyMark[]
  reflections: Record<string, Reflection>
  projects: Project[]
  settings: Settings
  session: Session | null
  onboardingDone: boolean
  dismissedAdvice: Record<string, string[]>
  firedNotifications: string[]
  lastBackupAt: number | null
}

export const uid = (): ID =>
  (crypto as Crypto & { randomUUID?: () => string }).randomUUID?.() ?? `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`.toUpperCase()
