import SwiftUI

// ============================================================
// 首页：当天总览（问候 / 照片卡+用药焦点 / 最新指标 / 时间线 / 护理提示）
// ============================================================
struct HomeView: View {
    @EnvironmentObject var store: DataStore
    @State private var showCatMenu = false
    @State private var showReminders = false
    @State private var editingCat: Cat?
    @State private var showAddCat = false
    @State private var quickType: QuickSheetType?

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 6 { return "夜深了" }
        if h < 12 { return "早上好" }
        if h < 18 { return "下午好" }
        return "晚上好"
    }
    private var todayLabel: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if store.cats.isEmpty {
                            emptyState
                        } else {
                            welcomeSection
                            overviewGrid
                            metricsSection
                            timelineSection
                            careTipSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }

                // 猫咪切换下拉
                if showCatMenu {
                    Color.clear.contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { showCatMenu = false }
                    catMenu
                }
            }
            .background(Color.appBg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { catSwitcher }
                ToolbarItem(placement: .topBarTrailing) { bellButton }
            }
            .sheet(isPresented: $showReminders) { RemindersSheet() }
            .sheet(item: $editingCat) { cat in CatSheet(editing: cat) }
            .sheet(isPresented: $showAddCat) { CatSheet(editing: nil) }
            .sheet(item: $quickType) { type in
                if type == .weight { WeightSheet(editing: nil) } else { TempSheet(editing: nil) }
            }
        }
    }

    // ========== 顶栏 ==========
    private var catSwitcher: some View {
        Button { showCatMenu.toggle() } label: {
            HStack(spacing: 8) {
                CatAvatar(avatar: store.currentCat?.avatar, size: 40, radius: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.currentCat?.name ?? "猫咪健康").font(.subheadline.bold())
                    Text("家庭档案").font(.caption2).foregroundStyle(Color.appGray)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.appGray)
            }
        }
    }

    private var bellButton: some View {
        Button { showReminders = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.body)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appLine, lineWidth: 1))
                if store.todayPending > 0 {
                    Circle().fill(Color.appOrange).frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: -6, y: 6)
                }
            }
        }
        .foregroundStyle(Color.primary)
    }

    private var catMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.cats) { cat in
                Button {
                    showCatMenu = false
                    Task { await store.switchCat(cat.id) }
                } label: {
                    HStack(spacing: 9) {
                        CatAvatar(avatar: cat.avatar, size: 28, radius: 10)
                        Text(cat.name).font(.subheadline)
                            .foregroundStyle(cat.id == store.currentCatId ? Color.appGreen : Color.primary)
                            .fontWeight(cat.id == store.currentCatId ? .semibold : .regular)
                        Spacer()
                        Button {
                            showCatMenu = false
                            editingCat = cat
                        } label: {
                            Image(systemName: "pencil").font(.caption).foregroundStyle(Color.appGray)
                                .padding(6)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 9)
                }
            }
            Divider().padding(.vertical, 4)
            Button { showCatMenu = false; showAddCat = true } label: {
                Text("＋ 添加猫咪").font(.subheadline).foregroundStyle(Color.appGray)
                    .padding(.horizontal, 10).padding(.vertical, 8)
            }
        }
        .frame(width: 200)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.leading, 20)
        .padding(.top, 52)
    }

    // ========== 问候 ==========
    private var welcomeSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(todayLabel).font(.subheadline).foregroundStyle(Color.appGray)
                Text(greeting).font(.largeTitle.bold())
            }
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(Color.appOrange.opacity(0.1))
                Image(systemName: "pawprint.fill").font(.title3).foregroundStyle(Color.appOrange)
            }
            .frame(width: 45, height: 45)
        }
        .padding(.top, 14).padding(.bottom, 16)
    }

    private var catInfoText: String {
        guard let cat = store.currentCat else { return "" }
        let age = DateKit.catAge(cat)
        return (cat.breed ?? "小可爱") + (age.isEmpty ? "" : " · \(age)")
    }

    // ========== 双联卡 ==========
    private var overviewGrid: some View {
        HStack(spacing: 12) {
            // 猫咪照片卡
            Button { editingCat = store.currentCat } label: {
                ZStack(alignment: .bottomLeading) {
                    if let avatar = store.currentCat?.avatar,
                       let data = Data(base64Encoded: avatar.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                       let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Color(red: 214/255, green: 228/255, blue: 220/255)
                        Image(systemName: "pawprint.fill").font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日状态").font(.caption2).opacity(0.85)
                        Text(store.currentCat?.name ?? "").font(.title3.bold())
                        Text(catInfoText).font(.caption2).opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                }
                .frame(maxWidth: .infinity, minHeight: 174, maxHeight: 174)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 下一次用药卡（点击跳用药 Tab）
            Button { switchToMeds() } label: { medFocusContent }
        }
    }

    private var medFocusContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color(red: 73/255, green: 123/255, blue: 103/255))
                    Image(systemName: "pills").font(.caption).foregroundStyle(.white)
                }
                .frame(width: 26, height: 26)
                Text("下一次用药").font(.caption).foregroundStyle(Color(red: 196/255, green: 222/255, blue: 210/255))
            }
            if let next = store.nextDose {
                Text(next.time).font(.system(size: 26, weight: .bold)).padding(.top, 10)
                Text("\(next.plan.drug)\(next.plan.dose.map { " · \($0)" } ?? "")")
                    .font(.caption).foregroundStyle(Color(red: 214/255, green: 233/255, blue: 223/255))
                    .padding(.top, 2)
            } else {
                Text(store.doseTotal > 0 ? "今日已完成" : "今日无安排")
                    .font(.system(size: 20, weight: .bold)).padding(.top, 10)
                Text(store.doseTotal > 0 ? "所有药物都已喂完" : "没有待服用的药物")
                    .font(.caption).foregroundStyle(Color(red: 214/255, green: 233/255, blue: 223/255))
                    .padding(.top, 2)
            }
            Spacer()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(red: 79/255, green: 116/255, blue: 100/255))
                    RoundedRectangle(cornerRadius: 3).fill(Color.appGold)
                        .frame(width: geo.size.width * (store.doseTotal > 0 ? CGFloat(store.doseDone) / CGFloat(store.doseTotal) : 0))
                }
            }
            .frame(height: 5)
            Text("\(store.doseDone)/\(store.doseTotal) 剂已记录")
                .font(.caption2).foregroundStyle(Color(red: 196/255, green: 222/255, blue: 210/255))
                .padding(.top, 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 174, maxHeight: 174, alignment: .leading)
        .background(Color.appGreenDark)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func switchToMeds() {
        // 通过通知切换到用药 Tab
        NotificationCenter.default.post(name: .switchToMedsTab, object: nil)
    }

    // ========== 最新指标 ==========
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("最新指标").font(.headline)
                Spacer()
                Button { quickType = .weight } label: {
                    HStack(spacing: 2) {
                        Text("记录数据")
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .font(.subheadline).foregroundStyle(Color.appGreen)
                }
            }
            .padding(.bottom, 10)

            HStack(spacing: 12) {
                Button { quickType = .weight } label: {
                    MetricCard(icon: "scalemass", tint: .appGreen, tintBg: Color(red: 230/255, green: 243/255, blue: 236/255),
                               label: "体重", value: store.latestWeight.map { String(format: "%.2f", $0.kg) } ?? "--",
                               unit: "kg", desc: store.weightDelta, descWarm: false)
                }
                Button { quickType = .temp } label: {
                    MetricCard(icon: "thermometer.medium", tint: .appOrange, tintBg: Color.appOrange.opacity(0.1),
                               label: "体温", value: store.latestTemp.map { String(format: "%.1f", $0.celsius) } ?? "--",
                               unit: "°C", desc: store.tempStatus.text, descWarm: store.tempStatus.warm)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 24)
    }

    // ========== 今日健康安排（时间线） ==========
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("今天的健康安排").font(.headline)
                Spacer()
                Text("\(store.doseTotal) 项").font(.caption).foregroundStyle(Color.appGray)
            }
            .padding(.bottom, 6)

            if store.todayTasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "pawprint").font(.title2).foregroundStyle(Color(red: 182/255, green: 198/255, blue: 188/255))
                    Text("今天没有健康安排").font(.subheadline).foregroundStyle(Color.appGray)
                    Text("新增用药计划后会出现在这里").font(.caption).foregroundStyle(Color.appGray.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.todayTasks) { task in
                        DoseTimelineRow(task: task)
                    }
                }
            }
        }
        .padding(.top, 24)
    }

    private var careTipSection: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "leaf").foregroundStyle(Color(red: 79/255, green: 139/255, blue: 112/255))
            Text(store.careTip).font(.caption).foregroundStyle(Color(red: 82/255, green: 101/255, blue: 93/255))
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 229/255, green: 238/255, blue: 233/255))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.top, 22)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "pawprint").font(.system(size: 44))
                .foregroundStyle(Color(red: 182/255, green: 198/255, blue: 188/255))
            Text("还没有添加猫咪").font(.headline).foregroundStyle(Color.appGray)
            Text("点击下方按钮，为它建立健康档案").font(.caption).foregroundStyle(Color.appGray)
            Button { showAddCat = true } label: {
                Label("添加猫咪", systemImage: "plus")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 24).frame(height: 44)
                    .background(Color.appGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}

