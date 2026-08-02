import Foundation
#if canImport(Supabase)
import Supabase
#endif

/// Supabase 数据访问层（同步模式专用）。
/// 直接读写云端，不做离线合并 —— 见 SETUP.md「已知限制」。
///
/// 表结构（与网页版共用）：
///   cats(id, family_id, name, breed, birthday)
///   weights(id, family_id, cat_id, date, kg, note)
///   temps(id, family_id, cat_id, date, celsius, note)
///   med_plans(id, family_id, cat_id, drug, dose, remind_times text[], start_date, end_date, active, note)
///   med_logs(id, family_id, plan_id, cat_id, date, scheduled_time, status, taken_at, note)
///
/// 注意：未配置 Supabase 时本类不会被调用；
/// 同时用 #if canImport 包裹，万一 SPM 依赖未添加也能编过（同步功能不可用）。
enum SupabaseServiceError: LocalizedError {
    case sdkNotLinked
    case network(String)

    var errorDescription: String? {
        switch self {
        case .sdkNotLinked: return "未添加 supabase-swift 依赖，请按 SETUP.md 用 SPM 添加"
        case .network(let msg): return msg
        }
    }
}

#if canImport(Supabase)
final class SupabaseService {
    static let shared = SupabaseService()

    private let client: SupabaseClient?

    private init() {
        if Config.isSupabaseConfigured, let url = URL(string: Config.supabaseURL) {
            client = SupabaseClient(supabaseURL: url, supabaseKey: Config.supabaseAnonKey)
        } else {
            client = nil
        }
    }

    private func requireClient() throws -> SupabaseClient {
        guard let client else { throw SupabaseServiceError.sdkNotLinked }
        return client
    }

    // MARK: - 拉取整个家庭的全部数据

    struct FamilySnapshot {
        var cats: [Cat]
        var weights: [WeightRecord]
        var temps: [TempRecord]
        var plans: [MedPlan]
        var logs: [MedLog]
    }

    func fetchAll(familyId: UUID) async throws -> FamilySnapshot {
        let c = try requireClient()
        let fid = familyId.uuidString

        async let catsReq: [Cat] = c.from("cats").select().eq("family_id", value: fid).order("name").execute().value
        async let weightsReq: [WeightRecord] = c.from("weights").select().eq("family_id", value: fid).order("date", ascending: false).execute().value
        async let tempsReq: [TempRecord] = c.from("temps").select().eq("family_id", value: fid).order("date", ascending: false).execute().value
        async let plansReq: [MedPlan] = c.from("med_plans").select().eq("family_id", value: fid).execute().value
        async let logsReq: [MedLog] = c.from("med_logs").select().eq("family_id", value: fid).order("date", ascending: false).execute().value

        return try await FamilySnapshot(cats: catsReq, weights: weightsReq, temps: tempsReq, plans: plansReq, logs: logsReq)
    }

    /// 判断某个家庭码在云端是否已有数据（加入家庭前校验用）
    func familyExists(familyId: UUID) async throws -> Bool {
        let c = try requireClient()
        let cats: [Cat] = try await c.from("cats").select().eq("family_id", value: familyId.uuidString).limit(1).execute().value
        return !cats.isEmpty
    }

    // MARK: - 猫

    func upsertCat(_ cat: Cat) async throws {
        let c = try requireClient()
        try await c.from("cats").upsert(cat).execute()
    }

    func deleteCat(id: UUID) async throws {
        let c = try requireClient()
        try await c.from("cats").delete().eq("id", value: id.uuidString).execute()
    }

    // MARK: - 体重

    func insertWeight(_ r: WeightRecord) async throws {
        let c = try requireClient()
        try await c.from("weights").insert(r).execute()
    }

    func deleteWeight(id: UUID) async throws {
        let c = try requireClient()
        try await c.from("weights").delete().eq("id", value: id.uuidString).execute()
    }

    // MARK: - 体温

    func insertTemp(_ r: TempRecord) async throws {
        let c = try requireClient()
        try await c.from("temps").insert(r).execute()
    }

    func deleteTemp(id: UUID) async throws {
        let c = try requireClient()
        try await c.from("temps").delete().eq("id", value: id.uuidString).execute()
    }

    // MARK: - 用药计划

    func upsertPlan(_ p: MedPlan) async throws {
        let c = try requireClient()
        try await c.from("med_plans").upsert(p).execute()
    }

    func deletePlan(id: UUID) async throws {
        let c = try requireClient()
        try await c.from("med_plans").delete().eq("id", value: id.uuidString).execute()
    }

    // MARK: - 用药记录

    func insertLog(_ l: MedLog) async throws {
        let c = try requireClient()
        try await c.from("med_logs").insert(l).execute()
    }

    // MARK: - 创建家庭：把本地数据整体上传到云端

    func uploadLocalData(cats: [Cat], weights: [WeightRecord], temps: [TempRecord],
                         plans: [MedPlan], logs: [MedLog]) async throws {
        let c = try requireClient()
        if !cats.isEmpty { try await c.from("cats").upsert(cats).execute() }
        if !plans.isEmpty { try await c.from("med_plans").upsert(plans).execute() }
        if !weights.isEmpty { try await c.from("weights").upsert(weights).execute() }
        if !temps.isEmpty { try await c.from("temps").upsert(temps).execute() }
        if !logs.isEmpty { try await c.from("med_logs").upsert(logs).execute() }
    }
}
#else
/// 未添加 supabase-swift 依赖时的占位实现，保证工程可编译（仅本地模式可用）
final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    struct FamilySnapshot {
        var cats: [Cat] = []
        var weights: [WeightRecord] = []
        var temps: [TempRecord] = []
        var plans: [MedPlan] = []
        var logs: [MedLog] = []
    }

    private func unavailable() -> SupabaseServiceError { .sdkNotLinked }

    func fetchAll(familyId: UUID) async throws -> FamilySnapshot { throw unavailable() }
    func familyExists(familyId: UUID) async throws -> Bool { throw unavailable() }
    func upsertCat(_ cat: Cat) async throws { throw unavailable() }
    func deleteCat(id: UUID) async throws { throw unavailable() }
    func insertWeight(_ r: WeightRecord) async throws { throw unavailable() }
    func deleteWeight(id: UUID) async throws { throw unavailable() }
    func insertTemp(_ r: TempRecord) async throws { throw unavailable() }
    func deleteTemp(id: UUID) async throws { throw unavailable() }
    func upsertPlan(_ p: MedPlan) async throws { throw unavailable() }
    func deletePlan(id: UUID) async throws { throw unavailable() }
    func insertLog(_ l: MedLog) async throws { throw unavailable() }
    func uploadLocalData(cats: [Cat], weights: [WeightRecord], temps: [TempRecord],
                         plans: [MedPlan], logs: [MedLog]) async throws { throw unavailable() }
}
#endif
