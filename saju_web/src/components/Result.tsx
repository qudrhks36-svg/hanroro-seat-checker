import { useMemo, useRef, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { ShareCard } from '@/components/ShareCard'
import { MbtiCard } from '@/components/MbtiCard'
import { ReadingCard } from '@/components/ReadingCard'
import { SituationBubbles } from '@/components/SituationBubbles'
import { YearFortuneCard } from '@/components/YearFortuneCard'
import { PartnerRecommend } from '@/components/PartnerRecommend'
import { CompatPanel } from '@/components/CompatPanel'
import { buildCharacter } from '@/lib/character'
import { interpret, yearFortune } from '@/lib/interpret'
import { predictMbti } from '@/lib/mbti'
import { savePng, sharePng } from '@/lib/exportCard'
import type { Person } from '@/lib/person'

export function Result({ me, onReset }: { me: Person; onReset: () => void }) {
  const cardRef = useRef<HTMLDivElement>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(false)
  const year = useMemo(() => yearFortune(me.analysis, new Date().getFullYear()), [me])
  const sections = useMemo(() => interpret(me.pillars, me.analysis), [me])
  const prediction = useMemo(() => predictMbti(me.analysis), [me])
  const character = useMemo(
    () => buildCharacter({
      dayGan: me.pillars.day.gan,
      dayZhi: me.pillars.day.zhi,
      group: me.analysis.dominantGroup,
      strength: me.analysis.strength,
      dayElement: me.analysis.dayElement,
    }),
    [me],
  )

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
          <ShareCard innerRef={cardRef} person={me} character={character} chips={sections[0].chips} prediction={prediction} />
          <div className="flex gap-2">
            <Button className="flex-1" disabled={busy} onClick={() => run(savePng)}>이미지 저장</Button>
            <Button className="flex-1" variant="outline" disabled={busy} onClick={() => run(sharePng)}>공유</Button>
          </div>
          {error && <p className="text-sm text-destructive">이미지를 만들지 못했습니다. 다시 시도해 주세요.</p>}
          <MbtiCard prediction={prediction} />
          {sections.map((s) => <ReadingCard key={s.title} section={s} />)}
          <SituationBubbles bubbles={character.bubbles} />
          <YearFortuneCard y={year} />
        </TabsContent>

        <TabsContent value="compat" className="space-y-3">
          <PartnerRecommend me={me} />
          <CompatPanel me={me} />
        </TabsContent>
      </Tabs>
      <Button variant="ghost" className="w-full" onClick={onReset}>다시 입력</Button>
    </div>
  )
}
