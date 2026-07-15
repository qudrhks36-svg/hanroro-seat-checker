import datetime
import json
import os
import sys

import requests

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
    """(회차 라벨, 예매가능여부, 좌석선택URL) 리스트 반환"""
    resp = requests.get(SCHEDULE_API_URL, timeout=15)
    resp.raise_for_status()
    data = resp.json()

    results = []
    for pt in data["PlayTimes"]:
        label = pt["PlayTime"]
        available = not pt["IsSoldOut"]
        date_only = label[:10]  # "2026-08-06"
        seat_url = SEAT_URL_TEMPLATE.format(date=date_only, time_id=pt["TimeID"])
        results.append((label, available, seat_url))
    return results


def main():
    state = load_state()

    try:
        results = check_seats()
    except Exception as e:
        send_telegram(f"⚠️ 한로로 좌석확인 실패: {e}")
        sys.exit(1)

    if not results:
        send_telegram("⚠️ 한로로 좌석확인: 회차 정보를 찾지 못했습니다. API 응답이 비어있습니다.")
        return

    any_available = any(available for _, available, _ in results)
    now = datetime.datetime.now(KST)
    now_str = now.strftime("%m/%d %H:%M")

    lines = []
    for i, (label, available, seat_url) in enumerate(results, start=1):
        line = f"{i}회차 {label} 공연 {'있음' if available else '없음'}"
        if available:
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
