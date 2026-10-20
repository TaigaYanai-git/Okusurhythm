import SwiftUI

/// データの出典とご利用上の注意
struct AboutView: View {
    private let db = DrugDatabase.shared

    var body: some View {
        List {
            Section("ご利用上の注意") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("おくすリズムは、処方されたお薬の飲み忘れを防ぐための記録・通知アプリです。診断・治療を行うものではありません。")
                    Text("飲み合わせや飲食物の情報は、医療用医薬品の添付文書の記載から主なものを抜き出した参考情報です。すべての組み合わせを網羅しているわけではなく、「記載なし」でも安全とは限りません。")
                    Text("お薬の量や飲み方の変更・中止は、必ず医師・薬剤師に相談してください。体調に異変を感じたら、すぐに医療機関を受診してください。")
                }
                .font(.subheadline)
                .padding(.vertical, 4)
            }
            Section {
                Link(destination: URL(string: "https://www.pmda.go.jp/PmdaSearch/iyakuSearch/")!) {
                    Label("PMDA 医療用医薬品 情報検索", systemImage: "safari")
                }
                Text("データ版：\(db.version)（\(db.drugs.count)成分）").font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("データの出典")
            } footer: {
                Text("独立行政法人 医薬品医療機器総合機構（PMDA）が公開している医療用医薬品の添付文書をもとに作成しています。最新の情報は PMDA のサイトでご確認ください。")
            }
            Section("成分ごとの出典") {
                ForEach(db.drugs) { drug in
                    if let url = URL(string: drug.source.url) {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(drug.source.title).font(.subheadline)
                                Text(drug.source.revised).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Section("プライバシー") {
                Text("登録したお薬・記録・健康情報は、すべてこのiPhoneの中だけに保存されます。外部のサーバーに送信することはありません。")
                    .font(.subheadline)
            }
            if let url = Bundle.main.urlSetting("REPO_URL") {
                Section {
                    Link("ソースコード（GitHub）", destination: url)
                    Text("バージョン \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("このアプリについて")
        .navigationBarTitleDisplayMode(.inline)
    }
}
