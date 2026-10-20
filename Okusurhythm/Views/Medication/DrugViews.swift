import SwiftUI

/// 収録している薬から成分を選ぶ
struct DrugPickerView: View {
    let onPick: (Drug) -> Void
    /// 見つからないとき「この名前のまま登録する」を出す（お薬の登録画面から開いたときだけ）
    var onUseName: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Drug] { DrugDatabase.shared.search(query) }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            List {
                if let onUseName, !trimmedQuery.isEmpty, results.isEmpty {
                    Section {
                        Button {
                            onUseName(trimmedQuery)
                            dismiss()
                        } label: {
                            Label("「\(trimmedQuery)」の名前のまま登録する", systemImage: "square.and.pencil")
                                .font(.body.bold())
                        }
                    } header: {
                        Text("収録している成分に見つかりませんでした")
                    } footer: {
                        Text("通知・服薬記録・残薬管理は、どのお薬でも使えます。飲み合わせのチェックは行われないので、薬剤師に確認してください。")
                    }
                }
                ForEach(results) { drug in
                    Button {
                        onPick(drug)
                        dismiss()
                    } label: {
                        DrugRow(drug: drug)
                    }
                    .buttonStyle(.plain)
                }
                Section {
                    Text("見つからない薬も、名前だけで登録できます（飲み合わせのチェックは行われません）。収録外の薬の飲み合わせは薬剤師に確認してください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "一般名・商品名で検索")
            .themedList()
            .navigationTitle("成分を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}

struct DrugRow: View {
    let drug: Drug

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(drug.displayName).font(.body.bold())
            Text(drug.brandText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(drug.category).font(.caption2).foregroundStyle(Theme.primary)
        }
        .contentShape(Rectangle())
    }
}

/// 薬の添付文書情報（相互作用・飲食物・出典）
struct DrugDetailView: View {
    let drug: Drug
    @Environment(\.openURL) private var openURL

    private var contraindicated: [Interaction] { drug.interactions.filter { $0.level == .contraindicated } }
    private var caution: [Interaction] { drug.interactions.filter { $0.level == .caution } }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(drug.displayName).font(.title3.bold())
                    Text(drug.genericName).font(.subheadline).foregroundStyle(.secondary)
                    Text("主な商品名：\(drug.brandText)").font(.subheadline)
                    Text(drug.category).font(.caption).foregroundStyle(Theme.primary)
                }
                .padding(.vertical, 4)
            }

            Section {
                if drug.foods.isEmpty {
                    Text("添付文書に飲食物についての記載はありません。").foregroundStyle(.secondary)
                }
                ForEach(drug.foods, id: \.self) { FoodWarningRow(food: $0) }
            } header: {
                Text("一緒にとってはいけない・注意する飲食物")
            }

            interactionSection("併用禁忌（一緒に飲んではいけない薬）", contraindicated,
                               empty: "併用禁忌の記載はありません。")
            interactionSection("併用注意（主なもの）", caution, empty: "主な併用注意の記載はありません。")

            Section("出典") {
                Button {
                    if let url = URL(string: drug.source.url) { openURL(url) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(drug.source.title, systemImage: "doc.text")
                        Text(drug.source.revised).font(.caption).foregroundStyle(.secondary)
                    }
                }
                MedicalDisclaimer()
            }
        }
        .themedList()
        .navigationTitle(drug.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func interactionSection(_ title: String, _ items: [Interaction], empty: String) -> some View {
        Section(title) {
            if items.isEmpty { Text(empty).foregroundStyle(.secondary) }
            ForEach(items, id: \.self) { InteractionRow(interaction: $0) }
        }
    }
}

struct InteractionRow: View {
    let interaction: Interaction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: interaction.level.symbol).foregroundStyle(interaction.level.color)
                Text(interaction.targetLabel).font(.subheadline.bold())
            }
            Text(interaction.effect).font(.subheadline)
            if !interaction.mechanism.isEmpty {
                Text(interaction.mechanism).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct FoodWarningRow: View {
    let food: FoodWarning

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: food.symbol)
                .foregroundStyle(food.level.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(food.itemLabel).font(.subheadline.bold())
                    LevelBadge(text: food.level.label, color: food.level.color)
                }
                Text(food.effect).font(.subheadline)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 2剤の組み合わせ結果カード
struct PairResultCard: View {
    let result: PairResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let level = result.level {
                    LevelBadge(text: level.label, color: level.color)
                }
                Text("\(result.a.displayName) × \(result.b.displayName)").font(.headline)
            }
            ForEach(result.findings) { finding in
                VStack(alignment: .leading, spacing: 4) {
                    Text(finding.interaction.effect).font(.subheadline)
                    Text("\(finding.source.displayName)の添付文書：\(finding.interaction.targetLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !finding.interaction.mechanism.isEmpty {
                        Text(finding.interaction.mechanism).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
