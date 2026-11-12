import AppKit

/// A private WindowServer space above the desktops, so windows in it stay
/// put while you swipe between desktops, open Mission Control, or enter a
/// full-screen app.
///
/// A window on every desktop (`canJoinAllSpaces`) is still a member of the
/// desktop it is showing on, so it slides away with that desktop and joins
/// the next one only when the swipe ends. A window claimed into this space
/// belongs to no desktop, and the desktop transitions leave it alone.
///
/// This uses SkyLight's private space calls, looked up at run time. Without
/// them, windows keep the ordinary all-desktops behavior.
@MainActor
enum FixedSpace {
    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddWindowsAndRemoveFromSpaces =
        @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    /// Above the desktops and below the lock screen (setup assistant level;
    /// the screen lock is 300).
    private static let level: Int32 = 100
    /// Take the windows off the current, other, and user spaces.
    private static let everyManagedSpace: Int32 = 0x7

    private static let space: (connection: Int32, id: Int32, claim: AddWindowsAndRemoveFromSpaces)? = {
        guard
            let skyLight = dlopen(
                "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW),
            let mainConnection = dlsym(skyLight, "SLSMainConnectionID"),
            let create = dlsym(skyLight, "SLSSpaceCreate"),
            let setLevel = dlsym(skyLight, "SLSSpaceSetAbsoluteLevel"),
            let show = dlsym(skyLight, "SLSShowSpaces"),
            let claim = dlsym(skyLight, "SLSSpaceAddWindowsAndRemoveFromSpaces")
        else { return nil }
        let connection = unsafeBitCast(mainConnection, to: MainConnectionID.self)()
        let id = unsafeBitCast(create, to: SpaceCreate.self)(connection, 1, 0)
        guard id != 0,
            unsafeBitCast(setLevel, to: SpaceSetAbsoluteLevel.self)(connection, id, level) == 0
        else { return nil }
        // Its result is not a reliable error code on every macOS release.
        _ = unsafeBitCast(show, to: ShowSpaces.self)(connection, [id] as CFArray)
        return (connection, id, unsafeBitCast(claim, to: AddWindowsAndRemoveFromSpaces.self))
    }()

    /// Moves `windows` into the fixed space. Ordering a window front puts it
    /// back on the current desktop, so claim again after every order front.
    static func claim(_ windows: [NSWindow]) {
        guard let space, !windows.isEmpty else { return }
        let numbers = windows.map { NSNumber(value: $0.windowNumber) }
        _ = space.claim(space.connection, space.id, numbers as CFArray, everyManagedSpace)
    }
}
