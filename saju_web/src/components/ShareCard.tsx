import { CharacterCard } from '@/components/CharacterCard'
import { headline } from '@/lib/interpret'
import { PillarsTable } from '@/components/PillarsTable'
import type { Character } from '@/lib/character'
import type { MbtiPrediction } from '@/lib/mbti'
import type { Person } from '@/lib/person'

type Props = {
  innerRef: React.RefObject<HTMLDivElement | null>
  person: Person
  character: Character
  chips: string[]
  prediction: MbtiPrediction
}

export function ShareCard({ innerRef, person, character, chips, prediction }: Props) {
  const { pillars, solar } = person
  return (
    // 공유 이미지는 4:5 세로 비율을 최소로 하고 내용이 많으면 늘어난다
    <div ref={innerRef} className="flex flex-col gap-4 rounded-2xl border bg-background p-5" style={{ aspectRatio: '4 / 5' }}>
      <div className="text-xs text-muted-foreground">{solar.y}.{solar.m}.{solar.d} (양력 기준)</div>
      <CharacterCard character={character} chips={chips} summary={headline(person.analysis)} />
      <div className="space-y-2">
        <div className="flex items-center justify-between text-sm font-medium">
          <span>사주가 말하는 MBTI 경향</span>
          <span>{prediction.type}</span>
        </div>
        <div className="text-xs text-muted-foreground">사주 기운을 MBTI 축으로 번역한 경향</div>
        {prediction.axes.map((x) => {
          const pctSecond = 100 - x.pctFirst
          return (
            <div key={x.axis} className="flex items-center gap-2 text-xs">
              <span className="w-12 tabular-nums">{x.letters[0]} {x.pctFirst}%</span>
              <div className="flex h-1.5 flex-1 overflow-hidden rounded-full bg-muted">
                <div className="bg-sky-500" style={{ width: `${x.pctFirst}%` }} />
                <div className="bg-amber-500" style={{ width: `${pctSecond}%` }} />
              </div>
              <span className="w-12 text-right tabular-nums">{pctSecond}% {x.letters[1]}</span>
            </div>
          )
        })}
      </div>
      <PillarsTable pillars={pillars} />
    </div>
  )
}
