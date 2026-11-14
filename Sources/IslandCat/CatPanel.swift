import AppKit
import IslandCatCore
import QuartzCore

/// A click-through window over the camera's island that the cat lives in.
@MainActor
final class CatPanel: NSPanel {
    let island: Island
    private let pieces: [Piece]
    private let animates: Bool
    private var excited = false
    /// The island is grown under the pointer, as far as the cat knows.
    private var grown = false
    /// A change of `grown` waiting for the system's island to start it.
    private var pending: Task<Void, Never>?
    private var pointer = NSPoint.zero
    /// The pointer resting on the cat pets it, and it says something.
    private lazy var bubble = Bubble(animates: animates)
    private var lastReply: String?
    /// Waiting for the pointer to have rested on the cat long enough.
    private var petting: Task<Void, Never>?
    /// Legs, out only while the cat walks, and roller skates under them
    /// while it glides.
    private let legs = CAShapeLayer()
    private let skates = CAShapeLayer()
    /// The nyan cat's rainbow, one layer a band, behind everything, fading
    /// out toward its end.
    private let rainbow = CALayer()
    private let rainbowFade = CAGradientLayer()
    /// The rainbow is drawn on the right and mirrored to trail on the left.
    private var rainbowOnRight = true
    private let bands: [CAShapeLayer] = [
        (1, 0, 0), (1, 0.6, 0), (1, 1, 0), (0.2, 1, 0), (0, 0.6, 1), (0.4, 0.2, 1),
    ].map { red, green, blue in
        let band = CAShapeLayer()
        band.fillColor = NSColor(srgbRed: red, green: green, blue: blue, alpha: 1).cgColor
        return band
    }
    /// Mirrors the tail across the cat, to trail behind it as it goes right.
    private let tailSide = CALayer()
    /// The whole cat, which slides in and out of the notch, inside `clip`,
    /// which cuts it off at the notch's side meanwhile.
    private let cat = CALayer()
    private let clip = CALayer()
    /// The cat door in the notch's side, there only while the cat comes out.
    private let door = CAShapeLayer()
    private var entrance: Timer?

    /// One part of the cat: `shape` draws it and runs its motion, inside
    /// `holder`, which follows the island as it grows under the pointer.
    private struct Piece {
        var part: Cat.Part
        var holder: CALayer
        /// Turns the part around its pivot as the cat walks.
        var tilt: CALayer
        var shape: CAShapeLayer
        var restScale: CGFloat
    }

