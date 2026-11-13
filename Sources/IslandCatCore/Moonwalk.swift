import CoreGraphics
import Foundation

/// The cat moonwalking in place while you swipe between desktops: its feet
/// slide along with the sliding desktop, so it looks to walk with it.
public enum Moonwalk {
    /// How far the desktop has slid, in desktop widths: negative while the
    /// desktops move left (on to the desktop on the right), positive while
    /// they move right. Follows the swipe while a finger is down, then the
    /// system's own slide to the desktop it settles on.
    public struct Slide: Sendable {
        public private(set) var offset: Double = 0
        /// Where the slide ends after the fingers lift, and when it set off.
        private var release: (from: Double, to: Double, at: Double)?

        /// The system finishes the slide in about 0.75 s after the fingers
        /// lift (measured from a screen recording), easing out.
        static let settle = 0.75

        public init() {}

        /// The swipe has moved the desktops to `progress`.
        public mutating func follow(_ progress: Double) {
            release = nil
            offset = progress
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
            offset = progress
            release = (progress, to, now)
        }

        /// Advances the slide after the fingers lifted to time `now`.
        /// Returns false once it has come to rest.
        public mutating func advance(to now: Double) -> Bool {
            guard let release else { return false }
            let t = min(1, max(0, (now - release.at) / Self.settle))
            let eased = 1 - pow(1 - t, 3)
            offset = release.from + (release.to - release.from) * eased
            if t >= 1 { self.release = nil }
            return t < 1
        }

        public var isSettling: Bool { release != nil }
    }

    /// Steps the cat takes while the desktops slide one desktop width.
    public static let stepsPerDesktop = 5.0

    /// Where the cat is in its stride after the desktops slid `offset`:
    /// it steps forward as the desktops move left, back as they move right.
    public static func phase(_ offset: Double) -> Double {
        let steps = -offset * stepsPerDesktop
        return steps - steps.rounded(.down)
    }

    /// The legs, in art units: hips inside the body, feet on the ground
    /// under it. `phase` runs 0..<1 over one step; `reach` from 0 (tucked
    /// into the body) to 1 (standing).
    public static func legs(phase: Double, reach: Double) -> [(hip: CGPoint, foot: CGPoint)] {
        let hipY: CGFloat = 28
        let groundY: CGFloat = 42
        let stride: CGFloat = 5
        let lift: CGFloat = 3
        // Front and back pairs; diagonal legs step together.
        let legs: [(x: CGFloat, offset: Double)] = [(12, 0), (23, 0.5), (44, 0), (55, 0.5)]
        return legs.map { leg in
            let p = (phase + leg.offset).truncatingRemainder(dividingBy: 1)
            // On the ground the foot slides back with the desktop; in the
            // air it swings forward again.
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
