import datetime
import json
import os
import time

import requests

# 최유리 콘서트 2026 : 머무름 — [서울] 장충체육관, 2026.10.03(토) 18:00 회차만 감시.
GOODS_CODE = "26012515"
PLACE_CODE = "26001048"
PLAY_SEQ = "001"          # 10/3(토) 회차. 10/4은 감시 대상 아님.
BIZ_CODE = "WEBBR"
SEAT_STATUS_URL = "https://tickets.interpark.com/onestop/api/seatStatus"
# 예매 진입(로그인·대기열)은 알림 받은 사람이 직접 하는 상품 상세 페이지.
BOOKING_URL = "https://tickets.interpark.com/goods/26012515"

TELEGRAM_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
TELEGRAM_CHAT_ID = os.environ["CHOIYURI_CHAT_ID"]   # 알림 받을 사람이 들어와 있는 텔레그램 그룹 chat_id
GH_TOKEN = os.environ.get("GITHUB_TOKEN")
GH_REPOSITORY = os.environ.get("GITHUB_REPOSITORY")
WORKFLOW_FILE = "check-choiyuri-seats.yml"

STATE_FILE = "choiyuri_state.json"
# 빈자리가 없을 때 "감시 중" 알림은 하루 1번, 이 시각(KST)대에만 보낸다.
NO_SEAT_NOTIFY_HOUR = 17
KST = datetime.timezone(datetime.timedelta(hours=9))

# 인터파크 예매 마감(10.03 공연 전일 17:00) 이후로는 온라인 예매가 불가하므로 자동 종료한다.
CUTOFF = datetime.datetime(2026, 10, 2, 17, 0, tzinfo=KST)

# blockKey -> 구역명. 좌석 배치도 좌표로 확정한 매핑 (2026-09-02 조사).
# 1층 플로어 가~차 10개 구역만 감시 대상 (B1/A1/P1/O1, 2층은 제외).
SECTION_BY_BLOCK = {
    "001:101": "가", "001:102": "나", "001:103": "다", "001:104": "라", "001:105": "마",
    "001:106": "바", "001:107": "사", "001:108": "아", "001:109": "자", "001:110": "차",
}
BLOCK_KEYS = list(SECTION_BY_BLOCK)
SECTION_ORDER = "가나다라마바사아자차"
# 1순위 구역 — 빈자리 발생 시 별도 강조.
PRIORITY_1 = {"나", "라", "사", "자"}
# seatStatus API는 호출당 blockKeys 2개까지만 허용한다.
CHUNK_SIZE = 2

# 인터파크 API 일시 오류(502/타임아웃 등) 관대 처리.
FETCH_RETRIES = 3                 # run 안에서 재시도 횟수
FETCH_RETRY_BACKOFF = 0.5        # 재시도 간격(초) × 시도 횟수
FAIL_ALERT_AFTER = 5             # 연속 실패가 이 횟수 이상일 때만 ⚠️ 알림
FAIL_ALERT_COOLDOWN = datetime.timedelta(hours=2)  # ⚠️ 알림 재발송 최소 간격


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
    default = {"last_no_seat_notify_date": None, "consecutive_failures": 0, "last_fail_alert": None}
    if not os.path.exists(STATE_FILE):
        return default
    with open(STATE_FILE, "r", encoding="utf-8") as f:
        return {**default, **json.load(f)}


def save_state(state: dict) -> None:
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def count_available(seat_str: str) -> int:
    """seatStatus 문자열은 좌석 1개당 글자 1개. '0'이 아니면 예매 가능한 빈자리."""
    return sum(1 for ch in seat_str if ch != "0")


def _get_seat_status(params) -> list:
    """seatStatus GET 1건. 네트워크/HTTP/JSON 오류는 몇 차례 재시도한다."""
    last_err = None
    for attempt in range(1, FETCH_RETRIES + 1):
        try:
            resp = requests.get(
                SEAT_STATUS_URL, params=params, timeout=15,
                headers={"User-Agent": "Mozilla/5.0"},
            )
            resp.raise_for_status()
            return resp.json()["data"]
        except Exception as e:  # 502/타임아웃/JSON 파싱 등 모두 재시도 대상
            last_err = e
            if attempt < FETCH_RETRIES:
                time.sleep(FETCH_RETRY_BACKOFF * attempt)
    raise last_err


