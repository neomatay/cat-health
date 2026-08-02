import SwiftUI

// ============================================================
// 用药页：进度 hero / 今日剂次 / 长期计划 / 历史计划（折叠）
// ============================================================
struct MedsView: View {
    @EnvironmentObject var store: DataStore
    @State private var showAddPlan = false
    @State private var editingPlan: MedPlan?
    @State private var showHistory = false
    @State private var planToDelete: MedPlan?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.cats.isEmpty {
                    emptyHint
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        heading
                        hero
                        todaySection
                        ongoingSection
                        historySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .background(Color.appBg)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showAddPlan) { PlanSheet(editing: nil) }
        .sheet(item: $editingPlan) { p in PlanSheet(editing: p) }
        .confirmationDialog("删除计划", isPresented: $showDeleteConfirm, presenting: planToDelete) { plan in
            Button("删除「\(plan.drug)」", role: .destructive) {
                Task { await store.deletePlan(plan) }
            }
            Button("取消", role: .cancel) {}
        } message: { _ in
            Text("该计划及其打卡记录将一并删除，不可恢复。")
        }
    }

    private var heading: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("用药管理").font(.subheadline).foregroundStyle(Color.appGray)
                Text("每一剂都有记录").font(.largeTitle.bold())
            }
            Spacer()
            Button { showAddPlan = true } label: {
                Image(systemName: "plus")
                    .font(.body)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appLine, lineWidth: 1))
            }
            .foregroundStyle(Color.primary)
        }
        .padding(.top, 18).padding(.bottom, 16)
    }

    // 今日进度 hero
    private var hero: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日进度").font(.caption).foregroundStyle(Color(red: 200/255, green: 226/255, blue: 214/255))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(store.doseDone)").font(.system(size: 31, weight: .bold))
                    Text("/ \(store.doseTotal)").font(.subheadline).foregroundStyle(Color(red: 200/255, green: 226/255, blue: 214/255))
                }
                Text("剂次已完成").font(.caption).foregroundStyle(Color(red: 200/255, green: 226/255, blue: 214/255))
            }
            Spacer()
            // 环形进度
            ZStack {
                Circle().stroke(Color.white.opacity(0.22), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: store.doseTotal > 0 ? CGFloat(store.doseDone) / CGFloat(store.doseTotal) : 0)
                    .stroke(Color.appGold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "pills").foregroundStyle(Color.appGold)
            }
            .frame(width: 60, height: 60)
        }
        .foregroundStyle(.white)
        .padding(19)
        .background(Color.appGreenDeep)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // 今天
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("今天").font(.headline)
                Spacer()
                Text(DateKit.fmtMD(DateKit.today())).font(.caption).foregroundStyle(Color.appGray)
            }
            .padding(.bottom, 10)

            if store.todayTasks.isEmpty {
                Text("今天没有用药安排")
                    .font(.subheadline).foregroundStyle(Color.appGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.todayTasks) { task in
                        DoseCard(task: task)
                    }
                }
            }
        }
        .padding(.top, 22)
    }

    // 长期计划（进行中）
    private var ongoingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("长期用药计划").font(.headline)
                Spacer()
                Button { showAddPlan = true } label: {
                    HStack(spacing: 3) {
                        Text("新增"); Image(systemName: "plus").font(.caption2)
                    }
                    .font(.subheadline).foregroundStyle(Color.appGreen)
                }
            }
            .padding(.bottom, 6)

            if store.ongoingPlans.isEmpty {
                Text("还没有用药计划，点右上角 + 新增")
                    .font(.subheadline).foregroundStyle(Color.appGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.ongoingPlans) { item in
                        PlanRow(item: item, onEdit: { editingPlan = $0 }, onStop: { plan in
                            Task { await store.stopPlan(plan) }
                        }, onDelete: nil)
                    }
                }
            }
        }
        .padding(.top, 24)
    }

    // 历史计划（折叠）
    @ViewBuilder
    private var historySection: some View {
        if !store.historyPlans.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button { withAnimation { showHistory.toggle() } } label: {
                    HStack {
                        Text("历史用药计划").font(.headline).foregroundStyle(Color.primary)
                        Text("\(store.historyPlans.count)").font(.caption).foregroundStyle(Color.appGray)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(Color.appGray)
                            .rotationEffect(.degrees(showHistory ? 90 : 0))
                    }
                }
                .padding(.bottom, 6)

                if showHistory {
                    VStack(spacing: 0) {
                        ForEach(store.historyPlans) { item in
                            PlanRow(item: item, onEdit: { editingPlan = $0 }, onStop: nil, onDelete: {
                                planToDelete = $0
                                showDeleteConfirm = true
                            })
                            .opacity(0.6)
                        }
                    }
                }
            }
            .padding(.top, 24)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "pawprint").font(.system(size: 40))
                .foregroundStyle(Color(red: 182/255, green: 198/255, blue: 188/255))
            Text("添加猫咪后管理用药").font(.subheadline).foregroundStyle(Color.appGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}

