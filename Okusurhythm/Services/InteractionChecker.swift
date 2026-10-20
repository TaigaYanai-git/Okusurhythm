import Foundation

/// 2つの薬の組み合わせについて、添付文書に書かれている注意。
struct InteractionFinding: Identifiable, Hashable {
    /// 添付文書にこの記載がある薬
    let source: Drug
    /// 相手の薬
    let other: Drug
    let interaction: Interaction

    var id: String { "\(source.id)>\(other.id)>\(interaction.targetLabel)" }
    var level: Interaction.Level { interaction.level }
}

/// 薬の組み合わせの結果。どちらの添付文書の記載でも拾う。
struct PairResult: Identifiable {
    let a: Drug
    let b: Drug
    let findings: [InteractionFinding]

    var id: String { "\(a.id)+\(b.id)" }
    /// 最も重い区分。nil なら添付文書上の記載なし
    var level: Interaction.Level? { findings.map(\.level).min() }
}

enum InteractionChecker {
    /// source の添付文書に、other との相互作用が書かれているか
    static func findings(in source: Drug, against other: Drug) -> [InteractionFinding] {
        let keys = Set([other.id] + other.classes.map { "class:\($0)" })
        return source.interactions
            .filter { !keys.isDisjoint(with: $0.targets) }
            .map { InteractionFinding(source: source, other: other, interaction: $0) }
    }

    static func check(_ a: Drug, _ b: Drug) -> PairResult {
        let found = findings(in: a, against: b) + findings(in: b, against: a)
        return PairResult(a: a, b: b, findings: found.sorted { $0.level < $1.level })
    }

    /// 登録中の薬の全組み合わせのうち、注意のあるもの
    static func checkAll(_ drugs: [Drug]) -> [PairResult] {
        let unique = Array(Set(drugs)).sorted { $0.displayName < $1.displayName }
        var results: [PairResult] = []
        for i in unique.indices {
            for j in unique.indices where j > i {
                let result = check(unique[i], unique[j])
                if result.level != nil { results.append(result) }
            }
        }
        return results.sorted { ($0.level ?? .caution) < ($1.level ?? .caution) }
    }

    /// 新しい薬を、今飲んでいる薬と照らし合わせる
    static func check(candidate: Drug, against current: [Drug]) -> [PairResult] {
        current.filter { $0.id != candidate.id }
            .map { check(candidate, $0) }
            .filter { $0.level != nil }
            .sorted { ($0.level ?? .caution) < ($1.level ?? .caution) }
    }
}

/// 同じ成分の薬が2つ以上登録されている（別の病院で同じ薬が出た、など）
struct DuplicateIngredient: Identifiable {
    let drug: Drug
    let names: [String]
    var id: String { drug.id }
}

extension InteractionChecker {
    static func duplicates(_ medications: [Medication]) -> [DuplicateIngredient] {
        Dictionary(grouping: medications.filter { $0.drugID != nil }, by: { $0.drugID! })
            .compactMap { id, meds in
                guard meds.count > 1, let drug = DrugDatabase.shared.drug(id: id) else { return nil }
                return DuplicateIngredient(drug: drug, names: meds.map(\.name))
            }
            .sorted { $0.drug.displayName < $1.drug.displayName }
    }
}
