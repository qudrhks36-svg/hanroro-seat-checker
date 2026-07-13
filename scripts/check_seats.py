import datetime
import os
import sys

import requests
from playwright.sync_api import sync_playwright

URL = "https://www.lotteconcerthall.com/product/ko/performance/261129?q=YTcyY2ZkNDVlMDFlNGNjN2EwOTg2YzBhYzRkMzM0MmY%3d"

TELEGRAM_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
TELEGRAM_CHAT_ID = os.environ["TELEGRAM_CHAT_ID"]


def send_telegram(message: str) -> None:
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    resp = requests.post(url, data={"chat_id": TELEGRAM_CHAT_ID, "text": message}, timeout=15)
    resp.raise_for_status()


def check_seats():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.goto(URL, wait_until="networkidle", timeout=30000)
        page.wait_for_selector("#booking .episode_select ul li", timeout=15000)

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


def main():
    try:
        results = check_seats()
    except Exception as e:
        send_telegram(f"⚠️ 한로로 좌석확인 실패: {e}")
        sys.exit(1)

    if not results:
        send_telegram("⚠️ 한로로 좌석확인: 회차 정보를 찾지 못했습니다. 페이지 구조가 변경됐을 수 있습니다.")
        return

    any_available = any(available for _, available, _ in results)
    now = datetime.datetime.now().strftime("%m/%d %H:%M")

    lines = [f"{label}: {'있음' if available else '없음'}" for label, available, _ in results]
    prefix = "🚨 좌석 발생! " if any_available else ""
    message = f"{prefix}[한로로 콘서트 좌석확인]\n" + "\n".join(lines) + f"\n확인시각: {now}"

    send_telegram(message)


if __name__ == "__main__":
    main()
