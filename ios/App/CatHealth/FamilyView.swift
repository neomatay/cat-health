import SwiftUI

// ============================================================
// 家庭页：共享 banner / 猫咪档案 / 权限说明 / 数据备份 / 关于
// ============================================================
struct FamilyView: View {
    @EnvironmentObject var store: DataStore
    @State private var editingCat: Cat?
    @State private var showAddCat = false
    @State private var showJoin = false
    @State private var joinCode = ""
    @State private var showShare = false
    @State private var showLeaveConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heading
                    sharingBanner
                    catsSection
                    permissionGrid
                    backupSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(Color.appBg)
            .navigationBarHidden(true)
        }
        .sheet(item: $editingCat) { cat in CatSheet(editing: cat) }
        .sheet(isPresented: $showAddCat) { CatSheet(editing: nil) }
        .sheet(isPresented: $showJoin) { joinSheet }
        .sheet(isPresented: $showShare) {
            if let text = Optional(store.exportJSON()) {
                ShareLink(item: text) {
                    Label("分享备份文件", systemImage: "square.and.arrow.up")
                }
                .padding()
                .presentationDetents([.height(120)])
            }
        }
    }

    private var heading: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("家庭共享").font(.subheadline).foregroundStyle(Color.appGray)
                Text("一起照顾\(store.currentCat?.name ?? "毛孩子")").font(.largeTitle.bold())
            }
            Spacer()
            Button { showJoin = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.body)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appLine, lineWidth: 1))
            }
            .foregroundStyle(Color.primary)
        }
        .padding(.top, 18).padding(.bottom, 16)
    }

    // 共享 banner
    private var sharingBanner: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color(red: 69/255, green: 118/255, blue: 139/255))
                Image(systemName: "person.2").font(.title3).foregroundStyle(Color(red: 255/255, green: 246/255, blue: 214/255))
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text("云端同步已开启").font(.caption).foregroundStyle(Color(red: 201/255, green: 224/255, blue: 232/255))
                Text("家庭码共享中").font(.subheadline.bold())
                Text(Config.familyId ?? "")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Button {
                        UIPasteboard.general.string = Config.familyId
                        store.showToast("已复制")
                    } label: { bannerBtn("复制家庭码") }
                    Button { showJoin = true } label: { bannerBtn("加入其他家庭") }
                }
                .padding(.top, 4)
            }
        }
        .foregroundStyle(.white)
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBlue)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func bannerBtn(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.5), lineWidth: 1))
    }

    // 猫咪档案
    private var catsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("猫咪档案").font(.headline)
                Spacer()
                Button { showAddCat = true } label: {
                    HStack(spacing: 3) {
                        Text("添加"); Image(systemName: "plus").font(.caption2)
                    }
                    .font(.subheadline).foregroundStyle(Color.appGreen)
                }
            }
            .padding(.bottom, 6)

            if store.cats.isEmpty {
                Text("暂无猫咪档案")
                    .font(.subheadline).foregroundStyle(Color.appGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.cats) { cat in
                        Button { editingCat = cat } label: {
                            HStack(spacing: 11) {
                                CatAvatar(avatar: cat.avatar, size: 42, radius: 12)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(cat.name).font(.subheadline.weight(.medium)).foregroundStyle(Color.primary)
                                    Text(catDetail(cat)).font(.caption).foregroundStyle(Color.appGray)
                                }
                                Spacer()
                                Image(systemName: "pencil").font(.caption).foregroundStyle(Color.appGray)
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

    private func catDetail(_ cat: Cat) -> String {
        var s = cat.breed ?? "品种未知"
        let age = DateKit.catAge(cat)
        if !age.isEmpty { s += " · \(age)" }
        if let b = cat.birthday, !b.isEmpty { s += " · 生日 \(b)" }
        return s
    }

    // 权限说明
    private var permissionGrid: some View {
        HStack(spacing: 10) {
            permCard("shield.lefthalf.filled", "可记录", "新增健康数据、确认用药", green: true)
            permCard("heart", "仅查看", "查看趋势和完整历史", green: false)
        }
        .padding(.top, 20)
    }

    private func permCard(_ icon: String, _ title: String, _ desc: String, green: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(green ? Color(red: 62/255, green: 130/255, blue: 101/255) : Color(red: 82/255, green: 127/255, blue: 171/255))
            Text(title).font(.caption.bold())
            Text(desc).font(.caption2).foregroundStyle(Color.appGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(green ? Color(red: 106/255, green: 159/255, blue: 136/255) : Color(red: 122/255, green: 155/255, blue: 193/255))
                .frame(width: 3)
        }
    }

    // 数据备份
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("数据备份").font(.headline)
            HStack(spacing: 10) {
                ShareLink(item: store.exportJSON()) {
                    Label("导出 JSON", systemImage: "tray.and.arrow.down")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity).frame(height: 41)
                        .foregroundStyle(Color(red: 88/255, green: 112/255, blue: 103/255))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(red: 215/255, green: 227/255, blue: 220/255), lineWidth: 1))
                }
                Button { showLeaveConfirm = true } label: {
                    Label("更换家庭", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity).frame(height: 41)
                        .foregroundStyle(Color(red: 88/255, green: 112/255, blue: 103/255))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(red: 215/255, green: 227/255, blue: 220/255), lineWidth: 1))
                }
                .confirmationDialog("更换家庭", isPresented: $showLeaveConfirm) {
                    Button("加入其他家庭") { showJoin = true }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("加入新家庭后，将展示新家庭的数据。")
                }
            }
        }
        .padding(.top, 24)
    }

    // 关于
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("关于").font(.headline)
            Text("猫咪健康 App v2.0\n数据存储于你的设备与家庭云端，不上传任何第三方。")
                .font(.caption).foregroundStyle(Color.appGray)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 238/255, green: 242/255, blue: 239/255))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.top, 24)
    }

    // 加入家庭弹层
    private var joinSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("输入家人分享的家庭码（UUID），加入后将展示该家庭的数据。")
                    .font(.caption).foregroundStyle(Color.appGray)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 234/255, green: 243/255, blue: 238/255))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                TextField("粘贴家庭码", text: $joinCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .padding(11)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.appLine, lineWidth: 1))
                Button {
                    let fid = joinCode.trimmingCharacters(in: .whitespaces)
                    guard !fid.isEmpty else { return }
                    Config.familyId = fid
                    showJoin = false
                    Task {
                        await store.loadCats()
                        store.showToast("已加入家庭")
                    }
                } label: {
                    Text("加入")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(Color.appGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Spacer()
            }
            .padding(20)
            .background(Color.appBg)
            .navigationTitle("加入家庭")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showJoin = false } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}
