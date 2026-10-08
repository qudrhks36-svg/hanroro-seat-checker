import { useMemo, useRef, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { ShareCard } from '@/components/ShareCard'
import { ReadingSections } from '@/components/ReadingSections'
import { YearFortuneCard } from '@/components/YearFortuneCard'
import { interpret, yearFortune } from '@/lib/interpret'
import { savePng, sharePng } from '@/lib/exportCard'
import type { Person } from '@/lib/person'

export function Result({ me, onReset }: { me: Person; onReset: () => void }) {
  const cardRef = useRef<HTMLDivElement>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(false)
  const year = useMemo(() => yearFortune(me.analysis, new Date().getFullYear()), [me])
  const sections = useMemo(() => interpret(me.pillars, me.analysis), [me])

  const run = async (fn: (n: HTMLElement) => Promise<void>) => {
    if (!cardRef.current) return
    setBusy(true)
    setError(false)
    try {
      await fn(cardRef.current)
    } catch (e) {
      if ((e as Error).name !== 'AbortError') setError(true)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-4">
      <Tabs defaultValue="reading">
        <TabsList className="grid w-full grid-cols-2">
          <TabsTrigger value="reading">풀이</TabsTrigger>
          <TabsTrigger value="compat">궁합</TabsTrigger>
        </TabsList>

        <TabsContent value="reading" className="space-y-3">
          <ShareCard innerRef={cardRef} person={me} year={year} />
          <div className="flex gap-2">
            <Button className="flex-1" disabled={busy} onClick={() => run(savePng)}>이미지 저장</Button>
            <Button className="flex-1" variant="outline" disabled={busy} onClick={() => run(sharePng)}>공유</Button>
          </div>
          {error && <p className="text-sm text-destructive">이미지를 만들지 못했습니다. 다시 시도해 주세요.</p>}
          <ReadingSections sections={sections} />
          <YearFortuneCard y={year} />
        </TabsContent>

        <TabsContent value="compat"><p className="text-sm text-muted-foreground">준비 중</p></TabsContent>
      </Tabs>
      <Button variant="ghost" className="w-full" onClick={onReset}>다시 입력</Button>
    </div>
  )
}
