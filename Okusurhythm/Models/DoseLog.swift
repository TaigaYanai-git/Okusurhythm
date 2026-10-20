import Foundation
import SwiftData

/// 1回分の服用記録。記録がない予定は「未服用」として扱う。
@Model
final class DoseLog {
    var id: UUID = UUID()
    var medicationID: UUID = UUID()
    /// 薬を削除しても履歴に名前を残すためのコピー
    var medicationName: String = ""
    /// "yyyy-MM-dd"
    var dayKey: String = ""
    var slotRaw: String = DoseSlot.morning.rawValue
    var statusRaw: String = DoseStatus.taken.rawValue
    var amount: Double = 1
    var recordedAt: Date = Date()

    init(medication: Medication, dayKey: String, slot: DoseSlot, status: DoseStatus) {
        self.medicationID = medication.id
        self.medicationName = medication.name
        self.dayKey = dayKey
        self.slotRaw = slot.rawValue
        self.statusRaw = status.rawValue
        self.amount = medication.amountPerDose
    }

    var slot: DoseSlot { DoseSlot(rawValue: slotRaw) ?? .morning }
    var status: DoseStatus {
        get { DoseStatus(rawValue: statusRaw) ?? .taken }
        set { statusRaw = newValue.rawValue }
    }
}

enum DoseStatus: String {
    case taken, skipped
}

enum DayKey {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(from date: Date) -> String { formatter.string(from: date) }
    static func date(from key: String) -> Date? { formatter.date(from: key) }
}
