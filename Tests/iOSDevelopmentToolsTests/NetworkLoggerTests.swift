import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Network logger")
struct NetworkLoggerTests {
    private func request(_ path: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.example.com\(path)")!)
        request.httpMethod = method
        return request
    }

    private func response(_ path: String, status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.example.com\(path)")!, statusCode: status, httpVersion: nil, headerFields: headers)!
    }

    @Test("Limits outside their range are clamped", arguments: [
        (Int.min, Int.min, 1, 0),
        (0, -1, 1, 0),
        (Int.max, Int.max, NetworkLogger.Configuration.entryLimit, NetworkLogger.Configuration.bodySizeLimit),
        (25, 2048, 25, 2048),
    ])
    func clamping(entries: Int, bodySize: Int, expectedEntries: Int, expectedBodySize: Int) {
        var configuration = NetworkLogger.Configuration(maximumEntries: entries, maximumBodySize: bodySize)
        #expect(configuration.maximumEntries == expectedEntries)
        #expect(configuration.maximumBodySize == expectedBodySize)
        configuration.maximumEntries = entries
        configuration.maximumBodySize = bodySize
        #expect(configuration.maximumEntries == expectedEntries)
        #expect(configuration.maximumBodySize == expectedBodySize)
    }

    @Test("Ignored hosts cover subdomains, without case or a trailing dot")
    func ignoredHosts() {
        let configuration = NetworkLogger.Configuration(ignoredHosts: ["Analytics.example.com.", " ", ""])
        #expect(configuration.ignoredHosts == ["analytics.example.com"])
        #expect(!configuration.records(host: "analytics.example.com"))
        #expect(!configuration.records(host: "EU.Analytics.Example.com"))
        #expect(configuration.records(host: "notanalytics.example.com"))
        #expect(configuration.records(host: "example.com"))
        #expect(configuration.records(host: nil))
    }

    @Test("A recorded request keeps its response, redacted")
    func recordsManually() throws {
        let logger = NetworkLogger()
        var sent = request("/v1/session?token=abc", method: "POST")
        sent.setValue("application/json", forHTTPHeaderField: "Content-Type")
        sent.httpBody = Data(#"{"password":"p"}"#.utf8)
        let start = Date(timeIntervalSince1970: 1_000)
        let id = try #require(logger.record(
            request: sent,
            response: response("/v1/session", status: 201, headers: ["Content-Type": "application/json", "Set-Cookie": "a=b"]),
            body: Data(#"{"id":7}"#.utf8),
            startDate: start,
            endDate: start.addingTimeInterval(0.25)))

        let entry = try #require(logger.entry(id: id))
        #expect(entry.method == "POST")
        #expect(entry.url == "https://api.example.com/v1/session?token=\(RedactionPolicy.replacement)")
        #expect(entry.host == "api.example.com")
        #expect(entry.path == "/v1/session")
        #expect(entry.statusCode == 201)
        #expect(entry.duration == 0.25)
        #expect(entry.state == .completed)
        #expect(entry.requestContentType == "application/json")
        #expect(entry.requestBody?.redaction == .redacted)
        #expect(entry.responseBody?.text == #"{"id":7}"#)
        #expect(HTTPHeader.value(named: "Set-Cookie", in: entry.responseHeaders) == RedactionPolicy.replacement)
    }

