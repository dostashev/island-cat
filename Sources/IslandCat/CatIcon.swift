import AppKit

/// The menu bar icon: a small sketch of the island cat, its wide body,
/// ears, whiskers and the tail curling up beside it, as a template image so
/// the menu bar tints it. Drawn on its own rather than scaled down from the
/// cat, whose whiskers and long tail would make it too wide.
enum CatIcon {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 16), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            // Points, y down; the drawing spans y 3.8 to 13.6; center it.
            context.translateBy(x: 0, y: -0.8)
            context.setFillColor(.black)
            context.setStrokeColor(.black)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            let body = CGRect(x: 2, y: 6.5, width: 11.6, height: 6.3)
            context.addPath(
                CGPath(
                    roundedRect: body, cornerWidth: body.height / 2, cornerHeight: body.height / 2,
                    transform: nil))
            context.fillPath()

            for ear in [
                [(2.7, 9.3), (2.9, 3.8), (6.1, 6.0), (6.5, 7.8)],
                [(12.9, 9.3), (12.7, 3.8), (9.5, 6.0), (9.1, 7.8)],
            ] {
                context.addLines(between: ear.map { CGPoint(x: $0.0, y: $0.1) })
                context.closePath()
                context.fillPath()
            }

            context.setLineWidth(0.75)
            for (from, to) in [
                ((1.4, 8.6), (0.1, 8.0)), ((1.4, 10.4), (0.1, 11.0)),
                ((14.2, 8.6), (15.5, 8.0)), ((14.2, 10.4), (15.5, 11.0)),
            ] {
                context.move(to: CGPoint(x: from.0, y: from.1))
                context.addLine(to: CGPoint(x: to.0, y: to.1))
            }
            context.strokePath()

            context.setLineWidth(1.3)
            context.move(to: CGPoint(x: 11.8, y: 12.4))
            context.addCurve(
                to: CGPoint(x: 16.0, y: 12.6), control1: CGPoint(x: 13.5, y: 13.6),
                control2: CGPoint(x: 15.3, y: 13.6))
            context.addCurve(
                to: CGPoint(x: 17.6, y: 10.2), control1: CGPoint(x: 16.5, y: 11.6),
                control2: CGPoint(x: 16.9, y: 10.0))
            context.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Island Cat"
        return image
    }
}
