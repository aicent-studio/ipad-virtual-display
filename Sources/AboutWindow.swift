import AppKit

/// 关于窗口。系统自带的关于面板太窄、间距不可调，这里自己排版。
final class AboutWindow: NSWindowController {
    static let shared = AboutWindow()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 10),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .documentWindow
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        super.init(window: window)

        let content = Self.makeContent()
        window.contentView = content
        window.setContentSize(content.fittingSize)
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible != true {
            window?.center()
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private static func makeContent() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 88),
            icon.heightAnchor.constraint(equalToConstant: 88),
        ])

        let name = label("iPad 远程伴侣", size: 18, weight: .semibold)
        let version = label("版本 1.0", size: 12, color: .secondaryLabelColor)
        let summary = label(
            "在 Mac 上虚拟一块 iPad 尺寸的屏幕，\n配合远程软件在 iPad 上全屏、清晰地显示。",
            size: 13,
            lineSpacing: 5
        )
        let author = authorRow()
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 280).isActive = true
        let links = linksRow()
        let notice = label("本软件免费开源，请勿付费购买", size: 11, color: .tertiaryLabelColor)

        let stack = NSStackView(views: [icon, name, version, summary, author, divider, links, notice])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 0
        stack.setCustomSpacing(18, after: icon)
        stack.setCustomSpacing(6, after: name)
        stack.setCustomSpacing(22, after: version)
        stack.setCustomSpacing(22, after: summary)
        stack.setCustomSpacing(20, after: author)
        stack.setCustomSpacing(14, after: divider)
        stack.setCustomSpacing(8, after: links)
        stack.edgeInsets = NSEdgeInsets(top: 44, left: 40, bottom: 24, right: 40)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: 360),
        ])
        return container
    }

    /// 圆形头像 + 作者名，作者名旁边是抖音主页链接。
    private static func authorRow() -> NSView {
        let name = label("GGBOY", size: 13, weight: .medium, color: .secondaryLabelColor)
        let douyin = LinkButton(title: "关注抖音", url: Links.douyin, size: 13, color: .linkColor)
        let names = NSStackView(views: [name, douyin])
        names.orientation = .horizontal
        names.spacing = 8
        guard let url = Bundle.main.url(forResource: "avatar", withExtension: "jpg"),
              let image = NSImage(contentsOf: url) else { return names }

        let size: CGFloat = 28
        let avatar = NSImageView(image: image)
        avatar.imageScaling = .scaleProportionallyUpOrDown
        avatar.wantsLayer = true
        avatar.layer?.cornerRadius = size / 2
        avatar.layer?.masksToBounds = true
        avatar.layer?.borderWidth = 1
        avatar.layer?.borderColor = NSColor.separatorColor.cgColor
        avatar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: size),
            avatar.heightAnchor.constraint(equalToConstant: size),
        ])

        let row = NSStackView(views: [avatar, names])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    /// GitHub 仓库和问题反馈。
    private static func linksRow() -> NSView {
        let dot = label("·", size: 12, color: .tertiaryLabelColor)
        let row = NSStackView(views: [
            LinkButton(title: "GitHub ↗", url: Links.repo, size: 12, color: .secondaryLabelColor),
            dot,
            LinkButton(title: "问题反馈 ↗", url: Links.issues, size: 12, color: .secondaryLabelColor),
        ])
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    private static func label(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor,
        lineSpacing: CGFloat = 0
    ) -> NSTextField {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = lineSpacing
        let field = NSTextField(labelWithAttributedString: NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]))
        field.alignment = .center
        field.maximumNumberOfLines = 0
        return field
    }
}

private enum Links {
    static let repo = URL(string: "https://github.com/aicent-studio/ipad-virtual-display")!
    static let issues = URL(string: "https://github.com/aicent-studio/ipad-virtual-display/issues")!
    static let douyin = URL(string: "https://www.douyin.com/user/MS4wLjABAAAAMccOWHxMVp5LikiuKcnTBnj92WauvZh6AEUV9naixTF4_wBu1OkQFzV0E_132AvP")!
}

/// 文字链接：点击用浏览器打开，指针变手形，悬停时颜色加深（不做动画）。
private final class LinkButton: NSButton {
    private let url: URL
    private let size: CGFloat
    private let normalColor: NSColor

    init(title: String, url: URL, size: CGFloat, color: NSColor) {
        self.url = url
        self.size = size
        normalColor = color
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryChange)
        target = self
        action = #selector(open)
        setTitle(title, color: color)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    required init?(coder: NSCoder) { nil }

    private func setTitle(_ text: String, color: NSColor) {
        attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size),
            .foregroundColor: color,
        ])
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        setTitle(title, color: normalColor == .linkColor ? normalColor.blended(withFraction: 0.25, of: .labelColor) ?? normalColor : .labelColor)
    }

    override func mouseExited(with event: NSEvent) {
        setTitle(title, color: normalColor)
    }

    @objc private func open() {
        NSWorkspace.shared.open(url)
    }
}
