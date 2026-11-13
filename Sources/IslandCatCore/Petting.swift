import Foundation

/// Petting the cat: stroking the pointer back and forth over it.
public struct Petting: Sendable {
    /// Strokes count when the pointer turns back after moving at least
    /// this far one way, in points.
    static let strokeLength = 6.0
    /// Turns within this many seconds of each other make one petting.
    static let window = 1.2
    /// Turns it takes: over, back and over again.
    static let turns = 2

    private var anchor: Double?
    private var direction = 0.0
    private var turnTimes: [Double] = []

    public init() {}

    /// The pointer is over the cat at `x` points across, at time `now`
    /// seconds. Returns true when that makes a petting.
    public mutating func stroke(x: Double, at now: Double) -> Bool {
        guard let anchor else {
            self.anchor = x
            return false
        }
        let moved = x - anchor
        if direction == 0 {
            if abs(moved) >= Self.strokeLength { direction = moved > 0 ? 1 : -1 }
            self.anchor = x
            return false
        }
        if moved * direction > 0 {
            // Still going the same way.
            self.anchor = x
            return false
        }
        guard abs(moved) >= Self.strokeLength else { return false }
        // Turned back.
        direction = -direction
        self.anchor = x
        turnTimes = turnTimes.filter { now - $0 <= Self.window } + [now]
        guard turnTimes.count >= Self.turns else { return false }
        turnTimes = []
        return true
    }

    /// The pointer left the cat.
    public mutating func reset() {
        anchor = nil
        direction = 0
        turnTimes = []
    }

    /// What the cat says when petted: cat sounds only.
    public static let replies = [
        "mrr", "mrrp", "mrrp?", "prrrr", "prrrrrrr", "mew", "mrow", "mrrrow", "nyaa", "brrp",
        "mrr…", "♥",
    ]

    /// A reply other than `last`, picked with `random` in 0..<1.
    public static func reply(after last: String?, random: Double) -> String {
        let choices = replies.filter { $0 != last }
        let index = min(choices.count - 1, Int(random * Double(choices.count)))
        return choices[index]
    }
}
