import AppKit
import QuartzCore

/// A trace of every walk, to find out why the legs sometimes freeze: each
/// swipe event as it arrives (and how late), each frame the walk steps,
/// the event tap being switched off by the system, and the main thread
/// stalling. Off unless `defaults write com.dostashev.IslandCat traceWalks
/// -bool true`; writes CSV to ~/Library/Logs/IslandCat/walks.csv.
@MainActor
final class WalkTrace {
    static let shared = WalkTrace()

    let enabled = UserDefaults.standard.bool(forKey: "traceWalks")
    private var handle: FileHandle?
    private var lines: [String] = []
    private var watchdog: Thread?

    private init() {
        guard enabled else { return }
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/IslandCat")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("walks.csv")
        if !FileManager.default.fileExists(atPath: file.path) {
            FileManager.default.createFile(
                atPath: file.path, contents: Data("t,kind,a,b,c,d,e\n".utf8))
        }
        handle = try? FileHandle(forWritingTo: file)
        _ = try? handle?.seekToEnd()
        write("start", "\(ProcessInfo.processInfo.processIdentifier)")
        flush()
        startWatchdog()
    }

    /// One line: the time now (CACurrentMediaTime, seconds), what happened,
    /// and its numbers.
    func write(_ kind: String, _ values: Any...) {
        guard enabled else { return }
        let fields = values.map { value -> String in
            if let number = value as? Double { return String(format: "%.5f", number) }
            return "\(value)"
        }
        lines.append(([String(format: "%.5f", CACurrentMediaTime()), kind] + fields).joined(separator: ","))
        if lines.count > 2000 { flush() }
    }

    func flush() {
        guard enabled, !lines.isEmpty else { return }
        handle?.write(Data((lines.joined(separator: "\n") + "\n").utf8))
        lines.removeAll(keepingCapacity: true)
    }

    /// Pings the main thread every 5 ms from a thread of its own and notes
    /// whenever it took more than 25 ms to answer.
    private func startWatchdog() {
        let thread = Thread {
            while true {
                let sent = CACurrentMediaTime()
                DispatchQueue.main.async {
                    let late = CACurrentMediaTime() - sent
                    if late > 0.025 {
                        MainActor.assumeIsolated { WalkTrace.shared.write("stall", late) }
                    }
                }
                Thread.sleep(forTimeInterval: 0.005)
            }
        }
        thread.qualityOfService = .userInteractive
        thread.name = "WalkTrace watchdog"
        thread.start()
        watchdog = thread
    }
}
