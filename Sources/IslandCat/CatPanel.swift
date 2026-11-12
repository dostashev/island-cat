import AppKit
import IslandCatCore
import QuartzCore

/// A click-through window over the camera's island that the cat lives in.
@MainActor
final class CatPanel: NSPanel {
    let island: Island
    private let parts: [(Cat.Part, CAShapeLayer)]
    private let animates: Bool
    private var excited = false

    init(island: Island, scale: CGFloat, animates: Bool) {
        self.island = island
        self.animates = animates
        let canvas = island.canvas
        let placement = Cat.Placement(body: island.body, origin: canvas.origin)
        parts = Cat.parts.map { ($0, Self.layer(for: $0, placement: placement, scale: scale)) }

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
        for (_, layer) in parts { view.layer?.addSublayer(layer) }
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

    /// Perks the cat up while the pointer is near the island.
    func pointer(at location: NSPoint) {
        let near = island.canvas.contains(location)
        guard near != excited else { return }
        excited = near
        move()
    }

    private func move() {
        for (part, layer) in parts {
            layer.removeAnimation(forKey: "motion")
            guard animates, let motion = excited ? part.excited : part.idle else { continue }
            layer.add(Self.animation(motion), forKey: "motion")
        }
    }

    private static func layer(
        for part: Cat.Part, placement: Cat.Placement, scale: CGFloat
    ) -> CAShapeLayer {
        let path = placement.path(part)
        let bounds = path.boundingBoxOfPath
        let layer = CAShapeLayer()
        layer.contentsScale = scale
        layer.anchorPoint = part.pivot
        layer.frame = bounds
        var toLayer = CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY)
        layer.path = path.copy(using: &toLayer)
        let black = NSColor.black.cgColor
        layer.fillColor = part.filled ? black : nil
        if part.lineWidth > 0 {
            layer.strokeColor = black
            layer.lineWidth = part.lineWidth
            layer.lineCap = .round
            layer.lineJoin = .round
        }
        return layer
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
