import SwiftUI
import Charts

/// Tab 2「趋势」：体重/体温折线图，支持 7天/30天/全部 区间切换
struct TrendsView: View {
    @EnvironmentObject private var store: DataStore

    @State private var metric: Metric = .weight
    @State private var range: TimeRange = .month

    enum Metric: String, CaseIterable, Identifiable {
        case weight = "体重"
        case temp = "体温"
        var id: String { rawValue }
        var unit: String { self == .weight ? "kg" : "℃" }
    }

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "7天"
        case month = "30天"
        case all = "全部"
        var id: String { rawValue }

        var cutoff: Date? {
            switch self {
            case .week: return Calendar.current.date(byAdding: .day, value: -7, to: DateKit.today)
            case .month: return Calendar.current.date(byAdding: .day, value: -30, to: DateKit.today)
            case .all: return nil
            }
        }
    }

    /// 图用数据点
    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private var points: [Point] {
        guard let catId = store.selectedCatId else { return [] }
        let cutoff = range.cutoff
        switch metric {
        case .weight:
            return store.weights
                .filter { $0.catId == catId && (cutoff == nil || $0.date >= cutoff!) }
                .sorted { $0.date < $1.date }
                .map { Point(date: $0.date, value: $0.kg) }
        case .temp:
            return store.temps
                .filter { $0.catId == catId && (cutoff == nil || $0.date >= cutoff!) }
                .sorted { $0.date < $1.date }
                .map { Point(date: $0.date, value: $0.celsius) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.cats.isEmpty {
                    EmptyStateView(systemImage: "chart.xyaxis.line",
                                   title: "还没有猫咪档案",
                                   message: "先在「我的」里添加猫咪，再记录数据后这里会出现趋势图")
                } else {
                    VStack(spacing: 0) {
                        CatSwitcher()

                        // 指标 + 区间切换
                        VStack(spacing: 10) {
                            Picker("指标", selection: $metric) {
                                ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)

                            Picker("区间", selection: $range) {
                                ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding()

                        if points.isEmpty {
                            Spacer()
                            EmptyStateView(systemImage: "chart.line.downtrend.xyaxis",
                                           title: "该区间内没有\(metric.rawValue)记录",
                                           message: "在「今天」页点「记\(metric.rawValue)」添加一条")
                            Spacer()
                        } else {
                            chart
                            statsView
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("趋势")
        }
    }

    // MARK: - 折线图

    private var chart: some View {
        Chart {
            // 体温图叠加正常区间 38.0 – 39.2 ℃
            if metric == .temp {
                RectangleMark(
                    yStart: .value("下限", Config.tempNormalLow),
                    yEnd: .value("上限", Config.tempNormalHigh)
                )
                .foregroundStyle(.green.opacity(0.12))
                .annotation(position: .overlay, alignment: .topTrailing) {
                    Text("正常 \(Config.tempNormalLow, specifier: "%.1f")–\(Config.tempNormalHigh, specifier: "%.1f") ℃")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .padding(4)
                }
            }

            ForEach(points) { p in
                LineMark(
                    x: .value("日期", p.date, unit: .day),
                    y: .value(metric.rawValue, p.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.orange)

                PointMark(
                    x: .value("日期", p.date, unit: .day),
                    y: .value(metric.rawValue, p.value)
                )
                .foregroundStyle(.orange)
                .symbolSize(36)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 260)
        .padding(.horizontal)
    }

    // MARK: - 统计摘要

    private var statsView: some View {
        let values = points.map(\.value)
        let latest = points.last?.value
        let avg = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        let minV = values.min()
        let maxV = values.max()
        let fmt = metric == .weight ? "%.2f" : "%.1f"

        return HStack(spacing: 0) {
            StatCell(title: "记录数", value: "\(values.count)")
            StatCell(title: "最新", value: latest.map { String(format: fmt, $0) + " " + metric.unit } ?? "-")
            StatCell(title: "平均", value: avg.map { String(format: fmt, $0) } ?? "-")
            StatCell(title: "最低", value: minV.map { String(format: fmt, $0) } ?? "-")
            StatCell(title: "最高", value: maxV.map { String(format: fmt, $0) } ?? "-")
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}

private struct StatCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
