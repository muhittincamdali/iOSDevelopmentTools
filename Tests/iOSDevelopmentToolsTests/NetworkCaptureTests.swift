import Foundation
import Testing
@testable import iOSDevelopmentTools

/// End-to-end tests: requests go from an app session through ``NetworkCapture`` and the
/// forwarding session to ``StubServer``. Capture is global state, so the suite runs serially.
@Suite("Network capture", .serialized)
final class NetworkCaptureTests {
    let logger: NetworkLogger
    let session: URLSession

    init() {
        logger = NetworkLogger(configuration: .init(maximumBodySize: 1024))
        NetworkCapture.setForwardingProtocolClasses([StubServer.self])
        NetworkCapture.start(logger: logger)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        session = URLSession(configuration: configuration)
    }

    deinit {
        session.invalidateAndCancel()
        NetworkCapture.stop()
    }

    private func url(_ path: String) -> URL {
        URL(string: "https://\(StubServer.host)\(path)")!
    }

    /// The entry for a URL once it has ended. Entries are completed on the forwarding queue just
    /// before the app's session hears about it, so allow a moment for the last update.
    private func finishedEntry(_ path: String) async throws -> NetworkEntry {
        for _ in 0..<200 {
            if let entry = logger.entries.last(where: { $0.url.hasSuffix(path) }), entry.state != .pending {
                return entry
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("No finished entry for \(path)")
        throw CancellationError()
    }

    @Test("Starting capture installs the protocol in new default and ephemeral configurations")
    func installsIntoNewConfigurations() {
        for configuration in [URLSessionConfiguration.default, .ephemeral] {
            #expect(configuration.protocolClasses?.first { $0 == CaptureProtocol.self } != nil)
        }
        #expect(NetworkCapture.isCapturing)
        #expect(NetworkCapture.logger === logger)
    }

    @Test("The app receives the real response while the entry is redacted")
    func responseIsUntouchedButEntryRedacted() async throws {
        let (data, response) = try await session.data(from: url("/login"))
        #expect(String(decoding: data, as: UTF8.self) == #"{"access_token":"tok-123","user":"ada"}"#)
        #expect((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Set-Cookie") == "sid=abc; HttpOnly")

        let entry = try await finishedEntry("/login")
        #expect(entry.state == .completed)
        #expect(entry.statusCode == 200)
        #expect(HTTPHeader.value(named: "set-cookie", in: entry.responseHeaders) == RedactionPolicy.replacement)
        let stored = try #require(entry.responseBody?.text)
        #expect(!stored.contains("tok-123"))
        #expect(stored.contains("\"user\":\"ada\""))
        #expect(entry.responseBody?.redaction == .redacted)
        #expect(entry.duration != nil)
    }

    @Test("The server receives the real request body while the entry is redacted")
    func requestBodyIsForwardedIntact() async throws {
        var request = URLRequest(url: url("/echo?api_key=K&page=1"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer secret-token", forHTTPHeaderField: "Authorization")
        let body = Data(#"{"email":"ada@example.com","password":"hunter2"}"#.utf8)
        request.httpBody = body

        let (echoed, _) = try await session.data(for: request)
        #expect(echoed == body)

        let entry = try await finishedEntry("/echo?api_key=\(RedactionPolicy.replacement)&page=1")
        #expect(entry.method == "POST")
        #expect(HTTPHeader.value(named: "Authorization", in: entry.requestHeaders) == RedactionPolicy.replacement)
        let sent = try #require(entry.requestBody)
        #expect(sent.byteCount == body.count)
        #expect(sent.redaction == .redacted)
        #expect(sent.text?.contains("hunter2") == false)
        #expect(sent.text?.contains("ada@example.com") == true)
    }

    @Test("Bodies over the capture limit are sent whole but stored cut off")
    func largeBodies() async throws {
        let (data, _) = try await session.data(from: url("/bytes/5000"))
        #expect(data.count == 5000)
        let entry = try await finishedEntry("/bytes/5000")
        let body = try #require(entry.responseBody)
        #expect(body.data.count == 1024)
        #expect(body.byteCount == 5000)
        #expect(body.isTruncated)
    }

    @Test("Uploads larger than the in-memory limit are streamed to the server in full")
    func streamedUpload() async throws {
        let size = CaptureProtocol.inMemoryBodyLimit + 300_000
        var payload = Data(count: size)
        payload.withUnsafeMutableBytes { bytes in
            for index in bytes.indices { bytes[index] = UInt8(truncatingIfNeeded: index &* 31) }
        }
        var request = URLRequest(url: url("/echo"))
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (echoed, response) = try await session.upload(for: request, from: payload)
        #expect((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Received-Bytes") == "\(size)")
        #expect(echoed == payload)

        let entry = try await finishedEntry("/echo")
        let sent = try #require(entry.requestBody)
        #expect(sent.data.count == 1024)
        #expect(sent.byteCount == size)
        #expect(sent.isTruncated)
    }

    @Test("A redirect is recorded as its own entry and the app reaches the target")
    func redirects() async throws {
        let (data, response) = try await session.data(from: url("/redirect"))
        #expect(String(decoding: data, as: UTF8.self) == "done")
        #expect(response.url?.path() == "/final")

        let redirect = try await finishedEntry("/redirect")
        #expect(redirect.statusCode == 302)
        #expect(redirect.redirectURL == url("/final").absoluteString)
        #expect(redirect.state == .completed)
        let final = try await finishedEntry("/final")
        #expect(final.statusCode == 200)
    }

    @Test("Network errors reach the app and the entry")
    func failures() async throws {
        let session = session
        let offline = url("/offline")
        await #expect(throws: URLError.self) {
            _ = try await session.data(from: offline)
        }
        let entry = try await finishedEntry("/offline")
        #expect(entry.state == .failed)
        #expect(entry.error?.code == URLError.notConnectedToInternet.rawValue)
        #expect(entry.error?.isCancellation == false)
    }

    @Test("Cancelling a request records a cancellation")
    func cancellation() async throws {
        let task = session.dataTask(with: url("/hang"))
        task.resume()
        for _ in 0..<200 where !logger.entries.contains(where: { $0.url.hasSuffix("/hang") }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        task.cancel()
        let entry = try await finishedEntry("/hang")
        #expect(entry.state == .failed)
        #expect(entry.error?.isCancellation == true)
    }

    @Test("HTTP error statuses complete normally")
    func errorStatus() async throws {
        let (_, response) = try await session.data(from: url("/status/503"))
        #expect((response as? HTTPURLResponse)?.statusCode == 503)
        let entry = try await finishedEntry("/status/503")
        #expect(entry.state == .completed)
        #expect(entry.statusCode == 503)
        #expect(entry.responseBody == nil)
    }

    @Test("Ignored hosts are passed through without an entry")
    func ignoredHosts() async throws {
        logger.configuration.ignoredHosts = ["STUB.test."]
        defer { logger.configuration.ignoredHosts = [] }
        // Not captured, the request goes straight to the system loader and fails to resolve:
        // the point is that it is not recorded.
        _ = try? await session.data(from: url("/status/204"))
        #expect(logger.entries.isEmpty)
    }

    @Test("Concurrent requests each get one complete entry")
    func concurrentRequests() async throws {
        let session = session
        let urls = (0..<40).map { url("/bytes/\($0)") }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask { _ = try await session.data(from: url) }
            }
            try await group.waitForAll()
        }
        for _ in 0..<200 where logger.entries.contains(where: { $0.state == .pending }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        let entries = logger.entries
        #expect(entries.count == 40)
        #expect(entries.allSatisfy { $0.state == .completed && $0.statusCode == 200 })
        #expect(Set(entries.map(\.url)).count == 40)
    }

    @Test("Stopping capture passes new requests through unrecorded")
    func stopping() async throws {
        NetworkCapture.stop()
        #expect(!NetworkCapture.isCapturing)
        #expect(URLSessionConfiguration.default.protocolClasses?.contains { $0 == CaptureProtocol.self } != true)
        #expect(!CaptureProtocol.canInit(with: URLRequest(url: url("/final"))))
        NetworkCapture.start(logger: logger)
        #expect(CaptureProtocol.canInit(with: URLRequest(url: url("/final"))))
    }

    @Test("Only HTTP and HTTPS requests are captured, and never twice")
    func canInitRules() {
        #expect(!CaptureProtocol.canInit(with: URLRequest(url: URL(string: "wss://stub.test/socket")!)))
        #expect(!CaptureProtocol.canInit(with: URLRequest(url: URL(string: "file:///tmp/x")!)))
        let handled = NSMutableURLRequest(url: url("/final"))
        URLProtocol.setProperty(true, forKey: CaptureProtocol.handledKey, in: handled)
        #expect(!CaptureProtocol.canInit(with: handled as URLRequest))
    }
}
