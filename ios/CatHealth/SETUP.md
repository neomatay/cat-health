# CatHealth iOS 安装与配置指南

猫咪健康管理 App（SwiftUI，iOS 17+，全中文界面）。与网页版共用同一套 Supabase 数据表。
本目录只包含 Swift 源码（扁平结构），**不包含 Xcode 工程文件** —— 请按下面步骤自己建工程、把文件拖进去，5 分钟搞定。

---

## 一、新建 Xcode 工程

1. 打开 Xcode → **Create New Project** → **iOS → App** → Next
2. 填写：
   - **Product Name**: `CatHealth`
   - **Team**: 选你的 Personal Team（免费 Apple ID 登录后自动出现；没有就先到 Xcode → Settings → Accounts 添加 Apple ID）
   - **Organization Identifier**: 随意，如 `com.yourname`（Bundle ID 全局唯一即可）
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Storage**: **None**（重要！不要选 SwiftData/Core Data，模板代码会冲突）
   - Include Tests：可不勾
3. 保存位置随意（比如 `~/Developer/CatHealth`）。
4. 设置最低系统版本：选中工程 → TARGETS → CatHealth → General → **Minimum Deployments → iOS 17.0**。

## 二、替换模板文件

模板会自动生成 `CatHealthApp.swift` 和 `ContentView.swift`：

1. 在左侧导航器里**删除**这两个文件（选 **Move to Trash**）。
   - 注意：本源码包里的 `CatHealthApp.swift` 会替代它，同名所以必须先删模板的。
2. 把**本目录下全部 10 个 .swift 文件**拖进 Xcode 左侧的 `CatHealth` 分组（与 Info 平级）：
   - 拖入时勾选 **Copy items if needed**，Target 勾选 `CatHealth`。

文件清单：

| 文件 | 作用 |
|---|---|
| `CatHealthApp.swift` | App 入口、AppDelegate、四个 Tab |
| `Config.swift` | Supabase 配置、家庭码、校验范围 |
| `Models.swift` | 数据模型（Codable + SwiftData） |
| `SupabaseService.swift` | Supabase 读写层 |
| `DataStore.swift` | 数据中心（本地/同步双模式） |
| `NotificationManager.swift` | 本地通知 |
| `Components.swift` | 通用小组件 |
| `TodayView.swift` | Tab 1 今天 |
| `TrendsView.swift` | Tab 2 趋势 |
| `MedsView.swift` | Tab 3 用药 |
| `ProfileView.swift` | Tab 4 我的 |

## 三、添加 Supabase 依赖（SPM）

只用本地模式可以跳过这步（代码里有 `#if canImport(Supabase)` 兜底，不加依赖也能编译）。

1. Xcode 菜单 **File → Add Package Dependencies…**
2. 右上角搜索框输入：`https://github.com/supabase/supabase-swift`
3. Dependency Rule 选 **Up to Next Major Version**，版本 `2.0.0` 以上 → Add Package
4. 勾选 **Supabase** 库（只需这一个），Target 选 `CatHealth` → Add Package

## 四、填写 Config.swift（可选，同步模式需要）

不用云端同步可跳过，App 自动以**本地模式**运行，功能完整。

1. 打开 [supabase.com](https://supabase.com) 建免费项目（网页版用的就是同一个项目的话，直接复用）
2. 项目里建好 5 张表（如果网页版已经建过则跳过）：
   - `cats(id uuid pk, family_id uuid, name text, breed text, birthday date)`
   - `weights(id uuid pk, family_id uuid, cat_id uuid, date date, kg float8, note text)`
   - `temps(id uuid pk, family_id uuid, cat_id uuid, date date, celsius float8, note text)`
   - `med_plans(id uuid pk, family_id uuid, cat_id uuid, drug text, dose text, remind_times text[], start_date date, end_date date, active bool, note text)`
   - `med_logs(id uuid pk, family_id uuid, plan_id uuid, cat_id uuid, date date, scheduled_time text, status text, taken_at timestamptz, note text)`
   - 自用建议：每张表的 RLS 策略放开（`alter table xxx enable row level security;` + 允许 anon 全部读写），或干脆 `disable row level security`。家庭码即密码，别泄露即可。
3. Project **Settings → API**：复制 **Project URL** 和 **anon public** key
4. 填到 `Config.swift` 顶部两个常量：
   ```swift
   static let supabaseURL = "https://xxxxxxxx.supabase.co"
   static let supabaseAnonKey = "eyJhbGciOi..."
   ```
5. 装好后：App「我的 → 家庭同步」→ **创建家庭**（自动生成家庭码并上传本地数据）或 **加入家庭**（输入网页版那边的家庭码拉取数据）。

## 五、免费 Apple ID 真机运行

1. iPhone 用数据线连 Mac，解锁并信任电脑
2. Xcode 顶部设备选择器选你的 iPhone
3. 首次会提示签名问题：TARGETS → **Signing & Capabilities** → 勾选 **Automatically manage signing**，Team 选 **Personal Team**
4. 如果报 Bundle ID 冲突，把 Bundle Identifier 改个名（如 `com.yourname.cathealth2`）
5. 点 **Run（▶️）**，首次安装后 iPhone 上会提示「不受信任的开发者」：
   - iPhone → **设置 → 通用 → VPN与设备管理** → 点你的 Apple ID → **信任**
6. 回到桌面打开 App 即可

## 六、通知权限

首次启动会弹通知授权请求，请点**允许**。
用药提醒是**本地通知**（UNCalendarNotificationTrigger 每天重复），不依赖网络、不需要后台刷新：

- 到点弹出「该给{猫名}喂{药品}了」，横幅上**长按/下拉**可直接点「已喂 / 跳过」，App 会自动写入 med_logs
- 新建/编辑/停用/删除计划后自动重排全部通知
- 免费开发者证书下本地通知**不受 7 天签名过期影响**，但 App 本身过期后打不开，需要重新 Run 一次（见下）

## 七、常见问题

**Q: 7 天后 App 打不开了？**
免费 Apple ID 签名有效期 7 天。到期后把 iPhone 连上 Mac，Xcode 里再点一次 **Run** 即可。
**数据不会丢**：同步模式数据在 Supabase 云端；本地模式数据在手机 SwiftData 里，重装签名不删 App 数据。

**Q: 为什么要求 iOS 17？**
SwiftData（本地存储）和部分 SwiftUI API 是 iOS 17 引入的。系统低于 17 的设备无法安装。

**Q: 本地模式和同步模式有什么区别？**
- 本地模式（默认）：数据只存本机 SwiftData，单机使用，功能完整
- 同步模式：直接读写 Supabase，与网页版和其他设备实时互通；**不做离线合并**——同步模式下断网会读写失败（界面会提示错误），有网时自动恢复
- 两种模式互切时本地数据保留；「创建家庭」会把本地数据整体上传到云端

**Q: 编译报错找不到 Supabase？**
确认第三步的 SPM 依赖加在了正确的 Target 上；或者暂时不填 Config、不加依赖，用本地模式先跑起来。

**Q: 想换 Bundle ID / 改图标？**
随意，个人自用项目没有任何硬编码依赖 Bundle ID。

**Q: 通知 action 点了没反应？**
iOS 对通知 action 的回调在 App 被杀掉时会先冷启动 App 再投递，写入 med_logs 后下次打开界面即可见。若完全没记录，检查「设置 → 通知 → CatHealth」是否允许。
