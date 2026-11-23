import SwiftUI

/// 「記録」タブ。カレンダーでその日を見返す／達成率で傾向を見る
struct HistoryView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case calendar, stats
        var id: String { rawValue }
        var label: String { self == .calendar ? "カレンダー" : "達成率" }
    }

    @State private var mode: Mode = UserDefaults.standard.string(forKey: "historyMode").flatMap(Mode.init(rawValue:)) ?? .calendar
    @ObservedObject private var guide = AppGuide.shared

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .calendar: CalendarView()
                case .stats: RecordsView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("表示", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
            // 使い方ガイドはカレンダーを照らす
            .onReceive(guide.$tab) { if $0 == .records { mode = .calendar } }
        }
    }
}
