import CoreGraphics
import Testing

@testable import IslandCatCore

/// Recorded swipes: lifting at -0.48 desktop widths at -2.27 widths a
/// second went on to the desktop on the right; the slide takes ~0.75 s.
@Test func liftedPastHalfwaySlidesOnToTheNextDesktop() {
    var slide = Walk.Slide()
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
    var slide = Walk.Slide()
    slide.lift(at: -0.424, velocity: -2.038, now: 0, canGoLeft: true, canGoRight: false)
    _ = slide.advance(to: 1)
    #expect(slide.offset == 0)
}

@Test func slowShortSwipeSpringsBack() {
    var slide = Walk.Slide()
    slide.lift(at: 0.2, velocity: 0.3, now: 0, canGoLeft: true, canGoRight: true)
    _ = slide.advance(to: 1)
    #expect(slide.offset == 0)
    #expect(!slide.isSettling)
}

/// A whole desktop is a whole number of steps, so the stride carries on
/// where it left off at the next swipe.
@Test func strideIsContinuousAcrossDesktops() {
    #expect(Walk.phase(0) == 0)
    #expect(abs(Walk.phase(-1)) < 1e-9 || abs(Walk.phase(-1) - 1) < 1e-9)
    #expect(abs(Walk.phase(-0.1) - 0.5) < 1e-9)
    #expect(abs(Walk.phase(0.1) - 0.5) < 1e-9)
}

/// The cat walks the way the desktops slide: going right, the feet on the
/// ground push back to the left, and going left, to the right.
@Test(arguments: [(0.01, 0.03, true), (-0.01, -0.03, false)])
func feetOnTheGroundPushBackAgainstTheWalk(from: Double, to: Double, right: Bool) {
    let early = Walk.legs(phase: Walk.phase(from), reach: 1)
    let later = Walk.legs(phase: Walk.phase(to), reach: 1)
    // The first leg is on the ground at the start of a step going right,
    // and at the end of one going left.
    let leg = right ? 0 : 1
    #expect(early[leg].foot.y == later[leg].foot.y)
    #expect(right ? later[leg].foot.x < early[leg].foot.x : later[leg].foot.x > early[leg].foot.x)
}

@Test func tuckedLegsStayInTheBody() {
    for leg in Walk.legs(phase: 0.3, reach: 0) {
        #expect(leg.foot == leg.hip)
    }
}

/// Standing, the feet stay inside the cat's window, under the menu bar.
@Test func feetStayInTheCanvas() throws {
    let island = try #require(Island.on(proled))
    let canvas = island.canvas
    let placement = Cat.Placement(body: island.body, origin: canvas.origin)
    for phase in stride(from: 0.0, to: 1, by: 0.05) {
        for leg in Walk.legs(phase: phase, reach: 1) {
            let foot = placement.point(leg.foot)
            #expect(foot.y >= 1)
            #expect(foot.y + canvas.minY >= island.band.minY - 1)
        }
    }
}

/// After the slide settles on the next desktop, the next swipe carries on
/// from there instead of jumping back.
@Test func nextSwipeCarriesOnFromTheDesktopItReached() {
    var slide = Walk.Slide()
    slide.lift(at: -0.6, velocity: -1, now: 0, canGoLeft: true, canGoRight: true)
    _ = slide.advance(to: 1)
    slide.follow(0.05)
    #expect(abs(slide.offset - -0.95) < 1e-9)
}

/// Heading right while the desktops slide right, turning back left only
/// once they clearly slide left again.
@Test func headingTurnsWithTheSlideButNotOnAWobble() {
    var heading = Walk.Heading()
    let turns = [-0.1, -0.09, -0.05, 0.3, 0.29, 0.2].map { heading.follow($0) }
    #expect(turns == [false, false, true, false, false, true])
    #expect(!heading.right)
}

/// A walk that starts after the desktops settled one desktop to the right
/// starts heading left from there, not turning at once.
@Test func headingStartsFromWhereTheDesktopsAre() {
    var heading = Walk.Heading(at: 1)
    let turns = [1.01, 1.05].map { heading.follow($0) }
    #expect(turns == [false, true])
}
