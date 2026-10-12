import type { MbtiPrediction } from './mbti'

export type Compare = { matched: string[]; onlySaju: string[]; onlyMbti: string[]; score: number; notes: string[] }

export function compareMbti(pred: MbtiPrediction, actual: string): Compare {
  if (!/^[EI][SN][TF][JP]$/.test(actual)) throw new Error(`invalid MBTI: ${actual}`)
  const matched: string[] = []
  const onlySaju: string[] = []
  const onlyMbti: string[] = []
  const notes: string[] = []
  pred.axes.forEach((x, i) => {
    const letter = actual[i]
    if (letter === x.lean) {
      matched.push(letter)
      return
    }
    onlySaju.push(x.lean)
    onlyMbti.push(letter)
    const pct = letter === x.letters[0] ? x.pctFirst : 100 - x.pctFirst
    notes.push(pct >= 35 ? `사주에서도 ${letter} 쪽이 ${pct}%로 꽤 있는 편입니다` : `${letter} 쪽은 사주 경향과 다른 축입니다`)
  })
  return { matched, onlySaju, onlyMbti, score: matched.length / 4, notes }
}
