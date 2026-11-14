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
        /// that way; otherwise it springs back. `desktops` is how many there
        /// are before and after the current one; positive progress heads
        /// for the ones after it. However far a long swipe went, macOS
        /// moves at most one desktop, sliding back to it.
        public mutating func lift(
            at progress: Double, velocity: Double, now: Double, desktops: (before: Int, after: Int)
        ) {
            let projected = progress + velocity * 0.15
            var to = 0.0
            if projected <= -Walk.desktop / 2 && desktops.before > 0 { to = -Walk.desktop }
            if projected >= Walk.desktop / 2 && desktops.after > 0 { to = Walk.desktop }
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

    /// How far the swipe's progress goes from one desktop to the next,
    /// read off a swipe: the next desktop fills the screen at 1.17.
    public static let desktop = 1.17

    /// The desktops on the cat's screen, in Mission Control's order, as a
    /// swipe starts: which are plain desktops rather than full-screen apps,
    /// and which one the swipe starts on.
    public struct Desktops: Sendable {
        public var plain: [Bool]
        public var index: Int

        public init(plain: [Bool], index: Int) {
            self.plain = plain
            self.index = index
        }

        /// How many desktops there are before and after the current one.
        public var around: (before: Int, after: Int) { (index, plain.count - 1 - index) }
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
    /// it, every way they went, with the desktops `width` meters apart. A
    /// swipe on to the next desktop is that far; one that springs back is
    /// twice as far as it got; swiping back and forth counts every stroke.
    public struct Odometer: Sendable {
        public private(set) var meters: Double
        private var last: Double?

        public init(meters: Double = 0) {
            self.meters = meters
        }

        /// The desktops are at `offset` desktop widths, `width` meters apart.
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

        /// Stands on straight legs at once, at the nearest straight pose.
        public mutating func stand() {
            let half = (position - 0.25) * 2
            position = half.rounded() / 2 + 0.25
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

    /// How far the whiskers tilt, in degrees, `phase` of the way through a
    /// step with the legs `reach` of the way out: they bob once a step, the
    /// outer ends rising and falling together.
    public static func whiskerTilt(phase: Double, reach: Double) -> Double {
        5 * sin(2 * .pi * (phase - 0.25)) * min(1, max(0, reach))
    }

    static let hipY: CGFloat = 28
    /// Front and back pairs, across the body; diagonal legs step together.
    static let legPlaces: [(x: CGFloat, offset: Double)] = [(12, 0), (23, 0.5), (44, 0), (55, 0.5)]

    /// A roller skate under one foot, seen from the side, in art units.
    public struct Skate: Sendable, Equatable {
        public var hip: CGPoint
        /// Where the leg meets the boot.
        public var foot: CGPoint
        /// The boot's outline: a high top at the heel, a toe pointing the
        /// way the cat glides.
        public var boot: [CGPoint]
        /// The plate under the boot that holds the wheels.
        public var plate: CGRect
        public var wheels: [CGPoint]
        public var wheelRadius: CGFloat
    }

    /// The lowest the cat's feet reach, in art units, with the round ends
    /// of the legs: the skates' wheels stand there too.
    public static func floor(on island: Island) -> CGFloat {
        ground(on: island) + legWidth / 2 / (island.body.height / Cat.box.height)
    }

    /// The cat on roller skates, gliding: every leg straight down into a
    /// black high-top boot on two wheels, the wheels standing on `floor`,
    /// the toes pointing right or left. `reach` of the way out, the skates
    /// shrink back into the hips as the legs tuck away.
    public static func skates(reach: Double, floor: CGFloat, facingRight: Bool) -> [Skate] {
        let r = CGFloat(min(1, max(0, reach)))
        let wheel: CGFloat = 1.5
        let plateTop = floor - 2 * wheel - 0.6
        let top: CGFloat = 33
        let length: CGFloat = 8.5
        let toward: CGFloat = facingRight ? 1 : -1
        return legPlaces.map { leg in
            let hip = CGPoint(x: leg.x, y: hipY)
            // Toward the hips by `1 - r`.
            func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: hip.x + (leg.x + toward * x - hip.x) * r, y: hip.y + (y - hip.y) * r)
            }
            let heel = -length * 0.45
            let toe = length * 0.55
            let boot = [
                at(heel, plateTop), at(heel, top), at(length * 0.08, top),
                at(length * 0.12, plateTop - 2.6), at(toe - 1.4, plateTop - 2.2),
                at(toe, plateTop - 0.8), at(toe, plateTop),
            ]
            let plateCorners = [at(heel - 0.3, plateTop), at(toe + 0.3, plateTop + 0.9)]
            let plate = CGRect(
                x: min(plateCorners[0].x, plateCorners[1].x), y: plateCorners[0].y,
                width: abs(plateCorners[1].x - plateCorners[0].x),
                height: plateCorners[1].y - plateCorners[0].y)
            let axle = floor - wheel
            return Skate(
                hip: hip, foot: at(0, top), boot: boot, plate: plate,
                wheels: [at(heel + 0.4 + wheel, axle), at(toe - 0.4 - wheel, axle)],
                wheelRadius: wheel * r)
        }
    }

    /// What the cat glides on while the desktops finish sliding, when
    /// macOS does not draw it: something to stand on, frozen mid-glide.
    public enum Glide: String, Sendable, CaseIterable {
        /// It tucks its legs away and stands still.
        case none
        case skates
        case skateboard
    }

    /// A skateboard under the cat, seen from the side, in art units.
    public struct Board: Sendable, Equatable {
        /// Each leg, from the hip straight down to the deck.
        public var legs: [(hip: CGPoint, foot: CGPoint)]
        /// The deck's outline: flat in the middle, kicked up at both ends.
        public var deck: [CGPoint]
        public var wheels: [CGPoint]
        public var wheelRadius: CGFloat

        public static func == (a: Board, b: Board) -> Bool {
            a.deck == b.deck && a.wheels == b.wheels && a.wheelRadius == b.wheelRadius
                && a.legs.map(\.hip) == b.legs.map(\.hip) && a.legs.map(\.foot) == b.legs.map(\.foot)
        }
    }

    /// The cat standing on a skateboard, every leg straight down onto the
    /// deck, its wheels on `floor`. `reach` of the way out, the board
    /// shrinks back into the body as the legs tuck away.
    public static func skateboard(reach: Double, floor: CGFloat) -> Board {
        let r = CGFloat(min(1, max(0, reach)))
        let middle = CGPoint(x: Cat.box.width / 2, y: hipY)
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: middle.x + (x - middle.x) * r, y: middle.y + (y - middle.y) * r)
        }
        let wheel: CGFloat = 1.6
        let deckBottom = floor - 2 * wheel - 0.3
        let deckTop = deckBottom - 2
        let (nose, tail): (CGFloat, CGFloat) = (5, Cat.box.width - 5)
        let kick: CGFloat = 2.4
        // Around the outline: along the top, up the kicked tail, back along
        // the bottom and up the nose.
        let deck = [
            at(nose + 4, deckTop), at(tail - 4, deckTop), at(tail, deckTop - kick),
            at(tail + 0.6, deckTop - kick + 1.1), at(tail - 3.6, deckBottom),
            at(nose + 3.6, deckBottom), at(nose - 0.6, deckTop - kick + 1.1), at(nose, deckTop - kick),
        ]
        let axle = floor - wheel
        return Board(
            legs: legPlaces.map { (at($0.x, hipY), at($0.x, deckTop)) },
            deck: deck, wheels: [at(nose + 8, axle), at(tail - 8, axle)], wheelRadius: wheel * r)
    }

    /// The legs, in art units: hips inside the body, feet on the ground
    /// under it at `ground`. `phase` runs 0..<1 over one step; `reach` from
    /// 0 (tucked into the body) to 1 (standing).
    public static func legs(
        phase: Double, reach: Double, ground groundY: CGFloat = 42
    ) -> [(hip: CGPoint, foot: CGPoint)] {
        let stride: CGFloat = 5
        let lift: CGFloat = 3
        return legPlaces.map { leg in
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
            let hip = CGPoint(x: leg.x, y: Self.hipY)
            let foot = CGPoint(x: leg.x + x * r, y: Self.hipY + (groundY - up - Self.hipY) * r)
            return (hip, foot)
        }
    }
}

