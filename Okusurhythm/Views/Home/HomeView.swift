import SwiftData
import SwiftUI

struct HomeView: View {
    @Binding var tab: AppTab
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Medication> { $0.isActive }, sort: \Medication.createdAt) private var medications: [Medication]
    @Query private var logs: [DoseLog]
    @State private var editing: MedicationEditTarget?
    @State private var showSettings = false

    private var calendar: Calendar { .japanese }
    private var today: Date { calendar.startOfDay(for: Date()) }
    private var logIndex: [String: DoseLog] { DoseSchedule.index(logs) }
    private var doses: [Dose] { DoseSchedule.doses(on: today, medications: medications) }

    private var interactionAlerts: [PairResult] {
        InteractionChecker.checkAll(medications.compactMap { DrugDatabase.shared.drug(id: $0.drugID) })
    }

    private var duplicates: [DuplicateIngredient] { InteractionChecker.duplicates(medications) }

    private var refillMeds: [Medication] { medications.filter(\.needsRefill) }

    private var visitDue: [HospitalVisit.RunOut] {
        _ = logs.count // 記録が変わったら計算し直す
        return HospitalVisit.due(medications: medications, context: context)
    }

    var body: some View {
        let doses = doses
        let index = logIndex
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if medications.isEmpty {
                        emptyState
                    } else {
                        TodayProgress(doses: doses, index: index)

                        let visits = visitDue
                        ForEach(visits) { HospitalVisitBanner(item: $0) }
                        if !interactionAlerts.isEmpty || !duplicates.isEmpty || !refillMeds.isEmpty { noticeCard }

                        if doses.isEmpty {
                            Text("今日飲む予定のお薬はありません。")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .card()
                        } else {
                            VStack(spacing: 12) {
                                ForEach(DoseSlot.allCases) { slot in
                                    let slotDoses = doses.filter { $0.slot == slot }
                                    if !slotDoses.isEmpty {
                                        SlotDoseCard(slot: slot, doses: slotDoses, index: index)
                                    }
                                }
                            }
                            .guideTarget(.todayDoses)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("今日")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("通知設定", systemImage: "bell") { showSettings = true }
                }
            }
            .sheet(item: $editing) { target in
                MedicationEditView(medication: target.medication)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { NotificationSettingsView() }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "pills.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.primary)
            Text("お薬を登録しましょう").font(.headline)
            Text("処方されたお薬と飲む時間を登録すると、時間になったら通知でお知らせします。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("お薬を登録する") { editing = .new }
                .buttonStyle(PrimaryButtonStyle())
                .guideTarget(.addEmpty)
        }
        .frame(maxWidth: .infinity)
        .card()
        .guideTarget(.todayDoses)
    }

    /// 飲み合わせ・残りが少ないお薬を、1枚のカードにまとめて知らせる
    private var noticeCard: some View {
        VStack(spacing: 0) {
            if !interactionAlerts.isEmpty || !duplicates.isEmpty {
                let worst = interactionAlerts.first?.level ?? .caution
                let items = duplicates.map { "\($0.drug.displayName)が重複" }
                    + interactionAlerts.map { "\($0.a.displayName)×\($0.b.displayName)" }
                NavigationLink { InteractionCheckView() } label: {
                    NoticeRow(symbol: worst.symbol, tint: worst.color,
                              title: worst == .contraindicated ? "一緒に飲めない組み合わせがあります"
                                : interactionAlerts.isEmpty ? "同じ成分のお薬が重複しています" : "飲み合わせに注意が必要です",
                              detail: items.joined(separator: "、"), showsChevron: true)
                }
                .buttonStyle(.plain)
            }
            if (!interactionAlerts.isEmpty || !duplicates.isEmpty) && !refillMeds.isEmpty {
                Divider().padding(.vertical, 10)
            }
            if !refillMeds.isEmpty {
                Button { tab = .medications } label: {
                    NoticeRow(symbol: "shippingbox.fill", tint: Theme.warning, title: "残りが少ないお薬があります",
                              detail: refillMeds.map { "\($0.name) 残り\(($0.remainingCount ?? 0).formattedAmount)\($0.unit)" }
                                  .joined(separator: "、"),
                              showsChevron: true)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }
}

private struct NoticeRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            if showsChevron { Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary) }
        }
        .contentShape(Rectangle())
    }
}

/// 今日の日付と、飲んだ数・次に飲む時間
struct TodayProgress: View {
    let doses: [Dose]
    let index: [String: DoseLog]

