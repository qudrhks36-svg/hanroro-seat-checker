import data from '../data/character.json'
import type { Strength } from './analysis'
import type { Element, TenGodGroup } from './tables'

export type Character = {
  animal: string
  emoji: string
  job: string
  propEmoji: string
  propName: string
  adjective: string
  tone: string
  nickname: string
  accent: Element
  bubbles: { label: string; text: string }[]
}

const D = data as unknown as {
  gan: Record<string, { animal: string; emoji: string; job: string }>
  zhi: Record<string, { emoji: string; name: string }>
  adjective: Record<TenGodGroup, string>
  tone: Record<Strength, string>
  bubbles: Record<TenGodGroup, { love: string; work: string; stress: string }>
}

export function buildCharacter(i: {
  dayGan: string
  dayZhi: string
  group: TenGodGroup
  strength: Strength
  dayElement: Element
}): Character {
  const g = D.gan[i.dayGan]
  const z = D.zhi[i.dayZhi]
  const adjective = D.adjective[i.group]
  const b = D.bubbles[i.group]
  return {
    animal: g.animal,
    emoji: g.emoji,
    job: g.job,
    propEmoji: z.emoji,
    propName: z.name,
    adjective,
    tone: D.tone[i.strength],
    nickname: `${adjective} ${g.job} ${g.animal}`,
    accent: i.dayElement,
    bubbles: [
      { label: '연애할 때', text: b.love },
      { label: '일할 때', text: b.work },
      { label: '스트레스 받을 때', text: b.stress },
    ],
  }
}
