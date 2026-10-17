import CoreGraphics
import Foundation
import os.log

/// 按用户设置维护 iPad 虚拟屏：创建、切分辨率、镜像实体屏、睡眠唤醒后重建。
/// 换型号、显示大小时只切分辨率；只有换方向时才重建虚拟屏——
/// 系统镜像时会从虚拟屏已有的分辨率里挑，横屏建出来的屏换成竖屏后不能用来做竖屏镜像；
/// UU远程也按第一次看到这块屏时的方向固定画面比例，同一块屏转向后四周会留大片黑边。
final class ScreenController {
    static let shared = ScreenController()

    private let logger = Logger(subsystem: "com.aicent.iPadDisplay", category: "Screen")
    private var screen: VirtualScreen?
    private var screenIsPortrait: Bool?
    private var pendingSync: Timer?
    private var pendingWakeRebuild: Timer?

    private(set) var lastError: String?

    private init() {}

    func update(with settings: Settings) {
        // 「不适配」不建虚拟屏。开着「远程时自动镜像」时不远程就是这一档，
        // 平时只有实体屏，窗口不会被拖到看不见的虚拟屏上
        let shouldExist = settings.isEnabled && settings.displayMode != .original
        guard shouldExist else {
            tearDown()
            return
        }

        let mirroring = settings.displayMode == .adapt
        let rebuilding = screen == nil || screenIsPortrait != settings.isPortrait
        if rebuilding {
            tearDown()
            guard let created = VirtualScreen(maxPixels: Self.maxPixels, ppi: settings.model.ppi) else {
                fail("无法创建虚拟屏")
                return
            }
            screen = created
            screenIsPortrait = settings.isPortrait
        }
        guard let screen else { return }

        let sizes = Self.modeSizes(for: settings)
        let refreshRate = Self.preferredRefreshRate(excluding: screen.id)
        guard screen.setModes(sizes, refreshRate: refreshRate) else {
            fail("无法应用分辨率")
            return
        }
        lastError = nil

        if rebuilding && !mirroring {
            handOff(display: screen.id, size: sizes[0], refreshRate: refreshRate)
        } else {
            scheduleSync(display: screen.id, size: sizes[0], refreshRate: refreshRate, mirroring: mirroring, retriesLeft: 10)
        }
    }

    /// 扩展模式下让远程软件改看虚拟屏，用于远程刚连上时（它默认显示主屏）。
    func handOffToRemote(with settings: Settings) {
        guard settings.isEnabled, settings.displayMode == .extend, let screen else { return }
        handOff(display: screen.id, size: Self.modeSizes(for: settings)[0], refreshRate: Self.preferredRefreshRate(excluding: screen.id))
    }

    /// 扩展模式下新建的屏只是第二块屏，远程软件仍停在主屏（旧屏没了也会改跟主屏）。
    /// 先短暂镜像让虚拟屏当主屏，等远程软件跟上再改回扩展，它就一直跟着这块屏，比例也按当前方向重新认。
    private func handOff(display: CGDirectDisplayID, size: (width: Int, height: Int), refreshRate: Double) {
        scheduleSync(display: display, size: size, refreshRate: refreshRate, mirroring: true, retriesLeft: 10) { [weak self] in
            self?.pendingSync = MainRunLoop.after(Self.remoteFollowDelay) { [weak self] in
                self?.scheduleSync(display: display, size: size, refreshRate: refreshRate, mirroring: false, retriesLeft: 10)
            }
        }
    }

    /// 实体屏是否正在镜像虚拟屏。
    var isMirroringActive: Bool {
        guard let id = screen?.id else { return false }
        return DisplayConfig.onlineDisplays().contains { CGDisplayMirrorsDisplay($0) == id }
    }


    func tearDown() {
        pendingSync?.invalidate()
        unmirrorPhysicalDisplays()
        screen = nil
        screenIsPortrait = nil
    }

