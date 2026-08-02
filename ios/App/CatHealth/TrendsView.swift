import SwiftUI
import Charts

// 趋势数据点（统一体重/体温）
struct TrendPoint: Identifiable {
    let id: String
    let date: String
    let value: Double
}

// ============================================================
// 趋势页：大标题 / 胶囊分段 / 三栏摘要 / 图表卡 / 近期记录（可编辑）
// ============================================================
struct TrendsView: View {
    @EnvironmentObject var store: DataStore
    @State private var metric = "weight"   // weight | temp
    @State private var range = 7           // 7 | 30 | 0(全部)
    @State private var editingWeight: WeightRecord?
    @State private var editingTemp: TempRecord?

    private var isWeight: Bool { metric == "weight" }

    private var points: [TrendPoint] {
        var arr: [TrendPoint]
        if isWeight {
            arr = store.weights.map { TrendPoint(id: $0.id, date: $0.date, value: $0.kg) }
        } else {
            arr = store.temps.map { TrendPoint(id: $0.id, date: $0.date, value: $0.celsius) }
        }
        // 按日期去重（后者覆盖前者，兼容历史重复数据）
        var byDate: [String: TrendPoint] = [:]
        for p in arr { byDate[p.date] = p }
        arr = byDate.values.sorted { $0.date < $1.date }
        if range > 0, let cutoff = Calendar.current.date(byAdding: .day, value: -range, to: Date()) {
            arr = arr.filter { DateKit.parse($0.date) >= cutoff }
        }
        return arr
    }

    private var unit: String { isWeight ? "kg" : "°C" }
    private var accent: Color { isWeight ? .appGreen : .appOrange }

