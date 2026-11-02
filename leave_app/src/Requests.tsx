import { useState } from "react";
import type { Api } from "./api";
import {
  STATUS_LABEL,
  TYPE_LABEL,
  errorMessage,
  formatDays,
  formatRange,
  todayString,
  type Employee,
  type LeaveRequest,
} from "./lib";

/** 승인 대기 중인 결재 — 누구나 승인/반려/취소할 수 있다 */
export function Pending({
  api,
  items,
  employees,
  onChanged,
}: {
  api: Api;
  items: LeaveRequest[];
  employees: Employee[];
  onChanged: () => void;
}) {
  const [comment, setComment] = useState<Record<number, string>>({});
  const [err, setErr] = useState<string | null>(null);

  async function run(fn: () => Promise<unknown>) {
    try {
      await fn();
      setErr(null);
      onChanged();
    } catch (e) {
      setErr(errorMessage(e));
    }
  }

  return (
    <section className="card">
      <h2>승인 대기 {items.length > 0 && <span className="count">{items.length}</span>}</h2>
      {err && <p className="warn">{err}</p>}
      {items.length === 0 && <p className="muted">승인 대기 중인 결재가 없어요.</p>}
      {items.map((r) => {
        const bal = employees.find((e) => e.id === r.employee_id)?.balance;
        return (
          <div className="item" key={r.id}>
            <div className="between">
              <strong>{r.employee_name}</strong>
              <span className="badge pending">
                {TYPE_LABEL[r.leave_type]} {formatDays(r.days)}일
              </span>
            </div>
            <p>{formatRange(r)}</p>
            {r.reason && <p className="muted">{r.reason}</p>}
            {bal && (
              <p className="muted small">
                현재 잔여 {formatDays(bal.remaining)}일 (대기 중인 신청 차감 후) · 발생 {formatDays(bal.granted)} / 사용{" "}
                {formatDays(bal.used)}
              </p>
            )}
            <input
              type="text"
              placeholder="코멘트 (선택)"
              value={comment[r.id] ?? ""}
              onChange={(e) => setComment({ ...comment, [r.id]: e.target.value })}
            />
            <div className="actions">
              <button className="primary" onClick={() => run(() => api.decide(r.id, true, comment[r.id] ?? ""))}>
                승인
              </button>
              <button className="danger" onClick={() => run(() => api.decide(r.id, false, comment[r.id] ?? ""))}>
                반려
              </button>
              <button
                className="link"
                onClick={() => {
                  if (window.confirm(`${r.employee_name}님의 ${formatRange(r)} 신청을 취소할까요?`))
                    void run(() => api.cancel(r.id));
                }}
              >
                신청 취소
              </button>
            </div>
          </div>
        );
      })}
    </section>
  );
}

/** 처리된 내역 — 아직 끝나지 않은 승인 건은 취소해서 연차를 되돌릴 수 있다 */
export function History({ api, items, onChanged }: { api: Api; items: LeaveRequest[]; onChanged: () => void }) {
  const [err, setErr] = useState<string | null>(null);
  const [showAll, setShowAll] = useState(false);
  const today = todayString();
  const shown = showAll ? items : items.slice(0, 15);

  async function cancel(r: LeaveRequest) {
    if (!window.confirm(`${r.employee_name}님의 ${formatRange(r)} 승인을 취소하고 연차를 되돌릴까요?`)) return;
    try {
      await api.cancel(r.id, "승인 취소");
      setErr(null);
      onChanged();
    } catch (e) {
      setErr(errorMessage(e));
    }
  }

  return (
    <section className="card">
      <h2>처리 내역</h2>
      {err && <p className="warn">{err}</p>}
      {items.length === 0 && <p className="muted">처리한 내역이 없어요.</p>}
      <ul className="list">
        {shown.map((r) => (
          <li key={r.id}>
            <div>
              <strong>{r.employee_name}</strong> · {formatRange(r)}
              <div className="muted">
                {TYPE_LABEL[r.leave_type]} {formatDays(r.days)}일
                {r.reason && ` · ${r.reason}`}
                {r.decision_comment && ` · 코멘트: ${r.decision_comment}`}
              </div>
            </div>
            <div className="right">
              <span className={`badge ${r.status}`}>{STATUS_LABEL[r.status]}</span>
              {r.status === "approved" && r.end_date >= today && (
                <button className="link" onClick={() => cancel(r)}>
                  승인 취소
                </button>
              )}
            </div>
          </li>
        ))}
      </ul>
      {items.length > 15 && (
        <button className="link" onClick={() => setShowAll(!showAll)}>
          {showAll ? "접기" : `전체 ${items.length}건 보기`}
        </button>
      )}
    </section>
  );
}
