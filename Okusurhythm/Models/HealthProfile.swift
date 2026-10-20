import Foundation
import SwiftData

/// アレルギー・副作用歴・持病などの登録項目。
@Model
final class HealthNote {
    var id: UUID = UUID()
    var kindRaw: String = HealthNoteKind.allergy.rawValue
    var title: String = ""
    var detail: String = ""
    var createdAt: Date = Date()

    init(kind: HealthNoteKind, title: String, detail: String = "") {
        self.kindRaw = kind.rawValue
        self.title = title
        self.detail = detail
    }

    var kind: HealthNoteKind { HealthNoteKind(rawValue: kindRaw) ?? .allergy }
}

enum HealthNoteKind: String, CaseIterable, Identifiable {
    case allergy, sideEffect, condition, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .allergy: "アレルギー"
        case .sideEffect: "副作用歴"
        case .condition: "持病・既往歴"
        case .other: "その他"
        }
    }

    var placeholder: String {
        switch self {
        case .allergy: "例：ペニシリン系、卵、そば"
        case .sideEffect: "例：ロキソプロフェンで胃痛"
        case .condition: "例：高血圧、緑内障、喘息"
        case .other: "例：妊娠中、授乳中"
        }
    }

    var symbol: String {
        switch self {
        case .allergy: "allergens"
        case .sideEffect: "exclamationmark.triangle"
        case .condition: "heart.text.square"
        case .other: "note.text"
        }
    }
}
