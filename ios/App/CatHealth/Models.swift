import Foundation

// ============================================================
// 数据模型：与 Supabase 表结构一一对应（snake_case 列名）
// ============================================================

struct Cat: Codable, Identifiable {
    var id: String
    var familyId: String
    var name: String
    var breed: String?
    var birthday: String?     // yyyy-MM-dd
    var avatar: String?       // base64 压缩照片
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, breed, birthday, avatar
        case familyId = "family_id"
        case createdAt = "created_at"
    }
}

struct WeightRecord: Codable, Identifiable {
    var id: String
    var familyId: String
    var catId: String
    var date: String          // yyyy-MM-dd
    var kg: Double
    var note: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, date, kg, note
        case familyId = "family_id"
        case catId = "cat_id"
        case createdAt = "created_at"
    }
}

struct TempRecord: Codable, Identifiable {
    var id: String
    var familyId: String
    var catId: String
    var date: String
    var celsius: Double
    var note: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, date, celsius, note
        case familyId = "family_id"
        case catId = "cat_id"
        case createdAt = "created_at"
    }
}

struct MedPlan: Codable, Identifiable {
    var id: String
    var familyId: String
    var catId: String
    var drug: String
    var dose: String?               // 组合文本，如 "0.5 片" / "250 毫克"
    var remindTimes: [String]       // 用药时间，如 ["08:00","20:00"]
    var freqType: String?           // daily | weekly | interval（nil 视为 daily）
    var weekdays: [Int]?            // weekly：0=周日 1=周一 ... 6=周六
    var intervalDays: Int?          // interval：每 N 天一次（以 startDate 为第一次）
    var remindBefore: Int?          // 提前提醒分钟数（0=准时）
    var startDate: String
    var endDate: String?            // nil = 长期
    var active: Bool
    var note: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, drug, dose, note, active
        case familyId = "family_id"
        case catId = "cat_id"
        case remindTimes = "remind_times"
        case freqType = "freq_type"
        case weekdays, intervalDays = "interval_days"
        case remindBefore = "remind_before"
        case startDate = "start_date"
        case endDate = "end_date"
        case createdAt = "created_at"
    }
}

struct MedLog: Codable, Identifiable {
    var id: String
    var familyId: String
    var planId: String
    var catId: String
    var date: String
    var scheduledTime: String
    var status: String              // taken | skipped | missed
    var takenAt: String?
    var note: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, date, status, note
        case familyId = "family_id"
        case planId = "plan_id"
        case catId = "cat_id"
        case scheduledTime = "scheduled_time"
        case takenAt = "taken_at"
        case createdAt = "created_at"
    }
}

// ============================================================
// 通用工具
// ============================================================
enum DateKit {
    static func today() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    static func date(_ offsetDays: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Calendar.current.date(byAdding: .day, value: offsetDays, to: Date())!)
    }
    static func parse(_ s: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s) ?? Date()
    }
    static func nowISO() -> String {
        let f = ISO8601DateFormatter()
        return f.string(from: Date())
    }
    /// "08:00" → 当日的 Date
    static func timeToday(_ hm: String) -> Date {
        let parts = hm.split(separator: ":").compactMap { Int($0) }
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = parts.count > 0 ? parts[0] : 0
        c.minute = parts.count > 1 ? parts[1] : 0
        return Calendar.current.date(from: c) ?? Date()
    }
    /// 用药时间 - 提前量 = 实际提醒时间（跨天取模 1440）
    static func remindTime(of hm: String, before: Int) -> (hour: Int, minute: Int) {
        let parts = hm.split(separator: ":").compactMap { Int($0) }
        let total = (parts.count > 0 ? parts[0] : 0) * 60 + (parts.count > 1 ? parts[1] : 0)
        let t = ((total - before) % 1440 + 1440) % 1440
        return (t / 60, t % 60)
    }
    /// 判断某计划在某天是否该服药（与网页 isDoseDay 逻辑一致）
    static func isDoseDay(_ plan: MedPlan, on dateStr: String) -> Bool {
        let ft = plan.freqType ?? "daily"
        let date = parse(dateStr)
        if ft == "weekly" {
            let wd = Calendar.current.component(.weekday, from: date) - 1 // 0=周日
            return (plan.weekdays ?? []).contains(wd)
        }
        if ft == "interval" {
            let n = plan.intervalDays ?? 1
            let start = parse(plan.startDate)
            let diff = Calendar.current.dateComponents([.day], from: start, to: date).day ?? 0
            return diff >= 0 && diff % max(n, 1) == 0
        }
        return true
    }
    /// 频次展示文案
    static func freqText(_ plan: MedPlan) -> String {
        let ft = plan.freqType ?? "daily"
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        if ft == "weekly" {
            let days = (plan.weekdays ?? []).sorted { (($0 + 6) % 7) < (($1 + 6) % 7) }
            return "每周" + days.map { names[$0] }.joined(separator: "、")
        }
        if ft == "interval" { return "每\(plan.intervalDays ?? 1)天一次" }
        return "每天"
    }
    /// 猫咪年龄
    static func catAge(_ cat: Cat) -> String {
        guard let b = cat.birthday, !b.isEmpty else { return "" }
        let birth = parse(b), now = Date()
        var m = Calendar.current.dateComponents([.month], from: birth, to: now).month ?? 0
        if Calendar.current.component(.day, from: now) < Calendar.current.component(.day, from: birth) { m -= 1 }
        if m < 0 { return "" }
        if m < 12 { return "\(m) 个月" }
        let y = m / 12, r = m % 12
        return r > 0 ? "\(y) 岁 \(r) 个月" : "\(y) 岁"
    }
    /// "2026-08-02" → "8月2日"
    static func fmtMD(_ s: String) -> String {
        let p = s.split(separator: "-")
        guard p.count == 3, let m = Int(p[1]), let d = Int(p[2]) else { return s }
        return "\(m)月\(d)日"
    }
    /// ISO 时间 → "8月2日 08:15"
    static func fmtISO(_ s: String) -> String {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: s) else { return "" }
        let df = DateFormatter(); df.dateFormat = "M月d日 HH:mm"
        return df.string(from: d)
    }
}