def fetch_section_availability() -> dict:
    """{구역명: 빈자리수}. blockKeys를 2개씩 끊어 seatStatus를 호출한다."""
    result = {}
    for i in range(0, len(BLOCK_KEYS), CHUNK_SIZE):
        chunk = BLOCK_KEYS[i:i + CHUNK_SIZE]
        params = [
            ("goodsCode", GOODS_CODE),
            ("placeCode", PLACE_CODE),
            ("playSeq", PLAY_SEQ),
            ("bizCode", BIZ_CODE),
        ]
        params += [("blockKeys", bk) for bk in chunk]
        seat_strings = _get_seat_status(params)
        for bk, seat_str in zip(chunk, seat_strings):
            result[SECTION_BY_BLOCK[bk]] = count_available(seat_str)
        time.sleep(0.3)
    return result


def _sort_key(section: str):
    return (0 if section in PRIORITY_1 else 1, SECTION_ORDER.index(section))


def build_seat_message(avail: dict, now_str: str) -> str:
    open_sections = {s: c for s, c in avail.items() if c > 0}
    has_priority = any(s in PRIORITY_1 for s in open_sections)
    header = "🌟🚨 1순위(나·라·사·자) 빈자리!! 🚨🌟" if has_priority else "🚨 빈자리 발생!"
    lines = [f"{s}석 {open_sections[s]}자리" for s in sorted(open_sections, key=_sort_key)]
    return (
        f"{header} [최유리 콘서트 10/3 좌석확인]\n"
        + "\n".join(lines)
        + f"\n👉 예매(로그인·대기열은 직접): {BOOKING_URL}"
        + f"\n확인시각: {now_str}"
    )


def handle_fetch_failure(state: dict, err: Exception, now_dt: datetime.datetime) -> None:
    """일시적 실패는 조용히 삼키고, 연속으로 오래 실패할 때만 ⚠️ 알림(2시간 쿨다운)."""
    fails = min(state.get("consecutive_failures", 0) + 1, FAIL_ALERT_AFTER)
    state["consecutive_failures"] = fails
    print(f"fetch 실패 ({fails}회 연속): {err}", flush=True)
    if fails < FAIL_ALERT_AFTER:
        return
    last_alert = state.get("last_fail_alert")
    if last_alert is not None and (
        now_dt - datetime.datetime.fromisoformat(last_alert) < FAIL_ALERT_COOLDOWN
    ):
        return
    send_telegram(
        f"⚠️ 최유리 좌석확인이 {FAIL_ALERT_AFTER}회 이상 연속 실패 중입니다.\n"
        f"인터파크 API 오류: {err}\n"
        "일시적이면 자동 복구되며, 복구되면 이 알림은 멈춥니다."
    )
    state["last_fail_alert"] = now_dt.isoformat()


def main():
    now_dt = datetime.datetime.now(KST)

    if now_dt >= CUTOFF:
        print("past cutoff, disabling workflow and sending final notice", flush=True)
        send_telegram(
            "🛑 최유리 콘서트 10/3 온라인 예매가 마감되어 좌석확인 자동화를 종료합니다. "
            "(GitHub Actions 워크플로우 자동 비활성화)"
        )
        disable_workflow()
        return

    state = load_state()

    try:
        avail = fetch_section_availability()
    except Exception as e:
        handle_fetch_failure(state, e, now_dt)
        save_state(state)
        return

    # 조회 성공 → 실패 카운터 리셋
    if state.get("consecutive_failures") or state.get("last_fail_alert"):
        state["consecutive_failures"] = 0
        state["last_fail_alert"] = None

    now_str = now_dt.strftime("%m/%d %H:%M")

    if any(c > 0 for c in avail.values()):
        send_telegram(build_seat_message(avail, now_str))
    else:
        # 빈자리 없음 알림은 하루 1번(NO_SEAT_NOTIFY_HOUR 시각대)만. 첫 실행 때는 한 번 보내 가동을 확인시킨다.
        today_str = now_dt.strftime("%Y-%m-%d")
        last_date = state.get("last_no_seat_notify_date")
        should_notify = last_date is None or (
            now_dt.hour == NO_SEAT_NOTIFY_HOUR and last_date != today_str
        )
        if should_notify:
            send_telegram(
                "[최유리 콘서트 10/3 좌석확인]\n"
                "감시 중 · 현재 빈자리 없음 (가~차 전 구역)\n"
                f"확인시각: {now_str}"
            )
            state["last_no_seat_notify_date"] = today_str

    save_state(state)


if __name__ == "__main__":
    main()
