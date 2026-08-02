import SwiftUI

// ============================================================
// 设计系统：自然绿系（与网页 v2.0 一致）
// ============================================================
extension Color {
    static let appGreen = Color(red: 35/255, green: 122/255, blue: 92/255)      // #237a5c 主绿
    static let appGreenDark = Color(red: 32/255, green: 62/255, blue: 52/255)   // #203e34 深墨绿
    static let appGreenDeep = Color(red: 41/255, green: 99/255, blue: 77/255)   // #29634d hero
    static let appBg = Color(red: 245/255, green: 248/255, blue: 245/255)       // #f5f8f5 背景
    static let appLine = Color(red: 224/255, green: 232/255, blue: 226/255)     // #e0e8e2 细边
    static let appGray = Color(red: 125/255, green: 141/255, blue: 133/255)     // #7d8d85 次要文字
    static let appOrange = Color(red: 211/255, green: 93/255, blue: 70/255)     // #d35d46 强调橙
    static let appGold = Color(red: 243/255, green: 193/255, blue: 109/255)     // #f3c16d 金色
    static let appBlue = Color(red: 49/255, green: 95/255, blue: 115/255)       // #315f73 家庭蓝
    static let okBg = Color(red: 229/255, green: 244/255, blue: 235/255)
    static let okText = Color(red: 39/255, green: 116/255, blue: 87/255)
    static let pendBg = Color(red: 255/255, green: 240/255, blue: 223/255)
    static let pendText = Color(red: 171/255, green: 96/255, blue: 43/255)
    static let missBg = Color(red: 254/255, green: 233/255, blue: 230/255)
    static let missText = Color(red: 169/255, green: 83/255, blue: 76/255)
}

// 状态语义（与网页一致）
enum DoseStatus: String {
    case pending, overdue, taken, skipped
    var text: String {
        switch self {
        case .taken: return "已喂"
        case .skipped: return "已跳过"
        case .overdue: return "已错过"
        case .pending: return "待喂"
        }
    }
    var fg: Color {
        switch self {
        case .taken: return .okText
        case .skipped: return .missText
        case .overdue: return .pendText
        case .pending: return .pendText
        }
    }
    var bg: Color {
        switch self {
        case .taken: return .okBg
        case .skipped: return .missBg
        case .overdue: return .pendBg
        case .pending: return .pendBg
        }
    }
}

struct StatusPill: View {
    let status: DoseStatus
    var body: some View {
        Text(status.text)
            .font(.caption2).fontWeight(.medium)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(status.bg).foregroundStyle(status.fg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    var trailing: Trailing
    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title; self.trailing = trailing()
    }
    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            trailing
        }
        .padding(.bottom, 10)
    }
}

// SF Symbols 图标徽标（对应网页 metric-glyph）
struct IconBadge: View {
    let systemName: String
    var fg: Color = .appGreen
    var bg: Color = Color(red: 230/255, green: 243/255, blue: 236/255)
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32).fill(bg)
            Image(systemName: systemName).font(.system(size: size * 0.48)).foregroundStyle(fg)
        }
        .frame(width: size, height: size)
    }
}

// 卡片容器
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appLine, lineWidth: 1))
    }
}
extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}
