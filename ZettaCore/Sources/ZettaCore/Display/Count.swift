import Foundation

extension Display {
    /// A number with its word, such as "1 stream" or "3 streams".
    public static func count(_ n: Int, _ word: String) -> String {
        "\(n) \(word)" + (n == 1 ? "" : "s")
    }
}
