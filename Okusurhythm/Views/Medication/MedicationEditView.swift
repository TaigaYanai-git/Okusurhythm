import PhotosUI
import SwiftData
import SwiftUI

/// お薬の登録・編集
struct MedicationEditView: View {
    let medication: Medication?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Medication> { $0.isActive }) private var activeMeds: [Medication]
    @Query private var healthNotes: [HealthNote]

    @State private var name = ""
    @State private var drugID: String?
    @State private var amount: Double = 1
    @State private var unit = "錠"
    @State private var slots: Set<DoseSlot> = [.morning]
    @State private var frequency: Frequency = .daily
    @State private var intervalDays = 2
    @State private var weekdays: Set<Int> = []
    @State private var startDate = Date()
    @State private var startSlot: DoseSlot = .morning
    @State private var hasPeriod = false
    @State private var periodDays = 14
    @State private var memo = ""
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var tracksRemaining = false
    @State private var remaining: Double = 28
    @State private var refillThreshold: Double = 7
    @State private var showDrugPicker = false
    @State private var pendingWarnings: SaveWarnings?
    @State private var confirmDelete = false

    private static let units = ["錠", "カプセル", "包", "mL", "滴", "枚", "回"]
    private let db = DrugDatabase.shared

    private var linkedDrug: Drug? { db.drug(id: drugID) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !slots.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                nameSection
                dosageSection
                scheduleSection
                remainingSection
                Section("メモ（任意）") {
                    TextField("食後に服用してください", text: $memo, axis: .vertical)
                        .lineLimit(2...5)
                }
                if medication != nil {
                    Section {
                        Button("このお薬を削除", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle("お薬の登録・編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { trySave() }.bold().disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .onChange(of: photoItem) { _, item in
                Task { photoData = try? await item?.loadTransferable(type: Data.self).flatMap(Self.downscale) }
            }
            .sheet(isPresented: $showDrugPicker) {
                DrugPickerView { drug in
                    drugID = drug.id
                    if name.isEmpty { name = drug.displayName }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in photoData = image.jpegData(compressionQuality: 0.7).flatMap(Self.downscale) }
                    .ignoresSafeArea()
            }
            .sheet(item: $pendingWarnings) { warnings in
                SaveWarningSheet(warnings: warnings) {
                    pendingWarnings = nil
                    save()
                }
            }
            .confirmationDialog("このお薬を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("削除", role: .destructive) { delete() }
            } message: {
                Text("これまでの服薬記録は残ります。")
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            HStack(spacing: 16) {
                MedicationThumbnail(data: photoData, size: 96)
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photoData == nil ? "写真を選ぶ" : "写真を変更", systemImage: "photo")
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("撮影する", systemImage: "camera") { showCamera = true }
                    }
                    if photoData != nil {
                        Button("写真を削除", systemImage: "trash", role: .destructive) { photoData = nil }
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var nameSection: some View {
        Section {
            TextField("例：高血圧の薬、ノルバスク錠5mg", text: $name)
                .onChange(of: name) { _, newName in
                    // 名前から成分が分かれば自動で結びつける（手で選んだ成分は上書きしない）
                    if drugID == nil, let match = db.bestMatch(for: newName) { drugID = match.id }
                }
            if let linkedDrug {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("成分：\(linkedDrug.displayName)").font(.subheadline.bold())
                        Text(linkedDrug.category).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("解除") { drugID = nil }.buttonStyle(.borderless).font(.caption)
                }
            }
            Button(linkedDrug == nil ? "成分（一般名）を選ぶ" : "成分を選び直す", systemImage: "magnifyingglass") {
                showDrugPicker = true
            }
        } header: {
            Text("薬の名前")
        } footer: {
            Text("成分を選ぶと、今飲んでいる薬との飲み合わせや、一緒にとってはいけない飲食物を確認できます。薬の袋やお薬手帳の名前で探せます。")
        }
    }

    private var dosageSection: some View {
        Section("用法・用量") {
            Stepper(value: $amount, in: 0.5...20, step: 0.5) {
                HStack {
                    Text("1回の量")
                    Spacer()
                    Text("\(amount.formattedAmount)\(unit)").bold()
                }
            }
            Picker("単位", selection: $unit) {
                ForEach(Self.units, id: \.self) { Text($0) }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("服用時間")
                HStack(spacing: 8) {
                    ForEach(DoseSlot.allCases) { slot in
                        let on = slots.contains(slot)
                        Button {
                            if on { slots.remove(slot) } else { slots.insert(slot) }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: slot.symbol)
                                Text(slot.label).font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(on ? .white : Theme.primary)
                            .background(on ? Theme.primary : Theme.primaryLight, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var scheduleSection: some View {
        Section {
            Picker("頻度", selection: $frequency) {
                ForEach(Frequency.allCases) { Text($0.label).tag($0) }
            }
            if frequency == .everyNDays {
                Stepper("\(intervalDays)日ごと", value: $intervalDays, in: 2...30)
            }
            if frequency == .weekdays {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { weekday in
                        let on = weekdays.contains(weekday)
                        Button(Calendar.japanese.shortWeekdaySymbols[weekday - 1]) {
                            if on { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(on ? .white : Theme.primary)
                        .background(on ? Theme.primary : Theme.primaryLight, in: Circle())
                        .buttonStyle(.plain)
                    }
                }
            }
            DatePicker("飲み始める日", selection: $startDate, displayedComponents: .date)
            if slots.count > 1 {
                Picker("最初に飲むタイミング", selection: $startSlot) {
                    ForEach(slots.sorted()) { Text("\($0.label)から").tag($0) }
                }
            }
            Toggle("処方日数を設定", isOn: $hasPeriod)
            if hasPeriod {
                Stepper("\(periodDays)日分", value: $periodDays, in: 1...365)
            }
        } header: {
            Text("飲む日")
        } footer: {
            if let summary = startSummary { Text(summary) }
        }
        .onChange(of: slots) { _, newSlots in
            // 選んでいないタイミングから始まらないようにする
            if !newSlots.contains(startSlot), let first = newSlots.sorted().first { startSlot = first }
        }
    }

    /// 「10/20（月）の昼から飲み始めて、11/3（月）の朝で終わります」
    private var startSummary: String? {
        let sorted = slots.sorted()
        guard let first = sorted.first else { return nil }
        let slot = slots.count > 1 ? startSlot : first
        let start = "\(startDate.japaneseDayText)の\(slot.label)から飲み始め"
        guard hasPeriod, let end = endDate(for: slot) else { return start + "ます。" }
        let lastSlot = slot > first ? sorted.last { $0 < slot } ?? first : sorted.last ?? first
        return start + "て、\(end.japaneseDayText)の\(lastSlot.label)で終わります。"
    }

    /// 処方日数から最終日を出す。途中のタイミングから始めるときは翌日の分まで続く
    private func endDate(for slot: DoseSlot) -> Date? {
        guard hasPeriod, let first = slots.sorted().first else { return nil }
        let extra = slot > first ? 1 : 0
        return Calendar.japanese.date(byAdding: .day, value: periodDays - 1 + extra, to: startDate)
    }

    private var remainingSection: some View {
        Section {
            Toggle("残りの数を管理する", isOn: $tracksRemaining)
            if tracksRemaining {
                Stepper(value: $remaining, in: 0...999, step: 1) {
                    HStack { Text("今の残り"); Spacer(); Text("\(remaining.formattedAmount)\(unit)").bold() }
                }
                Stepper(value: $refillThreshold, in: 1...60, step: 1) {
                    HStack { Text("お知らせする残数"); Spacer(); Text("\(refillThreshold.formattedAmount)\(unit)以下").bold() }
                }
            }
        } header: {
            Text("残薬数と補充アラート")
        } footer: {
            if tracksRemaining {
                Text("服用を記録すると自動で減り、残りが少なくなったら通知でお知らせします。")
            }
        }
    }

    // MARK: - Load / Save

    private func load() {
        guard let med = medication else {
            // 新しく登録するときは、今日これから来るタイミングから始める
            let now = Date()
            startSlot = DoseSlot.allCases.first { SlotSettings.date(for: $0, on: now) > now } ?? .morning
            return
        }
        name = med.name
        drugID = med.drugID
        amount = med.amountPerDose
        unit = med.unit
        slots = Set(med.slots)
        frequency = med.frequency
        intervalDays = med.intervalDays
        weekdays = Set(med.weekdays)
        startDate = med.startDate
        startSlot = med.startSlot
        if let end = med.endDate {
            hasPeriod = true
            let days = Calendar.japanese.dateComponents([.day], from: Calendar.japanese.startOfDay(for: med.startDate),
                                                        to: Calendar.japanese.startOfDay(for: end)).day ?? 13
            periodDays = days + (med.startsMidDay ? 0 : 1)
        }
        memo = med.memo
        photoData = med.photoData
        tracksRemaining = med.remainingCount != nil
        remaining = med.remainingCount ?? 28
        refillThreshold = med.refillThreshold
    }

    private func trySave() {
        let current = activeMeds.filter { $0.id != medication?.id }.compactMap { db.drug(id: $0.drugID) }
        let pairs = linkedDrug.map { InteractionChecker.check(candidate: $0, against: current) } ?? []
        let allergies = AllergyMatcher.matches(name: name, drug: linkedDrug, notes: healthNotes)
        let changedDrug = medication?.drugID != drugID || medication == nil
        if changedDrug, !pairs.isEmpty || !allergies.isEmpty {
            pendingWarnings = SaveWarnings(pairs: pairs, allergies: allergies)
        } else {
            save()
        }
    }

    private func save() {
        let med = medication ?? Medication(name: name)
        med.name = name.trimmingCharacters(in: .whitespaces)
        med.drugID = drugID
        med.amountPerDose = amount
        med.unit = unit
        med.slots = Array(slots)
        med.frequency = frequency
        med.intervalDays = intervalDays
        med.weekdays = weekdays.sorted()
        med.startDate = startDate
        med.startSlot = slots.contains(startSlot) ? startSlot : (slots.sorted().first ?? .morning)
        med.endDate = endDate(for: med.startSlot)
        med.memo = memo
        med.photoData = photoData
        med.remainingCount = tracksRemaining ? remaining : nil
        med.refillThreshold = refillThreshold
        med.refillNotified = med.needsRefill
        if medication == nil { context.insert(med) }
        try? context.save()
        NotificationManager.shared.refresh(context: context)
        dismiss()
    }

    private func delete() {
        if let medication { context.delete(medication) }
        try? context.save()
        NotificationManager.shared.refresh(context: context)
        dismiss()
    }

    /// 写真は長辺 800px に縮めて保存する
    private static func downscale(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, 800 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.7)
    }
}

// MARK: - 保存前の確認

struct SaveWarnings: Identifiable {
    let id = UUID()
    let pairs: [PairResult]
    let allergies: [HealthNote]
}

struct SaveWarningSheet: View {
    let warnings: SaveWarnings
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !warnings.allergies.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("登録しているアレルギー・副作用歴に一致します", systemImage: "allergens")
                                .font(.headline)
                                .foregroundStyle(Theme.danger)
                            ForEach(warnings.allergies) { note in
                                Text("・\(note.kind.label)：\(note.title)")
                            }
                        }
                        .card()
                    }
                    ForEach(warnings.pairs) { pair in
                        PairResultCard(result: pair)
                    }
                    Text("医師が承知の上で処方している場合もあります。気になるときは、自己判断で飲むのをやめずに医師・薬剤師に相談してください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("登録前の確認")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button("確認して登録する", action: onConfirm).buttonStyle(PrimaryButtonStyle())
                    Button("戻って見直す") { dismiss() }
                }
                .padding()
                .background(.bar)
            }
        }
    }
}

enum AllergyMatcher {
    /// 登録済みのアレルギー・副作用歴の言葉が、薬の名前・成分名・分類に含まれるか
    static func matches(name: String, drug: Drug?, notes: [HealthNote]) -> [HealthNote] {
        let haystack = ([name] + (drug.map { [$0.displayName, $0.genericName, $0.category] + $0.brandNames } ?? []))
            .map(DrugDatabase.normalize)
        return notes.filter { note in
            guard note.kind == .allergy || note.kind == .sideEffect else { return false }
            return note.title
                .components(separatedBy: CharacterSet(charactersIn: "、,・/ 　"))
                .map { DrugDatabase.normalize($0.replacingOccurrences(of: "系", with: "")) }
                .filter { $0.count >= 2 }
                .contains { term in haystack.contains { $0.contains(term) } }
        }
    }
}

// MARK: - カメラ

struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPick(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
