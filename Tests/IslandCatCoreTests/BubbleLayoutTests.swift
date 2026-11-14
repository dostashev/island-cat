import CoreGraphics
import Foundation
import Testing

@testable import IslandCatCore

@Test(arguments: [CGSize(width: 40, height: 27.5), CGSize(width: 110, height: 27.5)])
func bubbleGrowsUpAndLeftFromItsBottomRight(size: CGSize) {
    let tip = CGPoint(x: -420, y: 1024)
    let layout = BubbleLayout(size: size, tip: tip)
    for scale: CGFloat in [0.4, 0.5, 1, 1.12, BubbleLayout.maximumScale] {
        let rect = layout.bounds(at: scale)
        #expect(abs(rect.maxX - tip.x) < 1e-9)
        #expect(rect.minY == tip.y)
        #expect(layout.window.contains(rect))
    }
    #expect(layout.window.minX + layout.localTip.x == tip.x)
    #expect(layout.window.minY + layout.localTip.y == tip.y)
    #expect(layout.bounds(at: 1).size == size)
}

/// The 400-stiffness, 18-damping pop starts at 0.4 and overshoots 1.
/// Include its full trajectory (not just the resting size) in the window.
@Test func bubbleWindowContainsTheSpringOvershoot() {
    let layout = BubbleLayout(size: CGSize(width: 110, height: 27.5), tip: .zero)
    let damping = 9.0  // damping / (2 * mass), mass = 1
    let frequency = sqrt(400.0 - damping * damping)
    var peak = 0.0
    for milliseconds in 0...2000 {
        let t = Double(milliseconds) / 1000
        let scale = 1 - 0.6 * exp(-damping * t)
            * (cos(frequency * t) + damping / frequency * sin(frequency * t))
        peak = max(peak, scale)
        #expect(layout.window.contains(layout.bounds(at: scale)))
    }
    #expect(peak > 1.1)
    #expect(peak < BubbleLayout.maximumScale)
}
