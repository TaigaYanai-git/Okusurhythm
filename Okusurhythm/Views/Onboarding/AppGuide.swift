import Combine
import SwiftData
import SwiftUI

// MARK: - 使い方ガイド
// はじめての人に、お薬の登録・飲んだときのチェック・カレンダー・飲み合わせの確認を、
// 画面の場所を照らしながら順に見せる。メニューの「使い方を見る」からもう一度見られる。

/// ガイドで照らす場所。各画面に `.guideTarget(_:)` で印を付ける
enum GuideTarget: Hashable {
    case addEmpty, addToolbar, todayDoses, calendarGrid, interactionRow
}

@MainActor
final class AppGuide: ObservableObject {
    static let shared = AppGuide()
    static let seenKey = "guide.seen.v1"

    @Published private(set) var isActive = false
    @Published var stepIndex = 0
    /// ガイドが見せたいタブ（RootView がこれに合わせて切り替える）
    @Published var tab: AppTab?
    @Published private(set) var frames: [GuideTarget: CGRect] = [:]

    func setFrame(_ rect: CGRect?, for target: GuideTarget) {
        if frames[target] != rect { frames[target] = rect }
    }

    /// まだ見ていない、お薬も登録していない人にだけ出す（前から使っている人には出さない）
    func startIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.seenKey) else { return }
        let count = (try? AppContainer.shared.mainContext.fetchCount(FetchDescriptor<Medication>())) ?? 0
        guard count == 0 else { defaults.set(true, forKey: Self.seenKey); return }
        start()
    }

    func start() {
        stepIndex = 0
        withAnimation(.easeOut(duration: 0.35)) { isActive = true }
    }

    func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        tab = .home
        withAnimation(.easeIn(duration: 0.25)) { isActive = false }
    }
}

private struct GuideTargetModifier: ViewModifier {
    let target: GuideTarget
    @State private var lastFrame: CGRect?
    func body(content: Content) -> some View {
        // ナビゲーションバーの項目は、タブを切り替えた直後に動きながら出てくるので、位置が変わるたびに測り直す。
        // 別のタブから戻ったときは位置が変わらず知らせが来ないので、覚えておいた位置を入れ直す
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
                lastFrame = rect
                AppGuide.shared.setFrame(rect, for: target)
            }
            .onAppear { if let lastFrame { AppGuide.shared.setFrame(lastFrame, for: target) } }
            .onDisappear { AppGuide.shared.setFrame(nil, for: target) }
    }
}

extension View {
    /// 使い方ガイドで照らす場所として印を付ける
    func guideTarget(_ target: GuideTarget) -> some View { modifier(GuideTargetModifier(target: target)) }
}

// MARK: - 手順

private struct GuideStep {
    let tab: AppTab
    /// 照らす場所の候補。前から順に、画面にあるものを使う
    let targets: [GuideTarget]
    let icon: String
    let tint: Color
    let label: String
    let title: String
    let message: String
    var isWelcome = false

    static let all: [GuideStep] = [
        GuideStep(tab: .home, targets: [], icon: "pills.fill", tint: Theme.primary, label: "",
                  title: "おくすリズムの使い方",
                  message: "覚えることは3つだけです。\n画面に沿ってご案内します。",
                  isWelcome: true),
        GuideStep(tab: .home, targets: [.addEmpty, .addToolbar], icon: "plus", tint: Theme.primary, label: "その1",
                  title: "お薬を登録する",
                  message: "処方されたお薬の名前と、飲む時間（朝・昼・夜など）を登録します。左上の「＋」からも登録できます。"),
        GuideStep(tab: .home, targets: [.todayDoses], icon: "checkmark", tint: Theme.success, label: "その2",
                  title: "飲んだらチェック",
                  message: "時間になると通知でお知らせします。お薬を飲んだら ✓ をタップして記録しましょう。通知からも記録できます。"),
        GuideStep(tab: .calendar, targets: [.calendarGrid], icon: "calendar", tint: Theme.primary, label: "その3",
                  title: "カレンダーでふりかえる",
                  message: "飲めた日・飲み忘れた日が、色でひと目で分かります。日付をタップすると、その日の記録が見られます。"),
        GuideStep(tab: .menu, targets: [.interactionRow], icon: "exclamationmark.shield.fill", tint: Theme.warning, label: "ほかにも",
                  title: "飲み合わせも確認できます",
                  message: "メニューから、登録したお薬どうしや飲食物との注意を確認できます。添付文書にもとづく参考情報です。"),
        GuideStep(tab: .home, targets: [.addEmpty, .addToolbar], icon: "pills.fill", tint: Theme.primary, label: "",
                  title: "さっそく登録してみましょう",
                  message: "まずは毎日飲んでいるお薬を1つ登録してみましょう。"),
    ]
}

// MARK: - 表示

/// 画面全体の上に重ねる。照らす場所以外を落ち着いた紺色で暗くし、青い枠・指・白いカードを出す
struct AppGuideOverlay: View {
    @ObservedObject private var guide = AppGuide.shared

    var body: some View {
        if guide.isActive {
            content.transition(.opacity)
        }
    }

