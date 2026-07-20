import datetime
import os
import re
from email.utils import parsedate_to_datetime
from urllib.parse import quote

import requests

HEADERS = {"User-Agent": "Mozilla/5.0"}
KST = datetime.timezone(datetime.timedelta(hours=9))

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

# 이미 확정된 공연은 뉴스 검색 결과에 의존하지 않고 직접 명시한다 (검색으로는 예매
# 링크를 못 찾는 경우가 잦아서). hanroro-seat-checker의 check_seats.py와 같은 공연.
# last_date가 지나면 자동으로 목록에서 빠진다 — 수동으로 지울 필요 없음.
KNOWN_SHOWS = [
    {
        "label": "8월 6일·7일 '시리즈L : 한로로' (롯데콘서트홀)",
        "last_date": datetime.date(2026, 8, 7),
        "booking_link": (
            "https://www.lotteconcerthall.com/product/ko/performance/261129"
            "?q=YTcyY2ZkNDVlMDFlNGNjN2EwOTg2YzBhYzRkMzM0MmY%3d"
        ),
        "note": "예매 이미 오픈됨. 실시간 취소표는 별도 좌석알리미 봇이 2분 간격으로 감시 중.",
    },
]

QUERIES = [
    "한로로 콘서트",
    "한로로 페스티벌",
    "한로로 공연",
    "한로로 내한",
    "한로로 티켓 예매",
    "한로로 예매 오픈",
    "한로로 단독 콘서트",
]
# 기사 본문 스니펫을 가져올 후보 수 (많을수록 정확하지만 실행시간/요청수 증가)
SNIPPET_FETCH_LIMIT = 15


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


def strip_html(html: str) -> str:
    text = re.sub(r"<script[\s\S]*?</script>", " ", html)
    text = re.sub(r"<style[\s\S]*?</style>", " ", text)
    text = re.sub(r"<[^>]+>", " ", text)
    text = decode_entities(text)
    return re.sub(r"\s+", " ", text).strip()


def fetch_snippet(url: str, max_chars: int = 500) -> str:
    """예매 링크/예매일/예매처처럼 제목엔 안 나오고 본문에만 있는 정보를 잡기 위해
    기사 페이지를 받아 텍스트 일부를 넘긴다. 구글 뉴스 RSS 링크는 JS 리다이렉트인
    경우가 있어 실패할 수 있는데, 그 경우 조용히 빈 문자열을 반환한다(파이프라인 안 막음)."""
    try:
        resp = requests.get(url, headers=HEADERS, timeout=8)
        if not resp.ok:
            return ""
        return strip_html(resp.text)[:max_chars]
    except Exception:
        return ""


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

    def sort_key(item):
        try:
            return parsedate_to_datetime(item["pubDate"])
        except Exception:
            return datetime.datetime.min.replace(tzinfo=datetime.timezone.utc)

    candidates.sort(key=sort_key, reverse=True)
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
    today = datetime.datetime.now(KST).date()
    active_known_shows = [s for s in KNOWN_SHOWS if s["last_date"] >= today]
    known_block = "\n\n".join(
        f"✅ {s['label']}\n👉 {s['booking_link']}\n({s['note']})" for s in active_known_shows
    )
    known_labels = ", ".join(s["label"] for s in active_known_shows) or "없음"

    candidates = collect_candidates()

    if not candidates:
        if known_block:
            send_telegram(f"🎤 [한로로 일정 알리미]\n{known_block}")
        else:
            send_telegram("🎤 [한로로 일정 알리미]\n오늘은 관련 뉴스를 찾지 못했습니다.")
        return

    blocks = []
    for c in candidates[:30]:
        snippet = fetch_snippet(c["link"]) if len(blocks) < SNIPPET_FETCH_LIMIT else ""
        block = f"- 제목: {c['title']}\n  뉴스 발행일: {c['pubDate'] or '알수없음'}\n  링크: {c['link']}"
        if snippet:
            block += f"\n  본문 일부: {snippet}"
        blocks.append(block)
    listing = "\n".join(blocks)

    today_str = datetime.datetime.now(KST).strftime("%Y-%m-%d")

    prompt = f"""아래는 아티스트 "한로로" 관련 최근 뉴스 검색 결과다 (제목, 뉴스 발행일, 링크, 본문 일부).
오늘 날짜는 {today_str}이다.

**중요**: "뉴스 발행일"은 그 기사가 인터넷에 올라온 날짜일 뿐이고, 기사가 다루는 실제 공연/행사 날짜와는 다르다.
예를 들어 6월에 올라온 기사가 "8월 공연 예정"을 다룰 수 있다 — 이런 경우 뉴스 발행일이 아니라 기사 속에서
언급된 공연 날짜(8월)를 기준으로 판단해야 하며, 절대 지난 일정으로 착각해서 빼면 안 된다.
반대로 뉴스 발행일이 최근이어도 기사 내용 자체가 이미 끝난 과거 행사를 회고하는 기사라면 제외해라.

다음 공연들은 이미 확정되어 별도로 안내되므로 절대 다시 언급하지 마라: {known_labels}

{listing}

이 정보만 근거로, 확대해석하거나 추측하지 말고 아래 형식으로 정리해라:
1. 위에서 이미 안내된 공연을 제외하고, 기사 내용에서 언급된 공연/행사 날짜가 오늘({today_str}) 이후인 것만 골라라. 정확한 일자가 없고 "8월"처럼 월만 나와 있어도, 그 달이 아직 지나지 않았다면 포함하고 아는 만큼("8월 중")이라도 적어라. 실제 행사 날짜 기준으로 이미 지난 것만 제외해라. 앞으로의 새 일정이 하나도 없을 때만 "새로운 일정 없음"이라고 써라.
2. 위에서 고른 각 일정마다, 본문 일부에서 예매 링크·예매처(인터파크/멜론티켓/예스24 등)·예매 시작일 중 언급된 게 있으면 최대한 찾아서 포함해라. 링크가 없어도 예매일이나 예매처만 나와 있으면 그것도 반드시 적어라. 정말 아무 단서도 없을 때만 "예매 정보 확인 안 됨"이라고 써라.
3. 뉴스가 전부 무관한 내용(공연과 상관없는 기사 등)이거나 전부 지난 일정이면 "새로운 일정 없음"이라고만 답해라.
4. 존댓말로, 텔레그램 메시지에 어울리게 불릿 기호 없이 줄바꿈으로 간결하게 작성해라. 400자 이내로."""

    try:
        summary = call_llm(prompt)
    except Exception as e:
        summary = f"(자동 요약 실패: {e})\n\n원본 뉴스 제목:\n{listing}"

    parts = [p for p in [known_block, summary] if p]
    message = "🎤 [한로로 일정 알리미]\n" + "\n\n".join(parts)
    send_telegram(message)


if __name__ == "__main__":
    main()
