import AppKit

/// 菜单里的「文字 + 开关」一行，样式仿照控制中心的 Wi‑Fi 开关。点开关或整行都会切换，菜单保持打开。
final class SwitchMenuItemView: NSView {
    var onChange: ((Bool) -> Void)?

    private let toggle: MenuSwitch

    // 与系统菜单项对齐：文字和带勾选列的菜单项文字左对齐，开关和子菜单箭头右对齐
    private static let leadingInset: CGFloat = 29
    private static let trailingInset: CGFloat = 16

    init(title: String, isOn: Bool) {
        toggle = MenuSwitch(isOn: isOn)
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 32))
        autoresizingMask = [.width]

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        toggle.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        addSubview(toggle)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.leadingInset),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.trailingInset),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 24),
        ])
    }

    required init?(coder: NSCoder) { nil }

    // 点在开关、文字或空白处都切换。
    // 开关虚拟屏会让系统重新配置显示器、短暂卡住界面，所以等滑动动画播完再执行
    override func mouseUp(with event: NSEvent) {
        toggle.isOn.toggle()
        let isOn = toggle.isOn
        MainRunLoop.after(MenuSwitch.duration + 0.05) { [weak self] in
            self?.onChange?(isOn)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }
}

/// 自绘开关。系统的 NSSwitch 只有在程序处于活动状态时才显示蓝色，而激活程序后开关虚拟屏会让系统收起菜单，
/// 所以自己画。用图层实现，切换时圆钮滑动、底色渐变，和系统开关的动画一致。
final class MenuSwitch: NSView {
    var isOn: Bool {
        didSet { updateLayers(animated: true) }
    }

    static let duration: CFTimeInterval = 0.2
    private static let size = NSSize(width: 32, height: 18)
    private static let knobInset: CGFloat = 2

    private let track = CALayer()
    private let knob = CALayer()

    init(isOn: Bool) {
        self.isOn = isOn
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        wantsLayer = true

        track.frame = bounds
        track.cornerRadius = bounds.height / 2

        let knobSize = bounds.height - Self.knobInset * 2
        knob.bounds = CGRect(x: 0, y: 0, width: knobSize, height: knobSize)
        knob.cornerRadius = knobSize / 2
        knob.backgroundColor = NSColor.white.cgColor
        knob.shadowColor = NSColor.black.cgColor
        knob.shadowOpacity = 0.25
        knob.shadowOffset = CGSize(width: 0, height: -0.5)
        knob.shadowRadius = 1

        layer?.addSublayer(track)
        layer?.addSublayer(knob)
        updateLayers(animated: false)
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize { Self.size }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayers(animated: false)
    }

    private func updateLayers(animated: Bool) {
        let knobSize = knob.bounds.width
        let x = isOn ? bounds.width - Self.knobInset - knobSize / 2 : Self.knobInset + knobSize / 2

        var trackColor: CGColor = NSColor.clear.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let off = isDark ? NSColor(white: 1, alpha: 0.22) : NSColor(white: 0, alpha: 0.12)
            trackColor = (isOn ? NSColor.controlAccentColor : off).cgColor
        }

        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(Self.duration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        } else {
            CATransaction.setDisableActions(true)
        }
        knob.position = CGPoint(x: x, y: bounds.midY)
        track.backgroundColor = trackColor
        CATransaction.commit()
    }
}