    init(island: Island, scale: CGFloat, animates: Bool) {
        self.island = island
        self.animates = animates
        let canvas = island.canvas
        let rest = Cat.Placement(body: island.body, origin: canvas.origin)
        pieces = Cat.parts.map { Self.piece($0, placement: rest, scale: scale) }

        super.init(
            contentRect: canvas, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        // Above the menu bar, below the menus that drop down from it.
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let view = NSView(frame: NSRect(origin: .zero, size: canvas.size))
        view.wantsLayer = true
        // The cat door behind the cat, whose back the open flap rests on.
        door.contentsScale = scale
        door.fillColor = NSColor(white: 0.28, alpha: 1).cgColor
        door.opacity = 0
        view.layer?.addSublayer(door)
        clip.frame = view.bounds
        cat.frame = view.bounds
        clip.addSublayer(cat)
        view.layer?.addSublayer(clip)
        legs.contentsScale = scale
        legs.strokeColor = NSColor.black.cgColor
        legs.fillColor = nil
        legs.lineWidth = Walk.legWidth
        legs.lineCap = .round
        for band in bands { rainbow.addSublayer(band) }
        // Mirrored across the middle of the body to trail on the left.
        rainbow.anchorPoint = CGPoint(x: (island.body.midX - canvas.minX) / canvas.width, y: 0.5)
        rainbow.frame = view.bounds
        rainbowFade.frame = rainbow.bounds
        rainbowFade.colors = [NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
        rainbow.mask = rainbowFade
        cat.addSublayer(rainbow)
        cat.addSublayer(legs)
        skates.contentsScale = scale
        skates.fillColor = NSColor.black.cgColor
        cat.addSublayer(skates)
        tailSide.anchorPoint = CGPoint(
            x: (island.body.midX - canvas.minX) / canvas.width, y: 0.5)
        tailSide.frame = CGRect(origin: .zero, size: canvas.size)
        cat.addSublayer(tailSide)
        for piece in pieces {
            (piece.part.name == "tail" ? tailSide : cat).addSublayer(piece.holder)
        }
        contentView = view
        setFrame(canvas, display: false)
        move()
    }

    /// Beside a notch, the cat comes out of it through a cat door: the
    /// flap in the notch's side swings open, the cat walks out to its
    /// place, and the flap swings shut behind its tail.
    func comeOutOfTheNotch() {
        guard animates, island.isNotch, !throughTheDoor else { return }
        goThroughTheDoor(out: true)
    }

    /// Clicked, the cat beside a notch goes back into it through the cat
    /// door, stays a few seconds, and comes out again.
    private func hideInTheNotch() {
        guard animates, island.isNotch, !throughTheDoor else { return }
        petting?.cancel()
        petting = nil
        goThroughTheDoor(out: false) { [weak self] in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.goThroughTheDoor(out: true)
            }
        }
    }

    /// The cat is going through the cat door, or is in the notch.
    private var throughTheDoor = false

    private func goThroughTheDoor(out: Bool, then done: (@MainActor @Sendable () -> Void)? = nil) {
        guard let notch = island.notch else { return }
        throughTheDoor = true
        ignoresMouseEvents = true
        let origin = island.canvas.origin
        let edge = notch.minX - origin.x
        let placement = Cat.Placement(body: island.body, origin: origin)
        // Far enough right that all of the cat, whiskers first, is inside
        // the notch.
        let inside = edge - placement.point(CGPoint(x: -18, y: 0)).x + 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        clip.frame = CGRect(x: 0, y: 0, width: edge, height: cat.bounds.height)
        clip.masksToBounds = true
        cat.setAffineTransform(CGAffineTransform(translationX: out ? inside : 0, y: 0))
        // Going in it walks right, its tail trailing on the left.
        tail(onLeft: !out)

        // The flap: hinged at its top on the notch's side, as tall as the
        // cat's body, pushed open to the left as the cat goes through.
        let width: CGFloat = 2.5
        let height = island.body.height + 4
        door.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        door.path = CGPath(
            roundedRect: door.bounds, cornerWidth: width / 2, cornerHeight: width / 2, transform: nil)
        door.anchorPoint = CGPoint(x: 0.5, y: 1)
        door.position = CGPoint(x: edge - width / 2, y: island.body.maxY + 2 - origin.y)
        door.opacity = 1
        CATransaction.commit()

        let swing = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let open = -70 * Double.pi / 180
        swing.values = [0, open, open, 0.3, -0.14, 0.06, 0]
        swing.keyTimes = [0, 0.1, 0.6, 0.72, 0.82, 0.91, 1]
        swing.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .easeInEaseOut),
        ]
        swing.duration = 1.9
        door.add(swing, forKey: "swing")
        let vanish = CABasicAnimation(keyPath: "opacity")
        vanish.fromValue = 1
        vanish.toValue = 0
        vanish.beginTime = CACurrentMediaTime() + 1.9
        vanish.duration = 0.3
        vanish.fillMode = .backwards
        door.add(vanish, forKey: "vanish")
        door.opacity = 0

