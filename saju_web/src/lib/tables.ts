export const GAN = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸']
export const ZHI = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥']
export const GAN_KO = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계']
export const ZHI_KO = ['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해']
export const ZODIAC = ['쥐', '소', '호랑이', '토끼', '용', '뱀', '말', '양', '원숭이', '닭', '개', '돼지']

export type Element = '木' | '火' | '土' | '金' | '水'
// 상생 순서: 인덱스 i 가 i+1 을 생하고, i+2 를 극한다.
export const ELEMENTS: Element[] = ['木', '火', '土', '金', '水']
export const ELEMENT_KO: Record<Element, string> = { 木: '목', 火: '화', 土: '토', 金: '금', 水: '수' }
export const GAN_ELEMENT: Element[] = ['木', '木', '火', '火', '土', '土', '金', '金', '水', '水']
export const ZHI_ELEMENT: Element[] = ['水', '土', '木', '木', '土', '火', '火', '土', '金', '金', '土', '水']
// 지지 본기(지장간 중 대표 천간). ponytail: 중기·여기 미반영, 정밀 분석이 필요하면 지장간 가중치 도입.
export const ZHI_MAIN_GAN = ['癸', '己', '甲', '乙', '戊', '丙', '丁', '己', '庚', '辛', '戊', '壬']

export type TenGod = '비견' | '겁재' | '식신' | '상관' | '편재' | '정재' | '편관' | '정관' | '편인' | '정인'
export type TenGodGroup = '비겁' | '식상' | '재성' | '관성' | '인성'
// 인덱스 = 일간 오행에서 상대 오행까지의 거리 (0 같은 오행, 1 내가 생함, 2 내가 극함, 3 나를 극함, 4 나를 생함)
export const GROUPS: TenGodGroup[] = ['비겁', '식상', '재성', '관성', '인성']
const GOD_BY_GROUP: Record<TenGodGroup, [TenGod, TenGod]> = {
  // [음양 같음, 음양 다름]
  비겁: ['비견', '겁재'],
  식상: ['식신', '상관'],
  재성: ['편재', '정재'],
  관성: ['편관', '정관'],
  인성: ['편인', '정인'],
}

export const ganEl = (gan: string): Element => GAN_ELEMENT[GAN.indexOf(gan)]
export const zhiEl = (zhi: string): Element => ZHI_ELEMENT[ZHI.indexOf(zhi)]
export const isYang = (gan: string): boolean => GAN.indexOf(gan) % 2 === 0

export function groupBetween(dayGan: string, other: string): TenGodGroup {
  const d = (ELEMENTS.indexOf(ganEl(other)) - ELEMENTS.indexOf(ganEl(dayGan)) + 5) % 5
  return GROUPS[d]
}

export function tenGod(dayGan: string, other: string): TenGod {
  const same = isYang(dayGan) === isYang(other)
  return GOD_BY_GROUP[groupBetween(dayGan, other)][same ? 0 : 1]
}

export const groupElement = (dayEl: Element, g: TenGodGroup): Element =>
  ELEMENTS[(ELEMENTS.indexOf(dayEl) + GROUPS.indexOf(g)) % 5]

const LIUHE = ['子丑', '寅亥', '卯戌', '辰酉', '巳申', '午未']
const SANHE = ['申子辰', '亥卯未', '寅午戌', '巳酉丑']
const CHONG = ['子午', '丑未', '寅申', '卯酉', '辰戌', '巳亥']
const GAN_HE = ['甲己', '乙庚', '丙辛', '丁壬', '戊癸']
const has = (list: string[], a: string, b: string) => list.some((s) => s.includes(a) && s.includes(b))

export type ZhiRel = '육합' | '삼합' | '충' | null
export function zhiRelation(a: string, b: string): ZhiRel {
  if (a === b) return null
  if (has(LIUHE, a, b)) return '육합'
  if (has(CHONG, a, b)) return '충'
  if (has(SANHE, a, b)) return '삼합'
  return null
}

export const ganHe = (a: string, b: string): boolean => a !== b && has(GAN_HE, a, b)
