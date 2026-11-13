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

/// The cat starts and ends on straight legs, not meeting in a V.
@Test func strideStartsOnStraightLegs() {
    let stride = Walk.Stride()
    #expect(stride.isStraight)
    for leg in Walk.legs(phase: stride.phase, reach: 1) {
        #expect(abs(leg.foot.x - leg.hip.x) < 1e-9)
    }
}

/// Five steps a desktop while the desktops slide slowly, but a fast flick
/// is held to six steps a second.
@Test func strideFollowsTheSlideUpToACadence() {
    var slow = Walk.Stride()
    slow.follow(0.1, elapsed: 0.2)
    #expect(abs(slow.phase - 0.75) < 1e-9)
    var fast = Walk.Stride()
    fast.follow(0.5, elapsed: 0.1)
    #expect(abs(fast.phase - 0.85) < 1e-9)
}

/// When the desktops stop, the cat finishes its step the way it was going
/// and ends on straight legs.
@Test(arguments: [0.03, -0.03])
func strideFinishesOnStraightLegs(slid: Double) {
    var stride = Walk.Stride()
    stride.follow(slid, elapsed: 0.1)
    #expect(!stride.isStraight)
    let before = stride.phase
    for _ in 0..<30 { stride.finish(elapsed: 1.0 / 120) }
    #expect(stride.isStraight)
    // It went on the way it was going: forward from 0.4 to 0.75, back from
    // 0.1 to -0.25.
    #expect(abs(stride.phase - 0.75) < 1e-9)
    #expect(before != stride.phase)
}

/// The cat walks the way the desktops slide: going right, the feet on the
/// ground push back to the left, and going left, to the right.
@Test(arguments: [(0.002, true), (-0.002, false)])
func feetOnTheGroundPushBackAgainstTheWalk(slid: Double, right: Bool) {
    var stride = Walk.Stride()
    let early = Walk.legs(phase: stride.phase, reach: 1)
    stride.follow(slid, elapsed: 0.01)
    let later = Walk.legs(phase: stride.phase, reach: 1)
    let ground = early.map(\.foot.y).max()!
    let planted = early.indices.filter { early[$0].foot.y == ground && later[$0].foot.y == ground }
    #expect(planted.count == 2)
    for leg in planted {
        #expect(right ? later[leg].foot.x < early[leg].foot.x : later[leg].foot.x > early[leg].foot.x)
    }
}

@Test func tuckedLegsStayInTheBody() {
    for leg in Walk.legs(phase: 0.3, reach: 0) {
        #expect(leg.foot == leg.hip)
    }
}

