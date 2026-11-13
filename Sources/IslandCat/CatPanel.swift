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
    /// Stroking the pointer back and forth over the cat pets it, and it
    /// says something.
    private var petting = Petting()
    private lazy var bubble = Bubble(animates: animates)
    private var lastReply: (text: String, at: Double)?
    /// Legs, out only while the cat walks.
    private let legs = CAShapeLayer()
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
        view.layer?.addSublayer(legs)
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
        let near = island.canvas.contains(location)
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

    private func pet(at location: NSPoint) {
        let cat = grown ? island.hovered(toward: location) : island.body
        guard cat.contains(location) else {
            petting.reset()
            return
        }
        let now = CACurrentMediaTime()
        guard petting.stroke(x: location.x, at: now) else { return }
        // One thing at a time.
        if let lastReply, now - lastReply.at < Bubble.shown + 0.4 { return }
        let reply = Petting.reply(after: lastReply?.text, random: Double.random(in: 0..<1))
        lastReply = (reply, now)
        bubble.say(reply, on: island)
    }

    /// Poses the legs `phase` of the way through a step, `reach` of the
    /// way out of the body, and the whiskers with them.
    func walk(phase: Double, reach: Double) {
        let placement = Cat.Placement(body: island.body, origin: island.canvas.origin)
        let path = CGMutablePath()
        if reach > 0 {
            for leg in Walk.legs(phase: phase, reach: reach, ground: Walk.ground(on: island)) {
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
        let to = NSValue(caTransform3D: CATransform3DMakeScale(onLeft ? -1 : 1, 1, 1))
        let from = (tailSide.presentation() ?? tailSide).value(forKeyPath: "transform")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tailSide.transform = to.caTransform3DValue
        CATransaction.commit()
        guard animates else { return }
        let swing = CABasicAnimation(keyPath: "transform")
        swing.fromValue = from
        swing.toValue = to
        swing.duration = 0.35
        swing.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        tailSide.add(swing, forKey: "swing")
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
