import { describe, it, expect } from 'vitest'
import raw from '../src/data/readings.json'
import { GAN, ZHI, ELEMENTS, GROUPS } from '../src/lib/tables'

type Card = { summary: string; chips: string[]; bullets: string[] }
const C = (raw as unknown as {
  cards: {
    dayGan: Record<string, Card>
    dayZhi: Record<string, { summary: string }>
    group: Record<string, { trait: { summary: string }; work: Card }>
    lacking: Record<string, Card>
    balanced: Card
    strength: Record<string, Card>
    yongshin: Record<string, Card>
  }
}).cards

// 문체 원칙: 면책/오락 표현, 흉운·질병 단정 금지
const FORBIDDEN = ['재미', '오락', '사망', '질병', '불운', '저주', '이혼', '파산']
const clean = (v: unknown) => { for (const w of FORBIDDEN) expect(JSON.stringify(v)).not.toContain(w) }

function full(name: string, c: Card) {
  it(`${name}: 요약·칩 3·불릿 3, 글자 수 제한`, () => {
    expect(c.summary.length).toBeGreaterThan(0)
    expect(c.summary.length).toBeLessThanOrEqual(28)
    expect(c.chips).toHaveLength(3)
    for (const x of c.chips) { expect(x.length).toBeGreaterThan(0); expect(x.length).toBeLessThanOrEqual(8) }
    expect(c.bullets).toHaveLength(3)
    for (const x of c.bullets) { expect(x.length).toBeGreaterThan(0); expect(x.length).toBeLessThanOrEqual(42) }
    expect(new Set(c.chips).size).toBe(3)
    clean(c)
  })
}
function line(name: string, s: { summary: string }) {
  it(`${name}: 요약 한 줄`, () => {
    expect(s.summary.length).toBeGreaterThan(0)
    expect(s.summary.length).toBeLessThanOrEqual(42)
    clean(s)
  })
}

describe('readings.cards 완결성', () => {
  it('키 집합', () => {
    expect(Object.keys(C.dayGan).sort()).toEqual([...GAN].sort())
    expect(Object.keys(C.dayZhi).sort()).toEqual([...ZHI].sort())
    expect(Object.keys(C.group).sort()).toEqual([...GROUPS].sort())
    expect(Object.keys(C.lacking).sort()).toEqual([...ELEMENTS].sort())
    expect(Object.keys(C.strength).sort()).toEqual(['신강', '신약', '중화'])
    expect(Object.keys(C.yongshin).sort()).toEqual([...ELEMENTS].sort())
  })
  for (const k of GAN) full(`dayGan ${k}`, C.dayGan[k])
  for (const k of ZHI) line(`dayZhi ${k}`, C.dayZhi[k])
  for (const k of GROUPS) { line(`group ${k} trait`, C.group[k].trait); full(`group ${k} work`, C.group[k].work) }
  for (const k of ELEMENTS) { full(`lacking ${k}`, C.lacking[k]); full(`yongshin ${k}`, C.yongshin[k]) }
  for (const k of ['신강', '중화', '신약']) full(`strength ${k}`, C.strength[k])
  full('balanced', C.balanced)

  it('오행 부족 카드 5장의 칩은 서로 겹치지 않는다 (여러 오행이 비어도 칩 3개가 나오도록)', () => {
    const all = ELEMENTS.flatMap((e) => C.lacking[e].chips)
    expect(new Set(all).size).toBe(all.length)
  })
})
