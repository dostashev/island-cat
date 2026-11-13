import AppKit

/// The menu bar icon: a sketch of the island cat's wide body, ears and
/// whiskers, about as big as the menu bar's other icons, as a template
/// image so the menu bar tints it. Drawn on its own rather than scaled
/// down from the cat, whose long whiskers and tail would make it too wide.
enum CatIcon {
    static func image() -> NSImage {
        // Sized to fill the menu bar's icon height, the body centered.
        let height: CGFloat = 18
        let body = CGSize(width: 14.8, height: 11.4)
        let scale = body.width / 67
        let earRise = 8 * scale
        let tailDrop: CGFloat = 1.6
        let side: CGFloat = 3.6
        let size = NSSize(width: body.width + 2 * side, height: height)
        let image = NSImage(size: size, flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            // Points, y down.
            context.setFillColor(.black)
            context.setStrokeColor(.black)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            let top = (height - (earRise + body.height + tailDrop)) / 2 + earRise
            let body = CGRect(origin: CGPoint(x: side, y: top), size: body)
            context.addPath(
                CGPath(
                    roundedRect: body, cornerWidth: body.height / 2, cornerHeight: body.height / 2,
                    transform: nil))
            context.fillPath()

            // The cat's own ears, scaled to the body, standing a little
            // taller so they read at this size.
            for mirrored in [false, true] {
                let ear = [(4.0, 13.0), (5, -4), (22, 1), (24, 8)].map { u, v in
                    CGPoint(
                        x: mirrored ? body.maxX - u * scale : body.minX + u * scale,
                        y: body.minY + v * scale * (v < 0 ? 2 : 1))
                }
                context.addLines(between: ear)
                context.closePath()
                context.fillPath()
            }

            // Three whiskers a side, fanning out like the cat's.
            context.setLineWidth(0.85)
            for (rise, spread) in [(-2.0, -2.9), (0.0, 0.0), (2.0, 2.9)] {
                context.move(to: CGPoint(x: body.minX - 0.8, y: body.midY + rise))
                context.addLine(to: CGPoint(x: body.minX - side + 0.5, y: body.midY + spread))
                context.move(to: CGPoint(x: body.maxX + 0.8, y: body.midY + rise))
                context.addLine(to: CGPoint(x: body.maxX + side - 0.5, y: body.midY + spread))
            }
            context.strokePath()

            // A short tail, hooking up under the whiskers.
            context.setLineWidth(1.5)
            let right = body.maxX
            context.move(to: CGPoint(x: right - 3.5, y: body.maxY - 0.6))
            context.addCurve(
                to: CGPoint(x: right + 2.2, y: body.maxY + 0.2),
                control1: CGPoint(x: right - 1, y: body.maxY + 1.1),
                control2: CGPoint(x: right + 1.3, y: body.maxY + 1.1))
            context.addCurve(
                to: CGPoint(x: right + 2.8, y: body.maxY - 1.6),
                control1: CGPoint(x: right + 2.8, y: body.maxY - 0.4),
                control2: CGPoint(x: right + 2.9, y: body.maxY - 1.0))
            context.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Island Cat"
        return image
    }
}
