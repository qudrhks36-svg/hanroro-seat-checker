import { useMemo, useState } from 'react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { VennCompare } from '@/components/VennCompare'
import { compareMbti } from '@/lib/compare'
import { axisText, type MbtiPrediction } from '@/lib/mbti'

export function MbtiCard({ prediction }: { prediction: MbtiPrediction }) {
  const [pick, setPick] = useState<(string | null)[]>([null, null, null, null])
  const done = pick.every((p) => p !== null)
  const compare = useMemo(() => (done ? compareMbti(prediction, pick.join('')) : null), [done, pick, prediction])

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center gap-2 text-base">
          사주가 말하는 MBTI 경향 <Badge>{prediction.type}</Badge>
        </CardTitle>
        <p className="text-xs text-muted-foreground">사주 기운을 MBTI 축으로 번역한 경향입니다.</p>
      </CardHeader>
      <CardContent className="space-y-5">
        <div className="space-y-4">
          {prediction.axes.map((x) => {
            const [first, second] = x.letters
            const pctSecond = 100 - x.pctFirst
            const t = axisText(x.axis, x.lean)
            return (
              <div key={x.axis} className="space-y-1.5">
                <div className="flex items-baseline justify-between text-sm">
                  <span className="font-medium">{first} {x.pctFirst}%</span>
                  <span className="text-xs text-muted-foreground">
                    {x.balanced ? '두 성향이 비슷해요' : `${x.lean}일 확률이 높아요`}
                  </span>
                  <span className="font-medium">{pctSecond}% {second}</span>
                </div>
                <div className="flex h-2 overflow-hidden rounded-full bg-muted" aria-hidden="true">
                  <div className="bg-sky-500" style={{ width: `${x.pctFirst}%` }} />
                  <div className="bg-amber-500" style={{ width: `${pctSecond}%` }} />
                </div>
                <p className="text-sm leading-relaxed">{t.advice}</p>
                <details className="text-sm">
                  <summary className="cursor-pointer text-xs text-muted-foreground">근거 보기</summary>
                  {x.reasons.length > 0 && (
                    <ul className="mt-2 list-disc space-y-0.5 pl-5 text-xs text-muted-foreground">
                      {x.reasons.map((r) => <li key={r.label}>{r.label}: {x.lean} 쪽 +{r.points}%p</li>)}
                    </ul>
                  )}
                  <p className="mt-2 leading-relaxed text-muted-foreground">{t.minor}</p>
                </details>
              </div>
            )
          })}
        </div>

        <div className="space-y-2 border-t pt-4">
          <p className="text-sm font-medium">내 MBTI와 비교해 보기</p>
          <div className="grid grid-cols-4 gap-2">
            {prediction.axes.map((x, i) => (
              <div key={x.axis} role="group" aria-label={`${x.letters[0]} 또는 ${x.letters[1]} 선택`} className="flex flex-col gap-1">
                {x.letters.map((l) => (
                  <Button
                    key={l}
                    type="button"
                    size="sm"
                    variant={pick[i] === l ? 'default' : 'outline'}
                    aria-pressed={pick[i] === l}
                    onClick={() => setPick((p) => p.map((v, j) => (j === i ? l : v)))}
                  >
                    {l}
                  </Button>
                ))}
              </div>
            ))}
          </div>
          {compare && <VennCompare c={compare} />}
          {pick.some((p) => p !== null) && (
            <Button type="button" variant="ghost" size="sm" onClick={() => setPick([null, null, null, null])}>다시 고르기</Button>
          )}
        </div>
      </CardContent>
    </Card>
  )
}
