import os
import re
from urllib.parse import quote

import requests

HEADERS = {"User-Agent": "Mozilla/5.0"}

TELEGRAM_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
TELEGRAM_CHAT_ID = os.environ["TELEGRAM_CHAT_ID"]
OPENROUTER_API_KEY = os.environ["OPENROUTER_API_KEY"]

# stock_agents/blog_agent와 동일한 무료 모델 폴백 목록 (순서대로 시도, 429/오류 시 다음 모델)
FREE_MODELS = [
    "google/gemma-4-26b-a4b-it:free",
    "meta-llama/llama-3.3-70b-instruct:free",
    "nvidia/nemotron-3-nano-30b-a3b:free",
    "qwen/qwen3-next-80b-a3b-instruct:free",
    "google/gemma-4-31b-it:free",
    "nousresearch/hermes-3-llama-3.1-405b:free",
    "meta-llama/llama-3.2-3b-instruct:free",
    "nvidia/nemotron-nano-9b-v2:free",
]

QUERIES = ["한로로 콘서트", "한로로 페스티벌", "한로로 공연", "한로로 내한"]


def send_telegram(message: str) -> None:
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    resp = requests.post(url, data={"chat_id": TELEGRAM_CHAT_ID, "text": message}, timeout=15)
    print(f"[telegram] status={resp.status_code} body={resp.text}")
    resp.raise_for_status()


def decode_entities(s: str) -> str:
    return (
        s.replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&amp;", "&")
        .replace("&quot;", '"')
        .replace("&#39;", "'")
    )


def fetch_news_rss(query: str, limit: int = 10) -> list[dict]:
    """구글 뉴스 RSS 검색 (money_agent/stock_agents와 동일 방식, API 키 불필요)."""
    url = f"https://news.google.com/rss/search?q={quote(query)}&hl=ko&gl=KR&ceid=KR:ko"
    resp = requests.get(url, headers=HEADERS, timeout=15)
    resp.raise_for_status()
    xml = resp.text

    items = re.findall(r"<item>([\s\S]*?)</item>", xml)
    results = []
    for item in items[:limit]:
        title_m = re.search(r"<title>([\s\S]*?)</title>", item)
        link_m = re.search(r"<link>([\s\S]*?)</link>", item)
        pubdate_m = re.search(r"<pubDate>([\s\S]*?)</pubDate>", item)
        if not title_m or not link_m:
            continue
        title = re.sub(r"^<!\[CDATA\[|\]\]>$", "", title_m.group(1))
        title = decode_entities(title).strip()
        results.append(
            {
                "title": title,
                "link": link_m.group(1).strip(),
                "pubDate": pubdate_m.group(1).strip() if pubdate_m else "",
            }
        )
    return results


def collect_candidates() -> list[dict]:
    seen_titles = set()
    candidates = []
    for q in QUERIES:
        try:
            for item in fetch_news_rss(q):
                if item["title"] in seen_titles:
                    continue
                seen_titles.add(item["title"])
                candidates.append(item)
        except Exception as e:
            print(f"[warn] news search failed for '{q}': {e}", flush=True)
    return candidates


def call_llm(prompt: str) -> str:
    errors = []
    for model in FREE_MODELS:
        try:
            resp = requests.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={"model": model, "messages": [{"role": "user", "content": prompt}]},
                timeout=30,
            )
            data = resp.json()
            if not resp.ok or data.get("error"):
                raise RuntimeError(data.get("error", {}).get("message", f"HTTP {resp.status_code}"))
            text = data["choices"][0]["message"]["content"].strip()
            if text:
                return text
            raise RuntimeError("빈 응답")
        except Exception as e:
            errors.append(f"{model}: {e}")
            continue
    raise RuntimeError("모든 무료 모델 실패: " + " / ".join(errors))


def main():
    candidates = collect_candidates()

    if not candidates:
        send_telegram("🎤 [한로로 일정 알리미]\n오늘은 관련 뉴스를 찾지 못했습니다.")
        return

    listing = "\n".join(f"- {c['title']} ({c['link']})" for c in candidates[:20])

    prompt = f"""아래는 아티스트 "한로로" 관련 최근 뉴스 검색 결과 제목과 링크다.

{listing}

이 정보만 근거로, 확대해석하거나 추측하지 말고 아래 형식으로 정리해라:
1. 확정되었거나 예정된 콘서트/페스티벌 참여 일정이 있으면 날짜·장소를 정리. 없으면 "새로운 일정 없음"이라고 명시.
2. 해당 일정의 티켓 예매 링크가 뉴스에 나와 있으면 그 링크를 포함. 예매가 아직 시작 안 됐다면 예매 오픈 예정일을 명시. 둘 다 확인 안 되면 "예매 정보 확인 안 됨"이라고 명시.
3. 뉴스 제목들이 전부 무관한 내용(공연과 상관없는 기사 등)이면 "관련 소식 없음"이라고만 답해라.
4. 존댓말로, 텔레그램 메시지에 어울리게 불릿 기호 없이 줄바꿈으로 간결하게 작성해라. 300자 이내로."""

    try:
        summary = call_llm(prompt)
    except Exception as e:
        summary = f"(자동 요약 실패: {e})\n\n원본 뉴스 제목:\n{listing}"

    message = f"🎤 [한로로 일정 알리미]\n{summary}"
    send_telegram(message)


if __name__ == "__main__":
    main()
