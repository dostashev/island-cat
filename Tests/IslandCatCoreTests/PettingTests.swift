import Testing

@testable import IslandCatCore

/// Over, back and over again within a second is a petting.
@Test func strokingBackAndForthPetsTheCat() {
    var petting = Petting()
    let strokes = [(840.0, 0.0), (850, 0.1), (860, 0.2), (848, 0.35), (836, 0.5), (850, 0.7)]
    let pets = strokes.map { petting.stroke(x: $0.0, at: $0.1) }
    #expect(pets == [false, false, false, false, false, true])
}

/// Passing over the cat one way, or jittering a few points, is not.
@Test func passingOverOrJitteringDoesNotPet() {
    var passing = Petting()
    #expect(!stride(from: 820.0, to: 920, by: 5).enumerated().contains {
        passing.stroke(x: $0.element, at: Double($0.offset) * 0.02)
    })
    var jitter = Petting()
    #expect(![860.0, 863, 860, 863, 860, 863, 860].enumerated().contains {
        jitter.stroke(x: $0.element, at: Double($0.offset) * 0.05)
    })
}

/// Turns too far apart in time do not add up.
@Test func slowTurnsDoNotPet() {
    var petting = Petting()
    let strokes = [(840.0, 0.0), (860, 0.5), (840, 1.0), (860, 2.5), (840, 4.0)]
    #expect(!strokes.map { petting.stroke(x: $0.0, at: $0.1) }.contains(true))
}

@Test func replyIsNeverTheSameTwiceInARow() {
    for r in stride(from: 0.0, to: 1, by: 0.01) {
        let reply = Petting.reply(after: "purr…", random: r)
        #expect(reply != "purr…")
        #expect(Petting.replies.contains(reply))
    }
}
