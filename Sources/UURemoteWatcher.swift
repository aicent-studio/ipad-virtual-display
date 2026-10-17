import Foundation
import Darwin

/// 判断网易 UU 远程是否有远程会话：画面走 UDP，远程时服务进程开着多条 UDP 套接字（实测 8 条），
/// 空闲时为 0 或 1 条（偶尔会留一个只在本机监听的端口），所以至少 2 条才算在远程。
final class UURemoteWatcher {
    var onChange: ((Bool) -> Void)?
    private(set) var isConnected = false

    private var timer: Timer?
    private var activeStreak = 0
    private var idleStreak = 0

    // 每秒检查一次：连续 2 次有连接算连上，连续 3 次（约 3 秒）没有算断开。
    // 网络短暂卡顿时 UDP 套接字不会关闭，所以不需要等太久
    private let interval: TimeInterval = 1
    private let connectThreshold = 2
    private let disconnectThreshold = 3
    private let minSessionSockets = 2

    func start() {
        timer = MainRunLoop.every(interval) { [weak self] in
            self?.poll()
        }
        poll()
    }

    private func poll() {
        if Self.udpSocketCount() >= minSessionSockets {
            activeStreak += 1
            idleStreak = 0
        } else {
            idleStreak += 1
            activeStreak = 0
        }

        if !isConnected, activeStreak >= connectThreshold {
            isConnected = true
            onChange?(true)
        } else if isConnected, idleStreak >= disconnectThreshold {
            isConnected = false
            onChange?(false)
        }
    }

    private static func serverPIDs() -> [pid_t] {
        let estimated = proc_listallpids(nil, 0)
        guard estimated > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimated) + 64)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard count > 0 else { return [] }

        var path = [CChar](repeating: 0, count: 4096)
        return pids.prefix(Int(count)).filter { pid in
            pid > 0
                && proc_pidpath(pid, &path, UInt32(path.count)) > 0
                && String(cString: path).hasSuffix("/UURemote.app/Contents/Helpers/UURemoteServer")
        }
    }

    private static func udpSocketCount() -> Int {
        var total = 0
        for pid in serverPIDs() {
            let bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
            guard bufferSize > 0 else { continue }
            var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(bufferSize) / MemoryLayout<proc_fdinfo>.stride)
            let filled = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, bufferSize)
            guard filled > 0 else { continue }

            for fd in fds.prefix(Int(filled) / MemoryLayout<proc_fdinfo>.stride)
            where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
                var info = socket_fdinfo()
                let size = Int32(MemoryLayout<socket_fdinfo>.size)
                if proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &info, size) == size,
                   info.psi.soi_protocol == IPPROTO_UDP {
                    total += 1
                }
            }
        }
        return total
    }
}
