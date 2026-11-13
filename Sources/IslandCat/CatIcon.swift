import AppKit
import IslandCatCore

/// The menu bar icon: the cat itself, body, ears, whiskers and tail, drawn
/// from the same art as the cat on the island, as a template image so the
/// menu bar tints it.
enum CatIcon {
    static func image(height: CGFloat = 14) -> NSImage {
        // Lay the art out at 1 point per art unit, then scale it to fit.
        let unit = Cat.Placement(
            body: CGRect(origin: .zero, size: Cat.box), origin: .zero)
        // Lines thicker than to scale, so they still read at this size.
        let thicken: CGFloat = 2.2
        let bounds = Cat.parts.reduce(CGRect.null) { box, part in
            let pad = part.lineWidth * thicken / 2
            return box.union(unit.path(part).boundingBoxOfPath.insetBy(dx: -pad, dy: -pad))
        }
        let scale = height / bounds.height
        let size = NSSize(width: ceil(bounds.width * scale), height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -bounds.minX, y: -bounds.minY)
            context.setFillColor(.black)
            context.setStrokeColor(.black)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            for part in Cat.parts {
                context.addPath(unit.path(part))
                if part.filled {
                    context.fillPath()
                } else {
                    context.setLineWidth(max(1 / scale, part.lineWidth * thicken))
                    context.strokePath()
                }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Island Cat"
        return image
    }
}
