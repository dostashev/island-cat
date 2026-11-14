import CoreGraphics

/// A screen as AppKit reports it: points, y up, in global screen coordinates.
public struct ScreenShape: Sendable, Equatable {
    /// `NSScreen.frame`.
    public var frame: CGRect
    /// `NSScreen.visibleFrame.maxY`: the bottom of the menu bar while it shows.
    public var visibleTop: CGFloat
    /// `NSScreen.safeAreaInsets.top`: the camera housing's height.
    public var safeTop: CGFloat
    /// `NSScreen.auxiliaryTopLeftArea`, or `.zero` without a camera housing.
    public var leftOfCamera: CGRect
    /// `NSScreen.auxiliaryTopRightArea`, or `.zero` without a camera housing.
    public var rightOfCamera: CGRect

    public init(
        frame: CGRect, visibleTop: CGFloat, safeTop: CGFloat,
        leftOfCamera: CGRect, rightOfCamera: CGRect
    ) {
        self.frame = frame
        self.visibleTop = visibleTop
        self.safeTop = safeTop
        self.leftOfCamera = leftOfCamera
        self.rightOfCamera = rightOfCamera
    }
}

/// Where the camera's island sits on a screen.
public struct Island: Sendable, Equatable {
    /// The strip across the top of the screen as tall as the menu bar.
    public var band: CGRect
    /// The island as the system draws it at rest.
    public var body: CGRect
    /// A notch, which the cat sits in the menu bar to the left of, its body
    /// drawn there, as nothing on screen grows under the pointer.
    public var notch: CGRect?
    public var isNotch: Bool { notch != nil }

    /// The Dynamic Island at rest sits in the bottom of its camera housing:
    /// a pill 31 pt tall, inset 0.5 pt from the housing's sides and bottom
    /// (58 × 31 pt in the 59 × 40 pt housing of the MacBook Pro with PROLED
    /// XDR Display, measured from a screenshot).
    static let restInset: CGFloat = 0.5
    static let restHeight: CGFloat = 31

    /// The island on `screen`, or nil when the screen has no camera housing.
    ///
    /// The band is as tall as the menu bar, which can be taller than the
    /// housing (45 pt beside a 40 pt housing on the PROLED panel); while the
    /// menu bar hides, `menuBarHeight` stands in for it.
    public static func on(_ screen: ScreenShape, menuBarHeight: CGFloat = 0) -> Island? {
        let left = screen.leftOfCamera
        let right = screen.rightOfCamera
        guard screen.safeTop > 0, left.width > 0, right.width > 0 else { return nil }
        let housingLeft = left.maxX
        let housing = right.minX - housingLeft
        guard housing > 0 else { return nil }

        let top = screen.frame.maxY
        let bandHeight = max(screen.safeTop, top - screen.visibleTop, menuBarHeight)
        let band = CGRect(
            x: screen.frame.minX, y: top - bandHeight, width: screen.frame.width, height: bandHeight)

        // A pill camera's housing is less than three times as wide as it is
        // tall; a notch is wider. Beside a notch the cat gets a body of the
        // Dynamic Island's shape, sized to the menu bar, with room above it
        // for the ears, below it for the legs, and between its tail and the
        // notch.
        if housing >= 3 * screen.safeTop {
            let height = (bandHeight * 0.62).rounded()
            let width = (height * 58 / 31).rounded()
            let tail = height * 51 / Cat.box.height
            let body = CGRect(
                x: housingLeft - 8 - tail - width,
                y: top - height * 0.15 - 2 - height,
                width: width, height: height)
            let notch = CGRect(
                x: housingLeft, y: top - screen.safeTop, width: housing, height: screen.safeTop)
            return Island(band: band, body: body, notch: notch)
        }
        let height = min(restHeight, screen.safeTop - restInset)
        let body = CGRect(
            x: housingLeft + restInset,
            y: top - screen.safeTop + restInset,
            width: housing - 2 * restInset,
            height: height)
        return Island(band: band, body: body, notch: nil)
    }

    /// How close, around the grown island, the pointer comes before the
    /// cat notices.
    static let noticeRoom: CGFloat = 64
    /// Room around the body for the parts that stick out, the nyan
    /// rainbow's the longest.
    static let sideRoom: CGFloat = 104
    static let roomBelow: CGFloat = 12

    /// Where the pointer livens the cat up: around the grown island, down
    /// to the bottom of the window.
    public var nearby: CGRect {
        let window = canvas
        let grown = hoverReach
        return CGRect(
            x: grown.minX - Self.noticeRoom, y: window.minY,
            width: grown.width + 2 * Self.noticeRoom, height: window.height)
    }

    /// The window the cat lives in: the band around the island, plus room
    /// below it for the tail and at the sides for the rainbow.
    public var canvas: CGRect {
        let grown = hoverReach
        let bottom = min(band.minY, grown.minY) - Self.roomBelow
        return CGRect(
            x: grown.minX - Self.sideRoom,
            y: bottom,
            width: grown.width + 2 * Self.sideRoom,
            height: band.maxY - bottom)
    }
}
