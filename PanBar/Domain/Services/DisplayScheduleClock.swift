import Foundation

/// 内嵌的法定节假日 / 调休上班日数据(来源:NateScarlet/holiday-cn,
/// 与国务院发布的放假安排一致)。
///
/// 结构:`"2026": { "2026-01-01": true, "2026-02-14": false }`
///   - 只收录**例外日**(全年绝大多数日期不在表内)
///   - `true`  = 放假(周末或工作日放假,休市)
///   - `false` = 调休上班(周末补班,A 股正常交易)
///
/// 数据按年更新:假日安排通常在前一年 11 月由国务院发布,
/// 届时重新拉取 holiday-cn 当年 JSON、按此格式合并进
/// PanBar/Resources/ChinaHolidays.json 即可。
struct ChinaHolidayCalendar {
    /// app bundle 内嵌数据;nil = 无数据(调用方退回纯工作日判断)。
    static let bundled: [String: Bool]? = load(
        from: Bundle.main.url(forResource: "ChinaHolidays", withExtension: "json")
    )

    static func load(from url: URL?) -> [String: Bool]? {
        guard let url,
              let data = try? Data(contentsOf: url),
              let obj = try? JSONDecoder().decode([String: [String: Bool]].self, from: data)
        else { return nil }
        var merged: [String: Bool] = [:]
        for (_, days) in obj {
            for (date, off) in days { merged[date] = off }
        }
        return merged.isEmpty ? nil : merged
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
/// 默认窗口:交易日(周一至周五且非法定节假日,含调休上班的周末)
/// 09:15-15:15(Asia/Shanghai),覆盖 A 股集合竞价(9:15)到收盘后一刻(15:15)。
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

    /// 是否交易日:周一至周五且非法定节假日;调休补班的周末也算交易日。
    /// 节假日数据缺失的年份自动退回纯「周一至周五」判断。
    func isTradingDay(
        at date: Date = Date(),
        holidayMap: [String: Bool]? = ChinaHolidayCalendar.bundled
    ) -> Bool {
        if let off = holidayMap?[ChinaHolidayCalendar.key(date)] {
            // 表内日期:false = 调休上班(交易日),true = 放假(休市)
            return !off
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
        holidayMap: [String: Bool]? = ChinaHolidayCalendar.bundled
    ) -> Bool {
        if tradingDaysOnly && !isTradingDay(at: date, holidayMap: holidayMap) { return false }

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
