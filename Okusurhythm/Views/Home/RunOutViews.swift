import SwiftData
import SwiftUI

/// なくなる日の10日前から、お薬ごとに出す「病院の予約はお済みですか？」のカード
struct HospitalVisitBanner: View {
    let item: HospitalVisit.RunOut
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "stethoscope")
                    .font(.title2)
                    .foregroundStyle(Theme.warning)
                VStack(alignment: .leading, spacing: 3) {
                    Text("病院の予約はお済みですか？").font(.caption.bold()).foregroundStyle(Theme.warning)
                    Text(item.medication.name).font(.subheadline.bold()).lineLimit(2)
                    Text("\(item.text)でなくなります").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                DaysLeftBadge(days: item.daysLeft())
            }
            HStack(spacing: 10) {
                Button {
                    withAnimation { HospitalVisit.mark(.booked, medications: [item.medication], context: context) }
                } label: {
                    Label("病院を予約した", systemImage: "checkmark")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Button {
                    withAnimation { HospitalVisit.mark(.notNeeded, medications: [item.medication], context: context) }
                } label: {
                    Text("次は行かなくていい")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(Theme.primary)
                        .background(Theme.primaryLight, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .buttonStyle(.plain)
        }
        .card()
    }
}

/// 「あと8日」。少ないほど目立たせる
struct DaysLeftBadge: View {
    let days: Int

    var body: some View {
        let color = days <= 3 ? Theme.danger : days <= HospitalVisit.leadDays ? Theme.warning : Theme.primary
        Text(days < 0 ? "なくなりました" : days == 0 ? "今日まで" : "あと\(days)日")
            .font(.caption.bold().monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}
