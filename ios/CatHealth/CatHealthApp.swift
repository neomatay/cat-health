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
                FamilySetupView(onDone: { fid in familyId = fid })
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
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "pawprint.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.appGreen)
            Text("猫咪健康").font(.largeTitle.bold())
            Text("创建家庭开始记录，或输入家人分享的家庭码加入")
                .font(.subheadline).foregroundStyle(Color.appGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Button {
                    let fid = Config.ensureFamilyId()
                    onDone(fid)
                } label: {
                    Text("创建家庭")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(Color.appGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                HStack {
                    TextField("粘贴家庭码加入", text: $code)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .padding(11)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.appLine, lineWidth: 1))
                    Button("加入") { join() }
                        .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                }
                if !joinError.isEmpty {
                    Text(joinError).font(.caption).foregroundStyle(Color.missText)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .background(Color.appBg.ignoresSafeArea())
    }

    private func join() {
        let fid = code.trimmingCharacters(in: .whitespaces)
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
                await MainActor.run { onDone(fid) }
            } catch {
                await MainActor.run { joinError = "加入失败，请检查家庭码和网络"; busy = false }
            }
        }
    }
}
