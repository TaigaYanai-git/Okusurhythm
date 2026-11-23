import SwiftData
import SwiftUI

/// 「お薬」タブ。登録したお薬と、毎回きちんと飲んだときになくなる日の一覧
struct MedicationsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.createdAt) private var medications: [Medication]
    @Query private var logs: [DoseLog]
    @State private var editing: MedicationEditTarget?

    private var active: [Medication] { medications.filter(\.isActive) }
    private var paused: [Medication] { medications.filter { !$0.isActive } }

    var body: some View {
        _ = logs.count // 記録が変わったら、なくなる日を計算し直す
        return NavigationStack {
            List {
                if medications.isEmpty {
                    Section {
                        Text("まだお薬が登録されていません。右上の＋から登録できます。").foregroundStyle(.secondary)
                    }
                }
                if !active.isEmpty {
                    Section {
                        ForEach(active) { row($0) }
                    } footer: {
                        Text("「なくなる日」は、毎回きちんと飲んだときに最後の1回を飲む日です。残りの数か処方日数を登録すると表示されます。")
                    }
                }
                if !paused.isEmpty {
                    Section("休止中") {
                        ForEach(paused) { row($0) }
                    }
                }
            }
            .themedList()
            .navigationTitle("お薬")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // ガイドで位置を測れるよう、ラベルは SwiftUI の View で描く
                    Button { editing = .new } label: {
                        Image(systemName: "plus").guideTarget(.addToolbar)
                    }
                    .accessibilityLabel("お薬を追加")
                }
            }
            .sheet(item: $editing) { MedicationEditView(medication: $0.medication) }
        }
    }

    private func row(_ med: Medication) -> some View {
        let runOut = HospitalVisit.runOut(of: med, context: context)
        return Button { editing = .edit(med) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    MedicationThumbnail(data: med.photoData, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(med.name).font(.body.bold()).lineLimit(2)
                        Text(med.dosageSummary).font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            ForEach(med.slots) { slot in
                                Text(slot.label)
                                    .font(.caption2.bold())
                                    .foregroundStyle(slot.tint)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(slot.tint.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                if med.isActive, med.remainingCount != nil || runOut != nil {
                    HStack(spacing: 8) {
                        if let remaining = med.remainingCount {
                            Label("残り\(remaining.formattedAmount)\(med.unit)", systemImage: "shippingbox")
                                .foregroundStyle(med.needsRefill ? Theme.danger : .secondary)
                        }
                        if let runOut {
                            Label("\(runOut.text)でなくなる", systemImage: "calendar")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let runOut { DaysLeftBadge(days: runOut.daysLeft()) }
                    }
                    .font(.caption)
                    .labelStyle(CompactLabelStyle())
                }
                if let runOut, let ack = HospitalVisit.ack(for: med, runOut: runOut.day) {
                    HStack(spacing: 6) {
                        Image(systemName: ack == .booked ? "checkmark.circle.fill" : "minus.circle.fill")
                            .foregroundStyle(ack == .booked ? Theme.success : .secondary)
                        Text(ack == .booked ? "病院を予約済み" : "次の受診なし（お知らせしません）")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Button("取り消す") { withAnimation { HospitalVisit.clear(med, context: context) } }
                            .buttonStyle(.borderless)
                    }
                    .font(.caption)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(med.isActive ? "休止" : "再開") {
                med.isActive.toggle()
                try? context.save()
                NotificationManager.shared.refresh(context: context)
            }
            .tint(med.isActive ? .gray : Theme.success)
        }
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}
