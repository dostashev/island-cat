import CoreGraphics
import Foundation

/// The cat walking in place while you swipe between desktops: it stays on
/// the island, fixed on the screen, and walks the way the desktops slide,
/// as if going along with them.
public enum Walk {
    /// How far the desktops have slid, in desktop widths: down while they
    /// move left (on to the desktop on the right), up while they move
    /// right. Follows the swipe while the fingers are down, then the
    /// system's own slide to the desktop it settles on, and carries on from
    /// there at the next swipe, so it never jumps.
    public struct Slide: Sendable {
        public private(set) var offset: Double = 0
        /// The offset of the desktop the current swipe started from.
        private var base: Double = 0
        /// Where the slide ends after the fingers lift, and when it set off.
        private var release: (from: Double, to: Double, at: Double)?

        /// The system finishes the slide in about 0.75 s after the fingers
        /// lift (measured from a screen recording), easing out.
        static let settle = 0.75

        public init() {}

        /// The swipe has moved the desktops `progress` desktop widths from
        /// where it started.
        public mutating func follow(_ progress: Double) {
            if let release {
                // A new swipe during the slide starts from where it was going.
                base = release.to
                self.release = nil
            }
            offset = base + progress
        }

        /// The fingers lifted at `progress`, moving at `velocity` desktop
        /// widths a second, at time `now`. The slide goes on to the next
        /// desktop past halfway or when flicked, unless there is no desktop
        /// that way; otherwise it springs back.
        public mutating func lift(
            at progress: Double, velocity: Double, now: Double, canGoLeft: Bool, canGoRight: Bool
        ) {
            let projected = progress + velocity * 0.15
            var to = 0.0
            if projected <= -0.5 && canGoRight { to = -1 }
            if projected >= 0.5 && canGoLeft { to = 1 }
            offset = base + progress
            release = (offset, base + to, now)
        }

        /// Advances the slide after the fingers lifted to time `now`.
        /// Returns false once it has come to rest.
        public mutating func advance(to now: Double) -> Bool {
            guard let release else { return false }
            let t = min(1, max(0, (now - release.at) / Self.settle))
            let eased = 1 - pow(1 - t, 3)
            offset = release.from + (release.to - release.from) * eased
            if t >= 1 {
                base = release.to
                self.release = nil
            }
            return t < 1
        }

        public var isSettling: Bool { release != nil }
    }

    /// Which way the cat is going: the way the desktops last slid, turning
    /// only once they have slid `turn` desktop widths back the other way,
    /// so a wobble of the fingers does not flip it.
    public struct Heading: Sendable {
        public private(set) var right = false
        /// The furthest the desktops got the way the cat is going.
        private var furthest: Double = 0
        static let turn = 0.02

        /// Heading left, with the desktops at `offset`.
        public init(at offset: Double = 0) {
            furthest = offset
        }

        /// Follows the slide to `offset`; returns true when the cat turns.
        public mutating func follow(_ offset: Double) -> Bool {
            if right ? offset < furthest - Self.turn : offset > furthest + Self.turn {
                right.toggle()
                furthest = offset
                return true
            }
            furthest = right ? max(furthest, offset) : min(furthest, offset)
            return false
        }
    }

    /// How thick the legs are drawn, in points.
    public static let legWidth: CGFloat = 2

    /// The ground under the cat on `island`, in art units: as low as the
    /// menu bar goes, so that the feet never stick out below it. A
    /// full-screen app paints the band black and starts right under it.
    public static func ground(on island: Island) -> CGFloat {
        let scale = island.body.height / Cat.box.height
        let room = island.body.maxY - island.band.minY - legWidth / 2 - 0.5
        return min(42, room / scale)
    }

    /// How far the cat has walked: as far as the desktops have slid under
    /// it, either way, on a screen `width` meters wide.
    public struct Odometer: Sendable {
        public private(set) var meters: Double
        private var last: Double?

        public init(meters: Double = 0) {
            self.meters = meters
        }

        /// The desktops are at `offset` desktop widths on a screen `width`
        /// meters wide.
        public mutating func follow(_ offset: Double, width: Double) {
            if let last { meters += abs(offset - last) * width }
            last = offset
        }
    }

    /// Where the cat is in its stride, as the desktops slide under it.
    ///
    /// It steps forward as they slide right, the way it walks then, and
    /// back as they slide left: five steps a desktop, but never more than
    /// six steps a second, so a fast swipe does not strobe the legs into a
    /// blur that seems to stand still or run backward. When the desktops
    /// stop, it finishes its step to where every leg stands straight under
    /// its hip, half on the ground and half mid-swing, a quarter or three
    /// quarters of the way through a step, and the legs tuck straight up.
    public struct Stride: Sendable {
        /// 0..<1 over one step.
        public var phase: Double { position - position.rounded(.down) }
        private var position = 0.25
        /// Which way it last stepped: 1 forward, -1 back.
        private var direction = 1.0

        static let stepsPerDesktop = 5.0
        static let cadence = 6.0

        public init() {}

        /// The desktops slid `slid` desktop widths in `elapsed` seconds.
        public mutating func follow(_ slid: Double, elapsed: Double) {
            let wanted = slid * Self.stepsPerDesktop
            let most = Self.cadence * elapsed
            position += min(most, max(-most, wanted))
            if wanted != 0 { direction = wanted > 0 ? 1 : -1 }
        }

        /// Whether the legs stand straight.
        public var isStraight: Bool {
            let half = (position - 0.25) * 2
            return abs(half - half.rounded()) < 1e-9
        }

        /// The desktops have stopped: carries on the way it was going to
        /// the next straight-legged pose, for `elapsed` seconds.
        public mutating func finish(elapsed: Double) {
            let half = (position - 0.25) * 2
            let target = (direction > 0 ? half.rounded(.up) : half.rounded(.down)) / 2 + 0.25
            let most = Self.cadence * elapsed
            position += min(most, max(-most, target - position))
            if abs(target - position) < 1e-9 { position = target }
        }
    }

    /// The legs, in art units: hips inside the body, feet on the ground
    /// under it at `ground`. `phase` runs 0..<1 over one step; `reach` from
    /// 0 (tucked into the body) to 1 (standing).
    public static func legs(
        phase: Double, reach: Double, ground groundY: CGFloat = 42
    ) -> [(hip: CGPoint, foot: CGPoint)] {
        let hipY: CGFloat = 28
        let stride: CGFloat = 5
        let lift: CGFloat = 3
        // Front and back pairs; diagonal legs step together.
        let legs: [(x: CGFloat, offset: Double)] = [(12, 0), (23, 0.5), (44, 0), (55, 0.5)]
        return legs.map { leg in
            let p = (phase + leg.offset).truncatingRemainder(dividingBy: 1)
            // On the ground the foot pushes back, against the way the cat
            // walks; in the air it swings forward again. Phase running
            // backward walks the other way.
            let x: CGFloat
            let up: CGFloat
            if p < 0.5 {
                x = stride - 4 * stride * CGFloat(p)
                up = 0
            } else {
                x = -stride + 4 * stride * CGFloat(p - 0.5)
                up = lift * CGFloat(sin(.pi * (p - 0.5) * 2))
            }
            let r = CGFloat(min(1, max(0, reach)))
            let hip = CGPoint(x: leg.x, y: hipY)
            let foot = CGPoint(x: leg.x + x * r, y: hipY + (groundY - up - hipY) * r)
            return (hip, foot)
        }
    }
}
