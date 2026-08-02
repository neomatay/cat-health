import Foundation
import SwiftData

// MARK: - 日期工具

enum DateKit {
    /// yyyy-MM-dd（对应 Postgres date 类型；个人自用，直接用本地时区）
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// HH:mm（对应 text 类型的提醒/计划时间）
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }

    static func parseDay(_ str: String) -> Date? {
        dayFormatter.date(from: str).map { Calendar.current.startOfDay(for: $0) }
    }

    /// timestamptz 解析：优先带毫秒，其次不带
    static func parseTimestamp(_ str: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: str)
    }

    static func timestampString(_ date: Date) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.string(from: date)
    }

    static var today: Date { Calendar.current.startOfDay(for: Date()) }

    /// 把 Date 的时间部分转成 "HH:mm"
    static func timeString(_ date: Date) -> String { timeFormatter.string(from: date) }

    /// 把 "HH:mm" 合成到某天的具体时刻
    static func dateOn(day: Date, time: String) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }
}

// MARK: - 用药记录状态

enum MedLogStatus: String, Codable, CaseIterable {
    case pending   // 待喂（内存态，一般不落库）
    case taken     // 已喂
    case skipped   // 跳过
    case missed    // 错过（展示态）

    var label: String {
        switch self {
        case .pending: return "待喂"
        case .taken: return "已喂"
        case .skipped: return "跳过"
        case .missed: return "错过"
        }
    }
}

// MARK: - 猫

struct Cat: Codable, Identifiable, Hashable {
    var id: UUID
    var familyId: UUID
    var name: String
    var breed: String?
    var birthday: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, breed
        case familyId = "family_id"
        case birthday
    }

    init(id: UUID = UUID(), familyId: UUID, name: String, breed: String? = nil, birthday: Date? = nil) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.breed = breed
        self.birthday = birthday
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        familyId = try c.decode(UUID.self, forKey: .familyId)
        name = try c.decode(String.self, forKey: .name)
        breed = try c.decodeIfPresent(String.self, forKey: .breed)
        birthday = try c.decodeIfPresent(String.self, forKey: .birthday).flatMap(DateKit.parseDay)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(familyId, forKey: .familyId)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(breed, forKey: .breed)
        try c.encodeIfPresent(birthday.map(DateKit.day), forKey: .birthday)
    }

    /// 年龄文案，如 "1岁3个月"
    var ageText: String? {
        guard let birthday else { return nil }
        let comp = Calendar.current.dateComponents([.year, .month], from: birthday, to: Date())
        let y = comp.year ?? 0, m = comp.month ?? 0
        if y <= 0 && m <= 0 { return "不满1个月" }
        if y <= 0 { return "\(m)个月" }
        if m <= 0 { return "\(y)岁" }
        return "\(y)岁\(m)个月"
    }
}

// MARK: - 体重记录

struct WeightRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var familyId: UUID
    var catId: UUID
    var date: Date
    var kg: Double
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id, kg, note, date
        case familyId = "family_id"
        case catId = "cat_id"
    }

    init(id: UUID = UUID(), familyId: UUID, catId: UUID, date: Date, kg: Double, note: String? = nil) {
        self.id = id
        self.familyId = familyId
        self.catId = catId
        self.date = Calendar.current.startOfDay(for: date)
        self.kg = kg
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        familyId = try c.decode(UUID.self, forKey: .familyId)
        catId = try c.decode(UUID.self, forKey: .catId)
        let dayStr = try c.decode(String.self, forKey: .date)
        date = DateKit.parseDay(dayStr) ?? DateKit.today
        kg = try c.decode(Double.self, forKey: .kg)
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(familyId, forKey: .familyId)
        try c.encode(catId, forKey: .catId)
        try c.encode(DateKit.day(date), forKey: .date)
        try c.encode(kg, forKey: .kg)
        try c.encodeIfPresent(note, forKey: .note)
    }
}

// MARK: - 体温记录

struct TempRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var familyId: UUID
    var catId: UUID
    var date: Date
    var celsius: Double
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id, date, note
        case familyId = "family_id"
        case catId = "cat_id"
        case celsius
    }

    init(id: UUID = UUID(), familyId: UUID, catId: UUID, date: Date, celsius: Double, note: String? = nil) {
        self.id = id
        self.familyId = familyId
        self.catId = catId
        self.date = Calendar.current.startOfDay(for: date)
        self.celsius = celsius
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        familyId = try c.decode(UUID.self, forKey: .familyId)
        catId = try c.decode(UUID.self, forKey: .catId)
        let dayStr = try c.decode(String.self, forKey: .date)
        date = DateKit.parseDay(dayStr) ?? DateKit.today
        celsius = try c.decode(Double.self, forKey: .celsius)
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(familyId, forKey: .familyId)
        try c.encode(catId, forKey: .catId)
        try c.encode(DateKit.day(date), forKey: .date)
        try c.encode(celsius, forKey: .celsius)
        try c.encodeIfPresent(note, forKey: .note)
    }

    /// 是否超出正常体温区间
    var isAbnormal: Bool {
        celsius < Config.tempNormalLow || celsius > Config.tempNormalHigh
    }
}

