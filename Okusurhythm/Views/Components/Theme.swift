import SwiftUI

enum Theme {
    static let primary = Color(red: 0.20, green: 0.55, blue: 0.91)
    static let primaryLight = Color(red: 0.88, green: 0.94, blue: 1.0)
    static let background = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let card = Color.white
    static let success = Color(red: 0.18, green: 0.72, blue: 0.42)
    static let warning = Color(red: 0.96, green: 0.60, blue: 0.10)
    static let danger = Color(red: 0.88, green: 0.25, blue: 0.25)
    static let corner: CGFloat = 16
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }

    /// List / Form を参考デザインの淡い青の背景にする
    func themedList() -> some View {
        scrollContentBackground(.hidden).background(Theme.background)
    }
}

/// 朝・昼・夜のアイコン
struct SlotIcon: View {
    let slot: DoseSlot
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: slot.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(slot.tint)
            .frame(width: size, height: size)
            .background(slot.tint.opacity(0.15), in: Circle())
    }
}

/// 押しやすい大きな青いボタン
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.primary.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

struct LevelBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

extension Interaction.Level {
    var color: Color { self == .contraindicated ? Theme.danger : Theme.warning }
    var symbol: String { self == .contraindicated ? "xmark.octagon.fill" : "exclamationmark.triangle.fill" }
}

extension FoodWarning.Level {
    var color: Color { self == .avoid ? Theme.danger : Theme.warning }
}

/// 医療情報の注意書き（各画面の下に出す）
struct MedicalDisclaimer: View {
    var body: some View {
        Label {
            Text("この情報は医療用医薬品の添付文書（PMDA）をもとにした参考情報です。自己判断で服薬を中止・変更せず、必ず医師・薬剤師に相談してください。")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

/// 写真がない薬のプレースホルダー
struct MedicationThumbnail: View {
    let data: Data?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "pills.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.primaryLight)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }
}

extension Date {
    /// 10月18日(土)
    var japaneseDayText: String {
        formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month().day().weekday(.abbreviated))
            .replacingOccurrences(of: " ", with: "")
    }
}
