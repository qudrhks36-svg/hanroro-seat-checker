import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'
import { InputForm } from '@/components/InputForm'
import { Result } from '@/components/Result'
import { BirthInputError, type BirthInput } from '@/lib/saju'
import { buildPerson, type Person } from '@/lib/person'

export default function App() {
  const [me, setMe] = useState<Person | null>(null)
  const [error, setError] = useState('')

  const submit = (b: BirthInput) => {
    try {
      setMe(buildPerson(b))
      setError('')
    } catch (e) {
      setError(e instanceof BirthInputError ? e.message : '계산 중 오류가 발생했습니다. 입력값을 확인해 주세요.')
    }
  }

  return (
    <main className="mx-auto min-h-screen max-w-2xl px-4 py-8">
      {me ? (
        <Result me={me} onReset={() => setMe(null)} />
      ) : (
        <Card>
          <CardHeader>
            <CardTitle className="text-2xl">사주 풀이</CardTitle>
            <CardDescription>생년월일시로 사주 구조, 오행 균형, 올해 흐름과 궁합 상대를 분석합니다.</CardDescription>
          </CardHeader>
          <CardContent><InputForm submitLabel="사주 보기" onSubmit={submit} error={error} /></CardContent>
        </Card>
      )}
    </main>
  )
}
