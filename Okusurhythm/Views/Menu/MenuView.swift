import SwiftData
import SwiftUI

struct MenuView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("お薬") {
                    NavigationLink { MedicationListView() } label: {
                        Label("お薬の一覧・登録", systemImage: "pills")
                    }
                    NavigationLink { InteractionCheckView() } label: {
                        Label("飲み合わせチェック", systemImage: "arrow.triangle.merge")
                    }
                    NavigationLink { FoodWarningsView() } label: {
                        Label("一緒にとってはいけない飲食物", systemImage: "cup.and.saucer")
                    }
                    NavigationLink { DrugLibraryView() } label: {
                        Label("お薬の情報を調べる", systemImage: "book")
                    }
                }
                Section("わたしの情報") {
                    NavigationLink { HealthProfileView() } label: {
                        Label("アレルギー・副作用歴・持病", systemImage: "heart.text.square")
                    }
                }
                Section("設定") {
                    NavigationLink { NotificationSettingsView() } label: {
                        Label("通知設定", systemImage: "bell.badge")
                    }
                }
                Section("このアプリについて") {
                    NavigationLink { AboutView() } label: {
                        Label("データの出典・ご利用上の注意", systemImage: "info.circle")
                    }
                    if let url = Bundle.main.urlSetting("PRIVACY_POLICY_URL") {
                        Link(destination: url) { Label("プライバシーポリシー", systemImage: "hand.raised") }
                    }
                }
            }
            .navigationTitle("メニュー")
        }
    }
}

extension Bundle {
    func urlSetting(_ key: String) -> URL? {
        (object(forInfoDictionaryKey: key) as? String).flatMap(URL.init(string:))
    }
}

struct MedicationListView: View {
    @Query(sort: \Medication.createdAt) private var medications: [Medication]
    @State private var editing: MedicationEditTarget?

    var body: some View {
        List {
            if medications.isEmpty {
                Text("まだお薬が登録されていません。右上の＋から登録できます。").foregroundStyle(.secondary)
            }
            ForEach(medications) { med in
                Button { editing = .edit(med) } label: {
                    HStack(spacing: 12) {
                        MedicationThumbnail(data: med.photoData)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(med.name).font(.body.bold())
                            Text(med.dosageSummary).font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                ForEach(med.slots) { slot in
                                    Text(slot.label).font(.caption2.bold()).foregroundStyle(slot.tint)
                                }
                                if let remaining = med.remainingCount {
                                    Text("残り\(remaining.formattedAmount)\(med.unit)")
                                        .font(.caption2)
                                        .foregroundStyle(med.needsRefill ? Theme.danger : .secondary)
                                }
                            }
                        }
                        Spacer()
                        if !med.isActive { Text("休止中").font(.caption).foregroundStyle(.secondary) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading) {
                    Button(med.isActive ? "休止" : "再開") { med.isActive.toggle() }
                        .tint(med.isActive ? .gray : Theme.success)
                }
            }
        }
        .navigationTitle("お薬の一覧")
        .toolbar {
            Button("お薬を追加", systemImage: "plus") { editing = .new }
        }
        .sheet(item: $editing) { MedicationEditView(medication: $0.medication) }
    }
}

/// 収録している薬の一覧から添付文書情報を見る
struct DrugLibraryView: View {
    @State private var query = ""

    var body: some View {
        List(DrugDatabase.shared.search(query)) { drug in
            NavigationLink { DrugDetailView(drug: drug) } label: { DrugRow(drug: drug) }
        }
        .searchable(text: $query, prompt: "一般名・商品名で検索")
        .navigationTitle("お薬の情報")
    }
}

