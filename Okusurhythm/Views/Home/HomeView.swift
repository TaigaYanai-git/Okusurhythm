import SwiftData
import SwiftUI

struct HomeView: View {
    @Binding var tab: AppTab
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Medication> { $0.isActive }, sort: \Medication.createdAt) private var medications: [Medication]
    @Query private var logs: [DoseLog]
    @State private var selectedDay = Calendar.japanese.startOfDay(for: Date())
    @State private var editing: MedicationEditTarget?
    @State private var showSettings = false

    private var calendar: Calendar { .japanese }
    private var logIndex: [String: DoseLog] { DoseSchedule.index(logs) }
    private var doses: [Dose] { DoseSchedule.doses(on: selectedDay, medications: medications) }
    private var isToday: Bool { calendar.isDateInToday(selectedDay) }

    private var interactionAlerts: [PairResult] {
        InteractionChecker.checkAll(medications.compactMap { DrugDatabase.shared.drug(id: $0.drugID) })
    }

    private var duplicates: [DuplicateIngredient] { InteractionChecker.duplicates(medications) }

    private var refillMeds: [Medication] { medications.filter(\.needsRefill) }

    /// 「まとめてチェックする」で記録する分（今の時刻までの未記録分）
    private var dueDoses: [Dose] {
        let now = Date()
        return doses.filter { logIndex[$0.id] == nil && (!isToday || $0.scheduledAt <= now.addingTimeInterval(3600)) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    WeekStrip(selectedDay: $selectedDay)

                    if !interactionAlerts.isEmpty || !duplicates.isEmpty { interactionBanner }
                    if !refillMeds.isEmpty { refillBanner }

                    HStack {
                        Text(isToday ? "今日の服薬" : "\(selectedDay.japaneseDayText)の服薬").font(.title3.bold())
                        Spacer()
                        Button("すべて見る", systemImage: "chevron.right") { tab = .calendar }
                            .labelStyle(TrailingIconLabelStyle())
                            .font(.subheadline)
                    }

                    if medications.isEmpty {
                        emptyState
                    } else if doses.isEmpty {
                        Text("この日に飲む予定の薬はありません。")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .card()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(doses) { dose in
                                DoseRow(dose: dose, log: logIndex[dose.id])
                            }
                        }
                        if !dueDoses.isEmpty, selectedDay <= Date() {
                            Button {
                                withAnimation {
                                    for dose in dueDoses {
                                        DoseRecorder.record(dose, status: .taken, existing: nil, context: context)
                                    }
                                }
                            } label: {
                                Label("まとめてチェックする", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .sensoryFeedback(.success, trigger: logs.count)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("おくすリズム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("お薬を追加", systemImage: "plus") { editing = .new }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("通知設定", systemImage: "gearshape.fill") { showSettings = true }
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
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var interactionBanner: some View {
        NavigationLink {
            InteractionCheckView()
        } label: {
            let worst = interactionAlerts.first?.level ?? .caution
            let items = duplicates.map { "\($0.drug.displayName)が重複" }
                + interactionAlerts.map { "\($0.a.displayName)×\($0.b.displayName)" }
            HStack(spacing: 12) {
                Image(systemName: worst.symbol).font(.title2).foregroundStyle(worst.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(worst == .contraindicated ? "一緒に飲めない組み合わせがあります"
                         : interactionAlerts.isEmpty ? "同じ成分のお薬が重複しています" : "飲み合わせに注意が必要です")
                        .font(.subheadline.bold())
                    Text(items.joined(separator: "、"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var refillBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill").font(.title2).foregroundStyle(Theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("残りが少ないお薬があります").font(.subheadline.bold())
                Text(refillMeds.map { "\($0.name) 残り\(($0.remainingCount ?? 0).formattedAmount)\($0.unit)" }
                    .joined(separator: "、"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card()
    }
}

/// 1回分の行。チェックで服用済みを切り替える。
struct DoseRow: View {
    let dose: Dose
    let log: DoseLog?
    @Environment(\.modelContext) private var context
    @State private var showPhoto = false
    @State private var showActions = false
    @State private var editing = false

    private var state: DoseState { DoseState(log: log, scheduledAt: dose.scheduledAt) }

    var body: some View {
        HStack(spacing: 14) {
            SlotIcon(slot: dose.slot)
            if let photo = dose.medication.photoData {
                // 写真があれば、どの薬かすぐ分かるように表示する（タップで拡大）
                Button { showPhoto = true } label: {
                    MedicationThumbnail(data: photo, size: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(dose.medication.name)の写真を拡大")
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(dose.slot.label).font(.subheadline.bold())
                    Text(SlotSettings.timeText(for: dose.slot)).font(.subheadline).foregroundStyle(.secondary)
                    if state == .missed {
                        LevelBadge(text: "飲み忘れ", color: Theme.danger)
                    } else if state == .skipped {
                        LevelBadge(text: "スキップ", color: .gray)
                    }
                }
                Text("\(dose.medication.name)（\(dose.medication.amountText)）")
                    .font(.body)
                    .lineLimit(2)
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
        .card()
        .contentShape(Rectangle())
        // 行をタップすると操作を選ぶポップアップを出す（チェックと写真のボタンはそれぞれの操作のまま）
        .onTapGesture { showActions = true }
        .confirmationDialog(dose.medication.name, isPresented: $showActions, titleVisibility: .visible) {
            Button("編集する") { editing = true }
            if log == nil {
                Button("スキップする") {
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
                Button("スキップする", systemImage: "forward") {
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

/// 1週間分の日付を横に並べる
struct WeekStrip: View {
    @Binding var selectedDay: Date
    private var calendar: Calendar { .japanese }

    private var days: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDay.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).month().day().weekday(.abbreviated)))
                .font(.headline)
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { day in
                    let selected = calendar.isDate(day, inSameDayAs: selectedDay)
                    Button {
                        selectedDay = day
                    } label: {
                        VStack(spacing: 4) {
                            Text(calendar.shortWeekdaySymbols[calendar.component(.weekday, from: day) - 1])
                                .font(.caption)
                            Text("\(calendar.component(.day, from: day))").font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selected ? .white : .primary)
                        .background(selected ? Theme.primary : Theme.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            if calendar.isDateInToday(day), !selected {
                                RoundedRectangle(cornerRadius: 12).stroke(Theme.primary, lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
