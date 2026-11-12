import CoreGraphics

/// How the system's island responds to the pointer, measured by recording
/// it at 120 frames a second on the MacBook Pro with PROLED XDR Display
/// (`scripts/measure-island.swift`).
///
/// - It grows 4.5 pt out to each side and 2.5 pt up and down (58 × 31 pt to
///   67 × 36 pt), and leans toward the pointer by a tenth of the pointer's
///   distance from its center.
/// - It starts to grow when the pointer comes within 7 pt of its left end
///   or 1.5 pt of its right end (it measures the arrow beside the pointer,
///   not just its tip), at most 24 pt below its top; and shrinks when the
///   pointer leaves the grown island, other than over its top.
/// - It grows like a critically damped spring settling in about 0.35 s,
///   about 50 ms after the pointer arrives, and shrinks twice as fast,
///   about 80 ms after the pointer leaves.
extension Island {
    public enum Hover {
        static let growth = CGSize(width: 4.5, height: 2.5)
        static let lean: CGFloat = 0.1
        static let reachLeft: CGFloat = 7
        static let reachRight: CGFloat = 1.5
        static let reachDown: CGFloat = 24

        /// A critically damped spring: `stiffness` and `damping` for a unit
        /// mass, started `delay` seconds after the pointer arrives or leaves.
        public struct Spring: Sendable, Equatable {
            public var stiffness: Double
            public var damping: Double
            public var delay: Double
        }

        public static let grow = Spring(stiffness: 280, damping: 33.5, delay: 0.05)
        public static let shrink = Spring(stiffness: 820, damping: 57, delay: 0.08)
    }

    /// Whether the pointer at `point` makes the island at rest grow.
    public func startsHover(at point: CGPoint) -> Bool {
        guard !isNotch else { return false }
        return point.x >= body.minX - Hover.reachLeft
            && point.x <= body.maxX + Hover.reachRight
            && point.y >= body.maxY - Hover.reachDown
            && point.y <= band.maxY
    }

    /// Whether the grown island stays grown with the pointer at `point`:
    /// anywhere on it, or above it up to the screen's edge.
    public func keepsHover(at point: CGPoint) -> Bool {
        guard !isNotch else { return false }
        let grown = hovered(toward: point)
        return point.x >= grown.minX && point.x <= grown.maxX
            && point.y >= grown.minY && point.y <= band.maxY
    }

    /// The grown island, leaning toward the pointer at `point`.
    public func hovered(toward point: CGPoint) -> CGRect {
        guard !isNotch else { return body }
        let grown = body.insetBy(dx: -Hover.growth.width, dy: -Hover.growth.height)
        return grown.offsetBy(
            dx: (point.x - body.midX) * Hover.lean, dy: (point.y - body.midY) * Hover.lean)
    }

    /// Everywhere the grown island can reach while the pointer keeps it grown.
    var hoverReach: CGRect {
        guard !isNotch else { return body }
        let grown = body.insetBy(dx: -Hover.growth.width, dy: -Hover.growth.height)
        // The pointer keeps it grown only inside it, so it leans at most a
        // tenth of its own half-size beyond the lean it already has.
        let lean = Hover.lean / (1 - Hover.lean)
        return grown.insetBy(dx: -grown.width / 2 * lean, dy: -grown.height / 2 * lean)
    }
}
