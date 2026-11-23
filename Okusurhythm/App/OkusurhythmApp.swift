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
    @ObservedObject private var guide = AppGuide.shared

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
                    .tabItem { Label("今日", systemImage: "checklist") }
                    .tag(AppTab.home)
                HistoryView()
                    .tabItem { Label("記録", systemImage: "calendar") }
                    .tag(AppTab.records)
                MedicationsView()
                    .tabItem { Label("お薬", systemImage: "pills.fill") }
                    .tag(AppTab.medications)
                MenuView()
                    .tabItem { Label("メニュー", systemImage: "line.3.horizontal") }
                    .tag(AppTab.menu)
            }
            // はじめての人への使い方ガイド（画面の場所を照らして説明する）
            .overlay { AppGuideOverlay() }
            .onReceive(guide.$tab) { if let t = $0 { tab = t } }
            .task {
                let args = ProcessInfo.processInfo.arguments
                // スクリーンショット用：-guide で必ず出す（-guideStep N でその手順から）
                if args.contains("-guide") {
                    guide.start()
                    if let i = args.firstIndex(of: "-guideStep"), args.indices.contains(i + 1), let n = Int(args[i + 1]) {
                        guide.stepIndex = n
                    }
                    return
                }
                guard !args.contains("-uiPreview") else { return }
                guide.startIfNeeded()
            }
        } else {
            OnboardingView { onboarded = true }
        }
    }
}

enum AppTab: String, Hashable { case home, records, medications, menu }
