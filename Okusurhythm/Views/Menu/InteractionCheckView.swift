import SwiftData
import SwiftUI

/// 飲み合わせチェック：登録中の薬どうし、または気になる薬を今の薬と照らし合わせる
struct InteractionCheckView: View {
    @Query(filter: #Predicate<Medication> { $0.isActive }, sort: \Medication.createdAt) private var medications: [Medication]
    @State private var candidate: Drug?
    @State private var showPicker = false

    private var currentDrugs: [Drug] { medications.compactMap { DrugDatabase.shared.drug(id: $0.drugID) } }
    private var unlinked: [Medication] { medications.filter { DrugDatabase.shared.drug(id: $0.drugID) == nil } }
    private var currentResults: [PairResult] { InteractionChecker.checkAll(currentDrugs) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                candidateSection
                currentSection
                MedicalDisclaimer()
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("飲み合わせチェック")
        .sheet(isPresented: $showPicker) {
            DrugPickerView { candidate = $0 }
        }
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新しく飲む薬を確認").font(.title3.bold())
            Text("市販薬や他の病院で出された薬が、今飲んでいる薬と併用してよいかを調べます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showPicker = true
            } label: {
                Label(candidate.map { "\($0.displayName)（変更）" } ?? "薬を選ぶ", systemImage: "magnifyingglass")
            }
            .buttonStyle(PrimaryButtonStyle())

            if let candidate {
                let results = InteractionChecker.check(candidate: candidate, against: currentDrugs)
                if currentDrugs.isEmpty {
                    resultMessage("成分が登録されている薬がないため、照らし合わせできません。", ok: nil)
                } else if results.isEmpty {
                    resultMessage("今飲んでいる薬（\(currentDrugs.map(\.displayName).joined(separator: "、"))）との併用禁忌・主な併用注意の記載は見つかりませんでした。", ok: true)
                } else {
                    ForEach(results) { PairResultCard(result: $0) }
                }
                NavigationLink {
                    DrugDetailView(drug: candidate)
                } label: {
                    Label("\(candidate.displayName)の詳しい情報", systemImage: "doc.text.magnifyingglass")
                }
            }
        }
    }

    private var currentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今飲んでいる薬どうし").font(.title3.bold())
            ForEach(InteractionChecker.duplicates(medications)) { dup in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        LevelBadge(text: "成分の重複", color: Theme.danger)
                        Text(dup.drug.displayName).font(.headline)
                    }
                    Text("「\(dup.names.joined(separator: "」「"))」は同じ成分です。別々の病院・薬局で同じ薬が出ている可能性があります。飲みすぎにならないよう、医師・薬剤師に確認してください。")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            if currentDrugs.count < 2 {
                resultMessage("成分を登録した薬が2つ以上あると、組み合わせを確認できます。", ok: nil)
            } else if currentResults.isEmpty {
                resultMessage("登録中の薬どうしで、併用禁忌・主な併用注意の記載は見つかりませんでした。", ok: true)
            } else {
                ForEach(currentResults) { PairResultCard(result: $0) }
            }
            if !unlinked.isEmpty {
                resultMessage("成分が未登録のため確認できない薬：\(unlinked.map(\.name).joined(separator: "、"))。お薬の編集画面で成分を選ぶか、薬剤師に確認してください。", ok: false)
            }
        }
    }

    private func resultMessage(_ text: String, ok: Bool?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ok == true ? "checkmark.seal.fill" : ok == false ? "questionmark.circle.fill" : "info.circle.fill")
                .foregroundStyle(ok == true ? Theme.success : ok == false ? Theme.warning : Theme.primary)
            Text(text).font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// 飲食物の注意：登録中の薬それぞれについて、添付文書にある飲食物
struct FoodWarningsView: View {
    @Query(filter: #Predicate<Medication> { $0.isActive }, sort: \Medication.createdAt) private var medications: [Medication]

    private var drugs: [Drug] {
        var seen = Set<String>()
        return medications.compactMap { DrugDatabase.shared.drug(id: $0.drugID) }.filter { seen.insert($0.id).inserted }
    }

    /// 飲食物ごとにまとめる（例：グレープフルーツ → アムロジピン、シンバスタチン）
    private var byItem: [(label: String, symbol: String, level: FoodWarning.Level, entries: [(Drug, FoodWarning)])] {
        var groups: [String: [(Drug, FoodWarning)]] = [:]
        for drug in drugs {
            for food in drug.foods { groups[food.item == "other" ? food.itemLabel : food.item, default: []].append((drug, food)) }
        }
        return groups.values.map { entries in
            let level: FoodWarning.Level = entries.contains { $0.1.level == .avoid } ? .avoid : .caution
            return (entries[0].1.itemLabel, entries[0].1.symbol, level, entries)
        }
        .sorted { ($0.level == .avoid ? 0 : 1, $0.label) < ($1.level == .avoid ? 0 : 1, $1.label) }
    }

    var body: some View {
        List {
            if drugs.isEmpty {
                Text("成分を登録した薬がありません。お薬の編集画面で成分を選ぶと、注意する飲食物が表示されます。")
                    .foregroundStyle(.secondary)
            } else if byItem.isEmpty {
                Label("登録中の薬の添付文書には、飲食物についての記載はありません。", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.success)
            }
            ForEach(byItem, id: \.label) { group in
                Section {
                    ForEach(group.entries, id: \.0.id) { drug, food in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(drug.displayName).font(.subheadline.bold())
                            Text(food.effect).font(.subheadline)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: group.symbol)
                        Text(group.label)
                        LevelBadge(text: group.level.label, color: group.level.color)
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                }
            }
            Section { MedicalDisclaimer() }
        }
        .themedList()
        .navigationTitle("一緒にとってはいけない飲食物")
        .navigationBarTitleDisplayMode(.inline)
    }
}
