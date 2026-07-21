import datetime
import json
import os
import sys

import requests

PERFORMANCE_ID = 261129
SCHEDULE_API_URL = f"https://www.lotteconcerthall.com/product/ko/performance/{PERFORMANCE_ID}/schedule"
# 좌석 "미리보기"(SeatPreviewProcess.aspx)는 실제로 클릭이 안 되는 열람 전용 화면이라
# 실제 예매하기 버튼이 이동하는 공연 상세(회차 선택) 페이지로 대신 연결한다.
PERFORMANCE_URL = (
    f"https://www.lotteconcerthall.com/product/ko/performance/{PERFORMANCE_ID}"
    "?q=YTcyY2ZkNDVlMDFlNGNjN2EwOTg2YzBhYzRkMzM0MmY%3d"
)

TELEGRAM_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
TELEGRAM_CHAT_ID = os.environ["TELEGRAM_CHAT_ID"]
GH_TOKEN = os.environ.get("GITHUB_TOKEN")
GH_REPOSITORY = os.environ.get("GITHUB_REPOSITORY")
WORKFLOW_FILE = "check-seats.yml"

STATE_FILE = "state.json"
NO_SEAT_NOTIFY_INTERVAL = datetime.timedelta(minutes=30)
KST = datetime.timezone(datetime.timedelta(hours=9))

# R/S석 취소표를 별도로 강조 알림하기 위한 등급 구분.
# 시야방해R/시야방해S는 제외(할인가·시야 제한석이라 사용자가 원하는 "진짜 R/S"가 아님).
RS_CLASSES = {"R석", "S석"}

# 마지막 공연(2026-08-07) 다음 날 자정 이후로는 확인이 무의미하므로 자동 종료한다.
CUTOFF = datetime.datetime(2026, 8, 8, 0, 0, tzinfo=KST)
# cron-job.org 외부 스케줄이 오작동해도 이 시간대 밖이면 조회/알림을 하지 않는다.
ACTIVE_HOUR_START = 9   # KST 9시부터
ACTIVE_HOUR_END = 18    # KST 18시 전까지

# 공연 날짜. 롯데콘서트홀 정책상 이 날짜들의 자정 직후, 그리고 이 날짜 전 마지막 평일
# 18시 직후에는 9-18시 가드를 예외적으로 풀어서 집중 확인한다 (아래 IN_BURST_WINDOW 참고).
SHOW_DATES = [datetime.date(2026, 8, 6), datetime.date(2026, 8, 7)]
# 무통장입금 미결제 취소표: 공연일 00:00 이후 순차 반영, 보통 00:05~00:10 사이 (버퍼 포함 00:20까지 감시)
RELEASE_BURST_END_MINUTE = 20
# 인터넷 취소 마감(공연일 전 마지막 평일 18시) 직후 반영분 감시 (18:00~18:20)
DEADLINE_BURST_END_MINUTE = 20


def _last_weekday_before(d: datetime.date) -> datetime.date:
    """d 기준 하루 전부터 거슬러 올라가며 토/일을 건너뛴 첫 평일을 반환."""
    prev = d - datetime.timedelta(days=1)
    while prev.weekday() >= 5:  # 5=토, 6=일
        prev -= datetime.timedelta(days=1)
    return prev


def in_burst_window(now_dt: datetime.datetime) -> bool:
    """무통장입금 취소표 반영 시각(공연일 00:00~) / 인터넷 취소 마감 직후(공연일 전
    마지막 평일 18:00~)에는 9-18시 가드와 무관하게 조회를 허용한다."""
    for show_date in SHOW_DATES:
        if now_dt.date() == show_date and now_dt.hour == 0 and now_dt.minute < RELEASE_BURST_END_MINUTE:
            return True
        deadline_day = _last_weekday_before(show_date)
        if now_dt.date() == deadline_day and now_dt.hour == 18 and now_dt.minute < DEADLINE_BURST_END_MINUTE:
            return True
    return False


def send_telegram(message: str) -> None:
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    resp = requests.post(url, data={"chat_id": TELEGRAM_CHAT_ID, "text": message}, timeout=15)
    print(f"[telegram] status={resp.status_code} body={resp.text}")
    resp.raise_for_status()


