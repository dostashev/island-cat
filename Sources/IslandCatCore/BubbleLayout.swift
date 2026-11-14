import CoreGraphics

/// A bubble in screen coordinates (y up), growing around its bottom-right
/// tail. The window includes the spring's overshoot, not just its resting size.
public struct BubbleLayout: Sendable {
    public static let maximumScale: CGFloat = 1.25
    public static let edgePadding: CGFloat = 2

    public let size: CGSize
    public let tip: CGPoint
    public let window: CGRect

    public init(size: CGSize, tip: CGPoint) {
        self.size = size
        self.tip = tip
        let peak = CGRect(
            x: tip.x - size.width * Self.maximumScale, y: tip.y,
            width: size.width * Self.maximumScale, height: size.height * Self.maximumScale)
        window = peak.insetBy(dx: -Self.edgePadding, dy: -Self.edgePadding)
    }

    /// The explicit CALayer's anchor, in the unflipped host view's coordinates.
    public var localTip: CGPoint {
        CGPoint(x: tip.x - window.minX, y: tip.y - window.minY)
    }

    public func bounds(at scale: CGFloat) -> CGRect {
        CGRect(
            x: tip.x - size.width * scale, y: tip.y,
            width: size.width * scale, height: size.height * scale)
    }
}