    private var yDomain: ClosedRange<Double> {
        let vals = points.map { $0.value }
        guard let lo = vals.min(), let hi = vals.max() else {
            return isWeight ? 0...10 : 37...40
        }
        let pad = isWeight ? 0.3 : 0.5
        let minV = isWeight ? max(0, (lo - pad) * 10).rounded(.down) / 10 : ((lo - pad) * 10).rounded(.down) / 10
        let maxV = ((hi + pad) * 10).rounded(.up) / 10
        return minV...maxV
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.cats.isEmpty {
                    emptyHint("添加猫咪后查看趋势")
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        heading
                        segmented
                        rangePicker
                        summary
                        chartCard
                        recentSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .background(Color.appBg)
            .navigationBarHidden(true)
        }
        .sheet(item: $editingWeight) { r in WeightSheet(editing: r) }
        .sheet(item: $editingTemp) { r in TempSheet(editing: r) }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("健康趋势").font(.subheadline).foregroundStyle(Color.appGray)
            Text("看见细微变化").font(.largeTitle.bold())
            Text("每一次记录都会留在 \(store.currentCat?.name ?? "") 的档案中。")
                .font(.caption).foregroundStyle(Color.appGray)
        }
        .padding(.top, 18).padding(.bottom, 16)
    }

    private var segmented: some View {
        HStack(spacing: 4) {
            segButton("体重", icon: "scalemass", value: "weight")
            segButton("体温", icon: "thermometer.medium", value: "temp")
        }
        .padding(4)
        .background(Color(red: 231/255, green: 236/255, blue: 232/255))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func segButton(_ title: String, icon: String, value: String) -> some View {
        Button { metric = value } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.subheadline)
            }
            .frame(maxWidth: .infinity).frame(height: 38)
            .background(metric == value ? Color.white : Color.clear)
            .foregroundStyle(metric == value ? Color(red: 36/255, green: 66/255, blue: 53/255) : Color.appGray)
            .fontWeight(metric == value ? .semibold : .regular)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .shadow(color: metric == value ? .black.opacity(0.06) : .clear, radius: 1, y: 1)
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 4) {
            rangeButton("近7天", 7)
            rangeButton("近30天", 30)
            rangeButton("全部", 0)
        }
        .padding(4)
        .background(Color(red: 231/255, green: 236/255, blue: 232/255))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.top, 8)
    }

    private func rangeButton(_ title: String, _ value: Int) -> some View {
        Button { range = value } label: {
            Text(title).font(.caption)
                .frame(maxWidth: .infinity).frame(height: 30)
                .background(range == value ? Color.white : Color.clear)
                .foregroundStyle(range == value ? Color(red: 36/255, green: 66/255, blue: 53/255) : Color.appGray)
                .fontWeight(range == value ? .semibold : .regular)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }

    private var summary: some View {
        HStack(spacing: 8) {
            summaryCell("最近一次", points.last.map { "\(fmt($0.value)) \(unit)" } ?? "--")
            summaryCell("区间变化", deltaText)
            summaryCell("记录次数", "\(points.count)")
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Divider() }
        .overlay(alignment: .bottom) { Divider() }
        .padding(.top, 16)
    }

    private var deltaText: String {
        guard let first = points.first, let last = points.last, points.count > 1 else { return "--" }
        let d = last.value - first.value
        return "\(d >= 0 ? "+" : "")\(fmt(d)) \(unit)"
    }

    private func fmt(_ v: Double) -> String {
        isWeight ? String(format: "%.2f", v) : String(format: "%.1f", v)
    }

    private func summaryCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption2).foregroundStyle(Color.appGray)
            Text(value).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color(red: 214/255, green: 230/255, blue: 221/255)).frame(width: 2)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isWeight ? "体重变化" : "体温变化").font(.subheadline.bold())
                    Text(isWeight ? "建议每周固定时段称重" : "正常范围 38.0 - 39.2 °C")
                        .font(.caption).foregroundStyle(Color.appGray)
                }
                Spacer()
                Image(systemName: "waveform.path.ecg").foregroundStyle(Color(red: 62/255, green: 130/255, blue: 101/255))
            }
            if points.isEmpty {
                Text("暂无\(isWeight ? "体重" : "体温")数据")
                    .font(.subheadline).foregroundStyle(Color.appGray)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    if !isWeight {
                        RectangleMark(yStart: .value("低", 38.0), yEnd: .value("高", 39.2))
                            .foregroundStyle(Color.okText.opacity(0.08))
                    }
                    ForEach(points) { p in
                        LineMark(x: .value("日期", DateKit.parse(p.date)), y: .value("值", p.value))
                            .foregroundStyle(accent)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        PointMark(x: .value("日期", DateKit.parse(p.date)), y: .value("值", p.value))
                            .foregroundStyle(p.id == points.last?.id ? Color.white : accent)
                            .symbolSize(p.id == points.last?.id ? 90 : 25)
                    }
                }
                .chartYScale(domain: yDomain)
                .chartYAxisLabel(isWeight ? "体重 (kg)" : "体温 (°C)", alignment: .topLeading)
                .chartXAxisLabel("日期")
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(16)
        .cardStyle()
        .padding(.top, 16)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("近期记录").font(.headline)
                Spacer()
                Text("点击可编辑").font(.caption).foregroundStyle(Color.appGray)
            }
            .padding(.bottom, 6)

            let recent = points.suffix(5).reversed()
            if recent.isEmpty {
                Text("暂无记录，点底部 + 记一条")
                    .font(.subheadline).foregroundStyle(Color.appGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent)) { p in
                        Button {
                            openEditor(p)
                        } label: {
                            HStack(spacing: 11) {
                                IconBadge(systemName: isWeight ? "scalemass" : "thermometer.medium",
                                          fg: isWeight ? .appGreen : .appOrange,
                                          bg: isWeight ? Color(red: 230/255, green: 243/255, blue: 236/255) : Color.appOrange.opacity(0.1),
                                          size: 32)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(fmt(p.value)) \(unit)").font(.subheadline.weight(.medium)).foregroundStyle(Color.primary)
                                    Text(DateKit.fmtMD(p.date)).font(.caption).foregroundStyle(Color.appGray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.appGray)
                            }
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) { Divider().opacity(0.5) }
                        }
                    }
                }
            }
        }
        .padding(.top, 24)
    }

    private func openEditor(_ p: TrendPoint) {
        if isWeight {
            editingWeight = store.weights.first { $0.id == p.id }
        } else {
            editingTemp = store.temps.first { $0.id == p.id }
        }
    }

    private func emptyHint(_ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "pawprint").font(.system(size: 40))
                .foregroundStyle(Color(red: 182/255, green: 198/255, blue: 188/255))
            Text(text).font(.subheadline).foregroundStyle(Color.appGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}
