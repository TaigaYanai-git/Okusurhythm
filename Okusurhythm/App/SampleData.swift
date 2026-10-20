import Foundation
import SwiftData

/// スクリーンショット撮影用のサンプル（起動引数 -uiPreview のときだけ、メモリ上のDBに入れる）
@MainActor
enum SampleData {
    static func insert(into context: ModelContext) {
        UserDefaults.standard.set(true, forKey: SlotSettings.onboardedKey)
        let calendar = Calendar.japanese
        let start = calendar.date(byAdding: .day, value: -40, to: Date())!

        let amlodipine = Medication(name: "高血圧の薬（ノルバスク）")
        amlodipine.drugID = "amlodipine"
        amlodipine.slots = [.morning]
        amlodipine.startDate = start
        amlodipine.remainingCount = 24
        amlodipine.memo = "朝食後に服用"

        let magnesium = Medication(name: "マグミット錠330mg")
        magnesium.drugID = "magnesium_oxide"
        magnesium.slots = [.morning, .noon, .evening]
        magnesium.startDate = start

        let levofloxacin = Medication(name: "クラビット錠500mg")
        levofloxacin.drugID = "levofloxacin"
        levofloxacin.slots = [.evening]
        levofloxacin.startDate = calendar.date(byAdding: .day, value: -3, to: Date())!
        levofloxacin.endDate = calendar.date(byAdding: .day, value: 3, to: Date())
        levofloxacin.remainingCount = 3
        levofloxacin.refillThreshold = 3

        let sleep = Medication(name: "睡眠サポート薬（ロゼレム）")
        sleep.drugID = "ramelteon"
        sleep.slots = [.bedtime]
        sleep.startDate = start

        let meds = [amlodipine, magnesium, levofloxacin, sleep]
        meds.forEach(context.insert)

        // 過去の記録（ところどころ飲み忘れ）
        for offset in 1...35 {
            let day = calendar.date(byAdding: .day, value: -offset, to: Date())!
            for dose in DoseSchedule.doses(on: day, medications: meds) where (offset * 7 + dose.slot.rawValue.count) % 9 != 0 {
                context.insert(DoseLog(medication: dose.medication, dayKey: dose.dayKey, slot: dose.slot, status: .taken))
            }
        }
        // 今日は朝の分だけ飲んだ
        for dose in DoseSchedule.doses(on: Date(), medications: meds) where dose.slot == .morning {
            context.insert(DoseLog(medication: dose.medication, dayKey: dose.dayKey, slot: dose.slot, status: .taken))
        }

        context.insert(HealthNote(kind: .allergy, title: "ペニシリン系", detail: "20歳ごろ発疹"))
        context.insert(HealthNote(kind: .condition, title: "高血圧"))
        try? context.save()
    }
}
