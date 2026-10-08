import type { Pillar, Pillars } from './saju'
import {
  ELEMENTS, GROUPS, ZHI, ZHI_MAIN_GAN, ganEl, zhiEl, groupBetween, groupElement,
  type Element, type TenGodGroup,
} from './tables'

export type Strength = '신강' | '중화' | '신약'
export type Analysis = {
  dayGan: string
  dayElement: Element
  elements: Record<Element, number>
  lacking: Element[]
  groups: Record<TenGodGroup, number>
  dominantGroup: TenGodGroup
  ratio: number
  strength: Strength
  yongshin: Element
}

export function analyze(p: Pillars): Analysis {
  const dayGan = p.day.gan
  const dayElement = ganEl(dayGan)
  const elements: Record<Element, number> = { 木: 0, 火: 0, 土: 0, 金: 0, 水: 0 }
  const groups: Record<TenGodGroup, number> = { 비겁: 0, 식상: 0, 재성: 0, 관성: 0, 인성: 0 }

  const count = (pl: Pillar) => {
    elements[ganEl(pl.gan)]++
    elements[zhiEl(pl.zhi)]++
  }
  const addZhi = (zhi: string, w: number) => {
    groups[groupBetween(dayGan, ZHI_MAIN_GAN[ZHI.indexOf(zhi)])] += w
  }
  for (const [pos, pl] of [['year', p.year], ['month', p.month], ['time', p.time]] as const) {
    if (!pl) continue
    count(pl)
    groups[groupBetween(dayGan, pl.gan)] += 1
    addZhi(pl.zhi, pos === 'month' ? 3 : 1) // 월지(득령)만 가중치 3
  }
  count(p.day) // 일간은 기준이라 십성에서 제외, 일지만 반영
  addZhi(p.day.zhi, 1)

  const total = GROUPS.reduce((s, g) => s + groups[g], 0)
  const ratio = (groups.비겁 + groups.인성) / total
  // ponytail: 단순 비율 임계값(0.55/0.40). 조후·통관·지장간 가중치는 미반영, 정밀화가 필요하면 여기부터 교체.
  const strength: Strength = ratio >= 0.55 ? '신강' : ratio <= 0.4 ? '신약' : '중화'
  const dominantGroup = GROUPS.reduce((best, g) => (groups[g] > groups[best] ? g : best))

  const cand: TenGodGroup[] =
    strength === '신강' ? ['식상', '재성', '관성'] : strength === '신약' ? ['인성', '비겁'] : GROUPS
  const yongshin = cand
    .map((g) => groupElement(dayElement, g))
    .reduce((best, e) => (elements[e] < elements[best] ? e : best))

  return {
    dayGan, dayElement, elements,
    lacking: ELEMENTS.filter((e) => elements[e] === 0),
    groups, dominantGroup, ratio, strength, yongshin,
  }
}
