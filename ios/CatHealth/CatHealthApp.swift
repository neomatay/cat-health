import SwiftUI
import SwiftData
import UserNotifications

/// AppDelegate：接入通知 delegate，处理通知 action（已喂/跳过）与前台展示
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationManager.shared.setup()
        return true
    }
}

@main
struct CatHealthApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
        // SwiftData 容器（本地模式使用；同步模式下仅作本地缓存留存）
        .modelContainer(for: [LocalCat.self, LocalWeight.self, LocalTemp.self,
                              LocalMedPlan.self, LocalMedLog.self])
    }
}

/// 根视图：四个 Tab，与网页版一致
struct RootView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// lastError 有值时弹窗
    private var errorBinding: Binding<Bool> {
        Binding(get: { store.lastError != nil },
                set: { if !$0 { store.lastError = nil } })
    }

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今天", systemImage: "sun.max.fill") }
            TrendsView()
                .tabItem { Label("趋势", systemImage: "chart.line.uptrend.xyaxis") }
            MedsView()
                .tabItem { Label("用药", systemImage: "pills.fill") }
            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(.orange)
        .onAppear {
            store.attach(context: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            // 回到前台：刷新数据（同步模式拉云端；本地模式重载 SwiftData）
            if phase == .active {
                Task { await store.reload() }
            }
        }
        .alert("提示", isPresented: errorBinding) {
            Button("知道了", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
    }
}
