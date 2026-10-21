import Foundation

/// Answers the requests of a test with no network. Each test uses its own host,
/// so tests that run at the same time do not see the answers of the others.
final class StubServer: Sendable {
    struct Reply {
        var status = 200
        var body: String
    }

    fileprivate static let lock = NSLock()
    nonisolated(unsafe) fileprivate static var replies: [String: [Reply]] = [:]
    nonisolated(unsafe) fileprivate static var requests: [String: [URLRequest]] = [:]

    let host = "h\(UUID().uuidString.prefix(8).lowercased()).test"

    var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Loader.self]
        return URLSession(configuration: configuration)
    }

    func url(_ path: String) -> String { "https://\(host)\(path)" }

    func reply(_ body: String, status: Int = 200) {
        Self.lock.withLock { Self.replies[host, default: []].append(Reply(status: status, body: body)) }
    }

    /// The paths that the code asked for, in order.
    var paths: [String] {
        Self.lock.withLock { (Self.requests[host] ?? []).map { $0.url!.path } }
    }

    var lastRequest: URLRequest? {
        Self.lock.withLock { Self.requests[host]?.last }
    }

    /// The part that URLSession calls. It gives the next answer of the host.
    final class Loader: URLProtocol, @unchecked Sendable {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let host = request.url?.host ?? ""
            let reply: Reply? = StubServer.lock.withLock {
                StubServer.requests[host, default: []].append(request)
                guard var queue = StubServer.replies[host], !queue.isEmpty else { return nil }
                let first = queue.removeFirst()
                StubServer.replies[host] = queue
                return first
            }
            guard let reply else {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
                return
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }
}
