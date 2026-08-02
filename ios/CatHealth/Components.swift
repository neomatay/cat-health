import SwiftUI

/// 通用小组件与工具

// MARK: - 多猫切换器（横向胶囊）

struct CatSwitcher: View {
    @EnvironmentObject private var store: DataStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.cats) { cat in
                    let selected = store.selectedCatId == cat.id
                    Button {
                        store.selectedCatId = cat.id
                    } label: {
                        Text(cat.name)
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected ? Color.orange : Color(.secondarySystemBackground))
                            .foregroundStyle(selected ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - 空态视图

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - 展示用日期格式化

enum DisplayFormat {
    static let dayShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f
    }()

    static let dayFull: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    static func day(_ date: Date) -> String { dayShort.string(from: date) }
    static func full(_ date: Date) -> String { dayFull.string(from: date) }
    static func time(_ date: Date) -> String { time.string(from: date) }
}

// MARK: - 数字输入解析（兼容小数点/逗号，带范围校验）

enum InputParser {
    /// 解析体重，合法范围 0.1–20 kg
    static func weight(_ text: String) -> Double? {
        parse(text, range: Config.weightRange)
    }

    /// 解析体温，合法范围 35–42 ℃
    static func temperature(_ text: String) -> Double? {
        parse(text, range: Config.tempRange)
    }

    private static func parse(_ text: String, range: ClosedRange<Double>) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), range.contains(value) else { return nil }
        return value
    }
}
