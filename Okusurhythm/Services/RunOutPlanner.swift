import Foundation
import SwiftData

/// 「残りの数を飲み切るまで」の最終服用日を計算する。
///
/// 今日以降の予定を順にたどり、まだ記録していない分に残りを割り当てていく。
/// 飲み忘れて残りが減らなければ、そのぶん終わりが先に延びる。
enum RunOutPlanner {
    struct End: Equatable {
        let day: Date
        let slot: DoseSlot
    }

    /// 残りで飲める最後の1回。1回分もなければ nil
    static func lastDose(of med: Medication, remaining: Double, from now: Date = Date(),
                         logged: Set<String> = [], calendar: Calendar = .japanese) -> End? {
        let amount = max(med.amountPerDose, 0.5)
        var left = remaining
        var last: End?
        var day = max(calendar.startOfDay(for: now), calendar.startOfDay(for: med.startDate))
        for _ in 0..<3650 where left + 1e-9 >= amount {
            for slot in med.baseSlots(on: day, calendar: calendar)
            where !logged.contains("\(DayKey.string(from: day))-\(slot.rawValue)") && left + 1e-9 >= amount {
                left -= amount
                last = End(day: day, slot: slot)
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return last
    }

    /// 記録や設定が変わったときに、最終服用日を計算し直して保存する
    @MainActor
    static func update(_ med: Medication, context: ModelContext, now: Date = Date()) {
        guard med.untilRunsOut, let remaining = med.remainingCount else { return }
        let calendar = Calendar.japanese
        let todayKey = DayKey.string(from: now)
        let medID = med.id
        let logs = (try? context.fetch(FetchDescriptor<DoseLog>(
            predicate: #Predicate { $0.medicationID == medID && $0.dayKey >= todayKey }))) ?? []
        let logged = Set(logs.map { "\($0.dayKey)-\($0.slotRaw)" })

        if let end = lastDose(of: med, remaining: remaining, from: now, logged: logged, calendar: calendar) {
            med.endDate = end.day
            med.endSlotRaw = end.slot.rawValue
        } else if let lastToday = logs.filter({ $0.dayKey == todayKey }).map(\.slot).max() {
            // もう飲む分は残っていない。今日すでに記録した分までは表示に残す
            med.endDate = calendar.startOfDay(for: now)
            med.endSlotRaw = lastToday.rawValue
        } else {
            med.endDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
            med.endSlotRaw = nil
        }
    }

    @MainActor
    static func updateAll(context: ModelContext) {
        let meds = (try? context.fetch(FetchDescriptor<Medication>(predicate: #Predicate { $0.untilRunsOut }))) ?? []
        meds.forEach { update($0, context: context) }
        try? context.save()
    }
}