/// Standing, the feet stay inside the menu bar, round ends and all: a
/// full-screen app paints it black and starts right under it.
@Test(arguments: [proled, notched])
func feetStayInTheMenuBar(screen: ScreenShape) throws {
    let island = try #require(Island.on(screen))
    let placement = Cat.Placement(body: island.body, origin: .zero)
    for phase in stride(from: 0.0, to: 1, by: 0.05) {
        for leg in Walk.legs(phase: phase, reach: 1, ground: Walk.ground(on: island)) {
            let foot = placement.point(leg.foot)
            #expect(foot.y - Walk.legWidth / 2 >= island.band.minY)
            #expect(foot.y < island.body.minY)
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

/// Over and back counts both ways: one desktop right and back on the
/// 34.6 cm wide PROLED panel is 69.2 cm.
@Test func odometerCountsEveryWayTheDesktopsSlide() {
    var odometer = Walk.Odometer(meters: 1)
    for offset in [0, 0.5, 1, 0.6, 0] { odometer.follow(offset, width: 0.346) }
    #expect(abs(odometer.meters - 1.692) < 1e-9)
}


/// The whiskers bob once a step while walking, and rest level where a walk
/// starts and ends on straight legs, or with the legs tucked away.
@Test func whiskersBobWithTheSteps() {
    #expect(abs(Walk.whiskerTilt(phase: Walk.Stride().phase, reach: 1)) < 1e-9)
    #expect(abs(Walk.whiskerTilt(phase: 0.5, reach: 1) - 5) < 1e-9)
    #expect(abs(Walk.whiskerTilt(phase: 0.0, reach: 1) + 5) < 1e-9)
    #expect(Walk.whiskerTilt(phase: 0.5, reach: 0) == 0)
}

/// Gliding, the wheels reach no lower than the walking feet do, inside the
/// menu bar; the toes point the way it glides and the skates sit apart;
/// tucked away, they shrink into the hips.
@Test(arguments: [proled, notched], [true, false])
func skatesStandBelowTheMenuBarAndTuckIntoTheHips(screen: ScreenShape, right: Bool) throws {
    let island = try #require(Island.on(screen))
    let floor = Walk.floor(on: island)
    let standing = Walk.skates(reach: 1, floor: floor, facingRight: right)
    let placement = Cat.Placement(body: island.body, origin: island.canvas.origin)
    for skate in standing {
        for wheel in skate.wheels {
            #expect(abs(wheel.y + skate.wheelRadius - floor) < 1e-9)
            let bottom = placement.point(CGPoint(x: wheel.x, y: wheel.y + skate.wheelRadius))
            #expect(bottom.y + island.canvas.minY >= island.band.minY)
        }
        let toe = skate.boot.map(\.x).max(by: { right ? $0 < $1 : $0 > $1 })!
        #expect(right ? toe > skate.hip.x : toe < skate.hip.x)
    }
    for (a, b) in zip(standing, standing.dropFirst()) {
        let aRight = (a.boot.map(\.x) + [a.plate.maxX]).max()!
        let bLeft = (b.boot.map(\.x) + [b.plate.minX]).min()!
        #expect(aRight < bLeft)
    }
    for skate in Walk.skates(reach: 0, floor: floor, facingRight: right) {
        #expect(skate.boot.allSatisfy { $0 == skate.hip })
        #expect(skate.wheelRadius == 0)
    }
}

/// Gliding, the cat stands on straight legs, its whiskers level.
@Test(arguments: [0.03, -0.07, 0.11])
func glidingStandsOnStraightLegs(slid: Double) {
    var stride = Walk.Stride()
    stride.follow(slid, elapsed: 0.1)
    stride.stand()
    #expect(stride.isStraight)
    #expect(abs(Walk.whiskerTilt(phase: stride.phase, reach: 1)) < 1e-9)
}

/// The skateboard's wheels stand where the walking feet reach, inside the
/// menu bar; the deck fits the cat's window; tucked away, the board shrinks
/// into the body.
@Test(arguments: [proled, notched])
func skateboardStandsOnTheFloorAndTucksAway(screen: ScreenShape) throws {
    let island = try #require(Island.on(screen))
    let floor = Walk.floor(on: island)
    let board = Walk.skateboard(reach: 1, floor: floor)
    for wheel in board.wheels { #expect(abs(wheel.y + board.wheelRadius - floor) < 1e-9) }
    let placement = Cat.Placement(body: island.body, origin: island.canvas.origin)
    for point in board.deck {
        let p = placement.point(point)
        #expect(p.x >= 0 && p.x <= island.canvas.width)
        #expect(p.y + island.canvas.minY >= island.band.minY)
    }
    for leg in board.legs { #expect(leg.foot.x == leg.hip.x && leg.foot.y > leg.hip.y) }
    let tucked = Walk.skateboard(reach: 0, floor: floor)
    #expect(Set(tucked.deck.map(\.x)).count == 1)
    #expect(tucked.wheelRadius == 0)
}

/// The rainbow is blocks side by side out to its length, every other one a
/// step higher, swapping which as the cat steps.
@Test func rainbowStepsUpEveryOtherBlock() {
    let blocks = Walk.Rainbow.blocks(length: 25, width: 6, step: 1, flip: false)
    #expect(blocks.map(\.from) == [0, 6, 12, 18, 24])
    #expect(blocks.last?.to == 25)
    #expect(blocks.map(\.rise) == [0, 1, 0, 1, 0])
    let flipped = Walk.Rainbow.blocks(length: 25, width: 6, step: 1, flip: true)
    #expect(flipped.map(\.rise) == [1, 0, 1, 0, 1])
    #expect(Walk.Rainbow.blocks(length: 0, width: 6, step: 1, flip: false).isEmpty)
    #expect(Walk.Rainbow.flip(phase: 0.1) != Walk.Rainbow.flip(phase: 0.35))
    #expect(Walk.Rainbow.flip(phase: 0.1) == Walk.Rainbow.flip(phase: 0.6))
}

/// The longest rainbow fits the cat's window.
@Test(arguments: [proled, notched])
func rainbowFitsTheWindow(screen: ScreenShape) throws {
    let island = try #require(Island.on(screen))
    let reach = island.body.width / 2 + 90
    #expect(island.body.midX - reach >= island.canvas.minX)
    #expect(island.body.midX + reach <= island.canvas.maxX)
    #expect(island.nearby.width < island.canvas.width)
}
