import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Export: cURL and HAR")
struct ExportTests {
    let start = Date(timeIntervalSince1970: 1_760_000_000)

    private func entry(
        _ url: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        status: Int? = 200,
        responseHeaders: [String: String] = [:],
        responseBody: Data? = nil,
        error: (any Error)? = nil,
        configuration: NetworkLogger.Configuration = .init(),
        offset: TimeInterval = 0
    ) throws -> NetworkEntry {
        let logger = NetworkLogger(configuration: configuration)
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = body
        let response = status.map { HTTPURLResponse(url: request.url!, statusCode: $0, httpVersion: nil, headerFields: responseHeaders)! }
        let begin = start.addingTimeInterval(offset)
        let id = try #require(logger.record(
            request: request, response: response, body: responseBody, error: error,
            startDate: begin, endDate: begin.addingTimeInterval(0.125)))
        return try #require(logger.entry(id: id))
    }

    // MARK: cURL

    @Test("A GET becomes a quoted curl command with sorted headers")
    func curlGET() throws {
        let lenient = NetworkLogger.Configuration(redaction: RedactionPolicy(allowedHeaders: ["Accept", "X-Trace"], allowedQueryParameters: ["page"]))
        let command = try entry("https://api.example.com/v1/items?page=2&q=x", headers: ["Accept": "application/json", "X-Trace": "abc", "X-Other": "1"],
                                configuration: lenient).curlCommand()
        #expect(command == "curl --globoff 'https://api.example.com/v1/items?page=2&q=[REDACTED]' -H 'Accept: application/json' -H 'X-Other: [REDACTED]' -H 'X-Trace: abc'")
    }

    @Test("Methods, bodies and redacted values are written as curl expects")
    func curlPOST() throws {
        let command = try entry(
            "https://api.example.com/login?token=t",
            method: "POST",
            headers: ["Content-Type": "application/json", "Content-Length": "40", "X-Empty": ""],
            body: Data(#"{"note":"it's","password":"p"}"#.utf8),
            configuration: .init(redaction: RedactionPolicy(allowedHeaders: RedactionPolicy.defaultAllowedHeaders + ["X-Empty"]))
        ).curlCommand()
        #expect(command == #"curl --globoff -X 'POST' 'https://api.example.com/login?token=[REDACTED]' -H 'Content-Type: application/json' -H 'X-Empty;' --data-binary '{"note":"it'\''s","password":"[REDACTED]"}'"#)
    }

    @Test("Bodies that cannot be repeated are left out with a comment", arguments: [
        ("application/json", Data(#"{"password":"#.utf8), 1024, RedactionPolicy.default, "omitted by redaction (12 bytes)"),
        ("application/octet-stream", Data([0x00, 0xFF, 0x10]), 1024, .default, "omitted by redaction (3 bytes)"),
        ("text/plain", Data(repeating: 65, count: 64), 16, .default, "omitted by redaction (64 bytes)"),
        ("text/plain", Data(repeating: 65, count: 64), 16, .disabled, "only 16 of 64 bytes were stored"),
        ("application/octet-stream", Data([0x00, 0xFF, 0x10]), 1024, .disabled, "3 bytes of binary data"),
    ])
    func curlOmittedBodies(contentType: String, body: Data, limit: Int, policy: RedactionPolicy, note: String) throws {
        let command = try entry("https://e.com/", method: "PUT", headers: ["Content-Type": contentType], body: body,
                                configuration: .init(maximumBodySize: limit, redaction: policy)).curlCommand()
        let lines = command.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("# Request body left out: ") && lines[0].contains(note))
        #expect(!lines[1].contains("--data-binary"))
    }

    @Test("Shell quoting survives quotes, newlines and command characters")
    func shellQuoting() throws {
        let samples = [
            "plain", "it's", "''", "a\nb", "$(rm -rf /) `x` ; | & > <", "\\'\\", "🙂 ü", "",
            // A combining mark joins the quote before it into one Character.
            "it'\u{301}s; echo injected; '\u{301}",
        ]
        for sample in samples {
            let quoted = NetworkEntry.shellQuoted(sample)
            #expect(quoted.hasPrefix("'") && quoted.hasSuffix("'"))
            // Each quote in the text becomes '\'' (three quotes), between the two outer ones.
            let quotes = { (text: String) in text.unicodeScalars.filter { $0 == "'" }.count }
            #expect(quotes(quoted) == 2 + 3 * quotes(sample))
            #if os(macOS)
            // Let a real shell read the argument back.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", "printf '%s' \(quoted)"]
            let pipe = Pipe()
            process.standardOutput = pipe
            try process.run()
            process.waitUntilExit()
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            #expect(String(decoding: output, as: UTF8.self) == sample)
            #endif
        }
    }

    // MARK: HAR

    private func harObject(_ entries: [NetworkEntry]) throws -> [String: Any] {
        let data = try HTTPArchive(entries: entries).jsonData()
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(root["log"] as? [String: Any])
    }

    @Test("The archive has the HAR 1.2 structure, oldest entry first")
    func harStructure() throws {
        let later = try entry("https://e.com/b", offset: 10)
        let earlier = try entry("https://e.com/a?q=a%20b&token=x", headers: ["Accept": "*/*"], responseHeaders: ["Content-Type": "text/plain"],
                                responseBody: Data("hello".utf8), configuration: .init(redaction: RedactionPolicy(allowedQueryParameters: ["q"])))
        let log = try harObject([later, earlier])
        #expect(log["version"] as? String == "1.2")
        let creator = try #require(log["creator"] as? [String: Any])
        #expect(creator["name"] as? String == "iOSDevelopmentTools")
        #expect(creator["version"] as? String == HTTPArchive.creatorVersion)

        let entries = try #require(log["entries"] as? [[String: Any]])
        #expect(entries.count == 2)
        let first = entries[0]
        #expect(first["startedDateTime"] as? String == "2025-10-09T08:53:20.000Z")
        #expect(first["time"] as? Double == 125)
        let request = try #require(first["request"] as? [String: Any])
        #expect(request["method"] as? String == "GET")
        #expect(request["url"] as? String == "https://e.com/a?q=a%20b&token=[REDACTED]")
        let query = try #require(request["queryString"] as? [[String: String]])
        #expect(query == [["name": "q", "value": "a b"], ["name": "token", "value": "[REDACTED]"]])
        #expect(request["headersSize"] as? Int == -1)
        let response = try #require(first["response"] as? [String: Any])
        #expect(response["status"] as? Int == 200)
        #expect(response["statusText"] as? String == "OK")
        let content = try #require(response["content"] as? [String: Any])
        #expect(content["text"] as? String == "hello")
        #expect(content["size"] as? Int == 5)
        #expect(content["mimeType"] as? String == "text/plain")
        let timings = try #require(first["timings"] as? [String: Double])
        #expect(timings["wait"] == 125)
        #expect(timings["send"] == 0 && timings["receive"] == 0)
        #expect(timings["dns"] == -1)
    }

    @Test("Binary, omitted and failed requests are described, not lost")
    func harBodies() throws {
        let image = try entry("https://e.com/img", responseHeaders: ["Content-Type": "image/png"], responseBody: Data([0x89, 0x50, 0xFF]))
        let binary = try entry("https://e.com/raw", responseHeaders: ["Content-Type": "image/png"], responseBody: Data([0x89, 0x50, 0xFF]),
                               configuration: .init(redaction: .disabled))
        let malformed = try entry("https://e.com/w", method: "POST", headers: ["Content-Type": "application/json"], body: Data("{bad".utf8))
        let failed = try entry("https://e.com/f", status: nil, error: URLError(.timedOut))
        let entries = try #require(try harObject([image, binary, malformed, failed])["entries"] as? [[String: Any]])

        let imageContent = try #require((entries[0]["response"] as? [String: Any])?["content"] as? [String: Any])
        #expect(imageContent["text"] as? String == "[body omitted: 3 bytes, image/png]")
        #expect((imageContent["comment"] as? String)?.hasPrefix("Omitted by redaction") == true)

        let binaryContent = try #require((entries[1]["response"] as? [String: Any])?["content"] as? [String: Any])
        #expect(binaryContent["encoding"] as? String == "base64")
        #expect(binaryContent["text"] as? String == Data([0x89, 0x50, 0xFF]).base64EncodedString())

        let postData = try #require((entries[2]["request"] as? [String: Any])?["postData"] as? [String: Any])
        #expect(postData["text"] as? String == "[body omitted: 4 bytes, application/json]")
        #expect((postData["comment"] as? String)?.hasPrefix("Omitted by redaction") == true)

        let failedResponse = try #require(entries[3]["response"] as? [String: Any])
        #expect(failedResponse["status"] as? Int == 0)
        #expect(failedResponse["bodySize"] as? Int == -1)
        #expect((entries[3]["comment"] as? String)?.contains("NSURLErrorDomain -1001") == true)
    }

    @Test("Metrics timings are used when present, and their sum is the total time")
    func harTimings() throws {
        var timed = try entry("https://e.com/t")
        timed.timings = .init(domainLookup: 0.010, connect: 0.020, secureConnection: 0.015, send: 0.001, wait: 0.050, receive: 0.004)
        timed.networkProtocol = "h2"
        let first = try #require((try harObject([timed])["entries"] as? [[String: Any]])?.first)
        let timings = try #require(first["timings"] as? [String: Double])
        #expect(timings == ["blocked": -1, "dns": 10, "connect": 20, "ssl": 15, "send": 1, "wait": 50, "receive": 4])
        #expect(first["time"] as? Double == 85)
        #expect((first["request"] as? [String: Any])?["httpVersion"] as? String == "HTTP/2")
    }

    @Test("Milliseconds are finite and never negative", arguments: [
        (nil, nil), (Double.nan, nil), (Double.infinity, nil), (-Double.infinity, nil),
        (-1.0, 0.0), (0.0123456, 12.346), (1e12, 1e15),
    ] as [(Double?, Double?)])
    func milliseconds(seconds: Double?, expected: Double?) {
        #expect(HTTPArchive.milliseconds(seconds) == expected)
    }

    @Test("Status codes get their reason phrase", arguments: [(200, "OK"), (404, "Not Found"), (599, ""), (-1, "")])
    func reasonPhrases(status: Int, expected: String) {
        #expect(HTTPArchive.reasonPhrase(status) == expected)
    }

    @Test("Protocol names become HAR versions", arguments: [
        ("h2", "HTTP/2"), ("H3", "HTTP/3"), ("http/1.1", "HTTP/1.1"), ("spdy/3.1", "SPDY/3.1"),
    ])
    func httpVersions(name: String, expected: String) {
        #expect(HTTPArchive.httpVersion(name) == expected)
    }

    @Test("Query parsing copes with odd queries")
    func queryParsing() {
        #expect(HTTPArchive.queryItems(in: "https://e.com/").isEmpty)
        #expect(HTTPArchive.queryItems(in: "https://e.com/?#a=b").isEmpty)
        let items = HTTPArchive.queryItems(in: "https://e.com/?a&b=&=c&d=%ZZ&e=1+2#frag=x")
        #expect(items.map(\.name) == ["a", "b", "", "d", "e"])
        #expect(items.map(\.value) == ["", "", "c", "%ZZ", "1 2"])
    }
}
