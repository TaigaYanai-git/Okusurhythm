import SwiftData
import SwiftUI

@MainActor
enum AppContainer {
    static let shared: ModelContainer = {
        let schema = Schema([Medication.self, DoseLog.self, HealthNote.self])
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiPreview")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("データベースを開けませんでした: \(error)")
        }
    }()
}

@main
struct OkusurhythmApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        SlotSettings.registerDefaults()
        NotificationManager.shared.configure()
        if ProcessInfo.processInfo.arguments.contains("-uiPreview") {
            SampleData.insert(into: AppContainer.shared.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.primary)
                // 参考デザインの明るい配色に固定する（端末がダークモードでも黒くしない）
                .preferredColorScheme(.light)
        }
        .modelContainer(AppContainer.shared)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // 飲み忘れて残りが減っていなければ、飲み切る日を先に延ばす
                RunOutPlanner.updateAll(context: AppContainer.shared.mainContext)
                NotificationManager.shared.refresh(context: AppContainer.shared.mainContext)
            }
        }
    }
}

struct RootView: View {
    @AppStorage(SlotSettings.onboardedKey) private var onboarded = false
    @State private var tab = AppTab(rawValue: UserDefaults.standard.string(forKey: "initialTab") ?? "") ?? .home

    var body: some View {
        // スクリーンショット撮影用: -uiPreview -screen interactions など
        if let screen = UserDefaults.standard.string(forKey: "screen"), ProcessInfo.processInfo.arguments.contains("-uiPreview") {
            NavigationStack {
                switch screen {
                case "interactions": InteractionCheckView()
                case "foods": FoodWarningsView()
                case "edit": MedicationEditView(medication: nil)
                case "settings": NotificationSettingsView()
                default: AboutView()
                }
            }
        } else if onboarded {
            TabView(selection: $tab) {
                HomeView(tab: $tab)
                    .tabItem { Label("ホーム", systemImage: "house.fill") }
                    .tag(AppTab.home)
                RecordsView()
                    .tabItem { Label("記録", systemImage: "chart.bar.doc.horizontal") }
                    .tag(AppTab.records)
                CalendarView()
                    .tabItem { Label("カレンダー", systemImage: "calendar") }
                    .tag(AppTab.calendar)
                MenuView()
                    .tabItem { Label("メニュー", systemImage: "line.3.horizontal") }
                    .tag(AppTab.menu)
            }
        } else {
            OnboardingView { onboarded = true }
        }
    }
}

enum AppTab: String, Hashable { case home, records, calendar, menu }
