import AppKit

/// The menu bar icon: a sketch of the island cat's wide body, ears and
/// whiskers, about as big as the menu bar's other icons, as a template
/// image so the menu bar tints it. Drawn on its own rather than scaled
/// down from the cat, whose long whiskers and tail would make it too wide.
enum CatIcon {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 16), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            // Points, y down; the drawing spans y 2.6 to 14.4; center it.
            context.translateBy(x: 0, y: -0.5)
            context.setFillColor(.black)
            context.setStrokeColor(.black)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            let body = CGRect(x: 2.5, y: 6.8, width: 13, height: 7.6)
            context.addPath(
                CGPath(
                    roundedRect: body, cornerWidth: body.height / 2, cornerHeight: body.height / 2,
                    transform: nil))
            context.fillPath()

            for ear in [
                [(3.3, 10), (3.5, 2.6), (7.3, 5.2), (7.8, 7.6)],
                [(14.7, 10), (14.5, 2.6), (10.7, 5.2), (10.2, 7.6)],
            ] {
                context.addLines(between: ear.map { CGPoint(x: $0.0, y: $0.1) })
                context.closePath()
                context.fillPath()
            }

            // Three whiskers a side, fanning out like the cat's.
            context.setLineWidth(0.75)
            for (from, to) in [
                ((1.7, 9.0), (0.2, 8.2)), ((1.7, 10.6), (0.1, 10.6)), ((1.7, 12.2), (0.2, 13.0)),
                ((16.3, 9.0), (17.8, 8.2)), ((16.3, 10.6), (17.9, 10.6)), ((16.3, 12.2), (17.8, 13.0)),
            ] {
                context.move(to: CGPoint(x: from.0, y: from.1))
                context.addLine(to: CGPoint(x: to.0, y: to.1))
            }
            context.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Island Cat"
        return image
    }
}
