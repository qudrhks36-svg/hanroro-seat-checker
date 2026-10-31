import { useCallback, useEffect, useState } from "react";
import { api, configured } from "./api";
import { errorMessage, type Me } from "./lib";
import Staff from "./Staff";
import Admin from "./Admin";

const STORAGE_KEY = "leave_token";

/** 주소의 ?t=토큰 을 한 번 읽어 저장하고 주소창에서는 지운다. */
function loadToken(): string | null {
  const params = new URLSearchParams(window.location.search);
  const fromUrl = params.get("t");
  if (fromUrl) {
    localStorage.setItem(STORAGE_KEY, fromUrl);
    window.history.replaceState(null, "", window.location.pathname);
    return fromUrl;
  }
  return localStorage.getItem(STORAGE_KEY);
}

export default function App() {
  const [token] = useState(loadToken);
  const [me, setMe] = useState<Me | null>(null);
  const [error, setError] = useState<string | null>(null);

  const refreshMe = useCallback(async () => {
    if (!token) return;
    try {
      setMe(await api.me(token));
      setError(null);
    } catch (e) {
      setError(errorMessage(e));
    }
  }, [token]);

  useEffect(() => {
    void refreshMe();
  }, [refreshMe]);

  if (!configured) {
    return <Notice title="설정이 필요해요">VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY 환경변수를 설정해 주세요.</Notice>;
  }
  if (!token) {
    return <Notice title="연차 · 반차 결재">대표님께 받은 개인 링크로 접속해 주세요.</Notice>;
  }
  if (error) return <Notice title="접속할 수 없어요">{error}</Notice>;
  if (!me) return <Notice title="불러오는 중…">{null}</Notice>;

  return me.role === "admin" ? (
    <Admin token={token} me={me} />
  ) : (
    <Staff token={token} me={me} onChanged={refreshMe} />
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
