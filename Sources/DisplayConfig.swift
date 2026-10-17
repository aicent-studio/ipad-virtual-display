import CoreGraphics

/// 读写系统显示器配置的小工具。
enum DisplayConfig {
    static func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    /// 包含 HiDPI 在内的全部显示模式。
    static func modes(of display: CGDirectDisplayID) -> [CGDisplayMode] {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        return CGDisplayCopyAllDisplayModes(display, options) as? [CGDisplayMode] ?? []
    }

    /// 把若干改动放进一次显示器配置事务里提交。
    @discardableResult
    static func commit(_ option: CGConfigureOption = .forSession, _ changes: (CGDisplayConfigRef?) -> Void) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        changes(config)
        return CGCompleteDisplayConfiguration(config, option) == .success
    }
}
