import Foundation

final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            "modelID": IPadModels.defaultID,
            "isPortrait": false,
            "size": DisplaySize.standard.rawValue,
            "isEnabled": true,
            "autoMirrorWithUU": true,
        ])
    }

    var model: IPadModel {
        get { IPadModels.model(id: defaults.string(forKey: "modelID") ?? IPadModels.defaultID) }
        set { defaults.set(newValue.id, forKey: "modelID") }
    }

    var isPortrait: Bool {
        get { defaults.bool(forKey: "isPortrait") }
        set { defaults.set(newValue, forKey: "isPortrait") }
    }

    var size: DisplaySize {
        get { DisplaySize(rawValue: defaults.string(forKey: "size") ?? "") ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: "size") }
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: "isEnabled") }
        set { defaults.set(newValue, forKey: "isEnabled") }
    }

    /// iPad 上的显示方式。旧版只存了「是否镜像」，没选过的按它换算。
    var displayMode: DisplayMode {
        get {
            if let raw = defaults.string(forKey: "displayMode"), let mode = DisplayMode(rawValue: raw) {
                return mode
            }
            return defaults.object(forKey: "isMirroring") as? Bool == false ? .extend : .adapt
        }
        set {
            defaults.set(newValue.rawValue, forKey: "displayMode")
            defaults.removeObject(forKey: "isMirroring")
        }
    }

    /// 网易 UU 远程连上时自动切到镜像模式，断开后回到「不适配」。
    var autoMirrorWithUU: Bool {
        get { defaults.bool(forKey: "autoMirrorWithUU") }
        set { defaults.set(newValue, forKey: "autoMirrorWithUU") }
    }

    /// 按当前方向换算后的原生像素。
    var pixelSize: (width: Int, height: Int) {
        isPortrait ? (model.height, model.width) : (model.width, model.height)
    }

    /// 用户在菜单里手动关掉过开机自启。没关过就默认开启。
    var launchAtLoginDisabledByUser: Bool {
        get { defaults.bool(forKey: "launchAtLoginDisabledByUser") }
        set { defaults.set(newValue, forKey: "launchAtLoginDisabledByUser") }
    }
}

enum DisplayMode: String, CaseIterable {
    /// 虚拟屏当主、实体屏镜像它，iPad 上铺满
    case adapt
    /// 虚拟屏作为独立的扩展屏
    case extend
    /// 不建虚拟屏，远程看到的是实体屏原本的 16:9
    case original

    var name: String {
        switch self {
        case .adapt: return "适配 iPad（镜像模式）"
        case .extend: return "适配 iPad（扩展模式）"
        case .original: return "不适配（显示器原画面）"
        }
    }
}
