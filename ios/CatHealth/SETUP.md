# CatHealth iOS 安装与配置指南（v2.0）

猫咪健康管理 App（SwiftUI，iOS 17+，全中文界面，自然绿系设计）。
与网页版共用同一套 Supabase 数据库，数据实时互通。
**零第三方依赖**（不需要配 SPM/CocoaPods），源码已通过 iOS SDK 全量类型检查。

本目录只包含 Swift 源码（扁平结构），不包含 Xcode 工程文件——按下面步骤建工程、拖文件，约 10 分钟搞定。

---

## 一、新建 Xcode 工程

1. 打开 Xcode → **Create New Project** → **iOS → App** → Next
2. 填写：
   - **Product Name**: `CatHealth`
   - **Team**: 选你的 Personal Team（Xcode → Settings → Accounts 添加免费 Apple ID 后自动出现）
   - **Organization Identifier**: 随意，如 `com.neomatay`
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Storage**: **None**
3. 保存位置随意（如桌面）

## 二、导入源码

1. 在 Xcode 左侧文件树里，**删除**模板自动生成的 `CatHealthApp.swift` 和 `ContentView.swift`（选 Move to Trash）
2. 把本目录下全部 **12 个 .swift 文件**拖入 Xcode 左侧 `CatHealth` 组里
   - 拖入时勾选 **Copy items if needed**，Target 勾选 `CatHealth`

## 三、配置

1. 打开 `Config.swift`：**Supabase 地址和 key 已经填好**（与网页版同一个项目），无需改动
2. 首次启动会让你**创建或加入家庭**：
   - 想直接用网页版已有的数据 → 选「加入」，粘贴网页版"家庭"页里的**家庭码**
   - 加入后猫咪、体重、体温、用药计划全部同步过来

## 四、装到 iPhone（免费 Apple ID）

1. 用数据线连接 iPhone → iPhone 上点"信任此电脑"
2. Xcode 顶部设备栏选你的 iPhone
3. 左侧选中项目 → Signing & Capabilities → Team 选你的 Personal Team（勾选 Automatically manage signing）
4. 首次会提示注册设备，点 **Register Device**
5. ▶ Run。若 iPhone 提示"不受信任的开发者"：设置 → 通用 → VPN与设备管理 → 信任你的 Apple ID

## 五、通知权限（用药提醒的核心）

- 首次启动 App 会请求通知权限，**请务必允许**
- 之后 App 会按用药计划的"用药时间 - 提前量"自动发送本地通知
- **锁屏长按通知 → 「已喂」可直接打卡**，不用打开 App
- 三种频次都支持：每天 / 每周固定几天 / 每 N 天（每N天为预生成 45 天触发器，每次回前台自动滚动续期）

## 六、每 7 天续签（免费账号限制）

免费 Apple ID 签名的 App **7 天后会过期打不开**：重新连上 Mac，Xcode 里点一次 ▶ Run 即可（**数据在 Supabase 云端，不会丢**）。想免维护需 $99/年付费开发者账号。

---

## 文件结构

| 文件 | 说明 |
|---|---|
| `CatHealthApp.swift` | App 入口、根视图、Tab+FAB、家庭设置页 |
| `Config.swift` | Supabase 配置、家庭码存储 |
| `Theme.swift` | 绿系设计系统（颜色/状态徽章/组件） |
| `Models.swift` | 数据模型 + 日期/频次工具（DateKit） |
| `SupabaseService.swift` | REST 客户端（零依赖 URLSession） |
| `DataStore.swift` | 应用状态与全部业务逻辑 |
| `NotificationManager.swift` | 本地用药通知引擎（三频次/提前量/快捷打卡） |
| `HomeView.swift` | 首页（照片卡/用药焦点/指标/时间线） |
| `TrendsView.swift` | 趋势（Swift Charts 折线/摘要/近期记录） |
| `MedsView.swift` | 用药（进度hero/今日剂次/计划/历史折叠） |
| `FamilyView.swift` | 家庭（家庭码/猫咪档案/备份导出） |
| `Sheets.swift` | 全部弹层（记录/猫咪/计划/提醒中心） |

## 与网页版的差异

- 提醒方式：App 用**本地推送通知**（网页版用 .ics 系统日历）
- 备份：App 支持导出 JSON 分享；导入请用网页版
- 首次使用必须创建/加入家庭（暂不支持纯离线模式）

## 常见问题

- **编译报错 "Cannot find XXX in scope"**：检查是否所有 12 个文件都拖进了 Target（点文件 → 右侧 File Inspector → Target Membership 勾选 CatHealth）
- **通知不响**：设置 → 通知 → CatHealth → 允许通知；并确认计划是"进行中"且当天该服药
- **打开闪退/过期**：免费签名 7 天到期，重 Run 一次
- **加入家庭失败**：检查家庭码是否完整（UUID 格式）、手机能否访问 supabase.co
