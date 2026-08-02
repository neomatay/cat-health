import Foundation
import UserNotifications

// ============================================================
// 本地通知引擎：用药提醒（App 的核心优势）
// - 每天/每周固定几天：系统原生重复触发器，一次设置永久生效
// - 每 N 天：预生成未来 45 天的具体日期触发器，回前台时滚动重排
// - 提醒时间 = 用药时间 - 提前量（remind_before）
// - 通知上直接「已喂 / 跳过」快捷打卡，无需打开 App
// ============================================================
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    static let categoryId = "DOSE_REMINDER"
    static let actionTaken = "ACTION_TAKEN"
    static let actionSkipped = "ACTION_SKIPPED"

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
        let taken = UNNotificationAction(identifier: Self.actionTaken, title: "已喂", options: [])
        let skipped = UNNotificationAction(identifier: Self.actionSkipped, title: "跳过", options: [])
        let category = UNNotificationCategory(identifier: Self.categoryId, actions: [taken, skipped], intentIdentifiers: [])
        center.setNotificationCategories([category])
    }

    func requestAuth() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// 按计划全量重排（计划增删改、回前台、打卡后调用）
    func reschedule(plans: [MedPlan], cats: [Cat]) {
        center.removeAllPendingNotificationRequests()
        let today = DateKit.today()
        var requests: [UNNotificationRequest] = []

        for plan in plans where plan.active && plan.startDate <= today && (plan.endDate == nil || plan.endDate! >= today) {
            let catName = cats.first(where: { $0.id == plan.catId })?.name ?? "猫咪"
            let before = plan.remindBefore ?? 0
            let freq = plan.freqType ?? "daily"

            for time in plan.remindTimes {
                let (h, m) = DateKit.remindTime(of: time, before: before)
                let content = UNMutableNotificationContent()
                content.title = "该给\(catName)喂药了"
                let dosePart = (plan.dose ?? "").isEmpty ? "" : " · \(plan.dose!)"
                content.body = "\(plan.drug)\(dosePart)（用药时间 \(time)）"
                content.sound = .default
                content.categoryIdentifier = Self.categoryId
                content.userInfo = ["planId": plan.id, "catId": plan.catId, "time": time]

                if freq == "weekly" {
                    // 每周固定几天：每个选中的星期一个重复触发器
                    for wd in plan.weekdays ?? [] {
                        var c = DateComponents()
                        c.weekday = wd + 1  // 模型 0=周日 → 系统 1=周日
                        c.hour = h; c.minute = m
                        requests.append(UNNotificationRequest(
                            identifier: "\(plan.id)-\(time)-w\(wd)", content: content,
                            trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true)))
                    }
                } else if freq == "interval" {
                    // 每 N 天：预生成未来 45 天内的服药日（回前台时重排滚动续期）
                    for offset in 0..<45 {
                        let dateStr = DateKit.date(offset)
                        guard DateKit.isDoseDay(plan, on: dateStr) else { continue }
                        var c = Calendar.current.dateComponents([.year, .month, .day], from: DateKit.parse(dateStr))
                        c.hour = h; c.minute = m
                        requests.append(UNNotificationRequest(
                            identifier: "\(plan.id)-\(time)-\(dateStr)", content: content,
                            trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false)))
                    }
                } else {
                    // 每天
                    var c = DateComponents()
                    c.hour = h; c.minute = m
                    requests.append(UNNotificationRequest(
                        identifier: "\(plan.id)-\(time)-d", content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true)))
                }
            }
        }

        // iOS 待推送上限 64 条，留余量截断
        for req in requests.prefix(60) {
            center.add(req)
        }
    }

    /// 前台也弹横幅
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// 通知快捷操作：已喂/跳过（锁屏长按即可打卡）
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let planId = info["planId"] as? String,
           let catId = info["catId"] as? String,
           let time = info["time"] as? String {
            if response.actionIdentifier == Self.actionTaken || response.actionIdentifier == Self.actionSkipped {
                let status = response.actionIdentifier == Self.actionTaken ? "taken" : "skipped"
                Task {
                    await writeDoseLogFromNotification(planId: planId, catId: catId, time: time, status: status)
                    await MainActor.run {
                        NotificationCenter.default.post(name: .doseLoggedFromNotification, object: nil)
                    }
                }
            }
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let doseLoggedFromNotification = Notification.Name("doseLoggedFromNotification")
}
