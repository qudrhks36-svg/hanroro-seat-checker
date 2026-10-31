import { describe, expect, it } from "vitest";
import { errorMessage, formatDate, formatDays, formatRange, previewDays } from "./lib";

describe("previewDays", () => {
  it("연차는 주말을 뺀다 (월~일 = 5일)", () => {
    expect(previewDays("annual", "2026-11-02", "2026-11-08")).toBe(5);
  });
  it("종료일이 비어 있으면 하루", () => {
    expect(previewDays("annual", "2026-11-02", "")).toBe(1);
  });
  it("종료일이 시작일보다 빠르면 0", () => {
    expect(previewDays("annual", "2026-11-05", "2026-11-02")).toBe(0);
  });
  it("반차는 0.5, 주말이면 0", () => {
    expect(previewDays("half_am", "2026-11-02", "")).toBe(0.5);
    expect(previewDays("half_pm", "2026-11-07", "")).toBe(0);
  });
  it("날짜가 없으면 0", () => {
    expect(previewDays("annual", "", "")).toBe(0);
  });
});

describe("format", () => {
  it("요일을 붙인다", () => {
    expect(formatDate("2026-11-02")).toBe("11/2(월)");
  });
  it("범위", () => {
    expect(formatRange({ start_date: "2026-11-02", end_date: "2026-11-02" })).toBe("11/2(월)");
    expect(formatRange({ start_date: "2026-11-02", end_date: "2026-11-04" })).toBe("11/2(월) ~ 11/4(수)");
  });
  it("일수", () => {
    expect(formatDays(3)).toBe("3");
    expect(formatDays(0.5)).toBe("0.5");
    expect(formatDays(11.5)).toBe("11.5");
  });
});

describe("errorMessage", () => {
  it("서버 코드를 한글로", () => {
    expect(errorMessage({ message: "insufficient_balance" })).toBe("남은 연차가 부족해요.");
  });
  it("모르는 에러는 그대로 보여준다", () => {
    expect(errorMessage(new Error("boom"))).toContain("boom");
  });
});