    /// 系统睡眠时会拆掉虚拟屏，手里的旧对象已失效，唤醒后等系统就绪再重建。
    func rebuildAfterWake(with settings: Settings, attempt: Int = 1) {
        pendingWakeRebuild?.invalidate()
        pendingWakeRebuild = MainRunLoop.after(attempt == 1 ? 1 : 2) { [weak self] in
            guard let self, settings.isEnabled else { return }
            self.pendingSync?.invalidate()
            self.screen = nil
            self.update(with: settings)

            let online = self.screen.map { DisplayConfig.onlineDisplays().contains($0.id) } ?? false
            if !online, attempt < 3 {
                self.logger.warning("唤醒后第 \(attempt) 次重建未成功，稍后重试")
                self.rebuildAfterWake(with: settings, attempt: attempt + 1)
            }
        }
    }

    // MARK: - 规格与分辨率

    /// 所有型号、两个方向、三档显示大小里最大的渲染像素，宽高都按它留。
    private static let maxPixels: Int = IPadModels.all.flatMap { model in
        DisplaySize.allCases.map { size in
            let logical = size.logicalSize(pixelWidth: model.width, pixelHeight: model.height)
            return max(logical.width, logical.height) * 2
        }
    }.max()!

    /// 帧率交给 UU远程 自己调，这里只决定上限：实体屏都支持 120Hz（或没接实体屏）就用 120Hz，否则 60Hz。
    /// 镜像要求两块屏刷新率一致，所以不能超出实体屏支持的范围。
    private static func preferredRefreshRate(excluding virtualID: CGDirectDisplayID) -> Double {
        let physical = DisplayConfig.onlineDisplays().filter { $0 != virtualID }
        let supports120 = physical.allSatisfy { display in
            DisplayConfig.modes(of: display).contains { abs($0.refreshRate - 120) < 1 }
        }
        return supports120 ? 120 : 60
    }

    /// 三档显示大小都登记上，所选的一档排第一。
    /// 新屏当主屏后，等远程软件切过去的时间。
    private static let remoteFollowDelay: TimeInterval = 1

    private static func modeSizes(for settings: Settings) -> [(width: Int, height: Int)] {
        let pixels = settings.pixelSize
        let order = [settings.size] + DisplaySize.allCases.filter { $0 != settings.size }
        return order.map { $0.logicalSize(pixelWidth: pixels.width, pixelHeight: pixels.height) }
    }

    /// 分辨率和镜像都要等系统处理完上一步才生效，所以分步进行，每步检查到位再走下一步。
    /// 镜像时虚拟屏只能用实体屏也支持的分辨率，所以要换分辨率得先解除镜像，切好再重新镜像，
    /// 实体屏才会跟着用新的分辨率。系统也会沿用这块屏上次的分辨率，所以每次都显式切到所选的一档。
    private func scheduleSync(display: CGDirectDisplayID, size: (width: Int, height: Int), refreshRate: Double, mirroring: Bool, retriesLeft: Int, completion: (() -> Void)? = nil) {
        pendingSync?.invalidate()
        pendingSync = MainRunLoop.after(0.3) { [weak self] in
            guard let self, self.screen?.id == display else { return }
            #if DEBUG_SYNC
            let cur = CGDisplayCopyDisplayMode(display)
            print("同步[剩\(retriesLeft)] 目标\(size.width)x\(size.height) 当前\(cur?.width ?? 0)x\(cur?.height ?? 0) 镜像目标\(mirroring) 实体屏镜像中\(DisplayConfig.onlineDisplays().filter { CGDisplayMirrorsDisplay($0) == display }.count)")
            #endif
            let done: Bool
            if !Self.isUsingMode(size, refreshRate: refreshRate, on: display) {
                if self.unmirrorPhysicalDisplays() {
                    Self.useHiDPIMode(size, refreshRate: refreshRate, on: display)
                }
                done = false
            } else if mirroring {
                if !self.mirrorPhysicalDisplays(onto: display) {
                    done = false
                } else {
                    switch Self.matchPhysicalModes(to: display) {
                    case .matched: done = true
                    case .adjusting: done = false
                    // 实体屏没有对应分辨率：系统只在建立镜像那一刻给它加上，所以解除后重新镜像
                    case .unavailable: self.unmirrorPhysicalDisplays(); done = false
                    }
                }
            } else {
                done = self.unmirrorPhysicalDisplays()
            }
            guard !done else {
                completion?()
                return
            }
            if retriesLeft > 0 {
                self.scheduleSync(display: display, size: size, refreshRate: refreshRate, mirroring: mirroring, retriesLeft: retriesLeft - 1, completion: completion)
            } else {
                self.logger.error("分辨率或镜像未能生效")
            }
        }
    }

