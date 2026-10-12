import { Badge } from '@/components/ui/badge'
import type { Character } from '@/lib/character'
import type { Element } from '@/lib/tables'

const ACCENT: Record<Element, string> = {
  木: 'bg-emerald-100',
  火: 'bg-red-100',
  土: 'bg-amber-100',
  金: 'bg-slate-200',
  水: 'bg-sky-100',
}

export function CharacterCard({ character: c, chips }: { character: Character; chips: string[] }) {
  return (
    <div className={`flex items-center gap-4 rounded-2xl p-4 ${ACCENT[c.accent]}`}>
      <div className="relative flex size-20 shrink-0 items-center justify-center rounded-full bg-white/70 text-5xl" aria-hidden="true">
        {c.emoji}
        <span className="absolute -bottom-1 -right-1 flex size-8 items-center justify-center rounded-full bg-white text-xl shadow">{c.propEmoji}</span>
      </div>
      <div className="min-w-0 space-y-1.5">
        <div className="text-xs text-muted-foreground">{c.tone} · 소품 {c.propName}</div>
        <div className="text-lg font-bold leading-snug">{c.nickname}</div>
        <div className="flex flex-wrap gap-1">
          {chips.map((t) => <Badge key={t} variant="secondary">{t}</Badge>)}
        </div>
      </div>
    </div>
  )
}
