import type { Category, Settings, State } from './model'
import { uid } from './model'
import type { CategoryKind } from '../core/kinds'

const seed: [string, string, string, CategoryKind, string][] = [
  ['Пары', '#4F7BE8', '🎓', 'study', 'пара, пары, лекци, семинар, практическ, лаб, коллоквиум, консультаци'],
  ['Учёба', '#6C5CE7', '📘', 'study', 'учеб, домашк, дз, курсов, реферат, доклад, экзамен, зачет, сессия, подготовк, конспект, матан, математ, физик, химия, история, диплом'],
  ['Самообразование', '#A55EEA', '💡', 'study', 'курс, курсы, книг, чтение, читать, статья, вебинар, программирован, английск, язык'],
  ['Отдых', '#6AB04C', '🌿', 'rest', 'отдых, перерыв, прогулк, гулять, сериал, фильм, кино, друз, ютуб, youtube, музык'],
  ['Игры', '#E056A0', '🎮', 'rest', 'игры, игра, играть, поиграть, поиграл, game, игровой'],
  ['Сон', '#3C6382', '🌙', 'sleep', 'сон, спать, сплю, дневной сон'],
  ['Спорт', '#F0932B', '🏃', 'sport', 'спорт, зал, трениров, бег, пробежк, футбол, баскетбол, бассейн, плавани, йога, зарядк, растяжк'],
  ['Еда', '#E1B12C', '🍽️', 'routine', 'завтрак, обед, ужин, перекус, еда, готовк'],
  ['Быт', '#8D6E63', '🏠', 'routine', 'уборк, убраться, стирк, магазин, покупк, продукт, посуд, душ'],
  ['Дорога', '#22A6B3', '🚋', 'transit', 'дорог, метро, автобус, такси, электричк, поездк, доехать, ехать'],
  ['Работа', '#EB4D4B', '💼', 'work', 'работ, смена, созвон, подработк'],
  ['Другое', '#7F8C8D', '⚪', 'other', 'врач, больниц, поликлиник, день рожд'],
]

export function defaultCategories(): Category[] {
  return seed.map(([name, color, symbol, kind, keywords], order) => ({ id: uid(), name, color, symbol, kind, order, archived: false, keywords }))
}

export const defaultPrompt = 'Ты профессиональный психолог и специалист по тайм-менеджменту, который работает со студентами. Ниже мой отчёт «план/факт» из приложения для планирования дня. Разбери его: что получилось хорошо, какие закономерности ты видишь (что сбивает меня с плана, как распределены учёба, отдых и сон, насколько точно я оцениваю время, как продвигаются мои фокусы) и дай 3 конкретных совета на следующий период. Будь доброжелательным и без упрёков: мне важно понять причины, а не почувствовать вину. Учитывай, что я склонен откладывать сложное, недооцениваю время на дела и мне трудно отдыхать без чувства вины.'

export function defaultSettings(): Settings {
  return {
    firstWeekKey: null,
    wakeMinute: 8 * 60, bedMinute: 24 * 60,
    target: { study: 360, rest: 180, sleep: 480 },
    notify: {
      morningOn: true, morning: 8 * 60, eveningOn: true, evening: 21 * 60 + 30,
      factOn: true, factTimes: [13 * 60, 18 * 60], breakOn: true, breakInterval: 90,
      eveBeforeOn: true, eveBefore: 20 * 60,
    },
    advisor: { disabled: [], loadPercent: 70, buffer: 60, ceiling: 480 },
    games: { budget: 420, earnByStudy: false },
    theme: 'system',
    prompt: null,
    adviceCollapsed: false,
  }
}

export function emptyState(): State {
  return {
    version: 1, categories: defaultCategories(), days: {}, reminders: [], scheduleRules: [], templates: [],
    focuses: [], energy: [], reflections: {}, projects: [], settings: defaultSettings(), session: null,
    onboardingDone: false, dismissedAdvice: {}, firedNotifications: [], lastBackupAt: null,
  }
}

export const palette = ['#4F7BE8', '#6C5CE7', '#A55EEA', '#E056A0', '#EB4D4B', '#F0932B', '#E1B12C', '#6AB04C', '#22A6B3', '#3C6382', '#8D6E63', '#7F8C8D']
export const symbols = ['📘', '🎓', '💡', '✏️', '💻', '🧮', '📖', '🧠', '🌿', '🎮', '🎧', '📺', '👥', '🌙', '🛏️', '🏃', '🏋️', '🍽️', '☕', '🏠', '🛒', '🚋', '🚗', '💼', '📞', '❤️', '🩺', '⚪']