        // The cat walks through, stepping as it goes, coming out easing to
        // a stop and going in setting off slowly, then stands on straight
        // legs and tucks them away.
        let began = CACurrentMediaTime()
        var stride = Walk.Stride()
        var travelled: CGFloat = 0
        var reach = 0.0
        entrance?.invalidate()
        entrance = Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let t = min(1, max(0, (CACurrentMediaTime() - began - 0.12) / 0.85))
                let eased = out ? 1 - pow(1 - t, 3) : t * t * (3 - 2 * t)
                let offset = out ? inside * (1 - eased) : inside * eased
                let moved = abs(inside * eased - travelled)
                travelled = inside * eased
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.cat.setAffineTransform(CGAffineTransform(translationX: offset, y: 0))
                CATransaction.commit()
                if t < 1 && moved > 0.01 {
                    // Three steps through, back through the stride going
                    // left and forward going right.
                    stride.follow(Double(moved / inside) * (out ? -0.6 : 0.6), elapsed: 1.0 / 120)
                    reach = min(1, reach + 1.0 / 12)
                } else {
                    stride.finish(elapsed: 1.0 / 120)
                    if stride.isStraight { reach = max(0, reach - 1.0 / 18) }
                }
                self.walk(phase: stride.phase, reach: reach, gliding: nil)
                guard t >= 1 && reach == 0 else { return }
                self.entrance?.invalidate()
                self.entrance = nil
                if out {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.clip.masksToBounds = false
                    self.clip.frame = self.cat.frame
                    CATransaction.commit()
                    self.throughTheDoor = false
                } else {
                    // Facing out again for when it comes back.
                    self.tail(onLeft: false)
                }
                done?()
            }
        }
    }

    /// Beside a notch, the pointer over the cat takes clicks, to send it
    /// into the notch; anywhere else they go through to the menu bar.
    private func takeClicks(at location: NSPoint) {
        guard island.isNotch, animates else { return }
        let over = !throughTheDoor && island.body.insetBy(dx: -4, dy: -4).contains(location)
        if ignoresMouseEvents == over { ignoresMouseEvents = !over }
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            hideInTheNotch()
            return
        }
        super.sendEvent(event)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// The cat sits in the menu bar, where ordinary windows are not allowed.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// Perks the cat up while the pointer is near the island, and keeps its
    /// ears, whiskers and tail on the island while the pointer makes it grow.
    func pointer(at location: NSPoint) {
        pointer = location
        takeClicks(at: location)
        let near = island.nearby.contains(location)
        if near != excited {
            excited = near
            move()
        }
        pet(at: location)
        let wantsGrown = grown ? island.keepsHover(at: location) : island.startsHover(at: location)
        guard wantsGrown != grown else {
            // The pointer came back before the island changed.
            pending?.cancel()
            pending = nil
            // The grown island leans toward the pointer.
            if grown { follow(Island.Hover.grow) }
            return
        }
        guard pending == nil else { return }
        let spring = wantsGrown ? Island.Hover.grow : Island.Hover.shrink
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(spring.delay))
            guard !Task.isCancelled, let self else { return }
            pending = nil
            grown = wantsGrown
            follow(spring)
        }
    }

    /// The initial hover delay; later replies leave five quiet seconds
    /// after the previous bubble has finished fading out.
    static let petAfter = 3.0
    /// How long the pointer can slip off the cat without starting the wait
    /// over, so petting it while moving around counts.
    static let slipAllowed = 0.6

    /// Where the pointer pets the cat: its body or the grown island, a few
    /// points either side, and up to the top of the screen, where a pointer
    /// pushed against the edge stops.
    private func onCat(_ location: NSPoint) -> Bool {
        let cat = (grown ? island.hovered(toward: location) : island.body).union(island.body)
        let area = CGRect(
            x: cat.minX - 6, y: cat.minY - 2,
            width: cat.width + 12, height: island.band.maxY - cat.minY + 2)
        return area.contains(location)
    }

    private func pet(at location: NSPoint) {
        guard petting == nil, !throughTheDoor, onCat(location) else { return }
        petting = Task { [weak self] in
            var since = ContinuousClock.now
            var delay = Self.petAfter
            var lastOn = since
            // Checks where the pointer is ten times a second while it is
            // near, so resting it still or slipping off for a moment counts.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                let now = ContinuousClock.now
                if self.onCat(NSEvent.mouseLocation) {
                    lastOn = now
                } else if now - lastOn > .seconds(Self.slipAllowed) {
                    break
                }
                if now - since >= .seconds(delay) {
                    since = now
                    delay = Bubble.shown + 0.25 + 5  // Visible time + exit animation + quiet gap.
                    let reply = Petting.reply(after: self.lastReply, random: Double.random(in: 0..<1))
                    self.lastReply = reply
                    self.bubble.say(reply, on: self.island)
                }
            }
            self?.petting = nil
        }
    }
    /// Poses the legs `phase` of the way through a step, `reach` of the
    /// way out of the body, and the whiskers with them; or, while gliding
    /// (facing right or not), straight down on what it glides on.
    func walk(phase: Double, reach: Double, gliding: (on: Walk.Glide, facingRight: Bool)?) {
        let placement = Cat.Placement(body: island.body, origin: island.canvas.origin)
        let ground = Walk.ground(on: island)
        let path = CGMutablePath()
        let skatePath = CGMutablePath()
        if reach > 0, let gliding, gliding.on == .skateboard {
            let board = Walk.skateboard(reach: reach, floor: Walk.floor(on: island))
            for leg in board.legs {
                path.move(to: placement.point(leg.hip))
                path.addLine(to: placement.point(leg.foot))
            }
            skatePath.addLines(between: board.deck.map(placement.point))
            skatePath.closeSubpath()
            let radius = board.wheelRadius * placement.scale
            for wheel in board.wheels {
                let center = placement.point(wheel)
                skatePath.addEllipse(
                    in: CGRect(
                        x: center.x - radius, y: center.y - radius, width: 2 * radius,
                        height: 2 * radius))
            }
        } else if reach > 0, let gliding, gliding.on == .skates {
            for skate in Walk.skates(
                reach: reach, floor: Walk.floor(on: island), facingRight: gliding.facingRight)
            {
                path.move(to: placement.point(skate.hip))
                path.addLine(to: placement.point(skate.foot))
                skatePath.addLines(between: skate.boot.map(placement.point))
                skatePath.closeSubpath()
                let corners = [
                    placement.point(skate.plate.origin),
                    placement.point(CGPoint(x: skate.plate.maxX, y: skate.plate.maxY)),
                ]
                let plate = CGRect(
                    x: min(corners[0].x, corners[1].x), y: min(corners[0].y, corners[1].y),
                    width: abs(corners[1].x - corners[0].x), height: abs(corners[1].y - corners[0].y))
                skatePath.addRoundedRect(
                    in: plate, cornerWidth: plate.height / 2, cornerHeight: plate.height / 2)
                let radius = skate.wheelRadius * placement.scale
                for wheel in skate.wheels {
                    let center = placement.point(wheel)
                    skatePath.addEllipse(
                        in: CGRect(
                            x: center.x - radius, y: center.y - radius, width: 2 * radius,
                            height: 2 * radius))
                }
            }
        } else if reach > 0 {
            for leg in Walk.legs(phase: phase, reach: reach, ground: ground) {
                path.move(to: placement.point(leg.hip))
                path.addLine(to: placement.point(leg.foot))
            }
        }
        // The whiskers bob with the steps, each side turning about the
        // root of its middle whisker so the outer ends rise and fall together.
        let tilt = Walk.whiskerTilt(phase: phase, reach: reach) * .pi / 180
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        legs.path = path
        skates.path = skatePath
        for piece in pieces {
            switch piece.part.name {
            case "left whiskers":
                piece.tilt.transform = CATransform3DMakeRotation(-tilt, 0, 0, 1)
            case "right whiskers":
                piece.tilt.transform = CATransform3DMakeRotation(tilt, 0, 0, 1)
            default:
                break
            }
        }
        CATransaction.commit()
    }

    /// Swings the tail behind the body to the left side of the cat, or back
    /// to the right.
    func tail(onLeft: Bool) {
        swing(tailSide, onLeft: onLeft)
    }

    /// Mirrors `layer` across the cat to its left side, or back, swinging
    /// it round behind the body.
    private func swing(_ layer: CALayer, onLeft: Bool) {
        let to = NSValue(caTransform3D: CATransform3DMakeScale(onLeft ? -1 : 1, 1, 1))
        let from = (layer.presentation() ?? layer).value(forKeyPath: "transform")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = to.caTransform3DValue
        CATransaction.commit()
        guard animates else { return }
        let swing = CABasicAnimation(keyPath: "transform")
        swing.fromValue = from
        swing.toValue = to
        swing.duration = 0.35
        swing.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(swing, forKey: "swing")
    }

    /// Trails the rainbow out behind the cat, on its right or left,
    /// `amount` of the way out, its blocks stepped as `flip` says. It swings
    /// round from one side to the other like the tail.
    func trail(amount: Double, onRight: Bool, flip: Bool) {
        if onRight != rainbowOnRight {
            rainbowOnRight = onRight
            swing(rainbow, onLeft: !onRight)
        }
        let origin = island.canvas.origin
        let body = island.body.offsetBy(dx: -origin.x, dy: -origin.y)
        // From the middle of the body, behind it, out past the whiskers.
        let length = (body.width / 2 + 90) * CGFloat(min(1, max(0, amount)))
        let height = (body.height * 0.85).rounded()
        let band = height / CGFloat(Walk.Rainbow.bands)
        let bottom = body.midY - height / 2
        let blocks = Walk.Rainbow.blocks(length: length, width: 6, step: 1, flip: flip)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Solid by the cat, fading out over the last 30 points.
        let width = rainbow.bounds.width
        let end = body.midX + length
        rainbowFade.startPoint = CGPoint(x: body.midX / width, y: 0.5)
        rainbowFade.endPoint = CGPoint(x: end / width, y: 0.5)
        let fade = length > 0 ? min(1, 30 / length) : 1
        rainbowFade.locations = [0, NSNumber(value: Double(1 - fade)), 1]
        for (index, layer) in bands.enumerated() {
            let path = CGMutablePath()
            // Red on top.
            let y = bottom + CGFloat(Walk.Rainbow.bands - 1 - index) * band
            for block in blocks {
                let from = body.midX + block.from
                path.addRect(
                    CGRect(x: from, y: y + block.rise, width: block.to - block.from, height: band))
            }
            layer.path = path
        }
        CATransaction.commit()
    }

    private func move() {
        for piece in pieces {
            piece.shape.removeAnimation(forKey: "motion")
            guard animates, let motion = excited ? piece.part.excited : piece.part.idle else {
                continue
            }
            piece.shape.add(Self.animation(motion), forKey: "motion")
        }
    }

    /// Moves the ears, whiskers and tail to the island as it now is, on the
    /// system island's own spring. The body stays as it is: the system
    /// draws the grown island over it.
    private func follow(_ spring: Island.Hover.Spring) {
        let body = grown ? island.hovered(toward: pointer) : island.body
        let placement = Cat.Placement(body: body, origin: island.canvas.origin)
        for piece in pieces where !piece.part.segments.isEmpty {
            let to = Self.pivot(piece.part, placement)
            let grow = to.scale / piece.restScale
            Self.spring(piece.holder, "position", to: NSValue(point: to.pivot), spring, animates)
            Self.spring(
                piece.holder, "transform", to: NSValue(caTransform3D: CATransform3DMakeScale(grow, grow, 1)),
                spring, animates)
        }
    }

    private static func spring(
        _ layer: CALayer, _ key: String, to value: NSValue, _ spring: Island.Hover.Spring,
        _ animates: Bool
    ) {
        let from = (layer.presentation() ?? layer).value(forKeyPath: key)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.setValue(value, forKeyPath: key)
        CATransaction.commit()
        guard animates else { return }
        let animation = CASpringAnimation(keyPath: key)
        animation.mass = 1
        animation.stiffness = spring.stiffness
        animation.damping = spring.damping
        animation.fromValue = from
        animation.toValue = value
        animation.duration = animation.settlingDuration
        layer.add(animation, forKey: key)
    }

    /// Where `part` turns around, and the scale it is drawn at, in `placement`.
    private static func pivot(_ part: Cat.Part, _ placement: Cat.Placement) -> (
        pivot: CGPoint, scale: CGFloat
    ) {
        (placement.point(part.pivot), placement.scale)
    }

    private static func piece(_ part: Cat.Part, placement: Cat.Placement, scale: CGFloat) -> Piece {
        let path = placement.path(part)
        let bounds = path.boundingBoxOfPath
        let pivot = placement.point(part.pivot)
        let anchor = CGPoint(
            x: (pivot.x - bounds.minX) / bounds.width, y: (pivot.y - bounds.minY) / bounds.height)
        let holder = CALayer()
        holder.anchorPoint = anchor
        holder.frame = bounds

        let tilt = CALayer()
        tilt.anchorPoint = anchor
        tilt.frame = holder.bounds
        holder.addSublayer(tilt)

        let shape = CAShapeLayer()
        shape.contentsScale = scale
        shape.anchorPoint = anchor
        shape.frame = holder.bounds
        var toLayer = CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY)
        shape.path = path.copy(using: &toLayer)
        let black = NSColor.black.cgColor
        shape.fillColor = part.filled ? black : nil
        if part.lineWidth > 0 {
            shape.strokeColor = black
            shape.lineWidth = part.lineWidth
            shape.lineCap = .round
            shape.lineJoin = .round
        }
        tilt.addSublayer(shape)
        return Piece(
            part: part, holder: holder, tilt: tilt, shape: shape, restScale: placement.scale)
    }

    private static func animation(_ motion: Cat.Motion) -> CAKeyframeAnimation {
        let animation: CAKeyframeAnimation
        switch motion.property {
        case .rotation:
            animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            animation.values = motion.values.map { $0 * .pi / 180 }
        case .rise:
            animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
            animation.values = motion.values
        }
        animation.keyTimes = motion.keyTimes.map { NSNumber(value: $0) }
        animation.timingFunctions = Array(
            repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: motion.values.count - 1)
        animation.duration = motion.duration
        animation.autoreverses = motion.autoreverses
        animation.repeatCount = .infinity
        animation.beginTime = CACurrentMediaTime() + motion.delay
        return animation
    }
}
