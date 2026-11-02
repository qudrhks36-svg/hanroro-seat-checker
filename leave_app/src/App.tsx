import { useCallback, useEffect, useMemo, useState } from "react";
import { configured, createApi } from "./api";
import { errorMessage, type LeaveRequest, type Overview } from "./lib";
import Roster from "./Roster";
import RequestForm from "./RequestForm";
import { History, Pending } from "./Requests";
import People from "./People";

const TOKEN_KEY = "leave_token";

/** 주소의 ?t=토큰 을 한 번 읽어 저장하고 주소창에서는 지운다. */
function loadToken(): string | null {
  const params = new URLSearchParams(window.location.search);
  const fromUrl = params.get("t");
  try {
    if (fromUrl) {
      localStorage.setItem(TOKEN_KEY, fromUrl);
      window.history.replaceState(null, "", window.location.pathname);
      return fromUrl;
    }
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return fromUrl;
  }
}

export default function App() {
  const [token, setToken] = useState(loadToken);
  const api = useMemo(() => (token ? createApi(token) : null), [token]);
  const [overview, setOverview] = useState<Overview | null>(null);
  const [requests, setRequests] = useState<LeaveRequest[]>([]);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (!api) return;
    try {
      const [ov, rq] = await Promise.all([api.overview(), api.requests()]);
      setOverview(ov);
      setRequests(rq);
      setError(null);
    } catch (e) {
      setError(errorMessage(e));
    }
  }, [api]);

  useEffect(() => {
    void refresh();
    // 다른 사람이 올린 신청/승인이 보이도록 탭으로 돌아오거나 1분마다 새로 불러온다
    const onVisible = () => document.visibilityState === "visible" && void refresh();
    document.addEventListener("visibilitychange", onVisible);
    const timer = window.setInterval(onVisible, 60_000);
    return () => {
      document.removeEventListener("visibilitychange", onVisible);
      window.clearInterval(timer);
    };
  }, [refresh]);

  function changeToken(next: string) {
    try {
      localStorage.setItem(TOKEN_KEY, next);
    } catch {
      /* 저장이 막힌 브라우저에서는 이번 접속에서만 유효 */
    }
    setToken(next);
  }

  if (!configured) {
    return <Notice title="설정이 필요해요">VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY 환경변수를 설정해 주세요.</Notice>;
  }
  if (!token || !api) {
    return <Notice title="연차 · 반차 결재">회사 공용 링크로 접속해 주세요.</Notice>;
  }
  if (error && !overview) return <Notice title="접속할 수 없어요">{error}</Notice>;
  if (!overview) return <Notice title="불러오는 중…">{null}</Notice>;

  const pending = requests.filter((r) => r.status === "pending");
  const history = requests.filter((r) => r.status !== "pending");

  return (
    <main className="wrap">
      <header className="top">
        <h1>연차 · 반차 결재</h1>
        {overview.pending_count > 0 && <span className="count">승인 대기 {overview.pending_count}</span>}
      </header>
      {error && <p className="warn">{error}</p>}

      <Roster employees={overview.employees} />
      <RequestForm api={api} employees={overview.employees} onChanged={refresh} />
      <Pending api={api} items={pending} employees={overview.employees} onChanged={refresh} />
      <History api={api} items={history} onChanged={refresh} />
      <People api={api} employees={overview.employees} onChanged={refresh} onTokenChanged={changeToken} />
    </main>
  );
}

function Notice({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <main className="wrap">
      <div className="card center">
        <h1>{title}</h1>
        {children && <p className="muted">{children}</p>}
      </div>
    </main>
  );
}
