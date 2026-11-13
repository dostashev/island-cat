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
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        // Above the menu bar, below the menus that drop down from it.
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let view = NSView(frame: NSRect(origin: .zero, size: canvas.size))
        view.wantsLayer = true
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
        view.layer?.addSublayer(rainbow)
        view.layer?.addSublayer(legs)
        skates.contentsScale = scale
        skates.fillColor = NSColor.black.cgColor
        view.layer?.addSublayer(skates)
        tailSide.anchorPoint = CGPoint(
            x: (island.body.midX - canvas.minX) / canvas.width, y: 0.5)
        tailSide.frame = CGRect(origin: .zero, size: canvas.size)
        view.layer?.addSublayer(tailSide)
        for piece in pieces {
            (piece.part.name == "tail" ? tailSide : view.layer)?.addSublayer(piece.holder)
        }
        contentView = view
        setFrame(canvas, display: false)
        move()
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

    /// The cat says something once the pointer has rested on it this long,
    /// and again each time as long again while it stays.
    static let petAfter = 5.0

    private func onCat(_ location: NSPoint) -> Bool {
        (grown ? island.hovered(toward: location) : island.body).contains(location)
    }

    private func pet(at location: NSPoint) {
        guard onCat(location) else {
            petting?.cancel()
            petting = nil
            return
        }
        guard petting == nil else { return }
        petting = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(Self.petAfter))
                guard !Task.isCancelled, let self else { return }
                // The pointer may have rested still since; ask where it is.
                guard self.onCat(NSEvent.mouseLocation) else { break }
                let reply = Petting.reply(after: self.lastReply, random: Double.random(in: 0..<1))
                self.lastReply = reply
                self.bubble.say(reply, on: self.island)
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
