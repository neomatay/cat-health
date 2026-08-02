import SwiftUI

/// Tab 4「我的」：猫咪管理、家庭同步、数据导出
struct ProfileView: View {
    @EnvironmentObject private var store: DataStore

    @State private var showAddCat = false
    @State private var editingCat: Cat?
    @State private var catPendingDelete: Cat?
    @State private var showDeleteCatConfirm = false
    @State private var familyCodeInput = ""
    @State private var showJoinField = false
    @State private var showLeaveConfirm = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                // 当前模式
                Section {
                    HStack {
                        Label(store.mode.rawValue,
                              systemImage: store.mode == .synced ? "icloud.fill" : "iphone")
                        Spacer()
                        if store.isLoading { ProgressView() }
                    }
                    .foregroundStyle(store.mode == .synced ? .blue : .secondary)
                }

                // 猫咪管理
                Section {
                    ForEach(store.cats) { cat in
                        Button {
                            editingCat = cat
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.name).font(.headline)
                                    HStack(spacing: 8) {
                                        if let breed = cat.breed, !breed.isEmpty {
                                            Text(breed)
                                        }
                                        if let age = cat.ageText {
                                            Text(age)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.selectedCatId == cat.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                catPendingDelete = cat
                                showDeleteCatConfirm = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        showAddCat = true
                    } label: {
                        Label("添加猫咪", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("猫咪管理")
                } footer: {
                    if !store.cats.isEmpty {
                        Text("点按猫咪可编辑；左滑可删除（会一并删除它的全部记录）")
                    }
                }

                // 家庭同步
                Section {
                    if !Config.isSupabaseConfigured {
                        Text("本地模式可用全部功能。如需多设备/网页版同步，请按 SETUP.md 在 Config.swift 中填写 Supabase 配置后重新编译。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let familyId = Config.familyId {
                        // 已加入家庭：显示家庭码，可分享、可退出
                        VStack(alignment: .leading, spacing: 6) {
                            Text("家庭码")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(familyId.uuidString)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }

                        ShareLink(item: "猫咪健康家庭码：\(familyId.uuidString)\n在 App「我的 → 加入家庭」中输入即可同步数据") {
                            Label("分享家庭码", systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            showLeaveConfirm = true
                        } label: {
                            Label("退出家庭（回到本地模式）", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        Button {
                            Task { _ = await store.createFamily() }
                        } label: {
                            Label("创建家庭（上传本地数据到云端）", systemImage: "icloud.and.arrow.up")
                        }
                        .disabled(store.isLoading)

                        Button {
                            showJoinField.toggle()
                        } label: {
                            Label("加入家庭（输入家庭码）", systemImage: "person.badge.plus")
                        }

                        if showJoinField {
                            HStack {
                                TextField("粘贴家庭码 UUID", text: $familyCodeInput)
                                    .font(.caption.monospaced())
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                Button("加入") {
                                    Task { _ = await store.joinFamily(code: familyCodeInput) }
                                }
                                .disabled(familyCodeInput.trimmingCharacters(in: .whitespaces).isEmpty || store.isLoading)
                            }
                        }
                    }
                } header: {
                    Text("家庭同步")
                } footer: {
                    Text("与网页版共用同一套 Supabase 数据表，家庭码一致即可互通。")
                }

                // 数据导出
                Section {
                    if let url = exportURL {
                        ShareLink(item: url) {
                            Label("导出数据（JSON）", systemImage: "doc.zipper")
                        }
                    } else {
                        Button {
                            exportURL = store.exportJSONFile()
                        } label: {
                            Label("导出数据（JSON）", systemImage: "doc.zipper")
                        }
                    }

                    HStack {
                        Text("数据量")
                        Spacer()
                        Text("体重 \(store.weights.count) · 体温 \(store.temps.count) · 喂药 \(store.logs.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("数据")
                }

                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0 · 个人自用")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showAddCat) {
                CatEditSheet(cat: nil)
            }
            .sheet(item: $editingCat) { cat in
                CatEditSheet(cat: cat)
            }
            .confirmationDialog("确定删除「\(catPendingDelete?.name ?? "")」？",
                                isPresented: $showDeleteCatConfirm,
                                titleVisibility: .visible) {
                Button("删除猫咪及全部记录", role: .destructive) {
                    if let cat = catPendingDelete {
                        Task { await store.deleteCat(cat) }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("该猫咪的体重、体温、用药计划和喂药记录都会被删除，不可恢复。")
            }
            .confirmationDialog("退出家庭？",
                                isPresented: $showLeaveConfirm,
                                titleVisibility: .visible) {
                Button("退出家庭", role: .destructive) {
                    store.leaveFamily()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("退出后回到本地模式，云端数据不受影响，可随时用家庭码重新加入。")
            }
        }
    }
}

// MARK: - 猫咪新增/编辑 Sheet（今天页空态也复用）

struct CatEditSheet: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let cat: Cat?   // nil = 新建

    @State private var name = ""
    @State private var breed = ""
    @State private var hasBirthday = false
    @State private var birthday = Date()

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(cat: Cat?) {
        self.cat = cat
        if let cat {
            _name = State(initialValue: cat.name)
            _breed = State(initialValue: cat.breed ?? "")
            _hasBirthday = State(initialValue: cat.birthday != nil)
            _birthday = State(initialValue: cat.birthday ?? Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名字，如 咪咪", text: $name)
                    TextField("品种（可选），如 英短", text: $breed)
                }

                Section("生日") {
                    Toggle("记录生日", isOn: $hasBirthday)
                    if hasBirthday {
                        DatePicker("生日", selection: $birthday, in: ...Date(), displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(cat == nil ? "添加猫咪" : "编辑猫咪")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let newCat = Cat(
            id: cat?.id ?? UUID(),
            familyId: store.currentFamilyId,
            name: name.trimmingCharacters(in: .whitespaces),
            breed: breed.isEmpty ? nil : breed,
            birthday: hasBirthday ? birthday : nil
        )
        Task {
            await store.saveCat(newCat)
            dismiss()
        }
    }
}
