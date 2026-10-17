// 生成安装包窗口背景：深色底 + 呼应图标的蓝紫粉光晕、标题、箭头、名字底板和安装提示。
// 用法：swift Scripts/make-dmg-background.swift 输出目录   （生成 background.png 与 background@2x.png）
import AppKit

let width: CGFloat = 660
let height: CGFloat = 420
// 图标中心位置（与 make-dmg.sh 里访达摆放的位置一致，坐标原点在左上角）
let appCenter = CGPoint(x: 170, y: 215)
let folderCenter = CGPoint(x: 490, y: 215)

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    // 换成左上角为原点，和访达的坐标一致
    ctx.translateBy(x: 0, y: height)
    ctx.scaleBy(x: 1, y: -1)

    // 底色
    NSColor(calibratedRed: 0.067, green: 0.075, blue: 0.106, alpha: 1).setFill()
    CGRect(x: 0, y: 0, width: width, height: height).fill()

    // 光晕
    func glow(_ center: CGPoint, radius: CGFloat, _ color: NSColor, alpha: CGFloat) {
        let colors = [color.withAlphaComponent(alpha).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
    glow(CGPoint(x: 150, y: 250), radius: 300, NSColor(calibratedRed: 0.16, green: 0.30, blue: 1.0, alpha: 1), alpha: 0.30)
    glow(CGPoint(x: 330, y: 170), radius: 220, NSColor(calibratedRed: 0.55, green: 0.25, blue: 1.0, alpha: 1), alpha: 0.16)
    glow(CGPoint(x: 540, y: 330), radius: 260, NSColor(calibratedRed: 1.0, green: 0.22, blue: 0.60, alpha: 1), alpha: 0.18)
    glow(CGPoint(x: 70, y: 380), radius: 160, NSColor(calibratedRed: 0.0, green: 0.80, blue: 1.0, alpha: 1), alpha: 0.12)

    // 文字（翻转坐标后要让文字正着画）
    func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, centerY: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),
        ]
        let str = NSAttributedString(string: string, attributes: attributes)
        let s = str.size()
        ctx.saveGState()
        ctx.translateBy(x: (width - s.width) / 2, y: centerY + s.height / 2)
        ctx.scaleBy(x: 1, y: -1)
        str.draw(at: .zero)
        ctx.restoreGState()
    }
    text("iPad 远程伴侣", size: 22, weight: .semibold, alpha: 0.95, centerY: 58)
    text("让UU远程完美适配iPad的工具", size: 13, weight: .regular, alpha: 0.55, centerY: 88)
    text("将左侧图标拖到「应用程序」文件夹，即可完成安装", size: 12, weight: .regular, alpha: 0.45, centerY: 368)

    // 名字底板：访达里图标名字固定是黑字、颜色改不了，垫一块浅色圆角底板让它在深色背景上看得清
    let labelCenterY: CGFloat = 298
    for (center, plateWidth) in [(appCenter, CGFloat(104)), (folderCenter, CGFloat(84))] {
        let plate = CGRect(x: center.x - plateWidth / 2, y: labelCenterY - 11, width: plateWidth, height: 22)
        NSColor.white.withAlphaComponent(0.82).setFill()
        NSBezierPath(roundedRect: plate, xRadius: 11, yRadius: 11).fill()
    }

    // 箭头：两图标之间一条细线 + 箭头头部
    let startX = appCenter.x + 88, endX = folderCenter.x - 88, y = appCenter.y - 12
    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: startX, y: y))
    arrow.line(to: CGPoint(x: endX, y: y))
    arrow.move(to: CGPoint(x: endX - 9, y: y - 8))
    arrow.line(to: CGPoint(x: endX, y: y))
    arrow.line(to: CGPoint(x: endX - 9, y: y + 8))
    arrow.lineWidth = 2
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSColor.white.withAlphaComponent(0.4).setStroke()
    arrow.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let outDir = CommandLine.arguments[1]
for (scale, name) in [(1.0, "background.png"), (2.0, "background@2x.png")] {
    let data = render(scale: scale).representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}
