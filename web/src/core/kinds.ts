export type CategoryKind = 'study' | 'rest' | 'sleep' | 'sport' | 'routine' | 'transit' | 'work' | 'other'

export const categoryKinds: { id: CategoryKind; title: string }[] = [
  { id: 'study', title: 'Учёба' },
  { id: 'rest', title: 'Отдых' },
  { id: 'sleep', title: 'Сон' },
  { id: 'sport', title: 'Спорт' },
  { id: 'routine', title: 'Быт' },
  { id: 'transit', title: 'Дорога' },
  { id: 'work', title: 'Работа' },
  { id: 'other', title: 'Другое' },
]

export type Reason = 'suddenTask' | 'fatigue' | 'phone' | 'hardToStart' | 'underestimated' | 'mood' | 'health' | 'other'

export const reasons: { id: Reason; title: string }[] = [
  { id: 'suddenTask', title: 'Внезапное дело' },
  { id: 'fatigue', title: 'Усталость' },
  { id: 'phone', title: 'Телефон и соцсети' },
  { id: 'hardToStart', title: 'Трудно было начать' },
  { id: 'underestimated', title: 'Не рассчитал время' },
  { id: 'mood', title: 'Не было настроения' },
  { id: 'health', title: 'Самочувствие' },
  { id: 'other', title: 'Другое' },
]

export const reasonTitle = (r: Reason | undefined | null) => reasons.find((x) => x.id === r)?.title ?? 'Другое'
export const kindTitle = (k: CategoryKind) => categoryKinds.find((x) => x.id === k)?.title ?? 'Другое'

export type BalanceGroup = 'study' | 'rest' | 'sleep' | 'other'
export const balanceGroups: { id: BalanceGroup; title: string; color: string }[] = [
  { id: 'study', title: 'Учёба', color: '#6C5CE7' },
  { id: 'rest', title: 'Отдых', color: '#6AB04C' },
  { id: 'sleep', title: 'Сон', color: '#3C6382' },
  { id: 'other', title: 'Прочее', color: '#B2BEC3' },
]
export function groupOf(kind: CategoryKind): BalanceGroup {
  return kind === 'study' || kind === 'rest' || kind === 'sleep' ? kind : 'other'
}
