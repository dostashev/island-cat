import AppKit
import IslandCatCore
import QuartzCore

/// A speech bubble the cat says something in, just under the menu bar,
/// its tail pointing up at the cat.
@MainActor
final class Bubble: NSPanel {
    private let animates: Bool
    private var hiding: Task<Void, Never>?

    static let font = NSFont.systemFont(ofSize: 13, weight: .medium)
    static let padding = NSSize(width: 10, height: 5)
    static let tail = NSSize(width: 10, height: 7)
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
            string: text, attributes: [.font: Self.font, .foregroundColor: NSColor.black])
        let textSize = label.size()
        let box = NSSize(
            width: ceil(textSize.width) + 2 * Self.padding.width,
            height: ceil(textSize.height) + 2 * Self.padding.height)
        // Room around the bubble for its shadow.
        let margin: CGFloat = 6
        let size = NSSize(
            width: box.width + 2 * margin, height: box.height + Self.tail.height + 2 * margin)
        // The tail's tip sits just under the cat's chin, a quarter of the way
        // in from its left, and the bubble opens out to the right.
        let tip = CGPoint(x: island.body.minX + island.body.width / 4, y: island.band.minY - 1)
        let tailX = margin + 18
        setFrame(
            NSRect(
                x: tip.x - (tailX - 4), y: tip.y - size.height + margin, width: size.width,
                height: size.height),
            display: false)

        let view = BubbleView(
            frame: NSRect(origin: .zero, size: size), label: label, margin: margin, tailX: tailX)
        contentView = view
        orderFrontRegardless()
        FixedSpace.claim([self])

        hiding?.cancel()
        let layer = view.layer!
        // Pop out of the tail's tip.
        layer.anchorPoint = CGPoint(x: (tailX - 4) / size.width, y: 1 - margin / size.height)
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

/// Draws the bubble: a white rounded box with a tail pointing up-left, and
/// the text in it.
private final class BubbleView: NSView {
    private let label: NSAttributedString
    private let margin: CGFloat
    private let tailX: CGFloat

    init(frame: NSRect, label: NSAttributedString, margin: CGFloat, tailX: CGFloat) {
        self.label = label
        self.margin = margin
        self.tailX = tailX
        super.init(frame: frame)
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.25
        layer?.shadowRadius = 3
        layer?.shadowOffset = CGSize(width: 0, height: -1)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSRect(
            x: margin, y: margin,
            width: bounds.width - 2 * margin,
            height: bounds.height - 2 * margin - Bubble.tail.height)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: box, xRadius: box.height / 2, yRadius: box.height / 2).fill()
        // The tail, from inside the top edge up to the tip, filled on its
        // own so it does not cancel out where it overlaps the box.
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: tailX - 1, y: box.maxY - 3))
        tail.line(to: NSPoint(x: tailX - 4, y: box.maxY + Bubble.tail.height))
        tail.line(to: NSPoint(x: tailX + Bubble.tail.width - 1, y: box.maxY - 3))
        tail.close()
        tail.fill()
        let size = label.size()
        label.draw(
            at: NSPoint(x: box.midX - size.width / 2, y: box.midY - size.height / 2))
    }
}
