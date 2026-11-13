import AppKit
import IslandCatCore
import QuartzCore

/// A speech bubble the cat says something in: black like the cat, in the
/// menu bar to its left, its bottom right corner pointing at the cat.
@MainActor
final class Bubble: NSPanel {
    private let animates: Bool
    private var hiding: Task<Void, Never>?

    static let font = NSFont.systemFont(ofSize: 12, weight: .regular)
    static let ink = NSColor(white: 0.78, alpha: 1)
    static let padding = NSSize(width: 9, height: 4)
    /// How far the tail's tip reaches right of and below the box.
    static let tail = NSSize(width: 3, height: 4.5)
    static let shown = 2.4

    init(animates: Bool) {
        self.animates = animates
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
            defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// Says `text` under the cat on `island` for a couple of seconds.
    func say(_ text: String, on island: Island) {
        let label = NSAttributedString(
            string: text,
            attributes: [.font: Self.font, .foregroundColor: Self.ink])
        let textSize = label.size()
        let box = NSSize(
            width: ceil(textSize.width) + 2 * Self.padding.width,
            height: ceil(textSize.height) + 2 * Self.padding.height)
        let size = NSSize(width: box.width + Self.tail.width, height: box.height + Self.tail.height)
        // The tail's tip sits just short of the cat's lowest whisker, and
        // the bubble opens out up and to the left of it, its box level with
        // the whiskers.
        let whiskers = Cat.Placement(body: island.body, origin: .zero).point(CGPoint(x: -17, y: 30))
        let tip = CGPoint(x: whiskers.x - 3, y: whiskers.y)
        setFrame(
            NSRect(x: tip.x - size.width, y: tip.y, width: size.width, height: size.height),
            display: false)

        let view = BubbleView(frame: NSRect(origin: .zero, size: size), label: label)
        contentView = view
        orderFrontRegardless()
        FixedSpace.claim([self])

        hiding?.cancel()
        let layer = view.layer!
        // Pop out of the tail's tip.
        layer.anchorPoint = CGPoint(x: 1, y: 0)  // the tail's tip
        layer.frame = view.bounds
        layer.opacity = 1
        if animates {
            let pop = CASpringAnimation(keyPath: "transform.scale")
            pop.fromValue = 0.4
            pop.toValue = 1
            pop.stiffness = 400
            pop.damping = 18
            pop.duration = pop.settlingDuration
            layer.add(pop, forKey: "pop")
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.12
        layer.add(fade, forKey: "fade")

        hiding = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.shown))
            guard !Task.isCancelled, let self else { return }
            self.fadeOut()
        }
    }

    private func fadeOut() {
        guard let layer = contentView?.layer else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.contentView?.layer?.opacity == 0 else { return }
                self.orderOut(nil)
            }
        }
        layer.opacity = 0
        CATransaction.commit()
    }
}

/// Draws the bubble: a black rounded box with a Messages-style tail off its
/// bottom right corner, at the cat, and the text in it.
private final class BubbleView: NSView {
    private let label: NSAttributedString

    init(frame: NSRect, label: NSAttributedString) {
        self.label = label
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        let box = NSSize(
            width: bounds.width - Bubble.tail.width, height: bounds.height - Bubble.tail.height)
        Self.outline(box: box).fill()
        let size = label.size()
        label.draw(at: NSPoint(x: (box.width - size.width) / 2, y: (box.height - size.height) / 2))
    }

    /// The bubble's outline, y down, as one smooth path, like a Messages
    /// bubble's: a box with round ends whose right side runs on down past
    /// its bottom into a tail, curving out to a rounded tip below and to
    /// the right of the box and sweeping back in along its bottom edge.
    static func outline(box: NSSize) -> NSBezierPath {
        let right = box.width
        let bottom = box.height
        let r = bottom / 2
        let tip = NSPoint(x: right + Bubble.tail.width, y: bottom + Bubble.tail.height)
        // How round the tip is.
        let d: CGFloat = 1
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }
        let path = NSBezierPath()
        path.move(to: p(right - 9, bottom))
        path.line(to: p(r, bottom))
        path.curve(
            to: p(0, bottom - r), controlPoint1: p(0.45 * r, bottom),
            controlPoint2: p(0, bottom - 0.45 * r))
        path.line(to: p(0, r))
        path.curve(to: p(r, 0), controlPoint1: p(0, 0.45 * r), controlPoint2: p(0.45 * r, 0))
        path.line(to: p(right - r, 0))
        path.curve(
            to: p(right, r), controlPoint1: p(right - 0.45 * r, 0), controlPoint2: p(right, 0.45 * r))
        path.line(to: p(right, bottom - 3))
        path.curve(
            to: p(tip.x - d * 0.4, tip.y - d),
            controlPoint1: p(right, bottom + Bubble.tail.height * 0.35),
            controlPoint2: p(tip.x - d * 1.4, tip.y - d * 1.6))
        path.curve(
            to: p(tip.x - d * 1.8, tip.y), controlPoint1: p(tip.x + d * 0.3, tip.y - d * 0.3),
            controlPoint2: p(tip.x - d * 0.6, tip.y + d * 0.25))
        path.curve(
            to: p(right - 9, bottom), controlPoint1: p(tip.x - 5, tip.y - 0.4),
            controlPoint2: p(right - 5, bottom))
        path.close()
        return path
    }
}
