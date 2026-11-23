import Foundation
import SwiftData

/// 「毎回きちんと飲んだら、お薬がなくなる日」と、その前の病院予約のリマインド。
///
/// なくなる日の 10 日前から、「病院を予約した」か「次は病院に行かなくていい」を押すまで知らせる。
/// 押したときのなくなる日を覚えておき、補充して先に延びたら（新しい処方を入れたら）また知らせる。
enum HospitalVisit {
    /// なくなる日の何日前から知らせるか
    static let leadDays = 10
    /// 押したあと、飲み忘れなどでなくなる日がこの日数まで延びても、同じ処方とみなして知らせない
    static let sameCycleSlackDays = 10
    static let enabledKey = "reminders.hospital"
    /// 通知を出す時刻（分）。病院が開いていて電話しやすい昼に出す
    static let notifyMinutes = 12 * 60

    static var isEnabled: Bool { SlotSettings.defaults.bool(forKey: enabledKey) }

    enum Ack: String {
        case booked, notNeeded
        var label: String {
            switch self {
            case .booked: "病院を予約済み"
            case .notNeeded: "次の受診なし"
            }
        }
    }

    struct RunOut: Identifiable {
        let medication: Medication
        /// 最後の1回を飲む日
        let day: Date
        let slot: DoseSlot?
        var id: UUID { medication.id }

        func daysLeft(from now: Date = Date(), calendar: Calendar = .japanese) -> Int {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: day).day ?? 0
        }

        /// 「12月3日（水）の夜」
        var text: String {
            day.japaneseDayText + (slot.map { "の\($0.label)" } ?? "")
        }
    }

    /// 毎回きちんと飲んだときに、お薬がなくなる日。
    /// 残りの数を管理していればそこから、処方日数を決めていれば最終日。両方あれば早いほう。どちらもなければ nil
    @MainActor
    static func runOut(of med: Medication, context: ModelContext, now: Date = Date()) -> RunOut? {
        guard med.isActive else { return nil }
        let calendar = Calendar.japanese
        var best: (day: Date, slot: DoseSlot?)?
        if let endDate = med.endDate {
            let slot = med.endSlotRaw.flatMap(DoseSlot.init(rawValue:)) ?? med.slots(on: endDate).last
            best = (calendar.startOfDay(for: endDate), slot)
        }
        if !med.untilRunsOut, let remaining = med.remainingCount {
            let todayKey = DayKey.string(from: now)
            let medID = med.id
            let logs = (try? context.fetch(FetchDescriptor<DoseLog>(
                predicate: #Predicate { $0.medicationID == medID && $0.dayKey >= todayKey }))) ?? []
            let logged = Set(logs.map { "\($0.dayKey)-\($0.slotRaw)" })
            let end = RunOutPlanner.lastDose(of: med, remaining: remaining, from: now, logged: logged, calendar: calendar)
            let day = end.map { calendar.startOfDay(for: $0.day) }
                ?? calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
            if best == nil || day < best!.day { best = (day, end?.slot) }
        }
        guard let best else { return nil }
        return RunOut(medication: med, day: best.day, slot: best.slot)
    }

    /// 押したボタンが今の処方に効いているか
    static func ack(for med: Medication, runOut: Date, calendar: Calendar = .japanese) -> Ack? {
        guard let raw = med.visitAckRaw, let ack = Ack(rawValue: raw), let ackDay = med.visitAckRunOut else { return nil }
        let limit = calendar.date(byAdding: .day, value: sameCycleSlackDays, to: ackDay)!
        return runOut <= limit ? ack : nil
    }

    /// 今日から知らせる必要があるお薬（なくなる日の 10 日前〜、ボタン未操作）
    @MainActor
    static func due(medications: [Medication], context: ModelContext, on day: Date = Date()) -> [RunOut] {
        let calendar = Calendar.japanese
        let today = calendar.startOfDay(for: day)
        return medications.compactMap { runOut(of: $0, context: context) }
            .filter { item in
                let start = calendar.date(byAdding: .day, value: -leadDays, to: item.day)!
                return start <= today && ack(for: item.medication, runOut: item.day) == nil
            }
            .sorted { $0.day < $1.day }
    }

    @MainActor
    static func mark(_ ack: Ack, medications: [Medication], context: ModelContext) {
        for med in medications {
            guard let item = runOut(of: med, context: context) else { continue }
            med.visitAckRaw = ack.rawValue
            med.visitAckRunOut = item.day
        }
        try? context.save()
        NotificationManager.shared.removeDeliveredVisitReminders(for: medications.map(\.id))
        NotificationManager.shared.refresh(context: context)
    }

    @MainActor
    static func clear(_ med: Medication, context: ModelContext) {
        med.visitAckRaw = nil
        med.visitAckRunOut = nil
        try? context.save()
        NotificationManager.shared.refresh(context: context)
    }
}
