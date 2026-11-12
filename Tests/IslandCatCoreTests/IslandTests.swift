import CoreGraphics
import Testing

@testable import IslandCatCore

/// The MacBook Pro with PROLED XDR Display: 838.5 pt beside a 59 × 40 pt
/// housing, under a 45 pt menu bar.
let proled = ScreenShape(
    frame: CGRect(x: 0, y: 0, width: 1736, height: 1133),
    visibleTop: 1088,
    safeTop: 40,
    leftOfCamera: CGRect(x: 0, y: 1093, width: 838.5, height: 40),
    rightOfCamera: CGRect(x: 897.5, y: 1093, width: 838.5, height: 40))

/// A notched MacBook Pro: a 185 × 32 pt notch.
let notched = ScreenShape(
    frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
    visibleTop: 945,
    safeTop: 32,
    leftOfCamera: CGRect(x: 0, y: 950, width: 663.5, height: 32),
    rightOfCamera: CGRect(x: 848.5, y: 950, width: 663.5, height: 32))

@Test func islandRestsInTheBottomOfItsHousing() throws {
    let island = try #require(Island.on(proled))
    #expect(!island.isNotch)
    #expect(island.band == CGRect(x: 0, y: 1088, width: 1736, height: 45))
    // 58 × 31 pt, from 839 to 897 pt across and 8.5 to 39.5 pt down.
    #expect(island.body == CGRect(x: 839, y: 1093.5, width: 58, height: 31))
}

/// What the recordings showed: the pointer at the middle, and 30 pt left of
/// it, of the island grown to 67 × 36 pt.
@Test func grownIslandLeansTowardThePointer() throws {
    let island = try #require(Island.on(proled))
    let middle = CGPoint(x: 868, y: 1133 - 24)
    #expect(island.hovered(toward: middle) == CGRect(x: 834.5, y: 1091, width: 67, height: 36))
    let left = island.hovered(toward: CGPoint(x: 838, y: middle.y))
    #expect(left.midX == 865)
}

/// Recorded thresholds, in points from the screen's top-left corner.
@Test func pointerStartsAndEndsTheHoverWhereTheSystemDoes() throws {
    let island = try #require(Island.on(proled))
    func at(_ x: CGFloat, _ down: CGFloat) -> CGPoint { CGPoint(x: x, y: 1133 - down) }
    // From the left it grows about 7 pt early, from the right about 1.5 pt.
    #expect(island.startsHover(at: at(832.5, 20)))
    #expect(!island.startsHover(at: at(830.5, 20)))
    #expect(island.startsHover(at: at(898, 16)))
    #expect(!island.startsHover(at: at(900, 16)))
    // From below, only well inside it.
    #expect(island.startsHover(at: at(852, 31)))
    #expect(!island.startsHover(at: at(866, 36)))
    // Once grown it stays grown out to the grown island's edge.
    #expect(island.keepsHover(at: at(836, 20)))
    #expect(island.keepsHover(at: at(866, 42)))
    #expect(!island.keepsHover(at: at(866, 46)))
    #expect(!island.keepsHover(at: at(828, 20)))
    #expect(island.keepsHover(at: at(876, 0)))
}

@Test func hiddenMenuBarKeepsTheHeightItLastHad() throws {
    var hidden = proled
    hidden.visibleTop = hidden.frame.maxY
    let island = try #require(Island.on(hidden, menuBarHeight: 45))
    #expect(island == Island.on(proled))
}

@Test func notchIsItsOwnIsland() throws {
    let island = try #require(Island.on(notched))
    #expect(island.isNotch)
    #expect(island.body == CGRect(x: 663.5, y: 950, width: 185, height: 32))
    #expect(island.hovered(toward: CGPoint(x: 700, y: 960)) == island.body)
    #expect(!island.startsHover(at: CGPoint(x: 756, y: 970)))
}

@Test func screenWithoutCameraHasNoIsland() {
    let external = ScreenShape(
        frame: CGRect(x: 1736, y: -307, width: 2560, height: 1440), visibleTop: 1108,
        safeTop: 0, leftOfCamera: .zero, rightOfCamera: .zero)
    #expect(Island.on(external) == nil)
}

