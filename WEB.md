# 猫咪健康 PWA

个人家庭猫咪体重、体温、用药日常管理 PWA 网页应用。界面全中文，移动端优先，适配 iPhone Safari「添加到主屏幕」使用。

## 功能概览

- **今天**：多猫切换、今日用药打卡（喂了/跳过/超时标红）、快速记录体重体温、最近 5 条记录
- **趋势**：体重/体温折线图（ECharts），体温标注 38.0-39.2°C 正常区间，近 7 天/30 天/全部切换，统计卡
- **用药**：计划列表与完药率、新增/编辑/停用计划、一键生成 .ics 提醒日历（iOS 系统日历按时提醒）
- **我的**：猫咪管理、家庭同步（创建/加入家庭码）、数据导出导入 JSON 备份

## 双模式存储

- **本地模式**：未配置 Supabase 时，数据存 localStorage，开箱即用
- **同步模式**：配置 Supabase 后，可创建家庭（生成 UUID 作 family_id 并上传本地数据）或加入家庭（输入家庭码拉取数据），多设备共享

## 本地预览

```bash
cd cat-health/web
python3 -m http.server 8080
# 浏览器打开 http://localhost:8080
```

或用任意静态服务器（如 `npx serve`）。直接双击 `index.html` 也可用，但建议通过 HTTP 访问以获得完整 PWA 体验。

## 配置 Supabase 云端同步（可选）

1. 访问 [supabase.com](https://supabase.com) 注册并创建新项目
2. 进入项目 **SQL Editor**，将 `supabase-setup.sql` 全部内容粘贴执行（建表 + 启用 RLS + 宽松策略）
3. 进入 **Project Settings → API**，复制 **Project URL** 和 **anon public key**
4. 编辑 `js/config.js`，填入：
   ```js
   window.CAT_HEALTH_CONFIG = {
     SUPABASE_URL: 'https://你的项目.supabase.co',
     SUPABASE_ANON_KEY: '你的anon-key'
   };
   ```
5. 刷新页面，进入「我的」页即可「创建家庭」或「加入家庭」

> **安全说明**：`supabase-setup.sql` 使用宽松 RLS 策略（anon 全部读写），family_id 即访问凭证。知道家庭码即可访问对应数据。适合个人家庭项目，不建议用于敏感数据场景。

## 部署到 GitHub Pages

1. 在 GitHub 创建仓库，名称建议为 `cat-health`
2. 将本仓库所有文件推送至仓库根目录（index.html 必须位于仓库根目录）
3. 进入仓库 **Settings → Pages**，Source 选 `Deploy from a branch`，分支选 `main`、目录选 `/ (root)`，保存
4. 等待数分钟，访问 `https://用户名.github.io/cat-health/`
5. 在 iPhone Safari 打开上述地址，点击底部「分享」按钮 →「添加到主屏幕」

> 如果部署在子路径（如 `/cat-health/`），`manifest.json` 和 `icon.svg` 使用相对路径 `./`，无需额外配置。

## 添加到主屏幕（iPhone）

1. 在 Safari 打开应用地址
2. 点击底部「分享」图标
3. 滚动选择「添加到主屏幕」
4. 确认，桌面出现「猫咪健康」图标，点击全屏运行

## 订阅 .ics 用药提醒

1. 进入「用药」Tab，点击对应计划的「📅 生成提醒日历」按钮
2. 浏览器下载 `.ics` 文件
3. 点击下载的文件 → 选择「添加到日历」
4. iOS 系统日历将按计划时间每天提醒，有结束日期的计划到期自动停止

## 数据模型

| 表名 | 说明 |
|------|------|
| cats | 猫咪（名字、品种、生日） |
| weights | 体重记录（日期、kg、备注） |
| temps | 体温记录（日期、°C、备注） |
| med_plans | 用药计划（药品、剂量、提醒时间数组、起止、长期开关） |
| med_logs | 用药打卡（计划、日期、时间、状态 taken/skipped/missed、打卡时间） |

所有表含 `family_id` 列，family_id 即家庭码。

## 技术栈

- Vue 3 (global build, CDN)
- ECharts 5 (CDN)
- @supabase/supabase-js v2 (CDN)
- 纯静态文件，无构建工具，GitHub Pages 直接可跑
- manifest.json PWA + SVG 图标

## 文件结构

```
cat-health/             # 仓库根目录（网页文件直接在根目录）
├── index.html          # 主页（Vue 模板 + CDN 引入）
├── manifest.json       # PWA 清单
├── icon.svg            # 应用图标
├── supabase-setup.sql  # Supabase 建表 + RLS 脚本
├── css/style.css       # 移动端 iOS 风格样式
├── js/
│   ├── config.js       # Supabase 配置占位
│   ├── store.js        # 数据层（本地/远端透明读写）
│   └── app.js          # Vue 应用逻辑
└── README.md
```

## 已知限制

- 本地模式数据仅存于单设备浏览器 localStorage，清除浏览器数据会丢失（建议定期导出备份）
- Supabase 宽松 RLS 策略下，知道家庭码即可读写数据，非安全场景
- .ics 提醒依赖系统日历，iOS 需手动添加日历事件
- 图标为 SVG 格式，部分旧版 iOS 可能显示为默认图标
- 不支持 push 推送通知（需原生 App 或 Service Worker push，超出本项目范围）
