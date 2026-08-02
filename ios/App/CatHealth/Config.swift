import Foundation

// ============================================================
// 猫咪健康 App 配置
// Supabase 项目地址与 anon key（与网页版共用同一套数据库）
// ============================================================
enum Config {
    // Supabase 项目地址（Project URL，注意：不要带 /rest/v1/ 后缀）
    static let supabaseURL = "https://pvprdtfkqqxkwxvstzuo.supabase.co"
    // Supabase anon public key
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2cHJkdGZrcXF4a3d4dnN0enVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU2NTgyNjUsImV4cCI6MjEwMTIzNDI2NX0.FeX0-FBeIKcgQEefuUr5m1ufANIRe1bjoE2Nz-22mb8"

    static var isConfigured: Bool {
        supabaseURL.hasPrefix("https://") && supabaseURL.contains(".supabase.co") && supabaseAnonKey.count > 20
    }

    // ---- 家庭码（family_id 即家庭共享凭证） ----
    private static let familyKey = "cat_health_family_id"

    static var familyId: String? {
        get { UserDefaults.standard.string(forKey: familyKey) }
        set { UserDefaults.standard.set(newValue, forKey: familyKey) }
    }

    static func ensureFamilyId() -> String {
        if let fid = familyId { return fid }
        let fid = UUID().uuidString
        familyId = fid
        return fid
    }
}
