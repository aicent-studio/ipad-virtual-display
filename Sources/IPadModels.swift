import Foundation

/// iPad 型号，像素按横屏记录。
struct IPadModel {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let ppi: Double
}

enum IPadModels {
    static let all: [IPadModel] = [
        IPadModel(id: "pro-13", name: "iPad Pro 13 寸（M4 / M5）", width: 2752, height: 2064, ppi: 264),
        IPadModel(id: "pro-11", name: "iPad Pro 11 寸（M4 / M5）", width: 2420, height: 1668, ppi: 264),
        IPadModel(id: "pro-12-9", name: "iPad Pro 12.9 寸（旧款）", width: 2732, height: 2048, ppi: 264),
        IPadModel(id: "pro-11-old", name: "iPad Pro 11 寸（旧款）", width: 2388, height: 1668, ppi: 264),
        IPadModel(id: "air-13", name: "iPad Air 13 寸", width: 2732, height: 2048, ppi: 264),
        IPadModel(id: "air-11", name: "iPad Air 11 寸", width: 2360, height: 1640, ppi: 264),
        IPadModel(id: "ipad", name: "iPad（第 10 代 / A16）", width: 2360, height: 1640, ppi: 264),
        IPadModel(id: "mini", name: "iPad mini（第 6 代 / A17 Pro）", width: 2266, height: 1488, ppi: 326),
    ]

    static let defaultID = "pro-13"

    static func model(id: String) -> IPadModel {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}

/// 显示大小：标准 = iPad 原生像素的 2 倍 HiDPI；更多空间会渲染得比 iPad 更大，再由远程端缩小，依旧清晰。
enum DisplaySize: String, CaseIterable {
    case standard
    case more
    case most

    var name: String {
        switch self {
        case .standard: return "大字体（推荐）"
        case .more: return "中字体"
        case .most: return "小字体"
        }
    }

    var factor: Double {
        switch self {
        case .standard: return 1.0
        case .more: return 1.25
        case .most: return 1.5
        }
    }

    /// 「看起来像」的逻辑分辨率，实际渲染像素是它的 2 倍。
    func logicalSize(pixelWidth: Int, pixelHeight: Int) -> (width: Int, height: Int) {
        (Int((Double(pixelWidth) * factor / 2).rounded()),
         Int((Double(pixelHeight) * factor / 2).rounded()))
    }
}
