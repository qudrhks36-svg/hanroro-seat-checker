import { Solar, Lunar, LunarYear } from 'lunar-typescript'

export type Gender = 'male' | 'female'
export type BirthInput = {
  calendar: 'solar' | 'lunar'
  year: number
  month: number
  day: number
  leap?: boolean
  hour?: number
  minute?: number
  gender: Gender
}
export type Pillar = { gan: string; zhi: string }
export type Pillars = { year: Pillar; month: Pillar; day: Pillar; time: Pillar | null }
export type SolarDate = { y: number; m: number; d: number }

export const MIN_YEAR = 1900
export const MAX_YEAR = 2100
export class BirthInputError extends Error {}

function fail(msg: string): never {
  throw new BirthInputError(msg)
}

export function toSolar(i: BirthInput): SolarDate {
  const { year, month, day } = i
  if (![year, month, day].every(Number.isInteger)) fail('생년월일을 숫자로 입력해 주세요.')
  if (year < MIN_YEAR || year > MAX_YEAR) fail(`${MIN_YEAR}~${MAX_YEAR}년 사이만 지원합니다.`)
  if (i.calendar === 'solar') {
    const t = new Date(Date.UTC(year, month - 1, day))
    if (t.getUTCFullYear() !== year || t.getUTCMonth() !== month - 1 || t.getUTCDate() !== day)
      fail('존재하지 않는 양력 날짜입니다.')
    return { y: year, m: month, d: day }
  }
  if (month < 1 || month > 12) fail('음력 월은 1~12 사이여야 합니다.')
  const ly = LunarYear.fromYear(year)
  if (i.leap && ly.getLeapMonth() !== month) fail(`${year}년에는 윤${month}월이 없습니다.`)
  const signed = i.leap ? -month : month
  const lm = ly.getMonth(signed)
  if (!lm || day < 1 || day > lm.getDayCount()) fail('존재하지 않는 음력 날짜입니다.')
  const s = Lunar.fromYmd(year, signed, day).getSolar()
  return { y: s.getYear(), m: s.getMonth(), d: s.getDay() }
}

function readTime(i: BirthInput): { hour: number; minute: number } | null {
  const { hour: h, minute: m } = i
  if (h === undefined && m === undefined) return null
  if (h === undefined || m === undefined || !Number.isInteger(h) || !Number.isInteger(m) || h < 0 || h > 23 || m < 0 || m > 59)
    fail('태어난 시간을 올바르게 입력해 주세요.')
  return { hour: h, minute: m }
}

const split = (gz: string): Pillar => ({ gan: gz[0], zhi: gz[1] })

export function calcPillars(i: BirthInput): { solar: SolarDate; pillars: Pillars } {
  const solar = toSolar(i)
  const time = readTime(i)
  // ponytail: 시간 모름이면 정오 기준으로 연·월·일 계산. 절기 당일 출생이면 월주가 달라질 수 있음.
  const h = time?.hour ?? 12
  const mi = time?.minute ?? 0
  // 일주·시주: 한국 시각 그대로. sect 2 = 야자시(23시 이후도 당일 일주 유지).
  const kst = Solar.fromYmdHms(solar.y, solar.m, solar.d, h, mi, 0).getLunar().getEightChar()
  kst.setSect(2)
  // 연주·월주: 라이브러리 절기가 UTC+8 기준이라 한국 시각에서 1시간을 뺀다.
  const t = new Date(Date.UTC(solar.y, solar.m - 1, solar.d, h - 1, mi))
  const cst = Solar.fromYmdHms(
    t.getUTCFullYear(), t.getUTCMonth() + 1, t.getUTCDate(), t.getUTCHours(), t.getUTCMinutes(), 0,
  ).getLunar().getEightChar()
  return {
    solar,
    pillars: {
      year: split(cst.getYear()),
      month: split(cst.getMonth()),
      day: split(kst.getDay()),
      time: time ? split(kst.getTime()) : null,
    },
  }
}
