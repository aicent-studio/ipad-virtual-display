import CoreGraphics
import Foundation

/// 一块虚拟屏。对象存在期间屏幕在线，释放后系统自动移除。
final class VirtualScreen {
    // 固定的显示器身份：系统一直认作同一块屏，记得它的排列位置
    private static let vendorID: UInt32 = 0x1AD0
    private static let productID: UInt32 = 0x0001
    private static let serialNumber: UInt32 = 0x0001

    private let display: CGVirtualDisplay

    var id: CGDirectDisplayID { display.displayID }

    /// maxPixels 要一次留够：之后换型号、方向、显示大小都只切分辨率，不重建这块屏，
    /// 这样远程软件一直连着同一块屏，分辨率变了也会跟着更新。
    init?(maxPixels: Int, ppi: Double) {
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(.main)
        descriptor.name = "iPad"
        descriptor.maxPixelsWide = UInt32(maxPixels)
        descriptor.maxPixelsHigh = UInt32(maxPixels)
        let millimeters = Double(maxPixels) / ppi * 25.4
        descriptor.sizeInMillimeters = CGSize(width: millimeters, height: millimeters)
        descriptor.vendorID = Self.vendorID
        descriptor.productID = Self.productID
        descriptor.serialNum = Self.serialNumber

        let display = CGVirtualDisplay(descriptor: descriptor)
        guard display.displayID != 0 else { return nil }
        self.display = display
    }

    /// 登记可选的 HiDPI 分辨率（按「看起来像」的逻辑尺寸），排第一的是默认分辨率。
    func setModes(_ sizes: [(width: Int, height: Int)], refreshRate: Double) -> Bool {
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        settings.modes = sizes.map {
            CGVirtualDisplayMode(width: UInt($0.width), height: UInt($0.height), refreshRate: refreshRate)
        }
        return display.apply(settings)
    }
}