@Test func islandOnASecondScreenIsInThatScreensCoordinates() throws {
    var moved = proled
    let offset: CGFloat = -1736
    moved.frame.origin.x += offset
    moved.leftOfCamera.origin.x += offset
    moved.rightOfCamera.origin.x += offset
    let island = try #require(Island.on(moved))
    #expect(island.body.midX == 868 + offset)
}

/// Everything the cat draws, at its widest swing, fits in its window. The
/// window's top is the screen's edge, which clips whatever reaches past it.
@Test(arguments: [proled, notched], 0..<5)
func catFitsItsCanvas(screen: ScreenShape, pose: Int) throws {
    let island = try #require(Island.on(screen))
    let canvas = island.canvas
    // At rest, then grown and leaning as far as it can each way.
    let reach = island.body.insetBy(dx: -40, dy: -24)
    let toward = [
        CGPoint(x: reach.minX, y: reach.midY), CGPoint(x: reach.maxX, y: reach.midY),
        CGPoint(x: reach.midX, y: reach.minY), CGPoint(x: reach.midX, y: reach.maxY),
    ]
    let body = pose == 0 ? island.body : island.hovered(toward: toward[pose - 1])
    let placement = Cat.Placement(body: body, origin: canvas.origin)
    let local = CGRect(origin: .zero, size: canvas.size)
    for part in Cat.parts {
        let bounds = placement.path(part).boundingBoxOfPath
        let pivot = placement.point(part.pivot)
        let motions = [part.idle, part.excited].compactMap { $0 }
        let angles = [0] + motions.filter { $0.property == .rotation }.flatMap(\.values)
        let corners = [bounds.minX, bounds.maxX].flatMap { x in
            [bounds.minY, bounds.maxY].map { y in CGPoint(x: x - pivot.x, y: y - pivot.y) }
        }
        // The corners of the part's box, turned through every angle it takes.
        let swept = angles.flatMap { degrees in
            let turn = degrees * .pi / 180
            return corners.map { c in
                CGPoint(
                    x: pivot.x + c.x * cos(turn) - c.y * sin(turn),
                    y: pivot.y + c.x * sin(turn) + c.y * cos(turn))
            }
        }
        let pad = part.lineWidth / 2
        #expect(swept.map(\.x).min()! - pad >= local.minX, "\(part.name)")
        #expect(swept.map(\.x).max()! + pad <= local.maxX, "\(part.name)")
        #expect(swept.map(\.y).min()! - pad >= local.minY, "\(part.name)")
    }
}

/// An ear's base, the edge that closes it, and every corner of it inside
/// the head stay inside the head however far the ear flicks, so only the
/// ear shows.
@Test(arguments: ["left ear", "right ear"])
func earBaseStaysInsideTheHead(name: String) throws {
    let island = try #require(Island.on(proled))
    let placement = Cat.Placement(body: island.body, origin: .zero)
    let ear = try #require(Cat.parts.first { $0.name == name })
    let head = placement.bodyPath
    let pivot = placement.point(ear.pivot)
    let points = ear.segments.compactMap { segment -> CGPoint? in
        switch segment {
        case .move(let p), .line(let p): placement.point(p)
        default: nil
        }
    }
    // The base runs from the last corner back to the first; check its ends
    // and middle, and every other corner that starts inside the head.
    let first = try #require(points.first), last = try #require(points.last)
    let middle = CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2)
    let corners = [middle] + points.filter { head.contains($0) }
    let angles = [0] + [ear.idle, ear.excited].compactMap { $0 }.flatMap(\.values)
    for degrees in angles {
        let turn = degrees * .pi / 180
        for c in corners {
            let d = CGPoint(x: c.x - pivot.x, y: c.y - pivot.y)
            let turned = CGPoint(
                x: pivot.x + d.x * cos(turn) - d.y * sin(turn),
                y: pivot.y + d.x * sin(turn) + d.y * cos(turn))
            // Half a point of margin for the line width and edge smoothing.
            let inside = [CGPoint(x: 0, y: 0.5), CGPoint(x: 0.5, y: 0), CGPoint(x: -0.5, y: 0)]
                .allSatisfy { head.contains(CGPoint(x: turned.x + $0.x, y: turned.y + $0.y)) }
            #expect(inside, "\(name) corner \(c) at \(degrees)°")
        }
    }
}