    private enum PhysicalModeState { case matched, adjusting, unavailable }

    /// 镜像时实体屏可能挑了一个比例相近的分辨率（如 800×600），这里改成和虚拟屏一致。
    private static func matchPhysicalModes(to master: CGDirectDisplayID) -> PhysicalModeState {
        guard let target = CGDisplayCopyDisplayMode(master) else { return .adjusting }
        let mirrors = DisplayConfig.onlineDisplays().filter { CGDisplayMirrorsDisplay($0) == master }
        var state = PhysicalModeState.matched
        for display in mirrors {
            guard let current = CGDisplayCopyDisplayMode(display),
                  current.width != target.width || current.height != target.height else { continue }
            let candidates = DisplayConfig.modes(of: display).filter {
                $0.width == target.width && $0.height == target.height && $0.isUsableForDesktopGUI()
            }
            guard let best = candidates.max(by: { ($0.pixelWidth, $0.refreshRate) < ($1.pixelWidth, $1.refreshRate) }) else {
                return .unavailable
            }
            DisplayConfig.commit { CGConfigureDisplayWithDisplayMode($0, display, best, nil) }
            state = .adjusting
        }
        return state
    }

    private static func matches(_ mode: CGDisplayMode, _ size: (width: Int, height: Int), _ refreshRate: Double) -> Bool {
        mode.width == size.width && mode.height == size.height && mode.pixelWidth == size.width * 2
            && abs(mode.refreshRate - refreshRate) < 1
    }

    private static func isUsingMode(_ size: (width: Int, height: Int), refreshRate: Double, on display: CGDirectDisplayID) -> Bool {
        guard let current = CGDisplayCopyDisplayMode(display) else { return false }
        return matches(current, size, refreshRate)
    }

    @discardableResult
    private static func useHiDPIMode(_ size: (width: Int, height: Int), refreshRate: Double, on display: CGDirectDisplayID) -> Bool {
        guard let mode = DisplayConfig.modes(of: display).first(where: { matches($0, size, refreshRate) }) else { return false }
        return DisplayConfig.commit(.permanently) { CGConfigureDisplayWithDisplayMode($0, display, mode, nil) }
    }

    // MARK: - 镜像

    /// 镜像组对外只报告「主」的那块屏，所以由虚拟屏当主、实体屏镜像它：
    /// 远程软件能选中 iPad 屏，实体屏显示同样内容并跟着变成 iPad 比例。
    /// 返回是否已全部在镜像。
    @discardableResult
    private func mirrorPhysicalDisplays(onto master: CGDirectDisplayID) -> Bool {
        let pending = DisplayConfig.onlineDisplays().filter { $0 != master && CGDisplayMirrorsDisplay($0) != master }
        guard !pending.isEmpty else { return true }
        DisplayConfig.commit { config in
            pending.forEach { CGConfigureDisplayMirrorOfDisplay(config, $0, master) }
        }
        return false
    }

    /// 返回是否已全部解除镜像。
    @discardableResult
    private func unmirrorPhysicalDisplays() -> Bool {
        guard let master = screen?.id else { return true }
        let mirrored = DisplayConfig.onlineDisplays().filter { CGDisplayMirrorsDisplay($0) == master }
        guard !mirrored.isEmpty else { return true }
        DisplayConfig.commit { config in
            mirrored.forEach { CGConfigureDisplayMirrorOfDisplay(config, $0, kCGNullDirectDisplay) }
        }
        return false
    }

    private func fail(_ message: String) {
        lastError = message
        logger.error("\(message)")
    }
}