def disable_workflow() -> None:
    url = f"https://api.github.com/repos/{GH_REPOSITORY}/actions/workflows/{WORKFLOW_FILE}/disable"
    resp = requests.put(
        url,
        headers={
            "Authorization": f"Bearer {GH_TOKEN}",
            "Accept": "application/vnd.github+json",
        },
        timeout=15,
    )
    print(f"disable_workflow: {resp.status_code}", flush=True)


def load_state() -> dict:
    if not os.path.exists(STATE_FILE):
        return {"last_no_seat_notify": None}
    with open(STATE_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def save_state(state: dict) -> None:
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def check_seats():
    """(회차 라벨, 예매가능여부, 공연 상세 URL, {등급명: 잔여석수}) 리스트 반환.
    URL은 회차와 무관하게 동일한 상세 페이지 — 알림 받으면 그 화면에서 직접 회차를 선택해 예매한다.
    등급별 잔여석수(BookableCount)는 같은 스케줄 API 응답의 Seats 배열에 이미 포함되어 있어
    별도 API 호출 없이 R석/S석 취소표만 골라 강조 알림할 수 있다."""
    resp = requests.get(SCHEDULE_API_URL, timeout=15)
    resp.raise_for_status()
    data = resp.json()

    results = []
    for pt in data["PlayTimes"]:
        label = pt["PlayTime"]
        available = not pt["IsSoldOut"]
        seat_counts = {
            seat["ClassName"]: seat["BookableCount"]
            for seat in pt.get("Seats", [])
            if seat["BookableCount"] > 0
        }
        results.append((label, available, PERFORMANCE_URL, seat_counts))
    return results


def main():
    now_dt = datetime.datetime.now(KST)

    if now_dt >= CUTOFF:
        print("past cutoff, disabling workflow and sending final notice", flush=True)
        send_telegram("🛑 한로로 콘서트 공연 일정이 모두 지나서 좌석확인 자동화를 종료합니다. (GitHub Actions 워크플로우 자동 비활성화)")
        disable_workflow()
        return

    if not (ACTIVE_HOUR_START <= now_dt.hour < ACTIVE_HOUR_END) and not in_burst_window(now_dt):
        print(f"outside active window ({ACTIVE_HOUR_START}-{ACTIVE_HOUR_END}h KST) and not in a burst window, skipping run", flush=True)
        return

    state = load_state()

    try:
        results = check_seats()
    except Exception as e:
        send_telegram(f"⚠️ 한로로 좌석확인 실패: {e}")
        sys.exit(1)

    if not results:
        send_telegram("⚠️ 한로로 좌석확인: 회차 정보를 찾지 못했습니다. API 응답이 비어있습니다.")
        return

    any_available = any(available for _, available, _, _ in results)
    rs_available = any(
        seat_counts.get(cls, 0) > 0 for _, _, _, seat_counts in results for cls in RS_CLASSES
    )
    now_str = now_dt.strftime("%m/%d %H:%M")

    lines = []
    for i, (label, available, seat_url, seat_counts) in enumerate(results, start=1):
        line = f"{i}회차 {label} 공연 {'있음' if available else '없음'}"
        if available:
            grade_breakdown = ", ".join(f"{cls} {cnt}석" for cls, cnt in seat_counts.items())
            if grade_breakdown:
                line += f"\n   ({grade_breakdown})"
            line += f"\n👉 회차 선택 후 예매: {seat_url}"
        lines.append(line)

    if any_available:
        header = "🌟🚨 R/S석 취소표 발생!! 🚨🌟" if rs_available else "🚨 좌석 발생!"
        message = f"{header} [한로로 콘서트 좌석확인]\n" + "\n".join(lines) + f"\n확인시각: {now_str}"
        send_telegram(message)
        state["last_no_seat_notify"] = None
    else:
        last_notify = state.get("last_no_seat_notify")
        should_notify = last_notify is None or (
            now_dt - datetime.datetime.fromisoformat(last_notify) >= NO_SEAT_NOTIFY_INTERVAL
        )
        if should_notify:
            message = "[한로로 콘서트 좌석확인]\n" + "\n".join(lines) + f"\n확인시각: {now_str}"
            send_telegram(message)
            state["last_no_seat_notify"] = now_dt.isoformat()

    save_state(state)


if __name__ == "__main__":
    main()
