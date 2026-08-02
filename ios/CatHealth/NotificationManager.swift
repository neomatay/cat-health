import Foundation
import UserNotifications

/// 本地通知管理：用药提醒的授权、排期、以及通知按钮（已喂/跳过）的处理。
///
/// 设计说明：
/// - 每个 active 计划 × 每个提醒时间 = 一条 UNCalendarNotificationTrigger（每天重复）。
/// - 计划增删改后调用 rescheduleAll()，清空重建（个人 App 通知数量极少，无压力）。
/// - 通知 category 带「已喂」「跳过」两个 action，点击后直接写入 med_logs，
///   由 AppDelegate 在启动/回前台时把响应转交给 DataStore 处理。
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    static let categoryId = "MED_REMINDER"
    static let actionTaken = "MED_TAKEN"
    static let actionSkipped = "MED_SKIPPED"

    /// 由 DataStore 注入：处理「已喂 / 跳过」动作（写 med_logs）
    var logHandler: ((_ planId: UUID, _ catId: UUID, _ scheduledTime: String, _ status: MedLogStatus) -> Void)?

    /// 由 DataStore 注入：通过 planId 查计划（处理响应时需要药品/猫名等信息时可扩展）
    var planLookup: ((UUID) -> MedPlan?)?
    var catLookup: ((UUID) -> Cat?)?

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    /// 在 App 启动时调用：注册 category、设置代理、请求授权
    func setup() {
        center.delegate = self

        let taken = UNNotificationAction(identifier: Self.actionTaken, title: "已喂", options: [])
        let skipped = UNNotificationAction(identifier: Self.actionSkipped, title: "跳过", options: [])
        let category = UNNotificationCategory(identifier: Self.categoryId,
                                              actions: [taken, skipped],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])

        requestAuthorization()
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error { print("[通知] 授权请求失败: \(error.localizedDescription)") }
            print("[通知] 授权结果: \(granted ? "已允许" : "被拒绝")")
        }
    }

    // MARK: - 重排所有提醒

    /// 根据当前计划与猫列表重建全部本地通知
    func rescheduleAll(plans: [MedPlan], cats: [Cat]) {
        center.removeAllPendingNotificationRequests()

        let today = DateKit.today
        var requests: [UNNotificationRequest] = []

        for plan in plans where plan.active {
            // 已结束的计划不再提醒
            if let end = plan.endDate, end < today { continue }
            guard !plan.remindTimes.isEmpty else { continue }
            let catName = cats.first(where: { $0.id == plan.catId })?.name ?? "猫咪"

            for time in plan.remindTimes {
                let parts = time.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2 else { continue }

                let content = UNMutableNotificationContent()
                content.title = "该给\(catName)喂\(plan.drug)了"
                content.body = "剂量：\(plan.dose)（计划 \(time)）"
                content.sound = .default
                content.categoryIdentifier = Self.categoryId
                content.userInfo = [
                    "planId": plan.id.uuidString,
                    "catId": plan.catId.uuidString,
                    "scheduledTime": time
                ]

                var comps = DateComponents()
                comps.hour = parts[0]
                comps.minute = parts[1]
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

                // identifier 稳定：planId-time，便于调试
                let req = UNNotificationRequest(identifier: "\(plan.id.uuidString)-\(time)",
                                                content: content, trigger: trigger)
                requests.append(req)
            }
        }

        for req in requests {
            center.add(req) { error in
                if let error { print("[通知] 排期失败: \(error.localizedDescription)") }
            }
        }
        print("[通知] 已重排 \(requests.count) 条用药提醒")
    }

    // MARK: - 响应处理

    /// App 回到前台时调用：处理冷启动/后台期间积累的通知响应（iOS 会缓存到 delivered 队列，
    /// 但 action 响应只会回调一次；这里主要兜底 scenePhase 切换时刷新数据）
    func handlePendingResponses() {
        // UNUserNotificationCenter 对未处理的 action 响应会投递给 delegate，
        // 正常路径在 didReceive 中已处理。此方法预留扩展（如读取 deliveredNotifications 做补记）。
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// App 在前台时也展示横幅提醒
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    /// 用户点击通知本体或 action 按钮
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let planId = (info["planId"] as? String).flatMap(UUID.init)
        let catId = (info["catId"] as? String).flatMap(UUID.init)
        let time = info["scheduledTime"] as? String ?? ""

        switch response.actionIdentifier {
        case Self.actionTaken:
            if let planId, let catId {
                DispatchQueue.main.async { [weak self] in
                    self?.logHandler?(planId, catId, time, .taken)
                }
            }
        case Self.actionSkipped:
            if let planId, let catId {
                DispatchQueue.main.async { [weak self] in
                    self?.logHandler?(planId, catId, time, .skipped)
                }
            }
        default:
            // 点击通知本体：仅打开 App，不写记录
            break
        }
        completionHandler()
    }
}
