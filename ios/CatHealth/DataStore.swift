import Foundation
import SwiftUI

// 今日用药任务（计划 × 时间点）
struct DoseTask: Identifiable {
    var id: String { "\(plan.id)-\(time)" }
    let plan: MedPlan
    let time: String
    var status: DoseStatus
    var log: MedLog?
}

@MainActor
class DataStore: ObservableObject {
    @Published var cats: [Cat] = []
    @Published var weights: [WeightRecord] = []
    @Published var temps: [TempRecord] = []
    @Published var plans: [MedPlan] = []
    @Published var logs: [MedLog] = []
    @Published var currentCatId: String?
    @Published var toast = ""
    @Published var loading = false

    var currentCat: Cat? { cats.first { $0.id == currentCatId } }

    func showToast(_ msg: String) {
        toast = msg
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if toast == msg { toast = "" }
        }
    }

    // ========== 加载 ==========
    func loadCats() async {
        guard let fid = Config.familyId else { return }
        do {
            cats = try await Supa.list(Cat.self, table: "cats", query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "family_id", value: "eq.\(fid)"),
                URLQueryItem(name: "order", value: "created_at.asc")
            ])
            if currentCatId == nil || !cats.contains(where: { $0.id == currentCatId }) {
                currentCatId = cats.first?.id
            }
            if let cid = currentCatId { await loadCatData(cid) }
        } catch {
            print("loadCats: \(error.localizedDescription)")
            showToast("加载失败，请检查网络")
        }
    }

    func loadCatData(_ catId: String) async {
        guard let fid = Config.familyId else { return }
        do {
            async let w = Supa.list(WeightRecord.self, table: "weights", query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "family_id", value: "eq.\(fid)"),
                URLQueryItem(name: "cat_id", value: "eq.\(catId)"),
                URLQueryItem(name: "order", value: "date.asc")
            ])
            async let t = Supa.list(TempRecord.self, table: "temps", query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "family_id", value: "eq.\(fid)"),
                URLQueryItem(name: "cat_id", value: "eq.\(catId)"),
                URLQueryItem(name: "order", value: "date.asc")
            ])
            async let p = Supa.list(MedPlan.self, table: "med_plans", query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "family_id", value: "eq.\(fid)"),
                URLQueryItem(name: "cat_id", value: "eq.\(catId)"),
                URLQueryItem(name: "order", value: "created_at.asc")
            ])
            async let l = Supa.list(MedLog.self, table: "med_logs", query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "family_id", value: "eq.\(fid)"),
                URLQueryItem(name: "cat_id", value: "eq.\(catId)")
            ])
            let (ww, tt, pp, ll) = try await (w, t, p, l)
            weights = ww; temps = tt; plans = pp; logs = ll
            NotificationManager.shared.reschedule(plans: pp, cats: cats)
        } catch {
            print("loadCatData: \(error.localizedDescription)")
        }
    }

    func switchCat(_ id: String) async {
        currentCatId = id
        await loadCatData(id)
    }

    // ========== 今日任务 ==========
    var todayTasks: [DoseTask] {
        let today = DateKit.today()
        let now = Date()
        var tasks: [DoseTask] = []
        for plan in plans where plan.active && plan.startDate <= today && (plan.endDate == nil || plan.endDate! >= today) {
            guard DateKit.isDoseDay(plan, on: today) else { continue }
            for time in plan.remindTimes {
                let log = logs.first { $0.planId == plan.id && $0.date == today && $0.scheduledTime == time }
                var status: DoseStatus = .pending
                if let log = log {
                    status = log.status == "taken" ? .taken : .skipped
                } else if now > DateKit.timeToday(time).addingTimeInterval(30 * 60) {
                    status = .overdue // 超 30 分钟未喂
                }
                tasks.append(DoseTask(plan: plan, time: time, status: status, log: log))
            }
        }
        return tasks.sorted { $0.time < $1.time }
    }
    var doseDone: Int { todayTasks.filter { $0.status == .taken }.count }
    var doseTotal: Int { todayTasks.count }
    var todayPending: Int { todayTasks.filter { $0.status == .pending || $0.status == .overdue }.count }
    var nextDose: DoseTask? { todayTasks.first { $0.status == .pending || $0.status == .overdue } }

    // ========== 最新指标 ==========
    var latestWeight: WeightRecord? { weights.last }
    var latestTemp: TempRecord? { temps.last }
    var weightDelta: String {
        guard weights.count >= 2 else { return "暂无对比数据" }
        let diff = weights[weights.count - 1].kg - weights[weights.count - 2].kg
        return "较上次 \(diff >= 0 ? "+" : "")\(String(format: "%.2f", diff)) kg"
    }
    var tempStatus: (text: String, warm: Bool) {
        guard let t = latestTemp else { return ("暂无数据", false) }
        if t.celsius < 38.0 { return ("偏低，注意保暖", true) }
        if t.celsius > 39.2 { return ("偏高，建议就医", true) }
        return ("处于正常范围", false)
    }
    // 护理提示：最近 3 条体重极差 >5%
    var careTip: String {
        let arr = weights.suffix(3)
        guard arr.count >= 3 else { return "连续 3 天体重变化超过 5% 时，建议复查饮食与就诊计划。" }
        let vals = arr.map { $0.kg }
        let lo = vals.min() ?? 0, hi = vals.max() ?? 0
        if lo > 0 && (hi - lo) / lo > 0.05 {
            return "近期体重波动超过 5%，建议关注饮食与精神状态，必要时就医。"
        }
        return "连续 3 天体重变化超过 5% 时，建议复查饮食与就诊计划。"
    }

    // ========== 计划列表（含完药率/历史拆分） ==========
    struct PlanItem: Identifiable {
        var id: String { plan.id }
        let plan: MedPlan
        let rate: Int
        let ongoing: Bool
    }
    var planItems: [PlanItem] {
        let today = DateKit.today()
        return plans.map { plan in
            let pl = logs.filter { $0.planId == plan.id }
            let taken = pl.filter { $0.status == "taken" }.count
            let total = pl.count
            let ongoing = plan.active && (plan.endDate == nil || plan.endDate! >= today)
            return PlanItem(plan: plan, rate: total > 0 ? taken * 100 / total : 0, ongoing: ongoing)
        }
    }
    var ongoingPlans: [PlanItem] { planItems.filter { $0.ongoing } }
    var historyPlans: [PlanItem] { planItems.filter { !$0.ongoing } }

    // ========== 猫咪 ==========
    func saveCat(name: String, breed: String, birthday: String, avatar: String, editingId: String?) async {
        guard let fid = Config.familyId else { return }
        do {
            if let id = editingId {
                var patch: [String: Any] = ["name": name, "breed": breed, "birthday": birthday]
                patch["avatar"] = avatar.isEmpty ? NSNull() : avatar
                try await Supa.update(table: "cats", id: id, payload: patch)
            } else {
                let payload: [String: Any] = [
                    "id": UUID().uuidString, "family_id": fid, "name": name,
                    "breed": breed, "birthday": birthday, "avatar": avatar
                ]
                try await Supa.insert(table: "cats", payload: payload)
            }
            await loadCats()
            showToast(editingId == nil ? "已添加猫咪" : "已更新")
        } catch { showToast("保存失败") }
    }

    // ========== 体重/体温（同日 upsert + 编辑删除） ==========
    func saveWeight(catId: String, date: String, kg: Double, note: String, editingId: String?) async {
        await saveMetric(table: "weights", catId: catId, date: date,
                         valueKey: "kg", value: kg, note: note, editingId: editingId,
                         existCheck: weights)
        showToast(editingId == nil ? "体重已记录" : "体重已更新")
    }
    func saveTemp(catId: String, date: String, celsius: Double, note: String, editingId: String?) async {
        await saveMetric(table: "temps", catId: catId, date: date,
                         valueKey: "celsius", value: celsius, note: note, editingId: editingId,
                         existCheck: temps)
        showToast(editingId == nil ? "体温已记录" : "体温已更新")
    }

    private func saveMetric<T: Identifiable>(table: String, catId: String, date: String,
                                             valueKey: String, value: Double, note: String,
                                             editingId: String?, existCheck: [T]) async where T.ID == String {
        guard let fid = Config.familyId else { return }
        do {
            if let id = editingId {
                try await Supa.update(table: table, id: id, payload: ["date": date, valueKey: value, "note": note])
            } else {
                // 同日去重：查当天是否已有记录，有则更新
                let existing = try await Supa.list(WeightRecord.self, table: table, query: [
                    URLQueryItem(name: "select", value: "id"),
                    URLQueryItem(name: "family_id", value: "eq.\(fid)"),
                    URLQueryItem(name: "cat_id", value: "eq.\(catId)"),
                    URLQueryItem(name: "date", value: "eq.\(date)")
                ])
                if let first = existing.first {
                    try await Supa.update(table: table, id: first.id, payload: [valueKey: value, "note": note])
                } else {
                    let payload: [String: Any] = [
                        "id": UUID().uuidString, "family_id": fid, "cat_id": catId,
                        "date": date, valueKey: value, "note": note
                    ]
                    try await Supa.insert(table: table, payload: payload)
                }
            }
            if let cid = currentCatId { await loadCatData(cid) }
        } catch { showToast("保存失败") }
    }

    func deleteRecord(table: String, id: String) async {
        do {
            try await Supa.remove(table: table, query: [URLQueryItem(name: "id", value: "eq.\(id)")])
            if let cid = currentCatId { await loadCatData(cid) }
            showToast("已删除")
        } catch { showToast("删除失败") }
    }

    // ========== 用药计划 ==========
    func savePlan(payload: [String: Any], editingId: String?) async {
        guard let fid = Config.familyId else { return }
        do {
            var p = payload
            p["family_id"] = fid
            if let id = editingId {
                try await Supa.update(table: "med_plans", id: id, payload: p)
            } else {
                p["id"] = UUID().uuidString
                p["active"] = true
                try await Supa.insert(table: "med_plans", payload: p)
            }
            if let cid = currentCatId { await loadCatData(cid) }
            showToast(editingId == nil ? "计划已创建" : "计划已更新")
        } catch { showToast("保存失败") }
    }

    func stopPlan(_ plan: MedPlan) async {
        do {
            try await Supa.update(table: "med_plans", id: plan.id, payload: ["active": false])
            if let cid = currentCatId { await loadCatData(cid) }
            showToast("已停用")
        } catch { showToast("操作失败") }
    }

    // 删除计划（级联删打卡记录）
    func deletePlan(_ plan: MedPlan) async {
        do {
            try await Supa.remove(table: "med_logs", query: [URLQueryItem(name: "plan_id", value: "eq.\(plan.id)")])
            try await Supa.remove(table: "med_plans", query: [URLQueryItem(name: "id", value: "eq.\(plan.id)")])
            if let cid = currentCatId { await loadCatData(cid) }
            showToast("已删除")
        } catch { showToast("删除失败") }
    }

    // ========== 打卡 ==========
    func markDose(_ task: DoseTask, taken: Bool) async {
        guard let fid = Config.familyId else { return }
        let today = DateKit.today()
        let status = taken ? "taken" : "skipped"
        do {
            if let log = task.log {
                var patch: [String: Any] = ["status": status]
                if taken { patch["taken_at"] = DateKit.nowISO() }
                try await Supa.update(table: "med_logs", id: log.id, payload: patch)
            } else {
                var payload: [String: Any] = [
                    "id": UUID().uuidString, "family_id": fid,
                    "plan_id": task.plan.id, "cat_id": task.plan.catId,
                    "date": today, "scheduled_time": task.time, "status": status
                ]
                if taken { payload["taken_at"] = DateKit.nowISO() }
                try await Supa.insert(table: "med_logs", payload: payload)
            }
            if let cid = currentCatId { await loadCatData(cid) }
            showToast(taken ? "已记录本次用药" : "已标记为跳过")
        } catch { showToast("操作失败") }
    }

    // ========== 导出备份 ==========
    func exportJSON() -> String {
        let data: [String: Any] = [
            "family_id": Config.familyId ?? "",
            "exported_at": DateKit.nowISO(),
            "data": [
                "cats": cats.map { ["id": $0.id, "name": $0.name, "breed": $0.breed ?? "", "birthday": $0.birthday ?? ""] },
                "weights": weights.map { ["date": $0.date, "kg": $0.kg, "note": $0.note ?? ""] },
                "temps": temps.map { ["date": $0.date, "celsius": $0.celsius, "note": $0.note ?? ""] }
            ]
        ]
        guard let d = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
              let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }
}
