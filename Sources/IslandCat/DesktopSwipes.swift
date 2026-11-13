import AppKit
import os

/// Follows the trackpad swipe between desktops as it happens.
///
/// The system posts no public notification until the desktop has finished
/// changing, so this listens (without changing anything) to the Dock's
/// swipe gesture events through a session event tap: their phase (began,
/// changed, ended) and progress in desktop widths. Listening needs Input
/// Monitoring permission.
@MainActor
final class DesktopSwipes {
    enum Change {
        case moved(progress: Double)
        case lifted(progress: Double, velocity: Double)
    }

    private let changed: (Change) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var waiting: Timer?

    /// The Dock's gesture events, and the fields that carry the swipe.
    private static let dockGesture: UInt32 = 30
    private static let horizontalSwipe: Int64 = 1
    private static let kindField = CGEventField(rawValue: 123)!
    private static let progressField = CGEventField(rawValue: 124)!
    private static let velocityField = CGEventField(rawValue: 129)!
    private static let phaseField = CGEventField(rawValue: 132)!

    init(changed: @escaping (Change) -> Void) {
        self.changed = changed
    }

    /// Starts listening. Returns false without Input Monitoring permission,
    /// after asking for it.
    func start() -> Bool {
        guard tap == nil else { return true }
        // Without the permission a tap is still created but sees nothing.
        guard CGPreflightListenEventAccess() else {
            Self.log.notice("No Input Monitoring permission; asking for it")
            CGRequestListenEventAccess()
            waitForAccess()
            return false
        }
        let mask = CGEventMask(1) << CGEventMask(Self.dockGesture)
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                eventsOfInterest: mask,
                callback: { _, type, event, info in
                    guard let info else { return Unmanaged.passUnretained(event) }
                    let swipes = Unmanaged<DesktopSwipes>.fromOpaque(info).takeUnretainedValue()
                    MainActor.assumeIsolated {
                        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                            // The system switches a tap off when it falls behind;
                            // switch it back on.
                            swipes.reenable(type)
                        } else if type.rawValue == DesktopSwipes.dockGesture {
                            swipes.handle(event)
                        }
                    }
                    return Unmanaged.passUnretained(event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            Self.log.error("Could not listen to desktop swipes")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.tap = tap
        self.source = source
        Self.log.notice("Following desktop swipes")
        return true
    }

    /// Starts listening as soon as the permission is granted in System
    /// Settings, checking every two seconds.
    private func waitForAccess() {
        waiting?.invalidate()
        waiting = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, CGPreflightListenEventAccess() else { return }
                self.waiting?.invalidate()
                self.waiting = nil
                _ = self.start()
            }
        }
    }

    func stop() {
        waiting?.invalidate()
        waiting = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private static let log = Logger(subsystem: "com.dostashev.IslandCat", category: "swipes")

    private func reenable(_ type: CGEventType) {
        Self.log.error("Desktop swipe tap switched off (\(type.rawValue)); switching it back on")
        WalkTrace.shared.write("tapOff", type.rawValue)
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    /// Mach ticks to seconds, for event timestamps.
    private static let tick: Double = {
        var base = mach_timebase_info_data_t()
        mach_timebase_info(&base)
        return Double(base.numer) / Double(base.denom) / 1e9
    }()

    private func handle(_ event: CGEvent) {
        let kind = event.getIntegerValueField(Self.kindField)
        let phase = event.getIntegerValueField(Self.phaseField)
        let progress = event.getDoubleValueField(Self.progressField)
        if WalkTrace.shared.enabled {
            // How long ago the event happened, reading its timestamp both
            // as nanoseconds and as mach ticks.
            let now = CACurrentMediaTime()
            let stamp = Double(event.timestamp)
            WalkTrace.shared.write(
                "event", kind, phase, progress, now - stamp / 1e9, now - stamp * Self.tick)
        }
        if phase != 2 {
            Self.log.notice("Dock gesture kind \(kind) phase \(phase) progress \(progress)")
        }
        guard kind == Self.horizontalSwipe else { return }
        switch phase {
        case 1, 2:
            changed(.moved(progress: progress))
        case 4, 8:
            changed(.lifted(progress: progress, velocity: event.getDoubleValueField(Self.velocityField)))
        default:
            break
        }
    }

    /// Whether there is a desktop to the left and to the right of the
    /// current one on the screen with the island, from WindowServer's
    /// list of spaces. Assumes both when the list is unavailable.
    static func neighbors(on screen: NSScreen) -> (left: Bool, right: Bool) {
        typealias MainConnectionID = @convention(c) () -> Int32
        typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
        guard
            let skyLight = dlopen(
                "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW),
            let main = dlsym(skyLight, "SLSMainConnectionID"),
            let copy = dlsym(skyLight, "SLSCopyManagedDisplaySpaces"),
            let displays = unsafeBitCast(copy, to: CopyManagedDisplaySpaces.self)(
                unsafeBitCast(main, to: MainConnectionID.self)()
            )?.takeRetainedValue() as? [[String: Any]]
        else { return (true, true) }
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let uuid = number.flatMap { CGDisplayCreateUUIDFromDisplayID($0)?.takeRetainedValue() }
            .map { CFUUIDCreateString(nil, $0) as String }
        // With "Displays have separate Spaces" off there is one entry, "Main".
        let display = displays.first { ($0["Display Identifier"] as? String) == uuid } ?? displays.first
        guard let display,
            let spaces = display["Spaces"] as? [[String: Any]],
            let current = (display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int,
            let index = spaces.firstIndex(where: { ($0["ManagedSpaceID"] as? Int) == current })
        else { return (true, true) }
        return (index > 0, index < spaces.count - 1)
    }
}
