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

    /// Steps the cat takes while the desktops slide one desktop width.
    public static let stepsPerDesktop = 5.0

    /// Where the cat is in its stride after the desktops slid `offset`: it
    /// steps forward as they slide right, the way it walks then, and back
    /// as they slide left. A desktop at rest is a quarter of the way into
    /// a step, where every leg stands straight under its hip, half of them
    /// on the ground and half mid-swing, so a walk starts and ends there.
    public static func phase(_ offset: Double) -> Double {
        let steps = offset * stepsPerDesktop + 0.25
        return steps - steps.rounded(.down)
    }

    /// The legs, in art units: hips inside the body, feet on the ground
    /// under it. `phase` runs 0..<1 over one step; `stepping` from 0 (legs
    /// straight down, feet under the hips) to 1 (a full stride); `reach`
    /// from 0 (tucked into the body) to 1 (standing).
    public static func legs(
        phase: Double, stepping: Double = 1, reach: Double
    ) -> [(hip: CGPoint, foot: CGPoint)] {
        let hipY: CGFloat = 28
        let groundY: CGFloat = 42
        let stride: CGFloat = 5 * CGFloat(min(1, max(0, stepping)))
        let lift: CGFloat = 3 * CGFloat(min(1, max(0, stepping)))
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
            let foot = CGPoint(x: leg.x + x, y: hipY + (groundY - up - hipY) * r)
            return (hip, foot)
        }
    }
}
