import { useCallback, useEffect, useState } from "react";
import { api } from "./api";
import {
  STATUS_LABEL,
  TYPE_LABEL,
  errorMessage,
  formatDays,
  formatRange,
  previewDays,
  todayString,
  type LeaveRequest,
  type LeaveType,
  type Me,
} from "./lib";
import { BalanceCard } from "./BalanceCard";

export default function Staff({ token, me, onChanged }: { token: string; me: Me; onChanged: () => void }) {
  const [requests, setRequests] = useState<LeaveRequest[]>([]);
  const [type, setType] = useState<LeaveType>("annual");
  const [start, setStart] = useState("");
  const [end, setEnd] = useState("");
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ kind: "ok" | "err"; text: string } | null>(null);

  const load = useCallback(async () => {
    try {
      setRequests(await api.myRequests(token));
    } catch (e) {
      setMsg({ kind: "err", text: errorMessage(e) });
    }
  }, [token]);

  useEffect(() => {
    void load();
  }, [load]);

  const days = previewDays(type, start, type === "annual" ? end || start : start);
  const remaining = me.balance?.remaining ?? 0;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    try {
      await api.submit(token, type, start, type === "annual" ? end || start : null, reason.trim());
      setMsg({ kind: "ok", text: "결재를 올렸어요. 대표님이 확인하면 알려드릴게요." });
      setStart("");
      setEnd("");
      setReason("");
      await load();
      onChanged();
    } catch (err) {
      setMsg({ kind: "err", text: errorMessage(err) });
    } finally {
      setBusy(false);
    }
  }

  async function cancel(r: LeaveRequest) {
    if (!window.confirm(`${formatRange(r)} ${TYPE_LABEL[r.leave_type]} 신청을 취소할까요?`)) return;
    try {
      await api.cancel(token, r.id);
      await load();
      onChanged();
    } catch (err) {
      setMsg({ kind: "err", text: errorMessage(err) });
    }
  }

  const today = todayString();

  return (
    <main className="wrap">
      <header className="top">
        <h1>{me.name}님의 연차</h1>
      </header>

      {me.balance ? <BalanceCard b={me.balance} /> : <div className="card muted">입사일이 등록되지 않았어요.</div>}

      <form className="card" onSubmit={submit}>
        <h2>결재 올리기</h2>

        <div className="seg" role="radiogroup" aria-label="휴가 종류">
          {(Object.keys(TYPE_LABEL) as LeaveType[]).map((t) => (
            <button
              key={t}
              type="button"
              role="radio"
              aria-checked={type === t}
              className={type === t ? "on" : ""}
              onClick={() => setType(t)}
            >
              {TYPE_LABEL[t]}
            </button>
          ))}
        </div>

        <div className="row">
          <label>
            {type === "annual" ? "시작일" : "날짜"}
            <input type="date" value={start} min={today} required onChange={(e) => setStart(e.target.value)} />
          </label>
          {type === "annual" && (
            <label>
              종료일
              <input type="date" value={end} min={start || today} onChange={(e) => setEnd(e.target.value)} />
            </label>
          )}
        </div>

        <label>
          사유 (선택)
          <input type="text" value={reason} maxLength={200} onChange={(e) => setReason(e.target.value)} />
        </label>

        {start && (
          <p className={days > remaining ? "warn" : "muted"}>
            {days === 0
              ? "주말만 선택되어 있어요."
              : `${formatDays(days)}일 차감 · 신청 후 잔여 ${formatDays(remaining - days)}일`}
          </p>
        )}

        <button className="primary" disabled={busy || !start || days === 0}>
          {busy ? "올리는 중…" : "결재 올리기"}
        </button>
        {msg && <p className={msg.kind === "ok" ? "ok" : "warn"}>{msg.text}</p>}
      </form>

      <section className="card">
        <h2>내 신청 내역</h2>
        {requests.length === 0 && <p className="muted">아직 신청한 내역이 없어요.</p>}
        <ul className="list">
          {requests.map((r) => (
            <li key={r.id}>
              <div>
                <strong>{formatRange(r)}</strong> · {TYPE_LABEL[r.leave_type]} {formatDays(r.days)}일
                {r.reason && <div className="muted">{r.reason}</div>}
                {r.decision_comment && <div className="muted">대표: {r.decision_comment}</div>}
              </div>
              <div className="right">
                <span className={`badge ${r.status}`}>{STATUS_LABEL[r.status]}</span>
                {(r.status === "pending" || (r.status === "approved" && r.start_date > today)) && (
                  <button className="link" onClick={() => cancel(r)}>
                    취소
                  </button>
                )}
              </div>
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
