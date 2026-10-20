import Charts
import SwiftData
import SwiftUI

/// 服薬の記録・統計（週／月／年の達成率）
struct RecordsView: View {
    @Query(sort: \Medication.createdAt) private var medications: [Medication]
    @Query private var logs: [DoseLog]
    @State private var range: StatsRange = .week

    private var calendar: Calendar { .japanese }

    private struct Bucket: Identifiable {
        let id: Date
        let label: String
        let taken: Int
        let total: Int
        var rate: Double { total == 0 ? 0 : Double(taken) / Double(total) }
    }

    private var interval: (start: Date, end: Date) {
        let today = calendar.startOfDay(for: Date())
        switch range {
        case .week: return (calendar.date(byAdding: .day, value: -6, to: today)!, today)
        case .month: return (calendar.date(byAdding: .day, value: -29, to: today)!, today)
        case .year:
            let start = calendar.date(byAdding: .month, value: -11, to: calendar.dateInterval(of: .month, for: today)!.start)!
            return (start, today)
        }
    }

    private var buckets: [Bucket] {
        let index = DoseSchedule.index(logs)
        let (start, end) = interval
        var result: [Bucket] = []
        if range == .year {
            var month = start
            while month <= end {
                let monthEnd = min(calendar.date(byAdding: DateComponents(month: 1, day: -1), to: month)!, end)
                let r = DoseSchedule.adherence(from: month, to: monthEnd, medications: medications, logs: index)
                result.append(Bucket(id: month, label: "\(calendar.component(.month, from: month))月", taken: r.taken, total: r.total))
                month = calendar.date(byAdding: .month, value: 1, to: month)!
            }
        } else {
            var day = start
            while day <= end {
                let r = DoseSchedule.adherence(from: day, to: day, medications: medications, logs: index)
                result.append(Bucket(id: day, label: "\(calendar.component(.day, from: day))日", taken: r.taken, total: r.total))
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }
        }
        return result
    }

    var body: some View {
        let buckets = buckets
        let taken = buckets.map(\.taken).reduce(0, +)
        let total = buckets.map(\.total).reduce(0, +)
        let rate = total == 0 ? 0 : Double(taken) / Double(total)

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("期間", selection: $range) {
                        ForEach(StatsRange.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Text(rangeText).font(.headline)

                    ZStack {
                        Circle().stroke(Theme.primaryLight, lineWidth: 16)
                        Circle()
                            .trim(from: 0, to: rate)
                            .stroke(AngularGradient(colors: [Theme.success, Theme.primary], center: .center),
                                    style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("服薬達成率").font(.caption).foregroundStyle(.secondary)
                            Text("\(Int((rate * 100).rounded()))%").font(.system(size: 40, weight: .bold, design: .rounded))
                            Text("\(taken)/\(total)回").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 180, height: 180)
                    .animation(.easeOut, value: rate)
                    .accessibilityElement(children: .combine)

                    Chart(buckets) { bucket in
                        BarMark(x: .value("日付", bucket.label), y: .value("達成率", bucket.rate * 100))
                            .foregroundStyle(bucket.rate >= 0.8 ? Theme.success : bucket.total == 0 ? .gray.opacity(0.3) : Theme.warning)
                            .cornerRadius(4)
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis { AxisMarks(values: [0, 50, 100]) { AxisValueLabel("\($0.as(Int.self) ?? 0)%") ; AxisGridLine() } }
                    .chartXAxis {
                        AxisMarks { value in
                            if range != .month || (buckets.firstIndex { $0.label == value.as(String.self) } ?? 0) % 5 == 0 {
                                AxisValueLabel()
                            }
                        }
                    }
                    .frame(height: 180)
                    .card()

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                        Text(message(rate: rate, total: total)).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Theme.primaryLight.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.corner))

                    medicationBreakdown
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("服薬の記録")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// 薬ごとの達成率
    private var medicationBreakdown: some View {
        let index = DoseSchedule.index(logs)
        let (start, end) = interval
        return VStack(alignment: .leading, spacing: 10) {
            Text("お薬ごと").font(.headline)
            ForEach(medications.filter(\.isActive)) { med in
                let r = DoseSchedule.adherence(from: start, to: end, medications: [med], logs: index)
                HStack {
                    MedicationThumbnail(data: med.photoData, size: 36)
                    Text(med.name).lineLimit(1)
                    Spacer()
                    Text(r.total == 0 ? "-" : "\(Int((Double(r.taken) / Double(r.total) * 100).rounded()))%")
                        .bold()
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var rangeText: String {
        let (start, end) = interval
        let style = Date.FormatStyle.dateTime.locale(Locale(identifier: "ja_JP")).month().day()
        return "\(start.formatted(style)) - \(end.formatted(style))"
    }

    private func message(rate: Double, total: Int) -> String {
        if total == 0 { return "お薬を登録して服用を記録すると、ここに達成率が表示されます。" }
        switch rate {
        case 0.9...: return "とても良いペースです！この調子で続けましょう。"
        case 0.7..<0.9: return "よく続けられています。飲み忘れが多い時間帯は通知の時刻を見直してみましょう。"
        default: return "飲み忘れが続くときは、通知時刻の変更や、医師・薬剤師への相談も検討しましょう。"
        }
    }
}

enum StatsRange: String, CaseIterable, Identifiable {
    case week, month, year
    var id: String { rawValue }
    var label: String {
        switch self {
        case .week: "週"
        case .month: "月"
        case .year: "年"
        }
    }
}
