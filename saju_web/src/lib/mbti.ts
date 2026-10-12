import data from '../data/mbti.json'
import type { Analysis } from './analysis'
import { ELEMENTS, ELEMENT_KO, GROUPS, isYang, type Element, type TenGodGroup } from './tables'

// ponytail: 가중치(0.5, 보너스 0.15/0.10)와 배율은 우리가 정한 해석 규칙이다. 검증된 사주-MBTI 대응표는 없다.
// 배율은 분포 검증(tests/mbti.test.ts)으로 정한다. 바꾸면 스펙의 샘플 표 값도 갱신한다.
// 통과 구간은 좁다(대략 40 < g < 60). 실측: g=40 은 균형 구간 조건 실패(S/N 62.0%, T/F 55.3%, J/P 51.5%),
// g=60 은 EI 15/85 포화 실패(10.3%). g=50 은 S/N 균형 47.4%(한계 50% 미만), EI 포화 4.6%.
// analysis.ts 가중치나 아래 공식을 바꾸면 분포 테스트를 다시 돌리고 배율을 재조정해야 할 수 있다.
export const MBTI_GAIN = 50
const MIN_PCT = 15
const MAX_PCT = 85

export type AxisId = 'EI' | 'SN' | 'TF' | 'JP'
export type AxisResult = {
  axis: AxisId
  letters: [string, string]
  pctFirst: number
  lean: string
  balanced: boolean
  reasons: { label: string; points: number }[]
}
export type MbtiPrediction = { axes: AxisResult[]; type: string }

type Side = { el: Element[]; gr: TenGodGroup[] }
const AXES: { id: AxisId; letters: [string, string]; a: Side; b: Side }[] = [
  { id: 'EI', letters: ['E', 'I'], a: { el: ['火', '木'], gr: ['비겁', '식상'] }, b: { el: ['水', '金'], gr: ['인성', '관성'] } },
  { id: 'SN', letters: ['S', 'N'], a: { el: ['土', '金'], gr: ['재성'] }, b: { el: ['木', '水'], gr: ['식상'] } },
  { id: 'TF', letters: ['T', 'F'], a: { el: ['金', '水'], gr: ['관성'] }, b: { el: ['火', '土'], gr: ['인성'] } },
  { id: 'JP', letters: ['J', 'P'], a: { el: ['土', '金'], gr: ['관성', '재성'] }, b: { el: ['木', '火'], gr: ['식상', '비겁'] } },
]

type Part = { label: string; v: number } // v > 0 이면 첫 글자(E/S/T/J) 쪽으로 미는 힘

export function predictMbti(a: Analysis): MbtiPrediction {
  const elTotal = ELEMENTS.reduce((s, e) => s + a.elements[e], 0) || 1
  const grTotal = GROUPS.reduce((s, g) => s + a.groups[g], 0) || 1
  const el = (e: Element) => a.elements[e] / elTotal
  const gr = (g: TenGodGroup) => a.groups[g] / grTotal
  const elLabel = (e: Element) => `${ELEMENT_KO[e]}(${e}) 기운`
  const yang = isYang(a.dayGan) ? 1 : -1

  const axes = AXES.map(({ id, letters, a: A, b: B }): AxisResult => {
    const parts: Part[] = [
      ...A.el.map((e) => ({ label: elLabel(e), v: 0.5 * el(e) })),
      ...A.gr.map((g) => ({ label: g, v: 0.5 * gr(g) })),
      ...B.el.map((e) => ({ label: elLabel(e), v: -0.5 * el(e) })),
      ...B.gr.map((g) => ({ label: g, v: -0.5 * gr(g) })),
    ]
    const dayLabel = `일간 오행(${ELEMENT_KO[a.dayElement]})`
    if (A.el.includes(a.dayElement)) parts.push({ label: dayLabel, v: 0.15 })
    if (B.el.includes(a.dayElement)) parts.push({ label: dayLabel, v: -0.15 })
    if (id === 'EI') parts.push({ label: '일간 음양', v: 0.1 * yang })

    const d = parts.reduce((s, p) => s + p.v, 0)
    const pctFirst = Math.max(MIN_PCT, Math.min(MAX_PCT, Math.round(50 + MBTI_GAIN * d)))
    const sign = pctFirst >= 50 ? 1 : -1
    const reasons = parts
      .filter((p) => p.v * sign > 0)
      .sort((x, y) => Math.abs(y.v) - Math.abs(x.v))
      .slice(0, 2)
      .map((p) => ({ label: p.label, points: Math.round(Math.abs(p.v) * MBTI_GAIN) }))
    return {
      axis: id,
      letters,
      pctFirst,
      lean: sign > 0 ? letters[0] : letters[1],
      balanced: Math.abs(pctFirst - 50) < 10,
      reasons,
    }
  })
  return { axes, type: axes.map((x) => x.lean).join('') }
}

export function axisText(axis: AxisId, letter: string): { advice: string; minor: string } {
  return (data as Record<string, Record<string, { advice: string; minor: string }>>)[axis][letter]
}
