import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let settings = Settings.shared
    private let screen = ScreenController.shared
    private let uuWatcher = UURemoteWatcher()
    /// 依赖虚拟屏的菜单项，虚拟屏关闭时置灰
    private var dependentItems: [NSMenuItem] = []
    /// 虚拟屏规格（型号、方向、字体大小），不建虚拟屏时也置灰
    private var screenSpecItems: [NSMenuItem] = []
    private var modeItems: [NSMenuItem] = []
    private let connectedDot = StatusDotView()
    private var isMenuOpen = false

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        setUpConnectedDot()
        // 显示器配置一变就刷新图标（出错时变灰）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        LoginItem.migrateFromLaunchAgent()
        // 登录项按应用所在位置登记，改名或换位置后原来那条就失效了；用户没手动关过，就每次启动时确认已登记
        if !settings.launchAtLoginDisabledByUser && !LoginItem.isEnabled {
            LoginItem.setEnabled(true)
        }

        // 自动模式下以实际连接状态为准，启动时先按未连接处理，连上后几秒内会自动切换
        if settings.autoMirrorWithUU {
            settings.displayMode = .original
        }
        applyAndRefresh()

        uuWatcher.onChange = { [weak self] connected in
            guard let self else { return }
            guard self.settings.autoMirrorWithUU else {
                if connected {
                    self.screen.handOffToRemote(with: self.settings)
                }
                self.refreshIcon()
                return
            }
            // 连上时自动切到镜像模式，远程中用户可以改选其他方式；断开后回到「不适配」
            self.settings.displayMode = connected ? .adapt : .original
            self.refreshModeItems()
            self.applyAndRefresh()
        }
        uuWatcher.start()

        // 外部改了设置后发这个通知，程序会重新读取并应用（等同在菜单里操作，方便调试）
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(settingsChangedExternally),
            name: Notification.Name("com.aicent.iPadDisplay.reload"),
            object: nil
        )
    }

    @objc private func settingsChangedExternally() {
        MainRunLoop.after(0) { self.applyAndRefresh() }
    }

    func applicationWillTerminate(_: Notification) {
        screen.tearDown()
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
    }

    // 菜单开着时更新过图标，按钮会一直留着选中时的胶囊高亮，关闭时主动清掉
    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        MainRunLoop.after(0) { [weak self] in
            self?.statusItem.button?.highlight(false)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        dependentItems = []
        screenSpecItems = []

        let switchView = SwitchMenuItemView(title: "iPad 远程伴侣", isOn: settings.isEnabled)
        switchView.onChange = { [weak self, weak menu] isOn in
            guard let self else { return }
            // 镜像时虚拟屏是主屏、菜单栏在它上面；这次开关若会开始或结束镜像，菜单栏会换到另一块屏，
            // 已打开的菜单会留在原坐标「飘」在屏幕中间，所以先收起菜单再应用
            let movesMenuBar = isOn ? self.settings.displayMode == .adapt : self.screen.isMirroringActive
            self.settings.isEnabled = isOn
            self.refreshItemStates()
            if movesMenuBar {
                // 不带动画地收起：淡出过程中屏幕一变，半透明的菜单会定格在原处
                menu?.cancelTrackingWithoutAnimation()
                MainRunLoop.after(0.3) { [weak self] in self?.applyAndRefresh() }
            } else {
                self.applyAndRefresh()
            }
        }
        let toggleItem = NSMenuItem()
        toggleItem.view = switchView
        menu.addItem(toggleItem)

        if settings.isEnabled, let error = screen.lastError {
            let errorItem = NSMenuItem(title: "\(error)，可关闭后重新打开", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }

        menu.addItem(.separator())

        let header: NSMenuItem
        if #available(macOS 14, *) {
            header = .sectionHeader(title: "显示方式")
        } else {
            header = NSMenuItem(title: "显示方式", action: nil, keyEquivalent: "")
            header.isEnabled = false
        }
        menu.addItem(header)
        modeItems = DisplayMode.allCases.map { mode in
            let item = NSMenuItem(title: mode.name, action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            menu.addItem(dependent(item))
            return item
        }
        refreshModeItems()

        // 自动镜像是独立的开关，用分隔线和上面的三选一隔开
        menu.addItem(.separator())

        let autoItem = NSMenuItem(title: "UU远程连上时自动镜像", action: #selector(toggleAutoMirror), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = settings.autoMirrorWithUU ? .on : .off
        menu.addItem(dependent(autoItem))

        menu.addItem(.separator())

        let modelMenu = NSMenu()
        let modelTitles = Self.twoColumnTitles(IPadModels.all.map { ($0.name, "\($0.width) × \($0.height)") })
        var titles = modelTitles.makeIterator()
        for (groupIndex, group) in IPadModels.groups.enumerated() {
            if groupIndex > 0 {
                modelMenu.addItem(.separator())
            }
            for model in group {
                let item = NSMenuItem(title: model.name, action: #selector(selectModel(_:)), keyEquivalent: "")
                item.attributedTitle = titles.next()
                item.target = self
                item.representedObject = model.id
                item.state = model.id == settings.model.id ? .on : .off
                modelMenu.addItem(item)
            }
        }
        menu.addItem(screenSpec(submenuItem(title: "iPad 型号", submenu: modelMenu)))

        let orientationMenu = NSMenu()
        for (title, portrait) in [("横屏", false), ("竖屏", true)] {
            let item = NSMenuItem(title: title, action: #selector(selectOrientation(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = portrait
            item.state = portrait == settings.isPortrait ? .on : .off
            orientationMenu.addItem(item)
        }
        menu.addItem(screenSpec(submenuItem(title: "方向", submenu: orientationMenu)))

        let sizeMenu = NSMenu()
        let pixels = settings.pixelSize
        let sizeTitles = Self.twoColumnTitles(DisplaySize.allCases.map {
            let logical = $0.logicalSize(pixelWidth: pixels.width, pixelHeight: pixels.height)
            return ($0.name, "\(logical.width) × \(logical.height)")
        })
        for (size, title) in zip(DisplaySize.allCases, sizeTitles) {
            let item = NSMenuItem(title: size.name, action: #selector(selectSize(_:)), keyEquivalent: "")
            item.attributedTitle = title
            item.target = self
            item.representedObject = size.rawValue
            item.state = size == settings.size ? .on : .off
            sizeMenu.addItem(item)
        }
        menu.addItem(screenSpec(submenuItem(title: "字体大小", submenu: sizeMenu)))


        menu.addItem(.separator())

        let launchItem = NSMenuItem(title: "开机自启", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(launchItem)

        let aboutItem = NSMenuItem(title: "关于", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    /// 虚拟屏开关是总开关：关闭时这些选项置灰，不可操作。
    private func dependent(_ item: NSMenuItem) -> NSMenuItem {
        item.isEnabled = settings.isEnabled
        dependentItems.append(item)
        return item
    }

    private func screenSpec(_ item: NSMenuItem) -> NSMenuItem {
        screenSpecItems.append(item)
        item.isEnabled = screenSpecEnabled
        return item
    }

    /// 选了「不适配」又不会自动镜像时没有虚拟屏，型号、方向、字体大小改了也没用；
    /// 开着自动镜像时它们决定下次远程建出的屏，保留可用。
    private var screenSpecEnabled: Bool {
        settings.isEnabled && (settings.displayMode != .original || settings.autoMirrorWithUU)
    }

    private func refreshItemStates() {
        dependentItems.forEach { $0.isEnabled = settings.isEnabled }
        screenSpecItems.forEach { $0.isEnabled = screenSpecEnabled }
    }

    /// 选项名后面跟一列分辨率：用制表位对齐成一列，并用次要颜色，不和选项名抢眼。
    private static func twoColumnTitles(_ rows: [(name: String, detail: String)]) -> [NSAttributedString] {
        let font = NSFont.menuFont(ofSize: 0)
        let nameWidth = rows.map { ($0.name as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: ceil(nameWidth) + 20)]
        return rows.map { row in
            let title = NSMutableAttributedString(string: row.name + "\t", attributes: [.font: font, .paragraphStyle: paragraph])
            title.append(NSAttributedString(string: row.detail, attributes: [
                .font: font, .paragraphStyle: paragraph, .foregroundColor: NSColor.secondaryLabelColor,
            ]))
            return title
        }
    }

    private func submenuItem(title: String, submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    /// 图标状态：关闭时浅灰，打开时正常白色，UU远程连接中（镜像或扩展）再在右下角加一个绿点。
    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "ipad.landscape", accessibilityDescription: "iPad 远程伴侣")
        button.appearsDisabled = !settings.isEnabled || screen.lastError != nil
        connectedDot.isHidden = !(settings.isEnabled && uuWatcher.isConnected)
        // 换图片、变灰会让按钮重绘并保留高亮状态，菜单没开时不应有胶囊背景
        if !isMenuOpen {
            button.highlight(false)
        }
    }

    /// 绿点放在图标图案的右下角。
    private func setUpConnectedDot() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "ipad.landscape", accessibilityDescription: nil)
        let imageRect = button.cell?.imageRect(forBounds: button.bounds) ?? button.bounds
        let size: CGFloat = 7
        let y = button.isFlipped ? imageRect.maxY - size + 2 : imageRect.minY - 2
        connectedDot.frame = NSRect(x: imageRect.maxX - size + 2, y: y, width: size, height: size)
        connectedDot.isHidden = true
        button.addSubview(connectedDot)
    }

    @objc private func screensChanged() {
        refreshIcon()
    }

    private func applyAndRefresh() {
        screen.update(with: settings)
        refreshIcon()
    }

    // MARK: - Actions

    @objc private func showAbout() {
        AboutWindow.shared.show()
    }

    @objc private func selectDisplayMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = DisplayMode(rawValue: raw) else { return }
        settings.displayMode = mode
        applyAndRefresh()
    }

    /// 菜单开着时远程连上或断开，对勾也要跟着变。
    private func refreshModeItems() {
        for item in modeItems {
            item.state = item.representedObject as? String == settings.displayMode.rawValue ? .on : .off
        }
    }

    @objc private func toggleAutoMirror() {
        settings.autoMirrorWithUU.toggle()
        if settings.autoMirrorWithUU {
            settings.displayMode = uuWatcher.isConnected ? .adapt : .original
        }
        applyAndRefresh()
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        settings.model = IPadModels.model(id: id)
        applyAndRefresh()
    }

    @objc private func selectOrientation(_ sender: NSMenuItem) {
        guard let portrait = sender.representedObject as? Bool else { return }
        settings.isPortrait = portrait
        applyAndRefresh()
    }

    @objc private func selectSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let size = DisplaySize(rawValue: raw) else { return }
        settings.size = size
        applyAndRefresh()
    }

    @objc private func toggleLaunchAtLogin() {
        let enable = !LoginItem.isEnabled
        if LoginItem.setEnabled(enable) {
            settings.launchAtLoginDisabledByUser = !enable
        } else {
            let alert = NSAlert()
            alert.messageText = "开机自启设置失败"
            alert.informativeText = "请确认应用放在「应用程序」文件夹里，或到「系统设置 → 通用 → 登录项」中手动添加。"
            alert.runModal()
        }
    }

    // MARK: - 睡眠唤醒

    @objc private func systemDidWake(_: Notification) {
        screen.rebuildAfterWake(with: settings)
        refreshIcon()
    }
}

/// 菜单栏图标上表示「UU远程连接中」的绿点，带一圈和菜单栏同色的描边，压在图标上也看得清。
final class StatusDotView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let ring = bounds.insetBy(dx: 0.5, dy: 0.5)
        NSColor.systemGreen.setFill()
        NSBezierPath(ovalIn: ring).fill()
        NSColor(white: 0, alpha: 0.35).setStroke()
        let border = NSBezierPath(ovalIn: ring)
        border.lineWidth = 1
        border.stroke()
    }
}
