import CoreGraphics

/// The cat, drawn around the island as if the island were its body.
///
/// Parts are drawn in art units on a 67 × 36 box, y down, laid over the
/// island's body (see `Placement`); points outside the box stick out of it.
public enum Cat {
    public static let box = CGSize(width: 67, height: 36)

    public enum Segment: Sendable, Equatable {
        case move(CGPoint)
        case line(CGPoint)
        case curve(CGPoint, CGPoint, CGPoint)
        case close
    }

    /// One way a part moves: keyframes of `values` at `keyTimes` (fractions
    /// of `duration`, in seconds), starting `delay` seconds in.
    public struct Motion: Sendable, Equatable {
        public enum Property: Sendable { case rotation, rise }
        public var property: Property
        /// Rotation in degrees counterclockwise, or rise in points.
        public var values: [Double]
        public var keyTimes: [Double]
        public var duration: Double
        public var delay: Double = 0
        public var autoreverses = false
    }

    public struct Part: Sendable {
        public var name: String
        public var segments: [Segment]
        public var filled: Bool
        public var lineWidth: CGFloat
        /// What it turns around, as a fraction of its bounding box, y up.
        public var pivot: CGPoint
        /// How it moves on its own, and how it moves when the pointer is near.
        public var idle: Motion?
        public var excited: Motion?
    }

    static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// An ear flick: still most of the time, then a twitch out and back.
    static func flick(_ out: Double, duration: Double, delay: Double = 0) -> Motion {
        Motion(
            property: .rotation, values: [0, 0, out, -out * 3 / 7, 0],
            keyTimes: [0, 0.88, 0.92, 0.96, 1], duration: duration, delay: delay)
    }

    /// Ears perked up: flicking all the time.
    static func perked(_ out: Double, delay: Double = 0) -> Motion {
        Motion(
            property: .rotation, values: [0, out, -out * 3 / 7, 0, 0],
            keyTimes: [0, 0.2, 0.4, 0.6, 1], duration: 0.7, delay: delay)
    }

    public static let parts: [Part] = [
        Part(
            name: "body",
            segments: [],  // drawn as a pill; see `bodyPath`
            filled: true, lineWidth: 0, pivot: p(0.5, 0.5), idle: nil, excited: nil),
        Part(
            name: "left ear",
            segments: [.move(p(4, 13)), .line(p(5, -4)), .line(p(22, 1)), .close],
            filled: true, lineWidth: 1.6, pivot: p(0.5, 0),
            idle: flick(14, duration: 5.3), excited: perked(14)),
        Part(
            name: "right ear",
            segments: [.move(p(63, 13)), .line(p(62, -4)), .line(p(45, 1)), .close],
            filled: true, lineWidth: 1.6, pivot: p(0.5, 0),
            idle: flick(-14, duration: 7.1, delay: 1.7), excited: perked(-14, delay: 0.12)),
        Part(
            name: "left whiskers",
            segments: [
                .move(p(-3, 13)), .line(p(-16, 9)),
                .move(p(-3, 18)), .line(p(-17, 18)),
                .move(p(-3, 23)), .line(p(-16, 27)),
            ],
            filled: false, lineWidth: 1.6, pivot: p(0.5, 0.5),
            idle: nil, excited: whiskerTwitch),
        Part(
            name: "right whiskers",
            segments: [
                .move(p(70, 13)), .line(p(83, 9)),
                .move(p(70, 18)), .line(p(84, 18)),
                .move(p(70, 23)), .line(p(83, 27)),
            ],
            filled: false, lineWidth: 1.6, pivot: p(0.5, 0.5),
            idle: nil, excited: whiskerTwitch),
        Part(
            name: "tail",
            segments: [
                .move(p(58, 34)),
                .curve(p(78, 40), p(98, 38), p(104, 25)),
                .curve(p(108, 15), p(114, 11), p(118, 17)),
            ],
            filled: false, lineWidth: 3.2, pivot: p(0, 0),
            idle: Motion(
                property: .rotation, values: [4, -3], keyTimes: [0, 1], duration: 3.2,
                autoreverses: true),
            excited: Motion(
                property: .rotation, values: [0, 14, -5, 0], keyTimes: [0, 0.35, 0.7, 1],
                duration: 0.9)),
    ]

    static let whiskerTwitch = Motion(
        property: .rise, values: [0, 1, 0], keyTimes: [0, 0.5, 1], duration: 0.5)

    /// Maps art units onto `body`, in coordinates whose origin is `origin`,
    /// y up.
    public struct Placement: Sendable {
        public var body: CGRect
        public var origin: CGPoint

        public init(body: CGRect, origin: CGPoint) {
            self.body = body
            self.origin = origin
        }

        /// Points per art unit: the art keeps its shape at the body's height.
        public var scale: CGFloat { body.height / Cat.box.height }

        /// Art on the left half of the box keeps its distance from the
        /// body's left end, and art on the right half from its right end,
        /// so a wide notch makes a long cat rather than a stretched one.
        public func point(_ art: CGPoint) -> CGPoint {
            let x =
                art.x < Cat.box.width / 2
                ? body.minX + art.x * scale
                : body.maxX - (Cat.box.width - art.x) * scale
            return CGPoint(x: x - origin.x, y: body.maxY - origin.y - art.y * scale)
        }

        public func path(_ part: Part) -> CGPath {
            if part.segments.isEmpty { return bodyPath }
            let path = CGMutablePath()
            for segment in part.segments {
                switch segment {
                case .move(let to): path.move(to: point(to))
                case .line(let to): path.addLine(to: point(to))
                case .curve(let a, let b, let to):
                    path.addCurve(to: point(to), control1: point(a), control2: point(b))
                case .close: path.closeSubpath()
                }
            }
            return path
        }

        /// The island itself, so the cat is whole wherever the system's
        /// island is not drawn over it.
        public var bodyPath: CGPath {
            let rect = CGRect(
                origin: CGPoint(x: body.minX - origin.x, y: body.minY - origin.y), size: body.size)
            let radius = min(rect.height, rect.width) / 2
            return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
    }
}
