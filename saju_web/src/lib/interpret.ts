import { Solar } from 'lunar-typescript'
import raw from '../data/readings.json'
import type { Pillars } from './saju'
import type { Analysis } from './analysis'
import {
  ELEMENT_KO, ganEl, zhiEl, groupBetween, groupElement, tenGod, GAN, GAN_KO,
  type Element, type TenGod, type TenGodGroup,
} from './tables'

type Pair = { trait: string; work: string }
const D = raw as unknown as {
  dayGan: Record<string, string>
  dayZhi: Record<string, string>
  group: Record<TenGodGroup, Pair>
  lacking: Record<Element, string>
  balanced: string
  strength: Record<string, { summary: string; advice: string }>
  yongshin: Record<Element, string>
  sewoon: Record<TenGodGroup, string>
  sewoonMatch: { yes: string; no: string }
  partnerType: Record<Element, string>
  spouseStar: { male: string; female: string }
}
export const readings = D

export type Section = { title: string; body: string[] }

export const elementLabel = (e: Element) => `${ELEMENT_KO[e]}(${e})`

export function dayGanName(gan: string): string {
  const i = GAN.indexOf(gan)
  return `${GAN_KO[i]}${ELEMENT_KO[ganEl(gan)]}(${gan}${ganEl(gan)})`
}

export const headline = (a: Analysis) =>
  `${dayGanName(a.dayGan)} 일간 · ${a.strength} · 용신 ${elementLabel(a.yongshin)}`

export function interpret(p: Pillars, a: Analysis): Section[] {
  const s = D.strength[a.strength]
  const g = D.group[a.dominantGroup]
  return [
    { title: '기본 성향', body: [D.dayGan[a.dayGan], D.dayZhi[p.day.zhi]] },
    { title: '사주 구조', body: [s.summary, g.trait] },
    { title: '오행 균형', body: a.lacking.length ? a.lacking.map((e) => D.lacking[e]) : [D.balanced] },
    { title: '직업·활동 경향', body: [g.work] },
    { title: '조언', body: [s.advice, D.yongshin[a.yongshin]] },
  ]
}

export type YearFortune = {
  year: number
  ganzhi: string
  god: TenGod
  group: TenGodGroup
  matchesYongshin: boolean
  summary: string
  body: string[]
}

export function yearFortune(a: Analysis, year: number): YearFortune {
  const ganzhi = Solar.fromYmd(year, 6, 1).getLunar().getYearInGanZhi() // 6월 1일은 항상 입춘 이후
  const [gan, zhi] = [ganzhi[0], ganzhi[1]]
  const god = tenGod(a.dayGan, gan)
  const group = groupBetween(a.dayGan, gan)
  const matchesYongshin = ganEl(gan) === a.yongshin || zhiEl(zhi) === a.yongshin
  const match = (matchesYongshin ? D.sewoonMatch.yes : D.sewoonMatch.no).replace('{el}', elementLabel(a.yongshin))
  return {
    year, ganzhi, god, group, matchesYongshin, summary: D.sewoon[group],
    body: [`${year}년(${ganzhi})의 천간은 일간 기준 ${god}에 해당하며, ${D.sewoon[group]}`, match],
  }
}

/** 배우자성(남 재성 / 여 관성) 오행 문장 — compat.ts 에서 사용 */
export function spouseStarText(a: Analysis, gender: 'male' | 'female'): string {
  const el = groupElement(a.dayElement, gender === 'male' ? '재성' : '관성')
  return D.spouseStar[gender].replace('{el}', elementLabel(el))
}
