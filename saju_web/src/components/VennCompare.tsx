import type { Compare } from '@/lib/compare'

function column(items: string[], x: number) {
  return items.map((t, i) => (
    <text
      key={`${t}${i}`}
      x={x}
      y={108 + (i - (items.length - 1) / 2) * 24}
      textAnchor="middle"
      dominantBaseline="middle"
      fontSize="20"
      fontWeight="600"
      className="fill-foreground"
    >
      {t}
    </text>
  ))
}

export function VennCompare({ c }: { c: Compare }) {
  return (
    <div className="space-y-2">
      <svg viewBox="0 0 320 220" className="w-full" role="img" aria-label={`사주 예측과 내 MBTI가 4축 중 ${c.matched.length}축 일치`}>
        <circle cx="120" cy="115" r="75" className="fill-sky-500/20 stroke-sky-500" strokeWidth="1.5" />
        <circle cx="200" cy="115" r="75" className="fill-amber-500/20 stroke-amber-500" strokeWidth="1.5" />
        <text x="95" y="16" textAnchor="middle" fontSize="12" className="fill-muted-foreground">사주가 말하는 나</text>
        <text x="225" y="16" textAnchor="middle" fontSize="12" className="fill-muted-foreground">내 MBTI</text>
        {column(c.onlySaju, 85)}
        {column(c.matched, 160)}
        {column(c.onlyMbti, 235)}
        <text x="160" y="212" textAnchor="middle" fontSize="13" fontWeight="600" className="fill-foreground">{c.matched.length}/4 일치</text>
      </svg>
      {c.notes.length > 0 && (
        <ul className="list-disc space-y-1 pl-5 text-sm text-muted-foreground">
          {c.notes.map((n) => <li key={n}>{n}</li>)}
        </ul>
      )}
    </div>
  )
}
