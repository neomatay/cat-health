import SwiftUI

/// Tab 3「用药」：计划列表 + 新增/编辑计划
struct MedsView: View {
    @EnvironmentObject private var store: DataStore

    @State private var showEditor = false
    @State private var editingPlan: MedPlan?
    @State private var planPendingDelete: MedPlan?
    @State private var showDeleteConfirm = false

    private var currentCat: Cat? {
        store.cats.first { $0.id == store.selectedCatId }
    }

    /// 当前猫的计划（生效中在前，按开始日期倒序）
    private var plans: [MedPlan] {
        guard let cat = currentCat else { return [] }
        return store.plans
            .filter { $0.catId == cat.id }
            .sorted { a, b in
                if a.active != b.active { return a.active && !b.active }
                return a.startDate > b.startDate
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.cats.isEmpty {
                    EmptyStateView(systemImage: "pills",
                                   title: "还没有猫咪档案",
                                   message: "先在「我的」里添加猫咪，再来配置用药计划")
                } else {
                    VStack(spacing: 0) {
                        CatSwitcher()

                        if plans.isEmpty {
                            Spacer()
                            EmptyStateView(systemImage: "pills",
                                           title: "还没有用药计划",
                                           message: "点右上角「+」新建计划，App 会按提醒时间推送本地通知")
                            Spacer()
                        } else {
                            List {
                                ForEach(plans) { plan in
                                    PlanRow(plan: plan,
                                            completion: completionRate(for: plan))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            editingPlan = plan
                                            showEditor = true
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                planPendingDelete = plan
                                                showDeleteConfirm = true
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                            Button {
                                                Task { await store.setPlanActive(plan, active: !plan.active) }
                                            } label: {
                                                Label(plan.active ? "停用" : "启用",
                                                      systemImage: plan.active ? "pause.circle" : "play.circle")
                                            }
                                            .tint(.orange)
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("用药")
            .toolbar {
                if currentCat != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            editingPlan = nil
                            showEditor = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                if let cat = currentCat {
                    PlanEditSheet(cat: cat, plan: editingPlan)
                }
            }
            .confirmationDialog("确定删除该计划？",
                                isPresented: $showDeleteConfirm,
                                titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let plan = planPendingDelete {
                        Task { await store.deletePlan(plan) }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("历史喂药记录会保留，仅删除计划本身。")
            }
        }
    }

    /// 完药率 = 已喂 / (已喂 + 跳过)
    private func completionRate(for plan: MedPlan) -> (taken: Int, total: Int)? {
        let planLogs = store.logs.filter { $0.planId == plan.id && ($0.status == .taken || $0.status == .skipped) }
        guard !planLogs.isEmpty else { return nil }
        let taken = planLogs.filter { $0.status == .taken }.count
        return (taken, planLogs.count)
    }
}

// MARK: - 计划行

private struct PlanRow: View {
    let plan: MedPlan
    let completion: (taken: Int, total: Int)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.drug)
                    .font(.headline)
                    .foregroundStyle(plan.active ? .primary : .secondary)
                if !plan.active {
                    Text("已停用")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
                Spacer()
                if let completion {
                    let rate = Double(completion.taken) / Double(max(completion.total, 1))
                    Text(String(format: "完药率 %.0f%%", rate * 100))
                        .font(.caption)
                        .foregroundStyle(rate >= 0.8 ? .green : .orange)
                }
            }

            Text("剂量：\(plan.dose)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.caption2)
                Text(plan.remindTimes.sorted().joined(separator: " / "))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption2)
                if let end = plan.endDate {
                    Text("\(DisplayFormat.full(plan.startDate)) 至 \(DisplayFormat.full(end))")
                } else {
                    Text("\(DisplayFormat.full(plan.startDate)) 起 · 长期")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let note = plan.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 新增/编辑计划 Sheet

struct PlanEditSheet: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let cat: Cat
    let plan: MedPlan?   // nil = 新建

    @State private var drug = ""
    @State private var dose = ""
    @State private var timesPerDay = 1
    @State private var timeDates: [Date] = []
    @State private var startDate = Date()
    @State private var isLongTerm = true
    @State private var endDate = Date()
    @State private var note = ""

    private var isValid: Bool {
        !drug.trimmingCharacters(in: .whitespaces).isEmpty
            && !dose.trimmingCharacters(in: .whitespaces).isEmpty
            && (isLongTerm || endDate >= Calendar.current.startOfDay(for: startDate))
    }

    init(cat: Cat, plan: MedPlan?) {
        self.cat = cat
        self.plan = plan
        // 编辑时回填
        if let plan {
            _drug = State(initialValue: plan.drug)
            _dose = State(initialValue: plan.dose)
            let times = plan.remindTimes.sorted()
            _timesPerDay = State(initialValue: max(times.count, 1))
            _timeDates = State(initialValue: times.compactMap { DateKit.dateOn(day: Date(), time: $0) })
            _startDate = State(initialValue: plan.startDate)
            _isLongTerm = State(initialValue: plan.endDate == nil)
            _endDate = State(initialValue: plan.endDate ?? Date())
            _note = State(initialValue: plan.note ?? "")
        } else {
            // 新建默认 08:00
            _timeDates = State(initialValue: [DateKit.dateOn(day: Date(), time: "08:00") ?? Date()])
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("药品信息") {
                    TextField("药品名称，如 速诺", text: $drug)
                    TextField("剂量，如 50mg（1片）", text: $dose)
                }

                Section {
                    Stepper("每天 \(timesPerDay) 次", value: $timesPerDay, in: 1...4)
                        .onChange(of: timesPerDay) { _, _ in syncTimeSlots() }
                    ForEach(0..<timesPerDay, id: \.self) { i in
                        if i < timeDates.count {
                            DatePicker("第\(i + 1)次", selection: $timeDates[i],
                                       displayedComponents: .hourAndMinute)
                        }
                    }
                } header: {
                    Text("提醒时间")
                } footer: {
                    Text("到点会推送本地通知，可直接在通知上点「已喂 / 跳过」")
                }

                Section("用药周期") {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    Toggle("长期用药", isOn: $isLongTerm)
                    if !isLongTerm {
                        DatePicker("结束日期", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section("备注") {
                    TextField("可选，如 随餐服用", text: $note)
                }
            }
            .navigationTitle(plan == nil ? "新建计划" : "编辑计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    /// 次数变化时补齐/裁剪时间槽
    private func syncTimeSlots() {
        let defaults = ["08:00", "14:00", "20:00", "23:00"]
        while timeDates.count < timesPerDay {
            let t = defaults[min(timeDates.count, defaults.count - 1)]
            timeDates.append(DateKit.dateOn(day: Date(), time: t) ?? Date())
        }
        if timeDates.count > timesPerDay {
            timeDates = Array(timeDates.prefix(timesPerDay))
        }
    }

    private func save() {
        let times = timeDates.prefix(timesPerDay).map(DateKit.timeString)
        let newPlan = MedPlan(
            id: plan?.id ?? UUID(),
            familyId: store.currentFamilyId,
            catId: cat.id,
            drug: drug.trimmingCharacters(in: .whitespaces),
            dose: dose.trimmingCharacters(in: .whitespaces),
            remindTimes: times,
            startDate: startDate,
            endDate: isLongTerm ? nil : endDate,
            active: plan?.active ?? true,
            note: note.isEmpty ? nil : note
        )
        Task {
            await store.savePlan(newPlan)
            dismiss()
        }
    }
}