// 今日剂次卡
struct DoseCard: View {
    @EnvironmentObject var store: DataStore
    let task: DoseTask

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(task.time).font(.subheadline.bold())
                    .foregroundStyle(Color(red: 45/255, green: 89/255, blue: 73/255))
                    .frame(width: 46, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.plan.drug).font(.subheadline.weight(.medium))
                    Text(subText).font(.caption).foregroundStyle(Color.appGray)
                }
                Spacer()
                StatusPill(status: task.status)
            }
            if task.status == .pending || task.status == .overdue {
                HStack(spacing: 9) {
                    Button { Task { await store.markDose(task, taken: false) } } label: {
                        Text("标记漏服")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity).frame(height: 41)
                            .foregroundStyle(Color(red: 88/255, green: 112/255, blue: 103/255))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(red: 215/255, green: 227/255, blue: 220/255), lineWidth: 1))
                    }
                    Button { Task { await store.markDose(task, taken: true) } } label: {
                        Label("记录已喂", systemImage: "checkmark")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity).frame(height: 41)
                            .foregroundStyle(.white)
                            .background(Color.appGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }
                .padding(.top, 13)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var subText: String {
        var s = task.plan.dose ?? "按医嘱"
        if task.status == .taken, let at = task.log?.takenAt {
            s += " · \(DateKit.fmtISO(at)) 已喂"
        }
        return s
    }
}

// 计划行
struct PlanRow: View {
    let item: DataStore.PlanItem
    let onEdit: (MedPlan) -> Void
    var onStop: ((MedPlan) -> Void)? = nil
    var onDelete: ((MedPlan) -> Void)? = nil

    var body: some View {
        HStack(spacing: 11) {
            IconBadge(systemName: "pills", size: 35)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.plan.drug).font(.subheadline.weight(.medium))
                Text(detailText).font(.caption).foregroundStyle(Color.appGray)
                Text("\(item.plan.startDate) ~ \(item.plan.endDate ?? "长期") · 完药率 \(item.rate)%")
                    .font(.caption2).foregroundStyle(Color.appGray.opacity(0.8))
            }
            Spacer()
            HStack(spacing: 6) {
                iconBtn("pencil") { onEdit(item.plan) }
                if let onStop = onStop {
                    iconBtn("pause") { onStop(item.plan) }
                }
                if let onDelete = onDelete {
                    iconBtn("xmark", danger: true) { onDelete(item.plan) }
                }
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }

    private var detailText: String {
        var s = ""
        if let dose = item.plan.dose, !dose.isEmpty { s += dose + " · " }
        s += DateKit.freqText(item.plan) + " · 用药 " + item.plan.remindTimes.joined(separator: "、")
        if let before = item.plan.remindBefore, before > 0 { s += " · 提前\(before)分钟提醒" }
        return s
    }

    private func iconBtn(_ name: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.caption)
                .foregroundStyle(danger ? Color.missText : Color(red: 64/255, green: 81/255, blue: 74/255))
                .frame(width: 34, height: 34)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appLine, lineWidth: 1))
        }
    }
}
