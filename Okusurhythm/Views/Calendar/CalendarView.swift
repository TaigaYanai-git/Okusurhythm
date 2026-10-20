import SwiftData
import SwiftUI

/// 月のカレンダーで服薬状況を確認する
struct CalendarView: View {
    @Query(sort: \Medication.createdAt) private var medications: [Medication]
    @Query private var logs: [DoseLog]
    @State private var month = Calendar.japanese.dateInterval(of: .month, for: Date())!.start
    @State private var selectedDay = Calendar.japanese.startOfDay(for: Date())

    private var calendar: Calendar { .japanese }

    private var gridDays: [Date?] {
        let firstWeekday = calendar.component(.weekday, from: month)
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let leading = Array<Date?>(repeating: nil, count: firstWeekday - 1)
        return leading + (0..<count).map { calendar.date(byAdding: .day, value: $0, to: month) }
    }

    var body: some View {
        let index = DoseSchedule.index(logs)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 12) {
                        HStack {
                            Button("前の月", systemImage: "chevron.left") { shiftMonth(-1) }.labelStyle(.iconOnly)
                            Spacer()
                            Text(month.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).year().month()))
                                .font(.headline)
                            Spacer()
                            Button("次の月", systemImage: "chevron.right") { shiftMonth(1) }.labelStyle(.iconOnly)
                        }
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(0..<7, id: \.self) { i in
                                Text(calendar.veryShortWeekdaySymbols[i])
                                    .font(.caption)
                                    .foregroundStyle(i == 0 ? Theme.danger : i == 6 ? Theme.primary : .secondary)
                            }
                            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                                if let day {
                                    dayCell(day, status: status(for: day, index: index))
                                } else {
                                    Color.clear.frame(height: 44)
                                }
                            }
                        }
                        legend
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(selectedDay.japaneseDayText)の服薬記録").font(.headline)
                        let doses = DoseSchedule.doses(on: selectedDay, medications: medications)
                        if doses.isEmpty {
                            Text("この日の予定はありません。").foregroundStyle(.secondary)
                        }
                        ForEach(doses) { dose in
                            if selectedDay <= Date() {
                                DoseRow(dose: dose, log: index[dose.id])
                            } else {
                                HStack(spacing: 14) {
                                    SlotIcon(slot: dose.slot, size: 36)
                                    Text("\(dose.slot.label) \(SlotSettings.timeText(for: dose.slot))").font(.subheadline.bold())
                                    Text(dose.medication.name)
                                    Spacer()
                                }
                                .card()
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func dayCell(_ day: Date, status: DayStatus) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selectedDay)
        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline)
                    .fontWeight(calendar.isDateInToday(day) ? .bold : .regular)
                    .foregroundStyle(selected ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background(selected ? Theme.primary : .clear, in: Circle())
                Circle().fill(status.color).frame(width: 6, height: 6)
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.japaneseDayText) \(status.label)")
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach([DayStatus.complete, .partial, .missed], id: \.self) { status in
                HStack(spacing: 4) {
                    Circle().fill(status.color).frame(width: 8, height: 8)
                    Text(status.label).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func status(for day: Date, index: [String: DoseLog]) -> DayStatus {
        let doses = DoseSchedule.doses(on: day, medications: medications).filter { $0.scheduledAt <= Date() }
        guard !doses.isEmpty else { return .none }
        let taken = doses.filter { index[$0.id]?.status == .taken }.count
        if taken == doses.count { return .complete }
        return taken == 0 && doses.allSatisfy({ index[$0.id] == nil }) ? .missed : .partial
    }

    private func shiftMonth(_ value: Int) {
        month = calendar.date(byAdding: .month, value: value, to: month)!
    }
}

enum DayStatus: Hashable {
    case none, complete, partial, missed

    var color: Color {
        switch self {
        case .none: .clear
        case .complete: Theme.success
        case .partial: Theme.warning
        case .missed: Theme.danger
        }
    }

    var label: String {
        switch self {
        case .none: "予定なし"
        case .complete: "すべて服用"
        case .partial: "一部服用"
        case .missed: "飲み忘れ"
        }
    }
}
