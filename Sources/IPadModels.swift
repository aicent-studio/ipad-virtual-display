import Foundation

/// 设备型号与分辨率预设，像素按横屏记录。
struct IPadModel {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let ppi: Double
}

enum IPadModels {
    /// 按 Pro、Air、iPad、mini 分组；同组相同屏幕规格的机型共用预设。
    static let groups: [[IPadModel]] = [
        [
            IPadModel(id: "pro-13", name: "13 英寸 iPad Pro（M4 / M5）", width: 2752, height: 2064, ppi: 264),
            IPadModel(id: "pro-11", name: "11 英寸 iPad Pro（M4 / M5）", width: 2420, height: 1668, ppi: 264),
            IPadModel(id: "pro-12-9", name: "12.9 英寸 iPad Pro（第 1–6 代）", width: 2732, height: 2048, ppi: 264),
            IPadModel(id: "pro-11-old", name: "11 英寸 iPad Pro（第 1–4 代）", width: 2388, height: 1668, ppi: 264),
            IPadModel(id: "pro-10-5", name: "10.5 英寸 iPad Pro", width: 2224, height: 1668, ppi: 264),
            IPadModel(id: "pro-9-7", name: "9.7 英寸 iPad Pro", width: 2048, height: 1536, ppi: 264),
        ],
        [
            IPadModel(id: "air-13", name: "13 英寸 iPad Air（M2 / M3 / M4）", width: 2732, height: 2048, ppi: 264),
            IPadModel(id: "air-11", name: "11 英寸 iPad Air（M2 / M3 / M4）", width: 2360, height: 1640, ppi: 264),
            IPadModel(id: "air-4-5", name: "iPad Air（第 4–5 代）", width: 2360, height: 1640, ppi: 264),
            IPadModel(id: "air-3", name: "iPad Air（第 3 代）", width: 2224, height: 1668, ppi: 264),
            IPadModel(id: "air-1-2", name: "iPad Air（第 1–2 代）", width: 2048, height: 1536, ppi: 264),
        ],
        [
            IPadModel(id: "ipad", name: "iPad（第 10 代 / A16）", width: 2360, height: 1640, ppi: 264),
            IPadModel(id: "ipad-7-9", name: "iPad（第 7–9 代）", width: 2160, height: 1620, ppi: 264),
            IPadModel(id: "ipad-3-6", name: "iPad（第 3–6 代）", width: 2048, height: 1536, ppi: 264),
        ],
        [
            IPadModel(id: "mini", name: "iPad mini（第 6 代 / A17 Pro）", width: 2266, height: 1488, ppi: 326),
            IPadModel(id: "mini-2-5", name: "iPad mini（第 2–5 代）", width: 2048, height: 1536, ppi: 326),
        ],
    ]

    static let all: [IPadModel] = groups.flatMap { $0 }

    static let defaultID = "pro-13"

    static func model(id: String) -> IPadModel {
        // 兼容测试版误写的型号 ID，避免已选该项的用户重启后回到默认型号。
        let resolvedID = id == "mac-mini" ? "mini-2-5" : id
        return all.first(where: { $0.id == resolvedID }) ?? all[0]
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
