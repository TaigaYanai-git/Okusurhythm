import Foundation
import SwiftUI

/// 服用タイミング。時刻は通知設定（SlotSettings）で変えられる。
enum DoseSlot: String, CaseIterable, Identifiable, Comparable, Codable {
    case morning, noon, evening, bedtime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: "朝"
        case .noon: "昼"
        case .evening: "夜"
        case .bedtime: "寝る前"
        }
    }

    var symbol: String {
        switch self {
        case .morning: "sun.horizon.fill"
        case .noon: "sun.max.fill"
        case .evening: "moon.fill"
        case .bedtime: "bed.double.fill"
        }
    }

    var tint: Color {
        switch self {
        case .morning: Color(red: 0.98, green: 0.66, blue: 0.18)
        case .noon: Color(red: 0.25, green: 0.60, blue: 0.95)
        case .evening: Color(red: 0.32, green: 0.42, blue: 0.85)
        case .bedtime: Color(red: 0.50, green: 0.40, blue: 0.80)
        }
    }

    var defaultMinutes: Int {
        switch self {
        case .morning: 8 * 60
        case .noon: 12 * 60
        case .evening: 20 * 60
        case .bedtime: 22 * 60
        }
    }

    private var order: Int { DoseSlot.allCases.firstIndex(of: self)! }

    static func < (lhs: DoseSlot, rhs: DoseSlot) -> Bool { lhs.order < rhs.order }
}
