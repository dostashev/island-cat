import CoreGraphics
import Testing

@testable import IslandCatCore

/// Recorded swipes: lifting at -0.48 desktop widths at -2.27 widths a
/// second went on to the desktop on the right; the slide takes ~0.75 s.
@Test func liftedPastHalfwaySlidesOnToTheNextDesktop() {
    var slide = Moonwalk.Slide()
    slide.follow(-0.478)
    slide.lift(at: -0.478, velocity: -2.267, now: 10, canGoLeft: true, canGoRight: true)
    var last = slide.offset
    var t = 10.0
    while slide.advance(to: t) {
        #expect(slide.offset <= last)
        last = slide.offset
        t += 1.0 / 120
    }
    #expect(slide.offset == -1)
    #expect(abs(t - 10.75) < 0.02)
}

@Test func slideSpringsBackWithoutADesktopThatWay() {
    var slide = Moonwalk.Slide()
    slide.lift(at: -0.424, velocity: -2.038, now: 0, canGoLeft: true, canGoRight: false)
    _ = slide.advance(to: 1)
    #expect(slide.offset == 0)
}

@Test func slowShortSwipeSpringsBack() {
    var slide = Moonwalk.Slide()
    slide.lift(at: 0.2, velocity: 0.3, now: 0, canGoLeft: true, canGoRight: true)
    _ = slide.advance(to: 1)
    #expect(slide.offset == 0)
    #expect(!slide.isSettling)
}

/// A whole desktop is a whole number of steps, so the stride carries on
/// where it left off at the next swipe.
@Test func strideIsContinuousAcrossDesktops() {
    #expect(Moonwalk.phase(0) == 0)
    #expect(abs(Moonwalk.phase(-1)) < 1e-9 || abs(Moonwalk.phase(-1) - 1) < 1e-9)
    #expect(abs(Moonwalk.phase(-0.1) - 0.5) < 1e-9)
    #expect(abs(Moonwalk.phase(0.1) - 0.5) < 1e-9)
}

/// Feet on the ground slide the way the desktops slide: left as they move
/// left, which is the stride moving forward.
@Test func feetOnTheGroundSlideWithTheDesktop() {
    let early = Moonwalk.legs(phase: Moonwalk.phase(-0.01), reach: 1)
    let later = Moonwalk.legs(phase: Moonwalk.phase(-0.03), reach: 1)
    // Legs 0 and 2 start their step on the ground.
    for i in [0, 2] {
        #expect(early[i].foot.y == later[i].foot.y)
        #expect(later[i].foot.x < early[i].foot.x)
    }
}

@Test func tuckedLegsStayInTheBody() {
    for leg in Moonwalk.legs(phase: 0.3, reach: 0) {
        #expect(leg.foot == leg.hip)
    }
}

/// Standing, the feet stay inside the cat's window, under the menu bar.
@Test func feetStayInTheCanvas() throws {
    let island = try #require(Island.on(proled))
    let canvas = island.canvas
    let placement = Cat.Placement(body: island.body, origin: canvas.origin)
    for phase in stride(from: 0.0, to: 1, by: 0.05) {
        for leg in Moonwalk.legs(phase: phase, reach: 1) {
            let foot = placement.point(leg.foot)
            #expect(foot.y >= 1)
            #expect(foot.y + canvas.minY >= island.band.minY - 1)
        }
    }
}
