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
    private var grown = false

    /// One part of the cat: `shape` draws it and runs its motion, inside
    /// `holder`, which follows the island as it grows under the pointer.
    private struct Piece {
        var part: Cat.Part
        var holder: CALayer
        var shape: CAShapeLayer
        /// Where the part turns around, and how large it is drawn, for the
        /// island at rest and grown.
        var rest: (pivot: CGPoint, scale: CGFloat)
        var hovered: (pivot: CGPoint, scale: CGFloat)
    }

    init(island: Island, scale: CGFloat, animates: Bool) {
        self.island = island
        self.animates = animates
        let canvas = island.canvas
        let rest = Cat.Placement(body: island.body, origin: canvas.origin)
        let hovered = Cat.Placement(body: island.hovered, origin: canvas.origin)
        pieces = Cat.parts.map { Self.piece($0, rest: rest, hovered: hovered, scale: scale) }

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
        for piece in pieces { view.layer?.addSublayer(piece.holder) }
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
        let near = island.canvas.contains(location)
        if near != excited {
            excited = near
            move()
        }
        let over = (grown ? island.hovered : island.body).contains(location)
        if over != grown {
            grown = over
            follow()
        }
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

    /// Moves every part to where the island now is, springing a little the
    /// way the island does.
    private func follow() {
        CATransaction.begin()
        CATransaction.setDisableActions(!animates)
        CATransaction.setAnimationDuration(grown ? 0.35 : 0.3)
        CATransaction.setAnimationTimingFunction(
            CAMediaTimingFunction(controlPoints: 0.3, 1.35, 0.6, 1))
        for piece in pieces {
            let to = grown ? piece.hovered : piece.rest
            piece.holder.position = to.pivot
            let grow = to.scale / piece.rest.scale
            piece.holder.transform = CATransform3DMakeScale(grow, grow, 1)
        }
        CATransaction.commit()
    }

    private static func piece(
        _ part: Cat.Part, rest: Cat.Placement, hovered: Cat.Placement, scale: CGFloat
    ) -> Piece {
        let path = rest.path(part)
        let bounds = path.boundingBoxOfPath
        let holder = CALayer()
        holder.anchorPoint = part.pivot
        holder.frame = bounds

        let shape = CAShapeLayer()
        shape.contentsScale = scale
        shape.anchorPoint = part.pivot
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
        holder.addSublayer(shape)

        func pivot(_ placement: Cat.Placement) -> (pivot: CGPoint, scale: CGFloat) {
            let box = placement.path(part).boundingBoxOfPath
            let at = CGPoint(
                x: box.minX + part.pivot.x * box.width, y: box.minY + part.pivot.y * box.height)
            return (at, placement.scale)
        }
        // The body stays as it is: the system draws the grown island over it.
        let grown = part.segments.isEmpty ? pivot(rest) : pivot(hovered)
        return Piece(part: part, holder: holder, shape: shape, rest: pivot(rest), hovered: grown)
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
