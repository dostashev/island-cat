import Foundation

/// Petting the cat: the pointer over it.
public enum Petting {
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
