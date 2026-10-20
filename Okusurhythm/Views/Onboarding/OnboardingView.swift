import SwiftUI

/// 初回起動：アプリの紹介・注意事項への同意・通知の許可
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var agreed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 104, height: 104)
                    .background(LinearGradient(colors: [Theme.primary.opacity(0.75), Theme.primary],
                                               startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .padding(.top, 40)

                VStack(spacing: 8) {
                    Text("おくすリズム").font(.largeTitle.bold())
                    Text("飲み忘れをなくして、\nあなたの健康をサポート")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 18) {
                    feature("bell.fill", "飲み忘れを防ぐリマインダー", "決めた時間に通知。通知から服用を記録できます。")
                    feature("calendar", "服薬記録をかんたん管理", "カレンダーとグラフで続けられているかが分かります。")
                    feature("exclamationmark.shield.fill", "飲み合わせ・飲食物の確認", "添付文書（PMDA）をもとに、注意が必要な組み合わせを表示します。")
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("ご利用の前に").font(.headline)
                    Text("このアプリは診断や治療を行うものではありません。表示する情報は添付文書をもとにした参考情報で、すべての組み合わせを網羅してはいません。お薬の変更・中止は必ず医師・薬剤師に相談してください。")
                        .font(.subheadline)
                    Toggle("内容を確認しました", isOn: $agreed).font(.subheadline.bold())
                }
                .card()
                .padding(.horizontal)

                Button("はじめる") {
                    Task {
                        await NotificationManager.shared.requestAuthorization()
                        onFinish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!agreed)
                .opacity(agreed ? 1 : 0.5)
                .padding(.horizontal)

                Text("毎日の小さな習慣が、大きな健康につながる")
                    .font(.footnote)
                    .foregroundStyle(Theme.primary)
                    .padding(.bottom, 24)
            }
        }
        .background(Theme.background)
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.primary)
                .frame(width: 48, height: 48)
                .background(Theme.primaryLight, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
