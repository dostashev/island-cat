import Testing

@testable import IslandCatCore

@Test func replyIsNeverTheSameTwiceInARow() {
    for r in stride(from: 0.0, to: 1, by: 0.01) {
        let last = Petting.replies[0]
        let reply = Petting.reply(after: last, random: r)
        #expect(reply != last)
        #expect(Petting.replies.contains(reply))
    }
}
