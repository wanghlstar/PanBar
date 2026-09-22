import Foundation

/// 定时显示时钟:在配置的时间窗口内显示行情 ticker,窗口外只显示 app 图标。
///
/// 默认窗口:工作日(周一至周五)09:15-15:15(Asia/Shanghai),
/// 覆盖 A 股集合竞价(9:15)到收盘后一刻(15:15)。
///
/// 窗口语义:start 闭、end 开 —— 09:15 整显示,15:15 整收起。
/// start > end 时视为跨午夜窗口(如 22:00-06:00)。
/// start == end 视为零宽度窗口(始终收起)。
struct DisplayScheduleClock {
    let startMinutes: Int   // 0...1439,距零点的分钟数
    let endMinutes: Int     // 0...1439
    let weekdaysOnly: Bool

    /// 与 A 股一致的时区;PanBar 的主要场景是国内股市。
    static let timeZone: TimeZone = {
        TimeZone(identifier: "Asia/Shanghai") ?? .current
    }()

    init(startMinutes: Int, endMinutes: Int, weekdaysOnly: Bool) {
        self.startMinutes = Self.clampMinutes(startMinutes)
        self.endMinutes = Self.clampMinutes(endMinutes)
        self.weekdaysOnly = weekdaysOnly
    }

    private static func clampMinutes(_ value: Int) -> Int {
        min(1439, max(0, value))
    }

    /// 当前是否处于显示窗口内。
    func isActive(at date: Date = Date()) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.timeZone

        if weekdaysOnly {
            let weekday = cal.dateComponents([.weekday], from: date).weekday ?? 1
            // 1 = 周日,7 = 周六
            if weekday == 1 || weekday == 7 { return false }
        }

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