    // The tenth review: the entry kept the host as the request had it, so a host that the
    // recorded URL hides showed in the list of requests.
    @Test("The host of an entry is hidden when its URL hides it", arguments: [
        ("myapp://password=hunter2/x", "[REDACTED]"), ("https://4111111111111111.example/x", "[REDACTED]"),
        ("https://a_b.example/x", "[REDACTED]"), ("https://0123456789abcdef0123456789abcdef.example/x", "[REDACTED]"),
        ("https://h%41.example/x", "[REDACTED]"), ("https://xn--bcher-kva.de/x", "[REDACTED]"),
        ("https://eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl/x", "[REDACTED]"),
        ("https://api.example.com/v1/x", "api.example.com"), ("https://bob:hunter2@api.example.com/x", "api.example.com"),
        ("https://10.0.0.1/x", "10.0.0.1"), ("https://[::1]/x", "[::1]"),
    ])
    func hidesHost(url: String, host: String) throws {
        let logger = NetworkLogger()
        let request = URLRequest(url: try #require(URL(string: url)))
        let id = try #require(logger.record(request: request, response: nil, body: nil, startDate: Date()))
        let entry = try #require(logger.entry(id: id))
        #expect(entry.host == host)
        #expect(!(entry.host ?? "").contains("hunter2") && !(entry.host ?? "").contains("4111"))
        #expect(entry.url.hasSuffix("[REDACTED]") == (host == "[REDACTED]"))
    }

    @Test("A request that failed is recorded with its error")
    func recordsFailure() throws {
        let logger = NetworkLogger()
        let id = try #require(logger.record(
            request: request("/x"), response: nil, body: nil, error: URLError(.timedOut), startDate: Date()))
        let entry = try #require(logger.entry(id: id))
        #expect(entry.state == .failed)
        #expect(entry.error?.domain == NSURLErrorDomain)
        #expect(entry.error?.code == URLError.timedOut.rawValue)
        #expect(entry.statusCode == nil)
        #expect(entry.responseBody == nil)
    }

    @Test("Only the newest entries are kept, and lowering the limit drops the oldest")
    func capacity() {
        let logger = NetworkLogger(configuration: .init(maximumEntries: 3))
        for index in 0..<5 {
            logger.record(request: request("/\(index)"), response: response("/\(index)", status: 200), body: nil, startDate: Date())
        }
        #expect(logger.entries.map(\.path) == ["/2", "/3", "/4"])
        logger.configuration.maximumEntries = 1
        #expect(logger.entries.map(\.path) == ["/4"])
        logger.clear()
        #expect(logger.entries.isEmpty)
    }

    @Test("Ignored hosts are not recorded")
    func ignoredRecord() {
        let logger = NetworkLogger(configuration: .init(ignoredHosts: ["example.com"]))
        #expect(logger.record(request: request("/a"), response: nil, body: nil, startDate: Date()) == nil)
        #expect(logger.entries.isEmpty)
    }

    @Test("A body of zero bytes is no body, and the size limit applies to manual records")
    func bodies() throws {
        let logger = NetworkLogger(configuration: .init(maximumBodySize: 4))
        var sent = request("/a", method: "PUT")
        sent.httpBody = Data()
        let id = try #require(logger.record(request: sent, response: response("/a", status: 200), body: Data("123456".utf8), startDate: Date()))
        let entry = try #require(logger.entry(id: id))
        #expect(entry.requestBody == nil)
        // A body cut off at the limit cannot be parsed, so it is omitted.
        #expect(entry.responseBody?.redaction == .omitted)
        #expect(entry.responseBody?.text?.hasPrefix("[body omitted: 6 bytes, ") == true)
        #expect(entry.responseBody?.byteCount == 6)
        #expect(entry.responseBody?.isTruncated == true)
        // Without redaction, the first bytes are kept.
        let raw = NetworkLogger(configuration: .init(maximumBodySize: 4, redaction: .disabled))
        let rawID = try #require(raw.record(request: sent, response: response("/a", status: 200), body: Data("123456".utf8), startDate: Date()))
        #expect(raw.entry(id: rawID)?.responseBody?.data == Data("1234".utf8))
    }

    @Test("An end date before the start gives a duration of zero, not a negative one")
    func negativeDuration() throws {
        let logger = NetworkLogger()
        let start = Date()
        let id = try #require(logger.record(request: request("/a"), response: nil, body: nil, startDate: start, endDate: start.addingTimeInterval(-5)))
        #expect(logger.entry(id: id)?.duration == 0)
    }

    @Test("Observers hear about changes, and slow observers get them coalesced")
    func changes() async {
        let logger = NetworkLogger()
        let stream = logger.changes()
        for index in 0..<10 {
            logger.record(request: request("/\(index)"), response: nil, body: nil, startDate: Date())
        }
        var iterator = stream.makeAsyncIterator()
        // Twenty changes happened (two for each request); the stream buffers only one.
        #expect(await iterator.next() != nil)
        logger.clear()
        #expect(await iterator.next() != nil)
        #expect(logger.entries.isEmpty)
    }

    @Test("Many threads can record at once")
    func concurrentRecording() async {
        let logger = NetworkLogger(configuration: .init(maximumEntries: 10_000))
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<500 {
                group.addTask {
                    var request = URLRequest(url: URL(string: "https://example.org/\(index)")!)
                    request.httpMethod = "GET"
                    logger.record(request: request, response: nil, body: Data("x".utf8), startDate: Date())
                }
            }
        }
        #expect(logger.entries.count == 500)
        #expect(Set(logger.entries.map(\.id)).count == 500)
    }
}