// MARK: - 用药计划

struct MedPlan: Codable, Identifiable, Hashable {
    var id: UUID
    var familyId: UUID
    var catId: UUID
    var drug: String
    var dose: String
    var remindTimes: [String]      // ["08:00", "20:00"]
    var startDate: Date
    var endDate: Date?             // nil = 长期
    var active: Bool
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id, drug, dose, active, note
        case familyId = "family_id"
        case catId = "cat_id"
        case remindTimes = "remind_times"
        case startDate = "start_date"
        case endDate = "end_date"
    }

    init(id: UUID = UUID(), familyId: UUID, catId: UUID, drug: String, dose: String,
         remindTimes: [String], startDate: Date, endDate: Date? = nil, active: Bool = true, note: String? = nil) {
        self.id = id
        self.familyId = familyId
        self.catId = catId
        self.drug = drug
        self.dose = dose
        self.remindTimes = remindTimes
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.endDate = endDate.map { Calendar.current.startOfDay(for: $0) }
        self.active = active
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        familyId = try c.decode(UUID.self, forKey: .familyId)
        catId = try c.decode(UUID.self, forKey: .catId)
        drug = try c.decode(String.self, forKey: .drug)
        dose = try c.decode(String.self, forKey: .dose)
        remindTimes = try c.decodeIfPresent([String].self, forKey: .remindTimes) ?? []
        let startStr = try c.decode(String.self, forKey: .startDate)
        startDate = DateKit.parseDay(startStr) ?? DateKit.today
        endDate = try c.decodeIfPresent(String.self, forKey: .endDate).flatMap(DateKit.parseDay)
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(familyId, forKey: .familyId)
        try c.encode(catId, forKey: .catId)
        try c.encode(drug, forKey: .drug)
        try c.encode(dose, forKey: .dose)
        try c.encode(remindTimes, forKey: .remindTimes)
        try c.encode(DateKit.day(startDate), forKey: .startDate)
        try c.encodeIfPresent(endDate.map(DateKit.day), forKey: .endDate)
        try c.encode(active, forKey: .active)
        try c.encodeIfPresent(note, forKey: .note)
    }

    /// 某天是否在该计划生效期内
    func covers(day: Date) -> Bool {
        let d = Calendar.current.startOfDay(for: day)
        if d < startDate { return false }
        if let endDate, d > endDate { return false }
        return true
    }
}

// MARK: - 用药记录

struct MedLog: Codable, Identifiable, Hashable {
    var id: UUID
    var familyId: UUID
    var planId: UUID?
    var catId: UUID
    var date: Date
    var scheduledTime: String   // "HH:mm"
    var status: MedLogStatus
    var takenAt: Date?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id, status, note
        case familyId = "family_id"
        case planId = "plan_id"
        case catId = "cat_id"
        case date
        case scheduledTime = "scheduled_time"
        case takenAt = "taken_at"
    }

    init(id: UUID = UUID(), familyId: UUID, planId: UUID?, catId: UUID, date: Date,
         scheduledTime: String, status: MedLogStatus, takenAt: Date? = nil, note: String? = nil) {
        self.id = id
        self.familyId = familyId
        self.planId = planId
        self.catId = catId
        self.date = Calendar.current.startOfDay(for: date)
        self.scheduledTime = scheduledTime
        self.status = status
        self.takenAt = takenAt
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        familyId = try c.decode(UUID.self, forKey: .familyId)
        planId = try c.decodeIfPresent(UUID.self, forKey: .planId)
        catId = try c.decode(UUID.self, forKey: .catId)
        let dayStr = try c.decode(String.self, forKey: .date)
        date = DateKit.parseDay(dayStr) ?? DateKit.today
        scheduledTime = try c.decodeIfPresent(String.self, forKey: .scheduledTime) ?? ""
        status = MedLogStatus(rawValue: try c.decodeIfPresent(String.self, forKey: .status) ?? "") ?? .taken
        takenAt = try c.decodeIfPresent(String.self, forKey: .takenAt).flatMap(DateKit.parseTimestamp)
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(familyId, forKey: .familyId)
        try c.encodeIfPresent(planId, forKey: .planId)
        try c.encode(catId, forKey: .catId)
        try c.encode(DateKit.day(date), forKey: .date)
        try c.encode(scheduledTime, forKey: .scheduledTime)
        try c.encode(status.rawValue, forKey: .status)
        try c.encodeIfPresent(takenAt.map(DateKit.timestampString), forKey: .takenAt)
        try c.encodeIfPresent(note, forKey: .note)
    }
}

