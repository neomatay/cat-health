import SwiftUI
import PhotosUI

// ============================================================
// 全部弹层
// ============================================================

// 快捷记录类型（sheet(item:) 需要 Identifiable）
enum QuickSheetType: Identifiable {
    case weight, temp
    var id: Int { self == .weight ? 0 : 1 }
}

// ---- FAB 快捷记录 ----
struct QuickRecordSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var type: QuickSheetType?

    var body: some View {
        VStack(spacing: 16) {
            Text("新增健康记录").font(.title3.bold()).padding(.top, 8)
            Text("保存后会同步到健康趋势").font(.caption).foregroundStyle(Color.appGray)
            HStack(spacing: 10) {
                quickBtn("记体重", icon: "scalemass", tint: .appGreen,
                         bg: Color(red: 230/255, green: 243/255, blue: 236/255)) { type = .weight }
                quickBtn("记体温", icon: "thermometer.medium", tint: .appOrange,
                         bg: Color.appOrange.opacity(0.1)) { type = .temp }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .background(Color.appBg)
        .sheet(item: $type) { t in
            if t == .weight { WeightSheet(editing: nil) } else { TempSheet(editing: nil) }
        }
    }

    private func quickBtn(_ title: String, icon: String, tint: Color, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                IconBadge(systemName: icon, fg: tint, bg: bg, size: 36)
                Text(title).font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity).frame(height: 88)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appLine, lineWidth: 1))
        }
        .foregroundStyle(Color.primary)
    }
}

