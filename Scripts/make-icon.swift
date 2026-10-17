// 把一张方形图做成 macOS 应用图标：四周留边、裁成圆角方形。用法：swift Scripts/make-icon.swift 输入图 输出.png
import AppKit

let size: CGFloat = 1024
let inset: CGFloat = 100
let radius: CGFloat = 185
let source = NSImage(contentsOfFile: CommandLine.arguments[1])!

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
source.draw(in: rect)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
