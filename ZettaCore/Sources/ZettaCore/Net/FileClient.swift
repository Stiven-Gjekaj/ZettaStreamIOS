import Foundation

/// Downloads a large file, such as a playlist or a TV guide.
public struct FileClient: Sendable {
    private let session: URLSession
    private let userAgent: String

    public init(session: URLSession = .shared, userAgent: String = ZettaCore.appName) {
        self.session = session
        self.userAgent = userAgent
    }

    /// Downloads `url`. A gzip file is opened first, also when its name does not end in `.gz`.
    /// A status that is not 2xx throws `HTTPError`.
    public func data(_ url: String) async throws -> Data {
        guard let address = URL(string: url) else { throw URLError(.badURL) }
        var request = URLRequest(url: address, timeoutInterval: 30)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HTTPError(status: http.statusCode, url: url)
        }
        return try Gzip.openIfGzip(data)
    }
}
