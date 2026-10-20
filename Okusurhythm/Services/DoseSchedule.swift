import Foundation
import SwiftData

/// ある日のある薬の1回分。
struct Dose: Identifiable {
    let medication: Medication
    let day: Date
    let slot: DoseSlot

    var id: String { "\(medication.id.uuidString)-\(dayKey)-\(slot.rawValue)" }
    var dayKey: String { DayKey.string(from: day) }
    var scheduledAt: Date { SlotSettings.date(for: slot, on: day) }
}

/// 予定と記録を突き合わせた状態。
enum DoseState {
    case taken, skipped, pending, missed

    init(log: DoseLog?, scheduledAt: Date, now: Date = Date()) {
        switch log?.status {
        case .taken: self = .taken
        case .skipped: self = .skipped
        case nil: self = scheduledAt < now.addingTimeInterval(-3 * 3600) ? .missed : .pending
        }
    }
}

enum DoseSchedule {
    static func doses(on day: Date, medications: [Medication]) -> [Dose] {
        medications
            .filter { $0.isScheduled(on: day) }
            .flatMap { med in med.slots.map { Dose(medication: med, day: day, slot: $0) } }
            .sorted { ($0.slot, $0.medication.name) < ($1.slot, $1.medication.name) }
    }

    /// dayKey + 薬 ID + タイミングで記録を引けるようにする
    static func index(_ logs: [DoseLog]) -> [String: DoseLog] {
        Dictionary(logs.map { ("\($0.medicationID.uuidString)-\($0.dayKey)-\($0.slotRaw)", $0) },
                   uniquingKeysWith: { a, b in a.recordedAt > b.recordedAt ? a : b })
    }

    /// 期間内の服薬率。まだ時刻が来ていない予定は数えない。
    static func adherence(from start: Date, to end: Date, medications: [Medication], logs: [String: DoseLog],
                          now: Date = Date(), calendar: Calendar = .japanese) -> (taken: Int, total: Int) {
        var taken = 0, total = 0
        var day = calendar.startOfDay(for: start)
        while day <= end {
            for dose in doses(on: day, medications: medications) where dose.scheduledAt <= now {
                total += 1
                if logs[dose.id]?.status == .taken { taken += 1 }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return (taken, total)
    }
}

/// 服用の記録と取り消し。残薬数の増減と補充通知もここで行う。
@MainActor
enum DoseRecorder {
    static func record(_ dose: Dose, status: DoseStatus, existing: DoseLog?, context: ModelContext) {
        let med = dose.medication
        if let existing {
            if existing.status == .taken, status != .taken { adjustRemaining(med, by: existing.amount) }
            if existing.status != .taken, status == .taken { adjustRemaining(med, by: -med.amountPerDose) }
            existing.status = status
            existing.amount = med.amountPerDose
            existing.recordedAt = Date()
        } else {
            context.insert(DoseLog(medication: med, dayKey: dose.dayKey, slot: dose.slot, status: status))
            if status == .taken { adjustRemaining(med, by: -med.amountPerDose) }
        }
        try? context.save()
        NotificationManager.shared.refresh(context: context)
    }

    static func undo(_ log: DoseLog, medication: Medication?, context: ModelContext) {
        if log.status == .taken, let medication { adjustRemaining(medication, by: log.amount) }
        context.delete(log)
        try? context.save()
        NotificationManager.shared.refresh(context: context)
    }

    private static func adjustRemaining(_ med: Medication, by delta: Double) {
        guard let remaining = med.remainingCount else { return }
        med.remainingCount = max(remaining + delta, 0)
        if med.needsRefill {
            if !med.refillNotified {
                med.refillNotified = true
                NotificationManager.shared.notifyRefill(for: med)
            }
        } else {
            med.refillNotified = false
        }
    }
}
