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
    /// A notch: the housing itself, flush with the top edge.
    public var isNotch: Bool

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
        // tall; a notch is wider, and is its own island.
        if housing >= 3 * screen.safeTop {
            let body = CGRect(
                x: housingLeft, y: top - screen.safeTop, width: housing, height: screen.safeTop)
            return Island(band: band, body: body, isNotch: true)
        }
        let height = min(restHeight, screen.safeTop - restInset)
        let body = CGRect(
            x: housingLeft + restInset,
            y: top - screen.safeTop + restInset,
            width: housing - 2 * restInset,
            height: height)
        return Island(band: band, body: body, isNotch: false)
    }

    /// Room around the body for the parts that stick out, and for the
    /// pointer to come close before the cat notices.
    static let sideRoom: CGFloat = 56
    static let roomBelow: CGFloat = 12

    /// The window the cat lives in: the band around the island, plus room
    /// below it for the tail. Also the zone where the pointer livens it up.
    public var canvas: CGRect {
        let bottom = min(band.minY, body.minY) - Self.roomBelow
        return CGRect(
            x: body.minX - Self.sideRoom,
            y: bottom,
            width: body.width + 2 * Self.sideRoom,
            height: band.maxY - bottom)
    }
}
