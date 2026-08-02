import SwiftUI

/// Tab 1「今天」：多猫切换、今日用药任务、快速记体重/体温、最近记录
struct TodayView: View {
    @EnvironmentObject private var store: DataStore

    @State private var showWeightSheet = false
    @State private var showTempSheet = false
    @State private var showAddCat = false

    /// 当前选中的猫
    private var currentCat: Cat? {
        store.cats.first { $0.id == store.selectedCatId }
    }

    /// 今日用药任务（计划 × 提醒时间），合并 med_logs 状态
    private var todayTasks: [TodayTask] {
        guard let cat = currentCat else { return [] }
        let today = DateKit.today
        let now = Date()
        var tasks: [TodayTask] = []

        for plan in store.plans where plan.catId == cat.id && plan.active && plan.covers(day: today) {
            for time in plan.remindTimes.sorted() {
                let log = store.logs.first {
                    $0.planId == plan.id && $0.date == today && $0.scheduledTime == time
                }
                let status: MedLogStatus
                let takenAt: Date?
                if let log {
                    status = log.status
                    takenAt = log.takenAt
                } else if let scheduled = DateKit.dateOn(day: today, time: time),
                          now > scheduled.addingTimeInterval(30 * 60) {
                    status = .missed   // 超过计划时间 30 分钟标红
                    takenAt = nil
                } else {
                    status = .pending
                    takenAt = nil
                }
                tasks.append(TodayTask(plan: plan, time: time, status: status, takenAt: takenAt))
            }
        }
        return tasks.sorted { $0.time < $1.time }
    }

