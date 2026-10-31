import { formatDate, formatDays, parseDate, type Balance } from "./lib";

export function BalanceCard({ b }: { b: Balance }) {
  // period_end 는 다음 기간의 시작일(배타적)이므로 표시할 땐 하루 전
  const end = parseDate(b.period_end);
  end.setDate(end.getDate() - 1);
  const endStr = `${end.getFullYear()}-${String(end.getMonth() + 1).padStart(2, "0")}-${String(end.getDate()).padStart(2, "0")}`;

  return (
    <section className="card">
      <div className="big">
        <span>남은 연차</span>
        <strong>{formatDays(b.remaining)}일</strong>
      </div>
      <dl className="stats">
        <div>
          <dt>발생</dt>
          <dd>{formatDays(b.granted)}</dd>
        </div>
        <div>
          <dt>사용</dt>
          <dd>{formatDays(b.used)}</dd>
        </div>
        <div>
          <dt>승인 대기</dt>
          <dd>{formatDays(b.pending)}</dd>
        </div>
      </dl>
      <p className="muted small">
        {formatDate(b.period_start)} ~ {formatDate(endStr)} 기간 · 기간이 끝나면 남은 연차는 소멸돼요.
      </p>
    </section>
  );
}
