import Foundation
import SwiftData
import UserNotifications

/// 服薬リマインダーの通知。
///
/// iOS は予約できる通知が 64 件までなので、繰り返し通知ではなく「この先 7 日分」を
/// 日付・タイミングごとにまとめて予約し、記録や設定が変わるたびに作り直す。
/// 既に全部飲んだタイミングの通知は予約しない（飲んだのに通知が来るのを防ぐ）。
@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    static let doseCategory = "DOSE"
    static let takeAction = "TAKE"
    static let snoozeAction = "SNOOZE"
    private static let dosePrefix = "dose-"
    private static let followUpPrefix = "followup-"
    private static let snoozePrefix = "snooze-"
    private static let daysAhead = 7

    private let center = UNUserNotificationCenter.current()

    func configure() {
        center.delegate = self
        let take = UNNotificationAction(identifier: Self.takeAction, title: "服用を完了する", options: [])
        let snooze = UNNotificationAction(identifier: Self.snoozeAction, title: "10分後にもう一度", options: [])
        let category = UNNotificationCategory(identifier: Self.doseCategory, actions: [take, snooze],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - 予約

    func refresh(context: ModelContext) {
        let meds = (try? context.fetch(FetchDescriptor<Medication>(predicate: #Predicate { $0.isActive }))) ?? []
        let calendar = Calendar.japanese
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.date(byAdding: .day, value: Self.daysAhead, to: today)!
        let firstKey = DayKey.string(from: today), lastKey = DayKey.string(from: lastDay)
        let logs = (try? context.fetch(FetchDescriptor<DoseLog>(
            predicate: #Predicate { $0.dayKey >= firstKey && $0.dayKey <= lastKey }))) ?? []
        let logIndex = DoseSchedule.index(logs)

        var requests: [UNNotificationRequest] = []
        // まだ飲んでいない薬が残っている「日付-タイミング」
        var pendingKeys = Set<String>()
        if SlotSettings.remindersEnabled {
            let now = Date()
            for offset in 0...Self.daysAhead {
                let day = calendar.date(byAdding: .day, value: offset, to: today)!
                let doses = DoseSchedule.doses(on: day, medications: meds)
                for slot in DoseSlot.allCases where SlotSettings.isEnabled(slot) {
                    let pending = doses.filter { $0.slot == slot && logIndex[$0.id] == nil }
                    guard let first = pending.first else { continue }
                    let fireDate = first.scheduledAt
                    let key = "\(first.dayKey)-\(slot.rawValue)"
                    pendingKeys.insert(key)
                    if fireDate > now {
                        requests.append(request(id: Self.dosePrefix + key, doses: pending, slot: slot,
                                                title: "今すぐ服用しましょう", at: fireDate))
                    }
                    let followUp = fireDate.addingTimeInterval(TimeInterval(SlotSettings.followUpMinutes * 60))
                    if SlotSettings.followUpEnabled, followUp > now {
                        requests.append(request(id: Self.followUpPrefix + key, doses: pending, slot: slot,
                                                title: "まだ服用の記録がありません", at: followUp))
                    }
                }
            }
        }

        let center = self.center
        let isOurs: (String) -> Bool = { id in
            [Self.dosePrefix, Self.followUpPrefix, Self.snoozePrefix].contains { id.hasPrefix($0) }
        }
        let isDone: (String) -> Bool = { id in !pendingKeys.contains { id.hasSuffix($0) } }
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { id in
                id.hasPrefix(Self.dosePrefix) || id.hasPrefix(Self.followUpPrefix)
                    || (id.hasPrefix(Self.snoozePrefix) && isDone(id))
            }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for request in requests.prefix(60) { center.add(request) }
        }
        // 飲み終わったタイミングの通知は通知センターからも消す
        center.getDeliveredNotifications { delivered in
            let ids = delivered.map(\.request.identifier).filter { isOurs($0) && isDone($0) }
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    private func request(id: String, doses: [Dose], slot: DoseSlot, title: String, at date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = "\(slot.label)の薬（\(SlotSettings.timeText(for: slot))）"
        content.body = doses.map { "・\($0.medication.name)（\($0.medication.amountText)）" }.joined(separator: "\n")
        content.categoryIdentifier = Self.doseCategory
        content.threadIdentifier = "dose"
        content.interruptionLevel = .timeSensitive
        content.sound = SlotSettings.soundEnabled ? .default : nil
        content.userInfo = ["dayKey": doses[0].dayKey, "slot": slot.rawValue]
        let components = Calendar.japanese.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    func notifyRefill(for med: Medication) {
        let content = UNMutableNotificationContent()
        content.title = "お薬が残り少なくなっています"
        let remaining = (med.remainingCount ?? 0).formattedAmount
        content.body = "\(med.name)の残りが\(remaining)\(med.unit)です。早めに受診・処方の予定を立てましょう。"
        content.sound = SlotSettings.soundEnabled ? .default : nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        center.add(UNNotificationRequest(identifier: "refill-\(med.id.uuidString)", content: content, trigger: trigger))
    }

    // MARK: - 通知のボタン操作

    private func handle(action: String, content: UNNotificationContent) {
        guard let dayKey = content.userInfo["dayKey"] as? String,
              let slot = (content.userInfo["slot"] as? String).flatMap(DoseSlot.init(rawValue:)),
              let day = DayKey.date(from: dayKey) else { return }
        let context = AppContainer.shared.mainContext

        switch action {
        case Self.takeAction:
            let meds = (try? context.fetch(FetchDescriptor<Medication>(predicate: #Predicate { $0.isActive }))) ?? []
            let logs = (try? context.fetch(FetchDescriptor<DoseLog>(predicate: #Predicate { $0.dayKey == dayKey }))) ?? []
            let index = DoseSchedule.index(logs)
            for dose in DoseSchedule.doses(on: day, medications: meds) where dose.slot == slot && index[dose.id] == nil {
                DoseRecorder.record(dose, status: .taken, existing: nil, context: context)
            }
            refresh(context: context)
        case Self.snoozeAction:
            let snoozed = content.mutableCopy() as! UNMutableNotificationContent
            snoozed.title = "そろそろ服用しましょう"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
            center.add(UNNotificationRequest(identifier: Self.snoozePrefix + "\(dayKey)-\(slot.rawValue)",
                                             content: snoozed, trigger: trigger))
        default:
            break
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let content = response.notification.request.content
        await MainActor.run { handle(action: action, content: content) }
    }
}
