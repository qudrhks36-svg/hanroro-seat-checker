import { useState } from 'react'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import { InputForm } from '@/components/InputForm'
import { compatibility, type Compat } from '@/lib/compat'
import { buildPerson } from '@/lib/person'
import { BirthInputError, type BirthInput } from '@/lib/saju'
import type { Person } from '@/lib/person'

export function CompatPanel({ me }: { me: Person }) {
  const [result, setResult] = useState<Compat | null>(null)
  const [error, setError] = useState('')

  const submit = (b: BirthInput) => {
    try {
      const other = buildPerson(b)
      setResult(compatibility(me.pillars, me.analysis, other.pillars, other.analysis))
      setError('')
    } catch (e) {
      setResult(null)
      setError(e instanceof BirthInputError ? e.message : '계산 중 오류가 발생했습니다. 입력값을 확인해 주세요.')
    }
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-base">상대 사주로 궁합 보기</CardTitle>
        <CardDescription>상대의 생년월일시를 입력하면 일지·띠의 합충, 일간 합, 용신 보완도를 종합합니다.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-5">
        <InputForm submitLabel="궁합 보기" onSubmit={submit} error={error} />
        {result && (
          <div className="space-y-3 border-t pt-4 text-sm leading-relaxed">
            <div className="flex items-center gap-3">
              <span className="text-3xl font-semibold tabular-nums">{result.score}</span>
              <Badge>{result.level}</Badge>
            </div>
            <Progress value={result.score} className="h-2" />
            {result.reasons.map((t, i) => <p key={`r${i}`}>{t}</p>)}
            {result.cautions.map((t, i) => <p key={`c${i}`} className="text-muted-foreground">주의: {t}</p>)}
          </div>
        )}
      </CardContent>
    </Card>
  )
}
