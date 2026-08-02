import SwiftUI

@main
struct CatHealthApp: App {
    @StateObject private var store = DataStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _ = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .task { await store.loadCats() }
                .onAppear { NotificationManager.shared.requestAuth() }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await store.loadCats()
                            NotificationManager.shared.reschedule(plans: store.plans, cats: store.cats)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .doseLoggedFromNotification)) { _ in
                    Task { await store.loadCats() }
                }
        }
    }
}

/// 根视图：无家庭码 → 家庭设置页；有 → 主界面
struct RootView: View {
    @EnvironmentObject var store: DataStore
    @State private var familyId = Config.familyId

    var body: some View {
        ZStack(alignment: .bottom) {
            if familyId == nil {
                FamilySetupView(onDone: { fid in
                    familyId = fid
                    Task { await store.loadCats() }
                })
            } else {
                MainTabView()
            }
            // Toast
            if !store.toast.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                    Text(store.toast)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Color(red: 38/255, green: 61/255, blue: 51/255))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .shadow(radius: 6, y: 3)
                .padding(.bottom, 100)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: store.toast.isEmpty)
        .background(Color.appBg.ignoresSafeArea())
    }
}

/// 主界面：4 Tab + 中间 FAB
struct MainTabView: View {
    @State private var tab = 0
    @State private var showQuickRecord = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                HomeView()
                    .tabItem { Label("首页", systemImage: "house") }.tag(0)
                TrendsView()
                    .tabItem { Label("趋势", systemImage: "chart.line.uptrend.xyaxis") }.tag(1)
                MedsView()
                    .tabItem { Label("用药", systemImage: "pills") }.tag(2)
                FamilyView()
                    .tabItem { Label("家庭", systemImage: "person.2") }.tag(3)
            }
            .tint(.appGreen)

            // 中间 FAB
            Button { showQuickRecord = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.appGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: .appGreen.opacity(0.3), radius: 6, y: 4)
            }
            .padding(.bottom, 6)
        }
        .sheet(isPresented: $showQuickRecord) {
            QuickRecordSheet()
                .presentationDetents([.height(240)])
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToMedsTab)) { _ in
            tab = 2
        }
    }
}

/// 首次使用：创建/加入家庭
struct FamilySetupView: View {
    var onDone: (String) -> Void
    @State private var code = ""
    @State private var busy = false
    @State private var joinError = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 46)

                Image(systemName: "pawprint.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(Color.appGreen)

                VStack(spacing: 9) {
                    Text("猫爪健康屋")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.appGreenDark)
                    Text("记录体重和体温，用药不忘记；家人也能一起照顾毛孩子")
                        .font(.subheadline)
                        .foregroundStyle(Color.appGray)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    HStack(spacing: 18) {
                        SetupFeature(icon: "scalemass.fill", title: "体重体温")
                        SetupFeature(icon: "pills.fill", title: "用药提醒")
                    }
                    HStack(spacing: 18) {
                        SetupFeature(icon: "chart.line.uptrend.xyaxis", title: "健康趋势")
                        SetupFeature(icon: "person.2.fill", title: "家人同步")
                    }
                }

                VStack(alignment: .leading, spacing: 11) {
                    Text("第一次使用")
                        .font(.headline)
                        .foregroundStyle(Color.appGreenDark)
                    Text("建立一个只属于你家的健康记录")
                        .font(.subheadline)
                        .foregroundStyle(Color.appGray)
                    Button {
                        onDone(Config.ensureFamilyId())
                    } label: {
                        Label("创建我的家庭", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.appGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                VStack(alignment: .leading, spacing: 11) {
                    Text("已有家庭码")
                        .font(.headline)
                        .foregroundStyle(Color.appGreenDark)
                    Text("从网页或另一台设备的“家庭”页复制 36 位家庭码")
                        .font(.subheadline)
                        .foregroundStyle(Color.appGray)

                    HStack(spacing: 10) {
                        TextField("粘贴家庭码", text: $code)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.appGreenDark)
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.appLine, lineWidth: 1))
                            .onSubmit { join() }

                        Button("加入") { join() }
                            .font(.headline)
                            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                    }

                    if !joinError.isEmpty {
                        Label(joinError, systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.missText)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 34)
        }
        .background(Color.appBg.ignoresSafeArea())
    }

    private func join() {
        let fid = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: fid) != nil else {
            joinError = "家庭码格式不正确，请粘贴完整的 36 位编号"
            return
        }
        busy = true; joinError = ""
        Task {
            do {
                // 验证家庭码可访问
                _ = try await Supa.list(Cat.self, table: "cats", query: [
                    URLQueryItem(name: "select", value: "id"),
                    URLQueryItem(name: "family_id", value: "eq.\(fid)"),
                    URLQueryItem(name: "limit", value: "1")
                ])
                Config.familyId = fid
                await MainActor.run {
                    busy = false
                    onDone(fid)
                }
            } catch {
                await MainActor.run {
                    joinError = errorMessage(for: error)
                    busy = false
                }
            }
        }
    }

    private func errorMessage(for error: Error) -> String {
        if let supaError = error as? SupaError {
            switch supaError {
            case .badURL:
                return "云端地址配置有误"
            case .notConfigured:
                return "云端服务尚未配置"
            case .http(let status, _):
                return "云端返回错误（HTTP \(status)），请确认家庭码和数据库状态"
            }
        }
        if let urlError = error as? URLError {
            return urlError.code == .notConnectedToInternet ? "设备当前没有可用网络" : "无法连接云端，请稍后再试"
        }
        return "读取家庭资料失败，请稍后再试"
    }
}

private struct SetupFeature: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.appGreenDark)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
