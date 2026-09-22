#!/usr/bin/env python3
"""重新生成 PanBar/Resources/TradingDays.json(交易所交易日历)。

用法:
    pip3 install exchange_calendars
    python3 scripts/generate_trading_calendar.py

数据来源:exchange_calendars 的 XSHG(上交所)A 股日历,
每年随 pip 包更新;建议每年年初跑一次刷新新年份数据。
"""
import json
import os

import exchange_calendars as xcals

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "PanBar", "Resources", "TradingDays.json")


def main() -> None:
    cal = xcals.get_calendar("XSHG")
    days = [d.strftime("%Y-%m-%d") for d in cal.sessions if d >= "2026-01-01"]
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(days, f, ensure_ascii=False)
    print(f"written {len(days)} trading days ({days[0]} .. {days[-1]}) to {OUT}")


if __name__ == "__main__":
    main()