    private var content: some View {
        let steps = GuideStep.all
        let index = min(guide.stepIndex, steps.count - 1)
        let step = steps[index]
        return GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let spot = spotlight(for: step, origin: origin)
            ZStack(alignment: .topLeading) {
                GuideCutout(rect: spot ?? CGRect(x: geo.size.width / 2, y: geo.size.height / 2, width: 0, height: 0),
                            cornerRadius: radius(spot))
                    .fill(Color(red: 0.05, green: 0.14, blue: 0.27).opacity(0.62), style: FillStyle(eoFill: true))
                    .contentShape(Rectangle())
                    .onTapGesture {}

                if let spot {
                    GuideRing(rect: spot, cornerRadius: radius(spot))
                    GuidePointer(target: spot)
                }

                card(step: step, index: index, count: steps.count, isLast: index == steps.count - 1)
                    .frame(width: min(geo.size.width - 32, 440))
                    .position(x: geo.size.width / 2, y: cardY(spot: spot, size: geo.size))
                    .id(index)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity))
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: spot)
        }
        .ignoresSafeArea()
        .onAppear { guide.tab = steps[index].tab }
        .onChange(of: guide.stepIndex) { _, i in
            if steps.indices.contains(i) { guide.tab = steps[i].tab }
        }
    }

    private func spotlight(for step: GuideStep, origin: CGPoint) -> CGRect? {
        guard let rect = step.targets.lazy.compactMap({ guide.frames[$0] }).first(where: { $0.width > 0 && $0.height > 0 })
        else { return nil }
        return rect.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -8, dy: -8)
    }

    private func radius(_ rect: CGRect?) -> CGFloat {
        guard let rect else { return 0 }
        return min(Theme.corner + 4, min(rect.width, rect.height) / 2)
    }

    private func cardY(spot: CGRect?, size: CGSize) -> CGFloat {
        guard let spot else { return size.height * 0.5 }
        let h: CGFloat = 270
        let below = size.height - spot.maxY - 100
        let above = spot.minY - 70
        if below >= h { return spot.maxY + 36 + h / 2 }
        if above >= h { return spot.minY - 30 - h / 2 }
        return size.height - 110 - h / 2
    }

    // MARK: カード

    private func card(step: GuideStep, index: Int, count: Int, isLast: Bool) -> some View {
        VStack(alignment: step.isWelcome ? .center : .leading, spacing: 14) {
            if step.isWelcome {
                // はじめの画面と同じ、青いグラデーションの薬のアイコン
                Image(systemName: step.icon)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(LinearGradient(colors: [Theme.primary.opacity(0.75), Theme.primary],
                                               startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.top, 4)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: step.icon)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(step.tint)
                        .frame(width: 44, height: 44)
                        .background(step.tint.opacity(0.15), in: Circle())
                    if !step.label.isEmpty {
                        Text(step.label)
                            .font(.subheadline.bold())
                            .foregroundStyle(step.tint)
                    }
                    Spacer()
                }
            }

            VStack(alignment: step.isWelcome ? .center : .leading, spacing: 8) {
                Text(step.title)
                    .font(.title3.bold())
                    .foregroundStyle(Color.primary)
                Text(step.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(step.isWelcome ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: step.isWelcome ? .center : .leading)

            HStack(spacing: 14) {
                PillProgress(index: index, count: count)
                Spacer()
                if !isLast {
                    Button("スキップ") { guide.finish() }
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                Button {
                    if isLast { guide.finish() } else { guide.stepIndex = index + 1 }
                } label: {
                    Text(isLast ? "はじめる" : index == 0 ? "見てみる" : "次へ")
                        .font(.headline)
                        .fixedSize()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .background(Theme.primary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
    }
}

// MARK: - 部品

private struct GuideCutout: Shape {
    var rect: CGRect
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>> {
        get { AnimatablePair(AnimatablePair(rect.origin.x, rect.origin.y),
                             AnimatablePair(AnimatablePair(rect.width, rect.height), cornerRadius)) }
        set {
            rect = CGRect(x: newValue.first.first, y: newValue.first.second,
                          width: newValue.second.first.first, height: newValue.second.first.second)
            cornerRadius = newValue.second.second
        }
    }

    func path(in bounds: CGRect) -> Path {
        var path = Path(bounds.insetBy(dx: -200, dy: -200))
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: .continuous)
        return path
    }
}

/// 照らす場所を囲む青い枠（ゆっくり脈打つ）
private struct GuideRing: View {
    let rect: CGRect
    let cornerRadius: CGFloat
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius + 6, style: .continuous)
                .stroke(Theme.primary, lineWidth: 2)
                .frame(width: rect.width + 12, height: rect.height + 12)
                .scaleEffect(pulse ? 1.05 : 1)
                .opacity(pulse ? 0 : 0.8)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: rect.width, height: rect.height)
                .shadow(color: Theme.primary.opacity(0.9), radius: 8)
        }
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

/// 照らす場所をトントンと指す指
private struct GuidePointer: View {
    let target: CGRect
    @State private var tapping = false

    var body: some View {
        let tip = CGPoint(x: target.midX + min(target.width * 0.18, 30), y: target.midY + min(target.height * 0.18, 16))
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 2)
                .frame(width: 34, height: 34)
                .scaleEffect(tapping ? 1.5 : 0.4)
                .opacity(tapping ? 0 : 0.9)
                .position(tip)
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white)
                .shadow(color: Theme.primary.opacity(0.9), radius: 6)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                .position(x: tip.x + 18, y: tip.y + 21)
                .offset(x: tapping ? 0 : 6, y: tapping ? 0 : 8)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { tapping = true }
        }
    }
}

/// どこまで進んだかを、カプセル錠の列で見せる（進んだ分は青と白の錠剤になる）
private struct PillProgress: View {
    let index: Int
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                pill(done: i <= index, current: i == index)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(index + 1) / \(count)")
    }

    private func pill(done: Bool, current: Bool) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(done ? Theme.primary : Color(.systemGray5))
            Rectangle().fill(done ? Color.white : Color(.systemGray5))
        }
        .frame(width: current ? 20 : 13, height: current ? 9 : 7)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(done ? Theme.primary : Color(.systemGray4), lineWidth: 1))
        .rotationEffect(.degrees(current ? -25 : 0))
    }
}