struct HealthProfileView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HealthNote.createdAt) private var notes: [HealthNote]
    @State private var adding: HealthNoteKind?
    @State private var newTitle = ""
    @State private var newDetail = ""

    var body: some View {
        List {
            Section {
                Text("登録した内容は、お薬を登録するときの確認に使います。受診時や薬局で、この画面を見せることもできます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(HealthNoteKind.allCases) { kind in
                Section {
                    ForEach(notes.filter { $0.kind == kind }) { note in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.title).font(.body.bold())
                            if !note.detail.isEmpty { Text(note.detail).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .onDelete { offsets in
                        let items = notes.filter { $0.kind == kind }
                        offsets.map { items[$0] }.forEach(context.delete)
                    }
                    Button("\(kind.label)を追加", systemImage: "plus") {
                        newTitle = ""
                        newDetail = ""
                        adding = kind
                    }
                } header: {
                    Label(kind.label, systemImage: kind.symbol)
                }
            }
        }
        .navigationTitle("わたしの健康情報")
        .sheet(item: $adding) { kind in
            NavigationStack {
                Form {
                    TextField(kind.placeholder, text: $newTitle)
                    TextField("詳しく（任意）：いつ・どんな症状が出たか", text: $newDetail, axis: .vertical)
                        .lineLimit(2...4)
                }
                .navigationTitle("\(kind.label)を追加")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { adding = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("追加") {
                            context.insert(HealthNote(kind: kind, title: newTitle, detail: newDetail))
                            adding = nil
                        }
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(SlotSettings.remindersEnabledKey) private var remindersEnabled = true
    @AppStorage(SlotSettings.soundEnabledKey) private var soundEnabled = true
    @AppStorage(SlotSettings.followUpEnabledKey) private var followUpEnabled = true
    @AppStorage(SlotSettings.followUpMinutesKey) private var followUpMinutes = 30
    @State private var authorized = true

    var body: some View {
        Form {
            if !authorized {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("通知がオフになっています", systemImage: "bell.slash.fill").foregroundStyle(Theme.danger)
                        Text("iPhoneの設定で「おくすリズム」の通知を許可してください。")
                            .font(.footnote)
                        Button("設定を開く") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                    }
                }
            }
            Section {
                Toggle("服薬リマインダー", isOn: $remindersEnabled)
            }
            Section("通知時間の設定") {
                ForEach(DoseSlot.allCases) { SlotTimeRow(slot: $0) }
            }
            .disabled(!remindersEnabled)
            Section {
                Toggle("飲み忘れの再通知", isOn: $followUpEnabled)
                if followUpEnabled {
                    Picker("再通知までの時間", selection: $followUpMinutes) {
                        ForEach([15, 30, 60, 90, 120], id: \.self) { Text("\($0)分後").tag($0) }
                    }
                }
                Toggle("サウンド", isOn: $soundEnabled)
            } header: {
                Text("通知方法")
            } footer: {
                Text("記録がないときだけ、もう一度お知らせします。通知を長押しすると「服用を完了する」「10分後にもう一度」を選べます。")
            }
            .disabled(!remindersEnabled)
        }
        .navigationTitle("通知設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } }
        }
        .task {
            authorized = await NotificationManager.shared.authorizationStatus() != .denied
        }
        .onDisappear { NotificationManager.shared.refresh(context: context) }
    }
}

private struct SlotTimeRow: View {
    let slot: DoseSlot
    @AppStorage private var minutes: Int
    @AppStorage private var enabled: Bool

    init(slot: DoseSlot) {
        self.slot = slot
        _minutes = AppStorage(wrappedValue: slot.defaultMinutes, SlotSettings.minutesKey(slot))
        _enabled = AppStorage(wrappedValue: true, SlotSettings.enabledKey(slot))
    }

    private var time: Binding<Date> {
        Binding {
            Calendar.japanese.date(byAdding: .minute, value: minutes, to: Calendar.japanese.startOfDay(for: Date()))!
        } set: { date in
            let c = Calendar.japanese.dateComponents([.hour, .minute], from: date)
            minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            SlotIcon(slot: slot, size: 36)
            Text(slot.label).frame(width: 52, alignment: .leading)
            DatePicker(slot.label, selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
            Spacer()
            Toggle(slot.label, isOn: $enabled).labelsHidden()
        }
    }
}
