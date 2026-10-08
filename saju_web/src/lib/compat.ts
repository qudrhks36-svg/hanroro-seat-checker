import { Solar } from 'lunar-typescript'
import type { Pillars, Gender } from './saju'
import { MIN_YEAR, MAX_YEAR } from './saju'
import type { Analysis } from './analysis'
import { ZHI, ZODIAC, ganEl, zhiEl, ganHe, zhiRelation, type ZhiRel } from './tables'
import { readings, spouseStarText, elementLabel } from './interpret'

export type PartnerRec = {
  zodiac: { good: string[]; caution: string[] }
  type: string
  ages: { year: number; ganzhi: string; label: string; reason: string }[]
}

const zodiacOf = (zhi: string) => ZODIAC[ZHI.indexOf(zhi)]
const related = (base: string, rel: ZhiRel) => ZHI.filter((z) => zhiRelation(base, z) === rel)

export function recommendPartners(
  p: Pillars,
  a: Analysis,
  o: { gender: Gender; birthYear: number; currentYear: number },
): PartnerRec {
  const bases = [p.year.zhi, p.day.zhi]
  const good = [...new Set(bases.flatMap((b) => [...related(b, '육합'), ...related(b, '삼합')]))]
  const caution = [...new Set(bases.flatMap((b) => related(b, '충')))].filter((z) => !good.includes(z))

  const cands: { year: number; ganzhi: string; score: number; reasons: string[] }[] = []
  const last = Math.min(o.birthYear + 10, MAX_YEAR, o.currentYear - 19) // ponytail: 만 19세 이상만 추천
  for (let y = Math.max(o.birthYear - 10, MIN_YEAR); y <= last; y++) {
    const ganzhi = Solar.fromYmd(y, 6, 1).getLunar().getYearInGanZhi()
    let score = 0
    const reasons: string[] = []
    for (const [name, base] of [['띠', p.year.zhi], ['일지', p.day.zhi]] as const) {
      const rel = zhiRelation(base, ganzhi[1])
      if (rel === '육합') { score += 3; reasons.push(`${name} 육합`) }
      else if (rel === '삼합') { score += 2; reasons.push(`${name} 삼합`) }
      else if (rel === '충') { score -= 3 }
    }
    if (zhiEl(ganzhi[1]) === a.yongshin) { score += 2; reasons.push('지지가 용신 오행') }
    if (ganEl(ganzhi[0]) === a.yongshin) { score += 1; reasons.push('천간이 용신 오행') }
    if (score > 0) cands.push({ year: y, ganzhi, score, reasons })
  }
  const gap = (y: number) => y - o.birthYear
  cands.sort((x, y) => y.score - x.score || Math.abs(gap(x.year)) - Math.abs(gap(y.year)) || gap(x.year) - gap(y.year))

  return {
    zodiac: { good: good.map(zodiacOf), caution: caution.map(zodiacOf) },
    type: `${readings.partnerType[a.yongshin]} ${spouseStarText(a, o.gender)}`,
    ages: cands.slice(0, 3).map((c) => {
      const g = gap(c.year)
      const label = g === 0 ? '동갑' : g > 0 ? `${g}살 연하` : `${-g}살 연상`
      return { year: c.year, ganzhi: c.ganzhi, label, reason: c.reasons.join(', ') }
    }),
  }
}

export type Compat = { score: number; level: string; reasons: string[]; cautions: string[] }

const LEVELS: [number, string][] = [[80, '매우 좋음'], [65, '좋음'], [50, '무난함'], [35, '조율 필요']]

export function compatibility(p1: Pillars, a1: Analysis, p2: Pillars, a2: Analysis): Compat {
  let score = 40
  const reasons: string[] = []
  const cautions: string[] = []

  const dayRel = zhiRelation(p1.day.zhi, p2.day.zhi)
  if (dayRel === '육합') { score += 20; reasons.push('일지(배우자궁) 육합: 서로를 끌어당기는 안정적인 결합입니다.') }
  else if (dayRel === '삼합') { score += 12; reasons.push('일지(배우자궁) 삼합: 함께할수록 힘이 커지는 조합입니다.') }
  else if (dayRel === '충') { score -= 20; cautions.push('일지(배우자궁) 충: 생활 방식과 기준 차이를 의식적으로 조율해야 합니다.') }

  const yearRel = zhiRelation(p1.year.zhi, p2.year.zhi)
  if (yearRel === '육합' || yearRel === '삼합') { score += 8; reasons.push(`띠 ${yearRel}: 기본 기질이 잘 어울립니다.`) }
  else if (yearRel === '충') { score -= 8; cautions.push('띠 충: 기질이 부딪히기 쉬워 대화로 완충이 필요합니다.') }

  if (ganHe(p1.day.gan, p2.day.gan)) { score += 15; reasons.push('일간 천간합: 서로의 본질이 자연스럽게 맞물립니다.') }

  const fill = (from: Analysis, to: Analysis, who: string) => {
    const n = to.elements[from.yongshin]
    if (n >= 2) { score += 10; reasons.push(`${who}의 용신 오행 ${elementLabel(from.yongshin)}을 상대 사주가 풍부하게 채워 줍니다.`) }
    else if (n === 1) { score += 5; reasons.push(`${who}의 용신 오행 ${elementLabel(from.yongshin)}을 상대 사주가 일부 채워 줍니다.`) }
  }
  fill(a1, a2, '나')
  fill(a2, a1, '상대')

  score = Math.max(0, Math.min(100, score))
  return { score, level: LEVELS.find(([min]) => score >= min)?.[1] ?? '신중한 조율 필요', reasons, cautions }
}