    var body: some View {
        let done = doses.filter { index[$0.id] != nil }.count
        let taken = doses.filter { index[$0.id]?.status == .taken }.count
        let rate = doses.isEmpty ? 0 : Double(done) / Double(doses.count)
        let next = doses.first { index[$0.id] == nil }
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Theme.primaryLight, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(rate >= 1 ? Theme.success : Theme.primary, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy, value: rate)
                if rate >= 1 {
                    Image(systemName: "checkmark").font(.title3.bold()).foregroundStyle(Theme.success)
                } else {
                    Text("\(taken)/\(doses.count)").font(.subheadline.bold().monospacedDigit())
                }
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(Date().formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month().day().weekday(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if doses.isEmpty {
                    Text("今日は飲む予定がありません").font(.headline)
                } else if let next {
                    Text("次は\(next.slot.label)の\(SlotSettings.timeText(for: next.slot))").font(.headline)
                } else {
                    Text("今日の分はすべて記録しました").font(.headline)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 朝・昼などのタイミングごとに、その時間に飲むお薬をまとめたカード
struct SlotDoseCard: View {
    let slot: DoseSlot
    let doses: [Dose]
    let index: [String: DoseLog]
    @Environment(\.modelContext) private var context

    var body: some View {
        let open = doses.filter { index[$0.id] == nil }
        let due = doses.first.map { $0.scheduledAt <= Date().addingTimeInterval(3600) } ?? false
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                SlotIcon(slot: slot, size: 34)
                Text(slot.label).font(.headline)
                Text(SlotSettings.timeText(for: slot)).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if open.isEmpty {
                    Label("完了", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.success)
                } else if open.count > 1, due {
                    Button {
                        withAnimation(.snappy) {
                            for dose in open { DoseRecorder.record(dose, status: .taken, existing: nil, context: context) }
                        }
                    } label: {
                        Text("まとめて記録")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.primaryLight, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.primary)
                    .sensoryFeedback(.success, trigger: open.count)
                }
            }
            .padding(.bottom, 6)
            ForEach(doses) { dose in
                Divider().padding(.leading, 54)
                DoseRow(dose: dose, log: index[dose.id], grouped: true)
            }
        }
        .card()
    }
}

/// 1回分の行。チェックで服用済みを切り替える。
struct DoseRow: View {
    let dose: Dose
    let log: DoseLog?
    /// タイミングごとのカードの中に並べるとき（アイコン・時刻・カードの枠を出さない）
    var grouped = false
    @Environment(\.modelContext) private var context
    @State private var showPhoto = false
    @State private var showActions = false
    @State private var editing = false

    private var state: DoseState { DoseState(log: log, scheduledAt: dose.scheduledAt) }

    var body: some View {
        HStack(spacing: 14) {
            if !grouped { SlotIcon(slot: dose.slot) }
            if let photo = dose.medication.photoData {
                // 写真があれば、どの薬かすぐ分かるように表示する（タップで拡大）
                Button { showPhoto = true } label: {
                    MedicationThumbnail(data: photo, size: grouped ? 40 : 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(dose.medication.name)の写真を拡大")
            } else if grouped {
                // まとめたカードの中では、写真がなくても同じ位置に印を置いて名前の列をそろえる
                MedicationThumbnail(data: nil, size: 40)
            }
            VStack(alignment: .leading, spacing: 3) {
                if !grouped {
                    HStack(spacing: 6) {
                        Text(dose.slot.label).font(.subheadline.bold())
                        Text(SlotSettings.timeText(for: dose.slot)).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text(dose.medication.name)
                    .font(grouped ? .body.weight(.medium) : .body)
                    .strikethrough(state == .skipped, color: .secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(dose.medication.amountText).font(.caption).foregroundStyle(.secondary)
                    if state == .missed {
                        LevelBadge(text: "飲み忘れ", color: Theme.danger)
                    } else if state == .skipped {
                        LevelBadge(text: "飲まない", color: .gray)
                    }
                }
            }
            Spacer()
            Button {
                withAnimation(.snappy) { toggle() }
            } label: {
                Image(systemName: state == .taken ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(state == .taken ? Theme.success : Color(.systemGray4))
            }
            .accessibilityLabel(state == .taken ? "服用済み。タップで取り消し" : "服用済みにする")
            .sensoryFeedback(.success, trigger: state == .taken) { _, new in new }
        }
        .padding(.vertical, grouped ? 10 : 0)
        .modifier(CardIf(enabled: !grouped))
        .contentShape(Rectangle())
        // 行をタップすると操作を選ぶポップアップを出す（チェックと写真のボタンはそれぞれの操作のまま）
        .onTapGesture { showActions = true }
        .confirmationDialog(dose.medication.name, isPresented: $showActions, titleVisibility: .visible) {
            Button("編集する") { editing = true }
            if log == nil {
                Button("今回は飲まない") {
                    DoseRecorder.record(dose, status: .skipped, existing: nil, context: context)
                }
            } else {
                Button("記録を取り消す") {
                    if let log { DoseRecorder.undo(log, medication: dose.medication, context: context) }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $editing) {
            MedicationEditView(medication: dose.medication)
        }
        .sheet(isPresented: $showPhoto) {
            MedicationPhotoView(medication: dose.medication)
        }
        .contextMenu {
            if log == nil {
                Button("今回は飲まない", systemImage: "forward") {
                    DoseRecorder.record(dose, status: .skipped, existing: nil, context: context)
                }
            } else {
                Button("記録を取り消す", systemImage: "arrow.uturn.backward") {
                    if let log { DoseRecorder.undo(log, medication: dose.medication, context: context) }
                }
            }
        }
    }

    private func toggle() {
        if let log, log.status == .taken {
            DoseRecorder.undo(log, medication: dose.medication, context: context)
        } else {
            DoseRecorder.record(dose, status: .taken, existing: log, context: context)
        }
    }
}

private struct CardIf: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.card() } else { content }
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}

enum MedicationEditTarget: Identifiable {
    case new
    case edit(Medication)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let med): med.id.uuidString
        }
    }

    var medication: Medication? {
        if case .edit(let med) = self { return med }
        return nil
    }
}

/// 薬の写真を大きく表示する
struct MedicationPhotoView: View {
    let medication: Medication
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let data = medication.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                }
                VStack(spacing: 4) {
                    Text(medication.name).font(.title3.bold())
                    Text(medication.dosageSummary).foregroundStyle(.secondary)
                    if !medication.memo.isEmpty { Text(medication.memo).font(.subheadline) }
                }
                Spacer()
            }
            .padding()
            .background(Theme.background)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
