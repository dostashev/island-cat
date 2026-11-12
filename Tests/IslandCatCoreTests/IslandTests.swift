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
    // Hovered, about 67 × 36 pt, from 4.5 to 40.5 pt down.
    #expect(island.hovered == CGRect(x: 834.5, y: 1092.5, width: 67, height: 36))
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
    #expect(island.hovered == island.body)
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
@Test(arguments: [proled, notched], [false, true])
func catFitsItsCanvas(screen: ScreenShape, hovered: Bool) throws {
    let island = try #require(Island.on(screen))
    let canvas = island.canvas
    let placement = Cat.Placement(
        body: hovered ? island.hovered : island.body, origin: canvas.origin)
    let local = CGRect(origin: .zero, size: canvas.size)
    for part in Cat.parts {
        let bounds = placement.path(part).boundingBoxOfPath
        let pivot = CGPoint(
            x: bounds.minX + part.pivot.x * bounds.width,
            y: bounds.minY + part.pivot.y * bounds.height)
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
