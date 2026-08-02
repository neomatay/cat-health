import Foundation

// ============================================================
// Supabase REST 客户端（零依赖，直接 URLSession 调 PostgREST）
// ============================================================

enum SupaError: Error, LocalizedError {
    case badURL
    case notConfigured
    case http(Int, String)
    var errorDescription: String? {
        switch self {
        case .badURL: return "地址错误"
        case .notConfigured: return "未配置 Supabase"
        case .http(let code, let body): return "HTTP \(code): \(body)"
        }
    }
}

enum Supa {
    private static var base: String { Config.supabaseURL + "/rest/v1" }

    private static func request(path: String, method: String = "GET",
                                query: [URLQueryItem] = [], body: Data? = nil,
                                prefer: String? = nil) async throws -> Data {
        guard Config.isConfigured else { throw SupaError.notConfigured }
        guard var comp = URLComponents(string: base + path) else { throw SupaError.badURL }
        if !query.isEmpty { comp.queryItems = query }
        guard let url = comp.url else { throw SupaError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        if let prefer = prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body = body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            throw SupaError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    static func list<T: Decodable>(_ type: T.Type, table: String, query: [URLQueryItem]) async throws -> [T] {
        let data = try await request(path: "/\(table)", query: query)
        return try JSONDecoder().decode([T].self, from: data)
    }

    static func insert(table: String, payload: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: "/\(table)", method: "POST", body: body, prefer: "return=minimal")
    }

    static func update(table: String, id: String, payload: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: "/\(table)", method: "PATCH",
                              query: [URLQueryItem(name: "id", value: "eq.\(id)")],
                              body: body, prefer: "return=minimal")
    }

    static func remove(table: String, query: [URLQueryItem]) async throws {
        _ = try await request(path: "/\(table)", method: "DELETE", query: query)
    }
}

/// 通知快捷操作（已喂/跳过）直接写打卡记录，无需经过界面状态
func writeDoseLogFromNotification(planId: String, catId: String, time: String, status: String) async {
    guard let fid = Config.familyId else { return }
    let today = DateKit.today()
    do {
        // 查是否已有当天该时间点的记录
        let existing = try await Supa.list(MedLog.self, table: "med_logs", query: [
            URLQueryItem(name: "select", value: "id"),
            URLQueryItem(name: "family_id", value: "eq.\(fid)"),
            URLQueryItem(name: "plan_id", value: "eq.\(planId)"),
            URLQueryItem(name: "date", value: "eq.\(today)"),
            URLQueryItem(name: "scheduled_time", value: "eq.\(time)")
        ])
        if let first = existing.first {
            var patch: [String: Any] = ["status": status]
            if status == "taken" { patch["taken_at"] = DateKit.nowISO() }
            try await Supa.update(table: "med_logs", id: first.id, payload: patch)
        } else {
            var payload: [String: Any] = [
                "id": UUID().uuidString,
                "family_id": fid,
                "plan_id": planId,
                "cat_id": catId,
                "date": today,
                "scheduled_time": time,
                "status": status
            ]
            if status == "taken" { payload["taken_at"] = DateKit.nowISO() }
            try await Supa.insert(table: "med_logs", payload: payload)
        }
    } catch {
        print("通知打卡写入失败: \(error.localizedDescription)")
    }
}
