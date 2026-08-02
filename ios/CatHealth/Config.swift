import Foundation

/// 全局配置：Supabase 连接信息 + 家庭码存储
///
/// 使用方法：
/// 1. 在 https://supabase.com 建项目后，把 Project URL 和 anon public key 填到下面两个常量。
/// 2. 不填（保持占位符）时，App 自动进入「本地模式」，所有数据存本机 SwiftData，功能完整可用。
/// 3. 填写后，可在「我的 → 家庭同步」里创建/加入家庭，进入「同步模式」，直接读写 Supabase。
enum Config {

    // MARK: - Supabase 配置（按需填写）

    /// Supabase 项目 URL，形如 https://abcdefgh.supabase.co
    static let supabaseURL = "https://pvprdtfkqqxkwxvstzuo.supabase.co/rest/v1/"

    /// Supabase anon public key（Settings → API → anon public）
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2cHJkdGZrcXF4a3d4dnN0enVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU2NTgyNjUsImV4cCI6MjEwMTIzNDI2NX0.FeX0-FBeIKcgQEefuUr5m1ufANIRe1bjoE2Nz-22mb8"

    /// 是否已配置 Supabase（占位符未替换视为未配置）
    static var isSupabaseConfigured: Bool {
        supabaseURL.hasPrefix("https://")
            && supabaseURL.contains(".supabase.co")
            && supabaseAnonKey.count > 20
            && !supabaseAnonKey.contains("YOUR")
    }

    // MARK: - 家庭码（存 UserDefaults）

    private static let familyIdKey = "cat_health_family_id"

    /// 当前家庭码；nil 表示未加入家庭（本地模式）
    static var familyId: UUID? {
        get {
            guard let str = UserDefaults.standard.string(forKey: familyIdKey) else { return nil }
            return UUID(uuidString: str)
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: familyIdKey)
        }
    }

    /// 同步模式 = 已配置 Supabase 且已设置家庭码
    static var isSyncMode: Bool {
        isSupabaseConfigured && familyId != nil
    }

    // MARK: - 输入校验范围

    static let weightRange: ClosedRange<Double> = 0.1...20.0   // kg
    static let tempRange: ClosedRange<Double> = 35.0...42.0    // ℃
    static let tempNormalLow = 38.0                            // 猫正常体温下限
    static let tempNormalHigh = 39.2                           // 猫正常体温上限
}