// ---- 记/编辑体重 ----
struct WeightSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    let editing: WeightRecord?
    @State private var kg = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var error = ""
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("如 4.5", text: $kg)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                    if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Color.missText) }
                    Text("范围 0.1 - 20 kg").font(.caption).foregroundStyle(Color.appGray)
                        .frame(maxWidth: .infinity, alignment: .center)
                } header: { Text("体重 (kg) *") }
                Section("日期") {
                    DatePicker("记录日期", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                Section("备注") {
                    TextField("如：饭后称重", text: $note)
                }
                if editing != nil {
                    Section {
                        Button("删除这条记录", role: .destructive) { showDelete = true }
                    }
                }
            }
            .navigationTitle(editing == nil ? "记录体重" : "编辑体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("保存") { save() }.fontWeight(.semibold) }
            }
            .onAppear {
                if let e = editing {
                    kg = String(e.kg); date = DateKit.parse(e.date); note = e.note ?? ""
                }
            }
            .confirmationDialog("删除记录", isPresented: $showDelete) {
                Button("删除", role: .destructive) {
                    if let e = editing {
                        Task {
                            await store.deleteRecord(table: "weights", id: e.id)
                            dismiss()
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func save() {
        guard let v = Double(kg), v >= 0.1, v <= 20 else { error = "请输入 0.1-20 kg"; return }
        guard let catId = store.currentCatId else { return }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        Task {
            await store.saveWeight(catId: catId, date: f.string(from: date), kg: v, note: note, editingId: editing?.id)
            dismiss()
        }
    }
}

// ---- 记/编辑体温 ----
struct TempSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    let editing: TempRecord?
    @State private var celsius = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var error = ""
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("如 38.5", text: $celsius)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                    if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Color.missText) }
                    Text("范围 35 - 42 °C · 正常 38.0-39.2").font(.caption).foregroundStyle(Color.appGray)
                        .frame(maxWidth: .infinity, alignment: .center)
                } header: { Text("体温 (°C) *") }
                Section("日期") {
                    DatePicker("记录日期", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                Section("备注") {
                    TextField("如：肛温", text: $note)
                }
                if editing != nil {
                    Section {
                        Button("删除这条记录", role: .destructive) { showDelete = true }
                    }
                }
            }
            .navigationTitle(editing == nil ? "记录体温" : "编辑体温")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("保存") { save() }.fontWeight(.semibold) }
            }
            .onAppear {
                if let e = editing {
                    celsius = String(e.celsius); date = DateKit.parse(e.date); note = e.note ?? ""
                }
            }
            .confirmationDialog("删除记录", isPresented: $showDelete) {
                Button("删除", role: .destructive) {
                    if let e = editing {
                        Task {
                            await store.deleteRecord(table: "temps", id: e.id)
                            dismiss()
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func save() {
        guard let v = Double(celsius), v >= 35, v <= 42 else { error = "请输入 35-42 °C"; return }
        guard let catId = store.currentCatId else { return }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        Task {
            await store.saveTemp(catId: catId, date: f.string(from: date), celsius: v, note: note, editingId: editing?.id)
            dismiss()
        }
    }
}

// ---- 添加/编辑猫咪（含照片） ----
struct CatSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    let editing: Cat?
    @State private var name = ""
    @State private var breed = ""
    @State private var birthday = Date()
    @State private var hasBirthday = false
    @State private var avatar = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var error = ""

    private let breeds = ["不确定/混血", "中华田园猫", "英国短毛猫", "美国短毛猫", "布偶猫", "暹罗猫", "加菲猫（异国短毛猫）", "缅因猫", "波斯猫", "斯芬克斯猫", "苏格兰折耳猫", "其他"]

    var body: some View {
        NavigationStack {
            Form {
                Section("照片") {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            ZStack {
                                if let data = Data(base64Encoded: avatar.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                                   let img = UIImage(data: data), !avatar.isEmpty {
                                    Image(uiImage: img).resizable().scaledToFill()
                                } else {
                                    Color(red: 238/255, green: 242/255, blue: 239/255)
                                    Text("🐱").font(.system(size: 36))
                                }
                            }
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(style: StrokeStyle(lineWidth: 2, dash: [6])))
                            .foregroundStyle(Color(red: 182/255, green: 198/255, blue: 188/255))
                        }
                        Spacer()
                    }
                    Text("点击圆形区域选择照片（自动裁剪压缩）")
                        .font(.caption).foregroundStyle(Color.appGray)
                        .frame(maxWidth: .infinity, alignment: .center)
                    if !avatar.isEmpty {
                        Button("移除照片", role: .destructive) { avatar = "" }
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                Section("名字 *") {
                    TextField("如：小橘", text: $name)
                    if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Color.missText) }
                }
                Section("品种") {
                    Picker("品种", selection: $breed) {
                        ForEach(breeds, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("生日") {
                    Toggle("已设置生日", isOn: $hasBirthday)
                    if hasBirthday {
                        DatePicker("生日", selection: $birthday, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                }
            }
            .navigationTitle(editing == nil ? "添加猫咪" : "编辑猫咪")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("保存") { save() }.fontWeight(.semibold) }
            }
            .onAppear {
                if let e = editing {
                    name = e.name
                    breed = e.breed ?? ""
                    avatar = e.avatar ?? ""
                    if let b = e.birthday, !b.isEmpty {
                        hasBirthday = true
                        birthday = DateKit.parse(b)
                    }
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
        }
    }

    // 照片：居中裁剪正方形 → 240x240 JPEG → base64
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item,
              let data = try? await item.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else { return }
        let size: CGFloat = 240
        let side = min(img.size.width, img.size.height)
        let rect = CGRect(x: (img.size.width - side) / 2, y: (img.size.height - side) / 2, width: side, height: side)
        guard let cg = img.cgImage?.cropping(to: rect) else { return }
        let cropped = UIImage(cgImage: cg)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let resized = renderer.image { _ in
            cropped.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        if let jpeg = resized.jpegData(compressionQuality: 0.8) {
            avatar = "data:image/jpeg;base64," + jpeg.base64EncodedString()
        }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { error = "请输入名字"; return }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        Task {
            await store.saveCat(name: n, breed: breed,
                                birthday: hasBirthday ? f.string(from: birthday) : "",
                                avatar: avatar, editingId: editing?.id)
            dismiss()
        }
    }
}

// ---- 新增/编辑用药计划 ----
struct PlanSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    let editing: MedPlan?

    @State private var drug = ""
    @State private var doseAmount = ""
    @State private var doseUnit = "片"
    @State private var freqType = "daily"
    @State private var weekdays: Set<Int> = []
    @State private var intervalDays = 2
    @State private var times: [String] = ["08:00"]
    @State private var remindBefore = 0
    @State private var startDate = Date()
    @State private var isLongTerm = true
    @State private var endDate = Date()
    @State private var note = ""
    @State private var error = ""
    @State private var showDelete = false

    private let doseUnits = ["片", "粒", "毫克"]
    private let remindOptions = [0, 5, 10, 15, 30]
    private let wdNames = ["日", "一", "二", "三", "四", "五", "六"]
    private let wdOrder = [1, 2, 3, 4, 5, 6, 0]

    var body: some View {
        NavigationStack {
            Form {
                Section("药品名 *") {
                    TextField("如：阿莫西林", text: $drug)
                    if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Color.missText) }
                }

                Section("剂量") {
                    HStack {
                        TextField("数字", text: $doseAmount).keyboardType(.decimalPad)
                        Picker("单位", selection: $doseUnit) {
                            ForEach(doseUnits, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    Text("如 0.5 片、1 粒、250 毫克；留空表示不填剂量")
                        .font(.caption).foregroundStyle(Color.appGray)
                }

                Section("频次") {
                    Picker("频次", selection: $freqType) {
                        Text("每天").tag("daily")
                        Text("每周固定").tag("weekly")
                        Text("每N天").tag("interval")
                    }
                    .pickerStyle(.segmented)

                    if freqType == "weekly" {
                        HStack(spacing: 6) {
                            ForEach(wdOrder, id: \.self) { d in
                                Button { toggleWeekday(d) } label: {
                                    Text(wdNames[d])
                                        .font(.subheadline)
                                        .frame(width: 36, height: 36)
                                        .background(weekdays.contains(d) ? Color.appGreen : Color.white)
                                        .foregroundStyle(weekdays.contains(d) ? Color.white : Color.appGray)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(weekdays.contains(d) ? Color.appGreen : Color.appLine, lineWidth: 1))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if freqType == "interval" {
                        Stepper("每 \(intervalDays) 天一次（每隔\(intervalDays - 1)天，以开始日期为第一次）",
                                value: $intervalDays, in: 2...30)
                    }
                }

                Section("用药时间") {
                    ForEach(times.indices, id: \.self) { i in
                        HStack {
                            TextField("HH:mm", text: $times[i])
                                .keyboardType(.numbersAndPunctuation)
                            if times.count > 1 {
                                Button("删除", role: .destructive) { times.remove(at: i) }
                                    .font(.caption)
                            }
                        }
                    }
                    Button("＋ 添加时间") { times.append("20:00") }
                }

                Section("提醒") {
                    Picker("提前提醒", selection: $remindBefore) {
                        ForEach(remindOptions, id: \.self) { m in
                            Text(m == 0 ? "准时" : "提前\(m)分钟").tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("如用药 08:00、提前10分钟 → 07:50 本地通知提醒")
                        .font(.caption).foregroundStyle(Color.appGray)
                }

                Section("起止日期") {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    Toggle("长期用药", isOn: $isLongTerm)
                    if !isLongTerm {
                        DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section("备注") {
                    TextField("如：饭后服用", text: $note)
                }

                if editing != nil {
                    Section {
                        Button("删除此计划", role: .destructive) { showDelete = true }
                    }
                }
            }
            .navigationTitle(editing == nil ? "新增用药计划" : "编辑计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("保存") { save() }.fontWeight(.semibold) }
            }
            .onAppear { fillForm() }
            .confirmationDialog("删除计划", isPresented: $showDelete) {
                Button("删除", role: .destructive) {
                    if let e = editing {
                        Task {
                            await store.deletePlan(e)
                            dismiss()
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("该计划及其打卡记录将一并删除，不可恢复。")
            }
        }
    }

    private func toggleWeekday(_ d: Int) {
        if weekdays.contains(d) { weekdays.remove(d) } else { weekdays.insert(d) }
    }

    private func fillForm() {
        guard let p = editing else { return }
        drug = p.drug
        // 解析剂量文本 → 数字+单位
        if let dose = p.dose, !dose.isEmpty {
            let parts = dose.replacingOccurrences(of: "半", with: "0.5").split(separator: " ")
            if parts.count == 2 {
                doseAmount = String(parts[0])
                doseUnit = String(parts[1]) == "mg" ? "毫克" : String(parts[1])
            }
        }
        freqType = p.freqType ?? "daily"
        weekdays = Set(p.weekdays ?? [])
        intervalDays = p.intervalDays ?? 2
        times = p.remindTimes.isEmpty ? ["08:00"] : p.remindTimes
        remindBefore = p.remindBefore ?? 0
        startDate = DateKit.parse(p.startDate)
        if let e = p.endDate { isLongTerm = false; endDate = DateKit.parse(e) }
        note = p.note ?? ""
    }

    private func save() {
        let d = drug.trimmingCharacters(in: .whitespaces)
        guard !d.isEmpty else { error = "请输入药品名"; return }
        guard let catId = store.currentCatId else { return }
        if freqType == "weekly" && weekdays.isEmpty { error = "请选择每周哪几天服药"; return }

        var doseText = ""
        if !doseAmount.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let v = Double(doseAmount), v > 0, v <= 9999 else { error = "请输入正确的剂量数字"; return }
            doseText = "\(v) \(doseUnit)"
        }
        // 时间格式简单校验
        for t in times {
            let parts = t.split(separator: ":")
            guard parts.count == 2, Int(parts[0]) != nil, Int(parts[1]) != nil else {
                error = "用药时间格式应为 HH:mm，如 08:00"; return
            }
        }

        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        var payload: [String: Any] = [
            "cat_id": catId, "drug": d, "dose": doseText,
            "remind_times": times, "start_date": f.string(from: startDate),
            "note": note, "freq_type": freqType,
            "remind_before": remindBefore
        ]
        payload["end_date"] = isLongTerm ? NSNull() : f.string(from: endDate)
        payload["weekdays"] = freqType == "weekly" ? weekdays.sorted() : NSNull()
        payload["interval_days"] = freqType == "interval" ? intervalDays : NSNull()

        Task {
            await store.savePlan(payload: payload, editingId: editing?.id)
            dismiss()
        }
    }
}

// ---- 今日提醒（铃铛） ----
struct RemindersSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 用药提醒
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("用药提醒").font(.headline)
                            Spacer()
                            Text("\(store.todayPending) 项待办").font(.caption).foregroundStyle(Color.appGray)
                        }
                        if store.todayTasks.isEmpty {
                            Text("今天没有用药提醒")
                                .font(.subheadline).foregroundStyle(Color.appGray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            ForEach(store.todayTasks) { task in
                                HStack(spacing: 10) {
                                    Text(remindTime(task)).font(.subheadline.bold())
                                        .foregroundStyle(Color(red: 45/255, green: 89/255, blue: 73/255))
                                        .frame(width: 52, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.plan.drug).font(.subheadline.weight(.medium))
                                        Text("用药 \(task.time)\(task.plan.dose.map { " · \($0)" } ?? "")\(remindDesc(task))")
                                            .font(.caption).foregroundStyle(Color.appGray)
                                    }
                                    Spacer()
                                    StatusPill(status: task.status)
                                }
                                .padding(12)
                                .cardStyle()
                            }
                        }
                    }

                    // 健康提示
                    VStack(alignment: .leading, spacing: 10) {
                        Text("健康提示").font(.headline)
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "leaf").foregroundStyle(Color(red: 79/255, green: 139/255, blue: 112/255))
                            Text(store.careTip).font(.caption)
                                .foregroundStyle(Color(red: 82/255, green: 101/255, blue: 93/255))
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 229/255, green: 238/255, blue: 233/255))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // 本地通知说明
                    VStack(alignment: .leading, spacing: 10) {
                        Text("本地通知提醒").font(.headline)
                        Text("App 会按计划的用药时间（含提前量）发送本地通知，通知上可直接点「已喂」完成打卡。计划变更后自动重排，无需联网。")
                            .font(.caption).foregroundStyle(Color.appGray)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 234/255, green: 243/255, blue: 238/255))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }
                .padding(20)
            }
            .background(Color.appBg)
            .navigationTitle("今日提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }

    private func remindTime(_ task: DoseTask) -> String {
        let (h, m) = DateKit.remindTime(of: task.time, before: task.plan.remindBefore ?? 0)
        return String(format: "%02d:%02d", h, m)
    }
    private func remindDesc(_ task: DoseTask) -> String {
        let b = task.plan.remindBefore ?? 0
        return b > 0 ? " · 提前\(b)分钟提醒" : " · 准时提醒"
    }
}
