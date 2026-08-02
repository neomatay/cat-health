import Foundation
import SwiftData

/// 数据中心：页面只跟 DataStore 打交道，底层按模式走 SwiftData（本地）或 Supabase（同步）。
///
/// - 本地模式：未配置 Supabase 或未设置家庭码。数据全在本机 SwiftData。
/// - 同步模式：直接读写 Supabase（不做离线合并），家庭码存 UserDefaults。
/// - 两种模式互切时本地数据保留；创建家庭会把本地数据带新 family_id 上传到云端。
@MainActor
final class DataStore: ObservableObject {

    enum Mode: String {
        case local = "本地模式"
        case synced = "同步模式"
    }

    // MARK: - 发布的全局状态

    @Published private(set) var mode: Mode = .local
    @Published var cats: [Cat] = []
    @Published var weights: [WeightRecord] = []
    @Published var temps: [TempRecord] = []
    @Published var plans: [MedPlan] = []
    @Published var logs: [MedLog] = []
    @Published var isLoading = false
    @Published var lastError: String?

    /// 当前选中的猫（持久化到 UserDefaults）
    @Published var selectedCatId: UUID? {
        didSet {
            UserDefaults.standard.set(selectedCatId?.uuidString, forKey: Self.selectedCatKey)
        }
    }
    private static let selectedCatKey = "cat_health_selected_cat"

    /// 本地模式使用的稳定 familyId（首次启动生成；创建家庭上传时整体替换）
    private(set) var localFamilyId: UUID
    private static let localFamilyKey = "cat_health_local_family_id"

    private var modelContext: ModelContext?

    var currentFamilyId: UUID {
        Config.familyId ?? localFamilyId
    }

    // MARK: - 初始化

    init() {
        if let str = UserDefaults.standard.string(forKey: Self.localFamilyKey),
           let id = UUID(uuidString: str) {
            localFamilyId = id
        } else {
            let id = UUID()
            localFamilyId = id
            UserDefaults.standard.set(id.uuidString, forKey: Self.localFamilyKey)
        }
        if let str = UserDefaults.standard.string(forKey: Self.selectedCatKey) {
            selectedCatId = UUID(uuidString: str)
        }

        // 通知按钮「已喂/跳过」→ 写 med_logs
        NotificationManager.shared.logHandler = { [weak self] planId, catId, time, status in
            Task { @MainActor in
                self?.recordDose(planId: planId, catId: catId, scheduledTime: time, status: status)
            }
        }
    }

    /// 由 RootView 在 onAppear 时注入 SwiftData context 并加载数据
    func attach(context: ModelContext) {
        guard modelContext == nil else { return }
        modelContext = context
        Task { await reload() }
    }

    // MARK: - 加载

    func reload() async {
        isLoading = true
        defer { isLoading = false }

        if Config.isSyncMode {
            mode = .synced
            do {
                let snap = try await SupabaseService.shared.fetchAll(familyId: currentFamilyId)
                cats = snap.cats
                weights = snap.weights
                temps = snap.temps
                plans = snap.plans
                logs = snap.logs
                lastError = nil
            } catch {
                lastError = "同步失败：\(error.localizedDescription)"
            }
        } else {
            mode = .local
            loadLocal()
        }

        normalizeSelection()
        rescheduleNotifications()
    }

    private func loadLocal() {
        guard let ctx = modelContext else { return }
        do {
            cats = try ctx.fetch(FetchDescriptor<LocalCat>()).map { $0.toStruct() }
                .sorted { $0.name < $1.name }
            weights = try ctx.fetch(FetchDescriptor<LocalWeight>()).map { $0.toStruct() }
                .sorted { $0.date > $1.date }
            temps = try ctx.fetch(FetchDescriptor<LocalTemp>()).map { $0.toStruct() }
                .sorted { $0.date > $1.date }
            plans = try ctx.fetch(FetchDescriptor<LocalMedPlan>()).map { $0.toStruct() }
            logs = try ctx.fetch(FetchDescriptor<LocalMedLog>()).map { $0.toStruct() }
                .sorted { $0.date > $1.date }
        } catch {
            lastError = "本地读取失败：\(error.localizedDescription)"
        }
    }

    private func normalizeSelection() {
        if let sel = selectedCatId, cats.contains(where: { $0.id == sel }) { return }
        selectedCatId = cats.first?.id
    }

    private func rescheduleNotifications() {
        NotificationManager.shared.rescheduleAll(plans: plans, cats: cats)
    }

    private func saveLocal() {
        guard let ctx = modelContext else { return }
        do { try ctx.save() } catch { lastError = "本地保存失败：\(error.localizedDescription)" }
    }

    // MARK: - 猫

