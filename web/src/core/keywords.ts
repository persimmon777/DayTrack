export function normalize(text: string): string {
  return text.toLowerCase().replace(/ё/g, 'е').trim()
}

export function words(text: string): string[] {
  return normalize(text).split(/[^\p{L}\p{N}]+/u).filter(Boolean)
}

/** Ключевые слова из строки «через запятую». */
export function parseKeywords(raw: string): string[] {
  const result: string[] = []
  for (const part of raw.split(/[,;\n]/)) {
    const phrase = words(part).join(' ')
    if (phrase.length >= 2 && !result.includes(phrase)) result.push(phrase)
  }
  return result
}

/** Длина самого длинного совпавшего ключевого слова. Слово срабатывает как начало слова. */
export function keywordScore(title: string, keywords: string[]): number | null {
  const titleWords = words(title)
  if (!titleWords.length) return null
  let best: number | null = null
  for (const keyword of keywords) {
    const parts = keyword.split(' ')
    if (!parts.length || parts.length > titleWords.length) continue
    for (let offset = 0; offset <= titleWords.length - parts.length; offset++) {
      const ok = parts.every((p, i) => {
        const w = titleWords[offset + i]
        return i === parts.length - 1 ? w.startsWith(p) : w === p
      })
      if (ok) { best = Math.max(best ?? 0, keyword.length); break }
    }
  }
  return best
}

export function bestMatch(title: string, candidates: string[][]): number | null {
  let best: { index: number; score: number } | null = null
  candidates.forEach((keywords, index) => {
    const score = keywordScore(title, keywords)
    if (score !== null && score > (best?.score ?? 0)) best = { index, score }
  })
  return best ? (best as { index: number }).index : null
}
