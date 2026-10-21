import Foundation

/// Answers the requests of a test with no network. Each test uses its own host,
/// so tests that run at the same time do not see the answers of the others.
final class StubServer: Sendable {
    struct Reply {
        var status = 200
        var body: Data
        var headers: [String: String] = [:]
        /// The seconds before the answer comes. A test of a time limit uses it.
        var delay: TimeInterval = 0
    }

    fileprivate static let lock = NSLock()
    nonisolated(unsafe) fileprivate static var replies: [String: [Reply]] = [:]
    /// The answers for one path of a host. They come before the answers in order.
    nonisolated(unsafe) fileprivate static var pathReplies: [String: [Reply]] = [:]
    nonisolated(unsafe) fileprivate static var requests: [String: [URLRequest]] = [:]

    let host = "h\(UUID().uuidString.prefix(8).lowercased()).test"

    var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Loader.self]
        return URLSession(configuration: configuration)
    }

    func url(_ path: String) -> String { "https://\(host)\(path)" }

    func reply(_ body: String, status: Int = 200, headers: [String: String] = [:], delay: TimeInterval = 0) {
        reply(data: Data(body.utf8), status: status, headers: headers, delay: delay)
    }

    /// Answers with bytes, such as a gzip file.
    func reply(data: Data, status: Int = 200, headers: [String: String] = [:], delay: TimeInterval = 0) {
        let reply = Reply(status: status, body: data, headers: headers, delay: delay)
        Self.lock.withLock { Self.replies[host, default: []].append(reply) }
    }

    /// Answers a request for `path` only, whatever the order of the requests.
    func reply(path: String, _ body: String, status: Int = 200) {
        let reply = Reply(status: status, body: Data(body.utf8))
        Self.lock.withLock { Self.pathReplies[host + path, default: []].append(reply) }
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
        private let state = NSLock()
        private var stopped = false

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let host = request.url?.host ?? ""
            let reply: Reply? = StubServer.lock.withLock {
                StubServer.requests[host, default: []].append(request)
                let key = host + (request.url?.path ?? "")
                if var byPath = StubServer.pathReplies[key], !byPath.isEmpty {
                    let first = byPath.removeFirst()
                    StubServer.pathReplies[key] = byPath
                    return first
                }
                guard var queue = StubServer.replies[host], !queue.isEmpty else { return nil }
                let first = queue.removeFirst()
                StubServer.replies[host] = queue
                return first
            }
            guard let reply else {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
                return
            }
            if reply.delay > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + reply.delay) { self.answer(reply) }
            } else {
                answer(reply)
            }
        }

        private func answer(_ reply: Reply) {
            // A request that stopped, for example after a time limit, gets no answer.
            guard !state.withLock({ stopped }) else { return }
            let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: reply.body)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {
            state.withLock { stopped = true }
        }
    }
}