// MARK: - SwiftData 本地模型（本地模式专用，与上面结构一一对应）

@Model
final class LocalCat {
    @Attribute(.unique) var id: UUID
    var familyId: UUID
    var name: String
    var breed: String?
    var birthday: Date?

    init(from cat: Cat) {
        self.id = cat.id
        self.familyId = cat.familyId
        self.name = cat.name
        self.breed = cat.breed
        self.birthday = cat.birthday
    }

    func toStruct() -> Cat {
        Cat(id: id, familyId: familyId, name: name, breed: breed, birthday: birthday)
    }
}

@Model
final class LocalWeight {
    @Attribute(.unique) var id: UUID
    var familyId: UUID
    var catId: UUID
    var date: Date
    var kg: Double
    var note: String?

    init(from r: WeightRecord) {
        self.id = r.id
        self.familyId = r.familyId
        self.catId = r.catId
        self.date = r.date
        self.kg = r.kg
        self.note = r.note
    }

    func toStruct() -> WeightRecord {
        WeightRecord(id: id, familyId: familyId, catId: catId, date: date, kg: kg, note: note)
    }
}

@Model
final class LocalTemp {
    @Attribute(.unique) var id: UUID
    var familyId: UUID
    var catId: UUID
    var date: Date
    var celsius: Double
    var note: String?

    init(from r: TempRecord) {
        self.id = r.id
        self.familyId = r.familyId
        self.catId = r.catId
        self.date = r.date
        self.celsius = r.celsius
        self.note = r.note
    }

    func toStruct() -> TempRecord {
        TempRecord(id: id, familyId: familyId, catId: catId, date: date, celsius: celsius, note: note)
    }
}

@Model
final class LocalMedPlan {
    @Attribute(.unique) var id: UUID
    var familyId: UUID
    var catId: UUID
    var drug: String
    var dose: String
    var remindTimes: [String]
    var startDate: Date
    var endDate: Date?
    var active: Bool
    var note: String?

    init(from p: MedPlan) {
        self.id = p.id
        self.familyId = p.familyId
        self.catId = p.catId
        self.drug = p.drug
        self.dose = p.dose
        self.remindTimes = p.remindTimes
        self.startDate = p.startDate
        self.endDate = p.endDate
        self.active = p.active
        self.note = p.note
    }

    func toStruct() -> MedPlan {
        MedPlan(id: id, familyId: familyId, catId: catId, drug: drug, dose: dose,
                remindTimes: remindTimes, startDate: startDate, endDate: endDate, active: active, note: note)
    }
}

@Model
final class LocalMedLog {
    @Attribute(.unique) var id: UUID
    var familyId: UUID
    var planId: UUID?
    var catId: UUID
    var date: Date
    var scheduledTime: String
    var statusRaw: String
    var takenAt: Date?
    var note: String?

    init(from l: MedLog) {
        self.id = l.id
        self.familyId = l.familyId
        self.planId = l.planId
        self.catId = l.catId
        self.date = l.date
        self.scheduledTime = l.scheduledTime
        self.statusRaw = l.status.rawValue
        self.takenAt = l.takenAt
        self.note = l.note
    }

    func toStruct() -> MedLog {
        MedLog(id: id, familyId: familyId, planId: planId, catId: catId, date: date,
               scheduledTime: scheduledTime, status: MedLogStatus(rawValue: statusRaw) ?? .taken,
               takenAt: takenAt, note: note)
    }
}

// MARK: - 导出用全量数据包

struct ExportBundle: Codable {
    var exportedAt: String
    var familyId: String
    var cats: [Cat]
    var weights: [WeightRecord]
    var temps: [TempRecord]
    var medPlans: [MedPlan]
    var medLogs: [MedLog]

    enum CodingKeys: String, CodingKey {
        case cats, weights, temps
        case exportedAt = "exported_at"
        case familyId = "family_id"
        case medPlans = "med_plans"
        case medLogs = "med_logs"
    }
}
