import Foundation
import ServiceManagement
import os.log

/// 开机自启，用系统的登录项服务，会显示在「系统设置 → 通用 → 登录项」里。
enum LoginItem {
    private static let logger = Logger(subsystem: "com.aicent.iPadDisplay", category: "LoginItem")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            logger.error("设置登录项失败：\(error.localizedDescription)")
            return false
        }
    }

    /// 早期版本用 ~/Library/LaunchAgents 下的配置文件自启，换成登录项后删掉它，免得启动两次。
    static func migrateFromLaunchAgent() {
        let legacy = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.aicent.iPadDisplay.plist")
        guard FileManager.default.fileExists(atPath: legacy.path) else { return }
        try? FileManager.default.removeItem(at: legacy)
        setEnabled(true)
    }
}
