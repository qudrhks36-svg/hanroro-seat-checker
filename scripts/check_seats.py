import datetime
import json
import os
import sys

import requests
from playwright.sync_api import sync_playwright

URL = "https://www.lotteconcerthall.com/product/ko/performance/261129?q=YTcyY2ZkNDVlMDFlNGNjN2EwOTg2YzBhYzRkMzM0MmY%3d"

PERFORMANCE_ID = 261129
SCHEDULE_API_URL = f"https://www.lotteconcerthall.com/product/ko/performance/{PERFORMANCE_ID}/schedule"
SEAT_URL_TEMPLATE = (
    "https://www.lotteconcerthall.com/Pages/ko/Perf/Sale/SeatPreviewProcess.aspx"
    f"?spv=1&IdPerf={PERFORMANCE_ID}&SelDate={{date}}&IdTime={{time_id}}"
)

TELEGRAM_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
TELEGRAM_CHAT_ID = os.environ["TELEGRAM_CHAT_ID"]

STATE_FILE = "state.json"
NO_SEAT_NOTIFY_INTERVAL = datetime.timedelta(minutes=30)
KST = datetime.timezone(datetime.timedelta(hours=9))


def send_telegram(message: str) -> None:
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    resp = requests.post(url, data={"chat_id": TELEGRAM_CHAT_ID, "text": message}, timeout=15)
    resp.raise_for_status()


def load_state() -> dict:
    if not os.path.exists(STATE_FILE):
        return {"last_no_seat_notify": None}
    with open(STATE_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def save_state(state: dict) -> None:
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def check_seats():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.goto(URL, wait_until="networkidle", timeout=30000)
        page.wait_for_selector("#booking .episode_select ul li", state="attached", timeout=15000)

        results = []
        for ep in page.query_selector_all("#booking .episode_select ul li"):
            classes = ep.get_attribute("class") or ""
            label_el = ep.query_selector(".btn_episode span")
            status_el = ep.query_selector(".btn_remain span")
            label = label_el.inner_text().strip() if label_el else "알 수 없음"
            status_text = status_el.inner_text().strip() if status_el else ""
            available = "soldOut" not in classes
            results.append((label, available, status_text))

        browser.close()
        return results


def get_seat_urls() -> dict:
    """PlayTime 라벨(예: '2026-08-06 (목) 07:30 PM') -> 좌석선택 화면 URL 매핑.
    실패해도 좌석 발생 알림 자체는 막지 않도록 조용히 빈 dict를 반환한다."""
    try:
        resp = requests.get(SCHEDULE_API_URL, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        mapping = {}
        for pt in data["PlayTimes"]:
            date_only = pt["PlayTime"][:10]  # "2026-08-06"
            mapping[pt["PlayTime"]] = SEAT_URL_TEMPLATE.format(date=date_only, time_id=pt["TimeID"])
        return mapping
    except Exception:
        return {}


def main():
    state = load_state()

    try:
        results = check_seats()
    except Exception as e:
        send_telegram(f"⚠️ 한로로 좌석확인 실패: {e}")
        sys.exit(1)

    if not results:
        send_telegram("⚠️ 한로로 좌석확인: 회차 정보를 찾지 못했습니다. 페이지 구조가 변경됐을 수 있습니다.")
        return

    seat_urls = get_seat_urls()

    any_available = any(available for _, available, _ in results)
    now = datetime.datetime.now(KST)
    now_str = now.strftime("%m/%d %H:%M")

    lines = []
    for i, (label, available, _) in enumerate(results, start=1):
        line = f"{i}회차 {label} 공연 {'있음' if available else '없음'}"
        if available:
            seat_url = seat_urls.get(label)
            if seat_url:
                line += f"\n👉 {seat_url}"
        lines.append(line)

    if any_available:
        message = "🚨 좌석 발생! [한로로 콘서트 좌석확인]\n" + "\n".join(lines) + f"\n확인시각: {now_str}"
        send_telegram(message)
        state["last_no_seat_notify"] = None
    else:
        last_notify = state.get("last_no_seat_notify")
        should_notify = last_notify is None or (
            now - datetime.datetime.fromisoformat(last_notify) >= NO_SEAT_NOTIFY_INTERVAL
        )
        if should_notify:
            message = "[한로로 콘서트 좌석확인]\n" + "\n".join(lines) + f"\n확인시각: {now_str}"
            send_telegram(message)
            state["last_no_seat_notify"] = now.isoformat()

    save_state(state)


if __name__ == "__main__":
    main()
