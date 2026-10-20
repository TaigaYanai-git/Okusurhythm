import Foundation

/// 同梱の薬データ（PMDA 添付文書から作成した drugs.json）。
struct DrugData: Decodable {
    let version: String
    let drugs: [Drug]
}

struct Drug: Decodable, Identifiable, Hashable {
    let id: String
    let genericName: String
    let displayName: String
    let brandNames: [String]
    let category: String
    let classes: [String]
    let interactions: [Interaction]
    let foods: [FoodWarning]
    let source: Source

    struct Source: Decodable, Hashable {
        let title: String
        let url: String
        let revised: String
    }

    var brandText: String { brandNames.joined(separator: "、") }
}

struct Interaction: Decodable, Hashable {
    let level: Level
    let targets: [String]
    let targetLabel: String
    let effect: String
    let mechanism: String

    enum Level: String, Decodable, Comparable {
        case contraindicated, caution

        var label: String {
            switch self {
            case .contraindicated: "併用禁忌"
            case .caution: "併用注意"
            }
        }

        static func < (lhs: Level, rhs: Level) -> Bool {
            lhs == .contraindicated && rhs == .caution
        }
    }
}

struct FoodWarning: Decodable, Hashable {
    let item: String
    let itemLabel: String
    let level: Level
    let effect: String

    enum Level: String, Decodable {
        case avoid, caution
        var label: String { self == .avoid ? "避ける" : "注意" }
    }

    var symbol: String {
        switch item {
        case "grapefruit": "takeoutbag.and.cup.and.straw"
        case "alcohol": "wineglass"
        case "milk": "drop"
        case "vitamin_k_foods": "leaf"
        case "st_johns_wort": "camera.macro"
        case "caffeine": "cup.and.saucer"
        case "smoking": "smoke"
        case "high_fat_meal": "fork.knife"
        case "iron_calcium_supplements": "pills"
        default: "exclamationmark.circle"
        }
    }
}

final class DrugDatabase {
    static let shared = DrugDatabase()

    let version: String
    let drugs: [Drug]
    private let byID: [String: Drug]

    convenience init(bundle: Bundle = .main) {
        let data = bundle.url(forResource: "drugs", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
        let decoded = data.flatMap { try? JSONDecoder().decode(DrugData.self, from: $0) }
        self.init(data: decoded ?? DrugData(version: "-", drugs: []))
    }

    init(data: DrugData) {
        version = data.version
        drugs = data.drugs.sorted { $0.displayName < $1.displayName }
        byID = Dictionary(data.drugs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func drug(id: String?) -> Drug? { id.flatMap { byID[$0] } }

    /// 一般名・商品名・表示名の部分一致（ひらがな/カタカナ、全角/半角を同一視）
    func search(_ query: String) -> [Drug] {
        let q = Self.normalize(query)
        guard !q.isEmpty else { return drugs }
        return drugs.filter { drug in
            ([drug.displayName, drug.genericName, drug.category] + drug.brandNames)
                .contains { Self.normalize($0).contains(q) }
        }
    }

    /// 入力された薬の名前からデータベースの薬を推定する（商品名の「錠」「mg」などは無視）
    func bestMatch(for name: String) -> Drug? {
        let n = Self.normalize(name)
        guard n.count >= 2 else { return nil }
        return drugs.first { drug in
            ([drug.displayName, drug.genericName] + drug.brandNames).contains { candidate in
                let c = Self.normalize(candidate)
                return n.hasPrefix(c) || (c.count >= 3 && n.contains(c))
            }
        }
    }

    static func normalize(_ text: String) -> String {
        let width = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        let katakana = width.applyingTransform(.hiraganaToKatakana, reverse: false) ?? width
        // 半角カナを全角に戻す
        let full = katakana.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? katakana
        return full.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "　", with: "")
    }
}