// 指标卡
struct MetricCard: View {
    let icon: String
    let tint: Color
    let tintBg: Color
    let label: String
    let value: String
    let unit: String
    let desc: String
    let descWarm: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                IconBadge(systemName: icon, fg: tint, bg: tintBg, size: 32)
                Text(label).font(.subheadline).foregroundStyle(Color.appGray)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 25, weight: .bold)).foregroundStyle(Color(red: 32/255, green: 50/255, blue: 43/255))
                Text(unit).font(.caption).foregroundStyle(Color.appGray)
            }
            .padding(.top, 12)
            Text(desc).font(.caption2)
                .foregroundStyle(descWarm ? Color.appOrange : Color.appGray)
                .padding(.top, 3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// 时间线行
struct DoseTimelineRow: View {
    @EnvironmentObject var store: DataStore
    let task: DoseTask

    var body: some View {
        HStack(spacing: 9) {
            Text(task.time).font(.caption).foregroundStyle(Color.appGray)
                .frame(width: 44, alignment: .leading)
            ZStack {
                Circle().fill(dotColor).frame(width: 29, height: 29)
                    .overlay(Circle().stroke(Color.appBg, lineWidth: 4))
                Image(systemName: "pills").font(.system(size: 11)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.plan.drug).font(.subheadline.weight(.medium))
                Text(subText).font(.caption).foregroundStyle(Color.appGray)
            }
            Spacer()
            if task.status == .pending || task.status == .overdue {
                Button("已喂") { Task { await store.markDose(task, taken: true) } }
                    .font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .foregroundStyle(Color.appGreen)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(red: 75/255, green: 140/255, blue: 112/255), lineWidth: 1))
            } else {
                StatusPill(status: task.status)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    private var dotColor: Color {
        switch task.status {
        case .taken: return Color(red: 216/255, green: 238/255, blue: 226/255)
        case .pending: return Color(red: 255/255, green: 240/255, blue: 214/255)
        case .overdue: return .missBg
        case .skipped: return Color(red: 237/255, green: 240/255, blue: 238/255)
        }
    }
    private var subText: String {
        var s = task.plan.dose ?? "按医嘱"
        if task.status == .taken, let at = task.log?.takenAt {
            s += " · \(DateKit.fmtISO(at)) 已喂"
        }
        return s
    }
}

// 猫咪头像（base64 → 圆形/圆角图）
struct CatAvatar: View {
    let avatar: String?
    var size: CGFloat = 40
    var radius: CGFloat = 14

    var body: some View {
        ZStack {
            if let avatar = avatar,
               let data = Data(base64Encoded: avatar.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
               let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color(red: 216/255, green: 233/255, blue: 224/255)
                Text("🐱").font(.system(size: size * 0.5))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

extension Notification.Name {
    static let switchToMedsTab = Notification.Name("switchToMedsTab")
}