    /// 最近记录（体重+体温合并，最多 10 条）
    private var recentRecords: [RecentItem] {
        guard let cat = currentCat else { return [] }
        var items: [RecentItem] = []
        for w in store.weights where w.catId == cat.id {
            items.append(RecentItem(date: w.date,
                                    title: String(format: "体重 %.2f kg", w.kg),
                                    note: w.note, systemImage: "scalemass", isAbnormal: false))
        }
        for t in store.temps where t.catId == cat.id {
            items.append(RecentItem(date: t.date,
                                    title: String(format: "体温 %.1f ℃", t.celsius),
                                    note: t.note, systemImage: "thermometer.medium",
                                    isAbnormal: t.isAbnormal))
        }
        return items.sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.cats.isEmpty {
                    // 空态：引导先添加猫咪
                    VStack(spacing: 20) {
                        EmptyStateView(systemImage: "cat.fill",
                                       title: "还没有猫咪档案",
                                       message: "先添加一只猫咪，开始记录它的健康数据吧")
                        Button {
                            showAddCat = true
                        } label: {
                            Label("添加猫咪", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            CatSwitcher()
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }

                        // 今日用药任务
                        Section {
                            if todayTasks.isEmpty {
                                Text("今天没有用药任务")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            } else {
                                ForEach(todayTasks) { task in
                                    TaskCard(task: task)
                                }
                            }
                        } header: {
                            Text("今日用药")
                        }

                        // 快速记录
                        Section {
                            HStack(spacing: 12) {
                                Button { showWeightSheet = true } label: {
                                    Label("记体重", systemImage: "scalemass.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button { showTempSheet = true } label: {
                                    Label("记体温", systemImage: "thermometer.medium")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            .listRowBackground(Color.clear)
                        }

                        // 最近记录
                        Section {
                            if recentRecords.isEmpty {
                                Text("还没有记录，点上面按钮记一条吧")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            } else {
                                ForEach(recentRecords) { item in
                                    HStack(spacing: 12) {
                                        Image(systemName: item.systemImage)
                                            .foregroundStyle(item.isAbnormal ? .red : .orange)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(item.isAbnormal ? .red : .primary)
                                            if let note = item.note, !note.isEmpty {
                                                Text(note)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(DisplayFormat.day(item.date))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Text("最近记录")
                        }
                    }
                }
            }
            .navigationTitle("今天")
            .toolbar {
                if store.isLoading {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                    }
                }
            }
            .sheet(isPresented: $showAddCat) {
                CatEditSheet(cat: nil)
            }
            .sheet(isPresented: $showWeightSheet) {
                if let cat = currentCat {
                    QuickRecordSheet(kind: .weight, cat: cat)
                }
            }
            .sheet(isPresented: $showTempSheet) {
                if let cat = currentCat {
                    QuickRecordSheet(kind: .temp, cat: cat)
                }
            }
        }
    }
}

// MARK: - 今日任务模型

struct TodayTask: Identifiable {
    let plan: MedPlan
    let time: String
    var status: MedLogStatus
    var takenAt: Date?

    var id: String { "\(plan.id.uuidString)-\(time)" }
}

// MARK: - 任务卡片

private struct TaskCard: View {
    @EnvironmentObject private var store: DataStore
    let task: TodayTask

    private var statusColor: Color {
        switch task.status {
        case .taken: return .green
        case .missed: return .red
        case .skipped: return .secondary
        case .pending: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.plan.drug)
                        .font(.headline)
                    Text("剂量：\(task.plan.dose) · 计划 \(task.time)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // 状态徽标
                HStack(spacing: 4) {
                    if task.status == .taken, let takenAt = task.takenAt {
                        Text("已喂 ✓ \(DisplayFormat.time(takenAt))")
                    } else {
                        Text(task.status == .missed ? "已错过" : task.status.label)
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
            }

            // 待喂/错过时可操作
            if task.status == .pending || task.status == .missed {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await store.recordDose(planId: task.plan.id, catId: task.plan.catId,
                                                   scheduledTime: task.time, status: .taken)
                        }
                    } label: {
                        Label("喂了", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        Task {
                            await store.recordDose(planId: task.plan.id, catId: task.plan.catId,
                                                   scheduledTime: task.time, status: .skipped)
                        }
                    } label: {
                        Label("跳过", systemImage: "forward.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 最近记录条目

struct RecentItem: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let note: String?
    let systemImage: String
    let isAbnormal: Bool
}

// MARK: - 快速记录 Sheet（体重/体温）

struct QuickRecordSheet: View {
    enum Kind {
        case weight, temp

        var title: String { self == .weight ? "记体重" : "记体温" }
        var unit: String { self == .weight ? "kg" : "℃" }
        var placeholder: String { self == .weight ? "如 4.35" : "如 38.5" }
        var rangeText: String { self == .weight ? "范围 0.1 - 20 kg" : "范围 35 - 42 ℃" }
    }

    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let kind: Kind
    let cat: Cat

    @State private var valueText = ""
    @State private var date = Date()
    @State private var note = ""
    @FocusState private var valueFocused: Bool

    private var parsedValue: Double? {
        kind == .weight ? InputParser.weight(valueText) : InputParser.temperature(valueText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(kind.placeholder, text: $valueText)
                            .keyboardType(.decimalPad)
                            .focused($valueFocused)
                            .font(.title3)
                        Text(kind.unit)
                            .foregroundStyle(.secondary)
                    }
                    if !valueText.isEmpty && parsedValue == nil {
                        Text("数值无效（\(kind.rangeText)）")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("\(cat.name) 的\(kind == .weight ? "体重" : "体温")")
                } footer: {
                    Text(kind.rangeText)
                }

                Section {
                    DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date)
                    TextField("备注（可选）", text: $note)
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(parsedValue == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { valueFocused = false }
                }
            }
            .onAppear { valueFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let value = parsedValue else { return }
        Task {
            if kind == .weight {
                await store.addWeight(catId: cat.id, date: date, kg: value, note: note)
            } else {
                await store.addTemp(catId: cat.id, date: date, celsius: value, note: note)
            }
            dismiss()
        }
    }
}
