import AppKit
import IslandCatCore
import QuartzCore

/// A speech bubble the cat says something in: black like the cat, in the
/// menu bar to its left, its tail pointing at the cat.
@MainActor
final class Bubble: NSPanel {
    private let animates: Bool
    private var hiding: Task<Void, Never>?

    static let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    static let padding = NSSize(width: 9, height: 4)
    /// The tail's length out of the box, and its width where it leaves it.
    static let tail = NSSize(width: 6, height: 8)
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
            attributes: [.font: Self.font, .foregroundColor: NSColor(white: 0.92, alpha: 1)])
        let textSize = label.size()
        let box = NSSize(
            width: ceil(textSize.width) + 2 * Self.padding.width,
            height: ceil(textSize.height) + 2 * Self.padding.height)
        let size = NSSize(width: box.width + Self.tail.width, height: box.height)
        // The tail's tip sits just short of the cat's whiskers, level with
        // the middle of its face, and the bubble opens out to the left.
        let whiskers = Cat.Placement(body: island.body, origin: .zero).point(CGPoint(x: -17, y: 18))
        let tip = CGPoint(x: whiskers.x - 3, y: island.body.midY)
        setFrame(
            NSRect(
                x: tip.x - size.width, y: tip.y - size.height / 2, width: size.width,
                height: size.height),
            display: false)

        let view = BubbleView(frame: NSRect(origin: .zero, size: size), label: label)
        contentView = view
        orderFrontRegardless()
        FixedSpace.claim([self])

        hiding?.cancel()
        let layer = view.layer!
        // Pop out of the tail's tip.
        layer.anchorPoint = CGPoint(x: 1, y: 0.5)
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

/// Draws the bubble: a black rounded box with a tail pointing right, at
/// the cat, and the text in it.
private final class BubbleView: NSView {
    private let label: NSAttributedString

    init(frame: NSRect, label: NSAttributedString) {
        self.label = label
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSRect(
            x: 0, y: 0, width: bounds.width - Bubble.tail.width, height: bounds.height)
        NSColor.black.setFill()
        NSBezierPath(roundedRect: box, xRadius: box.height / 2, yRadius: box.height / 2).fill()
        // The tail, from inside the right end out to the tip, filled on its
        // own so it does not cancel out where it overlaps the box.
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: box.maxX - 6, y: box.midY + Bubble.tail.height / 2))
        tail.line(to: NSPoint(x: bounds.maxX, y: box.midY))
        tail.line(to: NSPoint(x: box.maxX - 6, y: box.midY - Bubble.tail.height / 2))
        tail.close()
        tail.fill()
        let size = label.size()
        label.draw(at: NSPoint(x: box.midX - size.width / 2, y: box.midY - size.height / 2))
    }
}
