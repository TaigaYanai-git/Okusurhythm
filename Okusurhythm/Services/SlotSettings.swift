import Foundation

/// 服用時刻と通知方法の設定。UserDefaults に保存し、画面側は @AppStorage で同じキーを読む。
enum SlotSettings {
    static let remindersEnabledKey = "reminders.enabled"
    static let soundEnabledKey = "reminders.sound"
    static let followUpEnabledKey = "reminders.followUp"
    static let followUpMinutesKey = "reminders.followUpMinutes"
    static let onboardedKey = "onboarding.done"

    static func minutesKey(_ slot: DoseSlot) -> String { "slot.\(slot.rawValue).minutes" }
    static func enabledKey(_ slot: DoseSlot) -> String { "slot.\(slot.rawValue).enabled" }

    static var defaults: UserDefaults { .standard }

    static func registerDefaults() {
        var values: [String: Any] = [
            remindersEnabledKey: true,
            soundEnabledKey: true,
            followUpEnabledKey: true,
            followUpMinutesKey: 30,
        ]
        for slot in DoseSlot.allCases {
            values[minutesKey(slot)] = slot.defaultMinutes
            values[enabledKey(slot)] = true
        }
        defaults.register(defaults: values)
    }

    static func minutes(for slot: DoseSlot) -> Int { defaults.integer(forKey: minutesKey(slot)) }
    static func isEnabled(_ slot: DoseSlot) -> Bool { defaults.bool(forKey: enabledKey(slot)) }
    static var remindersEnabled: Bool { defaults.bool(forKey: remindersEnabledKey) }
    static var soundEnabled: Bool { defaults.bool(forKey: soundEnabledKey) }
    static var followUpEnabled: Bool { defaults.bool(forKey: followUpEnabledKey) }
    static var followUpMinutes: Int { max(defaults.integer(forKey: followUpMinutesKey), 5) }

    /// その日のそのタイミングの日時
    static func date(for slot: DoseSlot, on day: Date, calendar: Calendar = .japanese) -> Date {
        let minutes = minutes(for: slot)
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }

    static func timeText(for slot: DoseSlot) -> String { timeText(minutes: minutes(for: slot)) }

    static func timeText(minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}
