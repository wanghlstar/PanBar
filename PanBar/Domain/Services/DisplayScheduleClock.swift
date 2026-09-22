import Foundation

/// 内嵌的交易所交易日历(来源:exchange_calendars 的 XSHG 上交所 A 股日历)。
///
/// 为什么用交易日历而不是「法定节假日表」:
///   交易日历直接给出交易所实际开市的每一天,自动处理好
///   - 法定节假日休市
///   - 周末休市(**含周末调休上班日 —— 交易所不开市**)
///   - 特殊闭市
///   规则与「周一至周五且非法定节假日」完全一致,但无需自己推导。
///
/// 数据更新:每年年初执行一次
///   pip3 install exchange_calendars
///   python3 scripts/generate_trading_calendar.py
struct ChinaTradingCalendar {
    /// app bundle 内嵌的交易日集合("2026-09-22" 格式);nil = 无数据。
    static let bundled: Set<String>? = load(
        from: Bundle.main.url(forResource: "TradingDays", withExtension: "json")
    )

    static func load(from url: URL?) -> Set<String>? {
        guard let url,
              let data = try? Data(contentsOf: url),
              let days = try? JSONDecoder().decode([String].self, from: data),
              !days.isEmpty
        else { return nil }
        return Set(days)
    }

    /// yyyy-MM-dd(Asia/Shanghai)。
    static func key(_ date: Date) -> String {
        let tz = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = tz
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

/// 定时显示时钟:在配置的时间窗口内显示行情 ticker,窗口外只显示 app 图标。
///
/// 默认窗口:交易日(交易所日历内的日期)09:15-15:15(Asia/Shanghai),
/// 覆盖 A 股集合竞价(9:15)到收盘后一刻(15:15)。
///
/// 窗口语义:start 闭、end 开 —— 09:15 整显示,15:15 整收起。
/// start > end 时视为跨午夜窗口(如 22:00-06:00)。
/// start == end 视为零宽度窗口(始终收起)。
struct DisplayScheduleClock {
    let startMinutes: Int   // 0...1439,距零点的分钟数
    let endMinutes: Int     // 0...1439
    let tradingDaysOnly: Bool

    /// 与 A 股一致的时区;PanBar 的主要场景是国内股市。
    static let timeZone: TimeZone = {
        TimeZone(identifier: "Asia/Shanghai") ?? .current
    }()

    init(startMinutes: Int, endMinutes: Int, tradingDaysOnly: Bool) {
        self.startMinutes = Self.clampMinutes(startMinutes)
        self.endMinutes = Self.clampMinutes(endMinutes)
        self.tradingDaysOnly = tradingDaysOnly
    }

    private static func clampMinutes(_ value: Int) -> Int {
        min(1439, max(0, value))
    }

    /// 是否交易日:交易所日历内的日期(周末含调休上班日一律休市)。
    /// 日历数据缺失时(如跨年数据未更新)退回纯「周一至周五」判断。
    func isTradingDay(
        at date: Date = Date(),
        tradingDays: Set<String>? = ChinaTradingCalendar.bundled
    ) -> Bool {
        if let days = tradingDays {
            return days.contains(ChinaTradingCalendar.key(date))
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.timeZone
        let weekday = cal.dateComponents([.weekday], from: date).weekday ?? 1
        // 1 = 周日,7 = 周六
        return weekday != 1 && weekday != 7
    }

    /// 当前是否处于显示窗口内。
    func isActive(
        at date: Date = Date(),
        tradingDays: Set<String>? = ChinaTradingCalendar.bundled
    ) -> Bool {
        if tradingDaysOnly && !isTradingDay(at: date, tradingDays: tradingDays) { return false }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.timeZone
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)

        if startMinutes == endMinutes { return false }
        if startMinutes < endMinutes {
            return minutes >= startMinutes && minutes < endMinutes
        }
        // 跨午夜:22:00-06:00 → 晚于等于 22:00 或 早于 06:00
        return minutes >= startMinutes || minutes < endMinutes
    }

    /// 格式化分钟数为 "HH:mm",供设置面板提示用。
    static func format(minutes: Int) -> String {
        String(format: "%02d:%02d", clampMinutes(minutes) / 60, clampMinutes(minutes) % 60)
    }
}