    func saveCat(_ cat: Cat) async {
        if mode == .synced {
            do {
                try await SupabaseService.shared.upsertCat(cat)
                await reload()
            } catch { lastError = "保存猫咪失败：\(error.localizedDescription)" }
        } else if let ctx = modelContext {
            if let existing = try? ctx.fetch(FetchDescriptor<LocalCat>(
                predicate: #Predicate { $0.id == cat.id })).first {
                existing.name = cat.name
                existing.breed = cat.breed
                existing.birthday = cat.birthday
            } else {
                ctx.insert(LocalCat(from: cat))
            }
            saveLocal()
            loadLocal()
            normalizeSelection()
        }
    }

    /// 删除猫，并级联删除其体重/体温/计划/记录
    func deleteCat(_ cat: Cat) async {
        if mode == .synced {
            do {
                for w in weights where w.catId == cat.id { try await SupabaseService.shared.deleteWeight(id: w.id) }
                for t in temps where t.catId == cat.id { try await SupabaseService.shared.deleteTemp(id: t.id) }
                for p in plans where p.catId == cat.id { try await SupabaseService.shared.deletePlan(id: p.id) }
                try await SupabaseService.shared.deleteCat(id: cat.id)
                await reload()
            } catch { lastError = "删除失败：\(error.localizedDescription)" }
        } else if let ctx = modelContext {
            if let c = try? ctx.fetch(FetchDescriptor<LocalCat>(predicate: #Predicate { $0.id == cat.id })).first { ctx.delete(c) }
            if let ws = try? ctx.fetch(FetchDescriptor<LocalWeight>(predicate: #Predicate { $0.catId == cat.id })) { ws.forEach(ctx.delete) }
            if let ts = try? ctx.fetch(FetchDescriptor<LocalTemp>(predicate: #Predicate { $0.catId == cat.id })) { ts.forEach(ctx.delete) }
            if let ps = try? ctx.fetch(FetchDescriptor<LocalMedPlan>(predicate: #Predicate { $0.catId == cat.id })) { ps.forEach(ctx.delete) }
            if let ls = try? ctx.fetch(FetchDescriptor<LocalMedLog>(predicate: #Predicate { $0.catId == cat.id })) { ls.forEach(ctx.delete) }
            saveLocal()
            loadLocal()
            normalizeSelection()
            rescheduleNotifications()
        }
    }

    // MARK: - 体重 / 体温

    func addWeight(catId: UUID, date: Date, kg: Double, note: String?) async {
        let record = WeightRecord(familyId: currentFamilyId, catId: catId, date: date, kg: kg,
                                  note: note?.isEmpty == true ? nil : note)
        if mode == .synced {
            do {
                try await SupabaseService.shared.insertWeight(record)
                await reload()
            } catch { lastError = "保存体重失败：\(error.localizedDescription)" }
        } else if let ctx = modelContext {
            ctx.insert(LocalWeight(from: record))
            saveLocal()
            loadLocal()
        }
    }

    func addTemp(catId: UUID, date: Date, celsius: Double, note: String?) async {
        let record = TempRecord(familyId: currentFamilyId, catId: catId, date: date, celsius: celsius,
                                note: note?.isEmpty == true ? nil : note)
        if mode == .synced {
            do {
                try await SupabaseService.shared.insertTemp(record)
                await reload()
            } catch { lastError = "保存体温失败：\(error.localizedDescription)" }
        } else if let ctx = modelContext {
            ctx.insert(LocalTemp(from: record))
            saveLocal()
            loadLocal()
        }
    }

    // MARK: - 用药计划

    func savePlan(_ plan: MedPlan) async {
        if mode == .synced {
            do {
                try await SupabaseService.shared.upsertPlan(plan)
                await reload()
            } catch { lastError = "保存计划失败：\(error.localizedDescription)" }
        } else if let ctx = modelContext {
            if let existing = try? ctx.fetch(FetchDescriptor<LocalMedPlan>(
                predicate: #Predicate { $0.id == plan.id })).first {
                existing.drug = plan.drug
                existing.dose = plan.dose
                existing.remindTimes = plan.remindTimes
                existing.startDate = plan.startDate
                existing.endDate = plan.endDate
                existing.active = plan.active
                existing.note = plan.note
            } else {
                ctx.insert(LocalMedPlan(from: plan))
            }
            saveLocal()
            loadLocal()
            rescheduleNotifications()
        }
    }

    /// 停用/启用计划
    func setPlanActive(_ plan: MedPlan, active: Bool) async {
        var p = plan
        p.active = active
        await savePlan(p)
    }

    func deletePlan(_ plan: MedPlan) async {
        if mode == .synced {
            do {
                try await SupabaseService.shared.deletePlan(id: plan.id)
                await reload()
            } catch { lastError = "删除计划失败：\(error.localizedDescription)" }
        } else if let ctx = modelContext {
            if let existing = try? ctx.fetch(FetchDescriptor<LocalMedPlan>(
                predicate: #Predicate { $0.id == plan.id })).first {
                ctx.delete(existing)
            }
            saveLocal()
            loadLocal()
            rescheduleNotifications()
        }
    }

    // MARK: - 用药记录

    /// 记录一次喂药结果（今天页面按钮 / 通知 action 共用）
    func recordDose(planId: UUID?, catId: UUID, scheduledTime: String, status: MedLogStatus,
                    date: Date = DateKit.today, note: String? = nil) async {
        let day = Calendar.current.startOfDay(for: date)
        // 防重复：同一计划+同一天+同一时间点已有记录则忽略（通知可能被点两次）
        if let planId, logs.contains(where: {
            $0.planId == planId && $0.date == day && $0.scheduledTime == scheduledTime
        }) { return }

        let log = MedLog(familyId: currentFamilyId, planId: planId, catId: catId, date: day,
                         scheduledTime: scheduledTime, status: status,
                         takenAt: status == .taken ? Date() : nil,
                         note: note?.isEmpty == true ? nil : note)
        if mode == .synced {
            do {
                try await SupabaseService.shared.insertLog(log)
                await reload()
            } catch { lastError = "记录失败：\(error.localizedDescription)" }
        } else if let ctx = modelContext {
            ctx.insert(LocalMedLog(from: log))
            saveLocal()
            loadLocal()
        }
    }

    // MARK: - 家庭同步

    /// 创建家庭：生成新家庭码，把本地全部数据改挂到新 familyId 后上传，进入同步模式
    func createFamily() async -> Bool {
        guard Config.isSupabaseConfigured else {
            lastError = "请先在 Config.swift 中填写 Supabase 配置"
            return false
        }
        isLoading = true
        defer { isLoading = false }

        let newFamily = UUID()
        // 确保本地数据已加载
        if mode == .local { loadLocal() }

        let newCats = cats.map { Cat(id: $0.id, familyId: newFamily, name: $0.name, breed: $0.breed, birthday: $0.birthday) }
        let newWeights = weights.map { WeightRecord(id: $0.id, familyId: newFamily, catId: $0.catId, date: $0.date, kg: $0.kg, note: $0.note) }
        let newTemps = temps.map { TempRecord(id: $0.id, familyId: newFamily, catId: $0.catId, date: $0.date, celsius: $0.celsius, note: $0.note) }
        let newPlans = plans.map { MedPlan(id: $0.id, familyId: newFamily, catId: $0.catId, drug: $0.drug, dose: $0.dose,
                                           remindTimes: $0.remindTimes, startDate: $0.startDate, endDate: $0.endDate,
                                           active: $0.active, note: $0.note) }
        let newLogs = logs.map { MedLog(id: $0.id, familyId: newFamily, planId: $0.planId, catId: $0.catId, date: $0.date,
                                        scheduledTime: $0.scheduledTime, status: $0.status, takenAt: $0.takenAt, note: $0.note) }

        do {
            try await SupabaseService.shared.uploadLocalData(cats: newCats, weights: newWeights,
                                                             temps: newTemps, plans: newPlans, logs: newLogs)
            Config.familyId = newFamily
            await reload()
            return true
        } catch {
            lastError = "创建家庭失败：\(error.localizedDescription)"
            return false
        }
    }

    /// 加入家庭：输入家庭码，拉取云端数据，进入同步模式
    func joinFamily(code: String) async -> Bool {
        guard Config.isSupabaseConfigured else {
            lastError = "请先在 Config.swift 中填写 Supabase 配置"
            return false
        }
        guard let id = UUID(uuidString: code.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            lastError = "家庭码格式不正确（应为 UUID）"
            return false
        }
        isLoading = true
        defer { isLoading = false }

        Config.familyId = id
        await reload()
        if lastError != nil {
            // 拉取失败则回退
            Config.familyId = nil
            await reload()
            return false
        }
        return true
    }

    /// 退出家庭：回到本地模式（本地数据保留）
    func leaveFamily() {
        Config.familyId = nil
        Task { await reload() }
    }

    // MARK: - 导出

    /// 导出全部数据为 JSON 文件，返回临时文件 URL（ShareLink 用）
    func exportJSONFile() -> URL? {
        let bundle = ExportBundle(
            exportedAt: DateKit.timestampString(Date()),
            familyId: currentFamilyId.uuidString,
            cats: cats, weights: weights, temps: temps,
            medPlans: plans, medLogs: logs
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(bundle) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("猫咪健康数据-\(DateKit.day(Date())).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            lastError = "导出失败：\(error.localizedDescription)"
            return nil
        }
    }
}
