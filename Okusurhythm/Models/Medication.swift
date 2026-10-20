import Foundation
import SwiftData

/// 利用者が登録した処方薬。
@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    /// 同梱データベース（drugs.json）の薬 ID。照合できたときだけ入る。
    var drugID: String?
    /// 1回に飲む量（0.5錠刻み）
    var amountPerDose: Double = 1
    var unit: String = "錠"
    /// 飲むタイミング（DoseSlot.rawValue の配列）
    var slotRawValues: [String] = [DoseSlot.morning.rawValue]
    var frequencyRaw: String = Frequency.daily.rawValue
    /// 「◯日ごと」のときの間隔
    var intervalDays: Int = 2
    /// 「曜日指定」のときの曜日（Calendar の weekday: 1=日曜〜7=土曜）
    var weekdays: [Int] = []
    var startDate: Date = Date()
    /// 飲み始める日の最初のタイミング（例：昼から飲み始める）。その日はこれより前の分を予定に入れない
    var startSlotRaw: String = DoseSlot.morning.rawValue
    /// 最終服用日（処方日数、または残りの数から計算）。nil なら期限なし
    var endDate: Date?
    /// 最終服用日の最後のタイミング。nil なら処方日数のルール（startsMidDay）で決める
    var endSlotRaw: String?
    /// 残りの数を飲み切るまで続ける（記録のたびに endDate / endSlotRaw を計算し直す）
    var untilRunsOut: Bool = false
    var memo: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    /// 残りの数。nil なら残数管理をしない
    var remainingCount: Double?
    /// 残りがこの数以下になったら補充を知らせる
    var refillThreshold: Double = 7
    /// 補充の通知を一度出したら、残数が閾値を上回るまで再通知しない
    var refillNotified: Bool = false
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(name: String) {
        self.name = name
    }

    var slots: [DoseSlot] {
        get { slotRawValues.compactMap(DoseSlot.init(rawValue:)).sorted() }
        set { slotRawValues = newValue.sorted().map(\.rawValue) }
    }

    var startSlot: DoseSlot {
        get { DoseSlot(rawValue: startSlotRaw) ?? .morning }
        set { startSlotRaw = newValue.rawValue }
    }

    /// 途中のタイミングから飲み始めるか（例：1日3回を昼から）
    var startsMidDay: Bool { slots.first.map { startSlot > $0 } ?? false }

    /// その日に飲むタイミング。
    /// 飲み始める日は startSlot 以降だけ。途中から始めて処方日数があるときは、
    /// 最終日は startSlot より前だけ（14日分を昼から飲むと、15日目の朝で終わる）
    func slots(on day: Date, calendar: Calendar = .japanese) -> [DoseSlot] {
        var result = baseSlots(on: day, calendar: calendar)
        guard !result.isEmpty, let endDate, calendar.isDate(day, inSameDayAs: endDate) else {
            return isScheduled(on: day, calendar: calendar) ? result : []
        }
        if let endSlot = endSlotRaw.flatMap(DoseSlot.init(rawValue:)) {
            result = result.filter { $0 <= endSlot }
        } else if startsMidDay {
            result = result.filter { $0 < startSlot }
        }
        return result
    }

    /// 終わりの日を考えないときの、その日に飲むタイミング（飲み始める日は startSlot 以降）
    func baseSlots(on day: Date, calendar: Calendar = .japanese) -> [DoseSlot] {
        guard isScheduled(on: day, ignoringEnd: true, calendar: calendar) else { return [] }
        if calendar.isDate(day, inSameDayAs: startDate) {
            return slots.filter { $0 >= startSlot }
        }
        return slots
    }

    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    /// 「1日2回 1錠」のような表示
    var dosageSummary: String {
        let perDay = slots.count
        let prefix: String
        switch frequency {
        case .daily: prefix = "1日\(perDay)回"
        case .everyNDays: prefix = "\(intervalDays)日ごと 1日\(perDay)回"
        case .weekdays:
            let names = weekdays.sorted().map { Calendar.japanese.shortWeekdaySymbols[$0 - 1] }.joined()
            prefix = "\(names.isEmpty ? "曜日未設定" : names) 1日\(perDay)回"
        }
        return "\(prefix) \(amountText)"
    }

    var amountText: String { "\(amountPerDose.formattedAmount)\(unit)" }

    /// その日に飲む予定があるか
    func isScheduled(on day: Date, ignoringEnd: Bool = false, calendar: Calendar = .japanese) -> Bool {
        guard isActive else { return false }
        let target = calendar.startOfDay(for: day)
        let start = calendar.startOfDay(for: startDate)
        if target < start { return false }
        if !ignoringEnd, let endDate, target > calendar.startOfDay(for: endDate) { return false }
        switch frequency {
        case .daily:
            return true
        case .everyNDays:
            let days = calendar.dateComponents([.day], from: start, to: target).day ?? 0
            return days % max(intervalDays, 1) == 0
        case .weekdays:
            return weekdays.contains(calendar.component(.weekday, from: target))
        }
    }

    var needsRefill: Bool {
        guard let remainingCount else { return false }
        return remainingCount <= refillThreshold
    }
}

enum Frequency: String, CaseIterable, Identifiable {
    case daily, everyNDays, weekdays
    var id: String { rawValue }
    var label: String {
        switch self {
        case .daily: "毎日"
        case .everyNDays: "◯日ごと"
        case .weekdays: "曜日を指定"
        }
    }
}

extension Double {
    /// 1.0 → "1"、0.5 → "0.5"
    var formattedAmount: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
    }
}

extension Calendar {
    static var japanese: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = .current
        return calendar
    }
}
