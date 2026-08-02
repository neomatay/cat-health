# 🐱 猫咪健康管理工具

记录毛孩子的体重、体温、用药，看趋势、准点提醒喂药。支持**家人共享记录**。

## 两个版本，一套数据

```
                Supabase 云数据库（免费）
                 ↕               ↕
        📱 iOS 原生 App      🌐 PWA 网页版
        （你自己用）          （你和家人都用）
        ios/                 仓库根目录（index.html 等）
```

- **iOS App**（`ios/`）：SwiftUI 原生应用，本地通知提醒喂药，体验最好。需要 Mac + Xcode 编译安装（免费 Apple ID 即可，7 天续签一次）
- **PWA 网页版**（仓库根目录的 `index.html` 等文件）：纯静态网页，GitHub Pages 免费托管，Safari 打开 → 添加到主屏幕。**家人不用装任何东西，打开网址输入家庭码就能一起记录**
- 两个版本读写**同一个 Supabase 数据库**，数据实时互通

## 一次性准备（约 15 分钟）

### 第 1 步：创建 Supabase 项目（家庭共享数据库）

1. 打开 [supabase.com](https://supabase.com)，用 GitHub 账号（neoma_tay@gmail.com）登录
2. New Project → 起名（如 `cat-health`）→ 设置数据库密码（记好）→ Region 选 `Singapore` → 等 2 分钟初始化
3. 左侧 **SQL Editor** → 把 `supabase-setup.sql` 的内容粘贴进去 → Run
4. 左侧 **Project Settings → API**，复制两样东西：
   - `Project URL`
   - `anon` `public` key
5. 把它们填到：
   - `js/config.js`
   - `ios/CatHealth/Config.swift`

> 安全说明：本项目用"家庭码"（family UUID）作为访问凭证，知道家庭码的人才能读写你家数据，个人家庭使用足够。不要把家庭码发到公开场所。

### 第 2 步：部署网页版（给家人用）

详见 `WEB.md`。简要：

1. GitHub 新建仓库 `cat-health`，把本仓库根目录的文件传上去（index.html 必须在根目录）
2. 仓库 Settings → Pages → Source 选 `main` 分支根目录 → Save
3. 等 1 分钟，访问 `https://<你的用户名>.github.io/cat-health/`
4. iPhone Safari 打开 → 分享按钮 → **添加到主屏幕**
5. 把网址 + 家庭码发给家人，他们打开 → 输入家庭码 → 完成

### 第 3 步：安装 iOS App（你自己用）

详见 `ios/CatHealth/SETUP.md`。简要：

1. Xcode 新建 iOS App 工程（SwiftUI），把 `ios/CatHealth/` 下的 `.swift` 文件拖进去
2. SPM 添加依赖 `supabase-swift`
3. 填入 Config.swift 的 URL 和 Key，连上 iPhone 点 Run
4. 之后每 7 天连上 Mac 重新 Run 一次（数据在云端，不丢）

## 功能一览

| 功能 | 网页版 | iOS App |
|---|---|---|
| 记体重/体温 | ✅ | ✅ |
| 体重/体温趋势图（体温带正常区间） | ✅ | ✅ |
| 用药计划（每天 N 次、起止日期/长期） | ✅ | ✅ |
| 喂药打卡（已喂/跳过/错过标红） | ✅ | ✅ |
| 完药率统计 | ✅ | ✅ |
| 用药提醒 | 系统日历订阅（.ics） | 本地推送通知（可点"已喂"快捷打卡） |
| 多猫支持 | ✅ | ✅ |
| 家人共享（家庭码） | ✅ | ✅ |
| 数据导出备份 | ✅ JSON | ✅ JSON |
| 未配置云端时纯本地使用 | ✅ localStorage | ✅ SwiftData |

## 数据模型

| 表 | 说明 |
|---|---|
| `cats` | 猫咪档案（名字、品种、生日） |
| `weights` | 体重记录（kg） |
| `temps` | 体温记录（°C） |
| `med_plans` | 用药计划（药品、剂量、提醒时间、起止） |
| `med_logs` | 每次喂药打卡（已喂/跳过/错过） |

所有表带 `family_id`，同一个家庭码的数据互通。
