import Foundation

/// 在主线程延后执行。
/// 菜单打开期间主线程处于菜单跟踪模式，DispatchQueue.main.asyncAfter 和默认模式的 Timer 都会暂停到菜单关闭，
/// 这里把定时器加到 common 模式，菜单开着时也照常执行。
enum MainRunLoop {
    @discardableResult
    static func after(_ delay: TimeInterval, _ block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: delay, repeats: false) { _ in block() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    static func every(_ interval: TimeInterval, _ block: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in block() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