extension Walk {
    /// The rainbow a nyan cat trails while it walks: six bands, drawn as
    /// short blocks side by side, every other block a step higher, the
    /// steps swapping with each stride.
    public enum Rainbow {
        public static let bands = 6
        /// One block of every band, `from` to `to` points out from where
        /// the rainbow starts, raised by `rise` points.
        public struct Block: Sendable, Equatable {
            public var from: CGFloat
            public var to: CGFloat
            public var rise: CGFloat
        }

        /// The blocks of a rainbow `length` points long, made of blocks
        /// `width` wide that step up by `step`; `flip` swaps which blocks
        /// are raised. The last block is cut short at `length`.
        public static func blocks(
            length: CGFloat, width: CGFloat, step: CGFloat, flip: Bool
        ) -> [Block] {
            guard length > 0, width > 0 else { return [] }
            let count = Int((length / width).rounded(.up))
            return (0..<count).map { i in
                let raised = (i % 2 == 1) != flip
                return Block(
                    from: CGFloat(i) * width, to: min(length, CGFloat(i + 1) * width),
                    rise: raised ? step : 0)
            }
        }

        /// Whether the raised blocks are swapped, `phase` of the way
        /// through a step: twice a step, with the footfalls.
        public static func flip(phase: Double) -> Bool {
            let half = (phase * 2).truncatingRemainder(dividingBy: 1)
            return half >= 0.5
        }
    }
}
