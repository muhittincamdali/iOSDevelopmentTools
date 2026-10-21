import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Section 6 of the redaction spec: the detectors read VT, FF, U+0085, U+2028 and U+2029 as nothing
/// inside an email address. The nineteenth review found that an address with such a separator right
/// after it, followed by a letter, a digit or `-` (`alice.smith@example.com`, a vertical tab and
/// `ok`), or with one inside or right before its top-level domain (`example.c`, a vertical tab and
/// `om`), was not found at all: the domain ran across the separator and its top-level domain held
/// it, so it was no top-level domain. The cut that the separator makes in free text kept the address
/// before it, in free text, log lines, JSON strings, forms, multipart parts, the `User-Agent` header,
/// allowed query values and the network log with its cURL command and HTTP archive.
@Suite("Redaction corpus: line separators after and inside the domain of an email address")
struct RedactionEmailLineBreakTests {
    static let separators = RedactionBridgedLineBreakTests.separators
    static let name = "alice.smith"

    /// Addresses with `{S}` where a separator is written, and the text after them.
    static let templates = [
        "alice.smith@example.com{S}ok", "alice.smith@example.com{S}1", "alice.smith@example.com{S}-x", "alice.smith@example.co.uk{S}x",
        "alice.smith@例子.中国{S}x", "alice.smith@example.com.{S}ok", "alice.smith@example.{S}com ok", "alice.smith@example.c{S}om",
        "alice.smith@example.com{S}1{S}x", "alice.smith@example.com{S}ok-1",
    ]

    static var cases: [(String, String)] {
        separators.flatMap { separator in templates.map { ($0, separator) } }
    }

    static func written(_ template: String, _ separator: String) -> String {
        template.replacingOccurrences(of: "{S}", with: separator)
    }

    /// Every place free text is read, an allowed query value and the network log among them.
    static func places(_ line: String) throws -> [(String, String)] {
        var outputs = RedactionBridgedLineBreakTests.places(line).map { ($0.0, $0.1) }
        let query = try #require(URL(string: "https://x.example/a?q=" + RedactionPolicy.formEncoded(line)))
        outputs.append(("query value", Redactor(allowedQueryParameters: ["q"]).redact(url: query)))
        let escaped = line.unicodeScalars.map { $0.value < 0x20 || $0.value == 0x85 ? String(format: "\\u%04x", $0.value) : String($0) }.joined()
        let nested = Redactor().redact(body: Data("{\"a\":[{\"b\":{\"note\":\"\(escaped)\"}}]}".utf8), contentType: "application/json")
        outputs.append(("nested JSON", nested))
        var request = URLRequest(url: query)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("MyApp/1.0 " + line, forHTTPHeaderField: "User-Agent")
        request.httpBody = Data("{\"note\":\"\(escaped)\"}".utf8)
        let logger = NetworkLogger(configuration: .init(redaction: RedactionPolicy(allowedHeaders: ["User-Agent"], allowedQueryParameters: ["q"])))
        let id = try #require(logger.record(request: request, response: nil, body: nil, startDate: Date()))
        let entry = try #require(logger.entry(id: id))
        outputs.append(("network entry", entry.url + " " + (entry.requestBody?.text ?? "") + " " + entry.requestHeaders.map(\.value).joined(separator: " ")))
        outputs.append(("cURL", entry.curlCommand()))
        outputs.append(("HAR", String(decoding: try HTTPArchive(entries: [entry]).jsonData(), as: UTF8.self)))
        return outputs
    }

    @Test("the address is hidden from its start in free text, a plain-text body and a log line", arguments: cases)
    func hiddenFromStart(template: String, separator: String) {
        let line = "mail " + Self.written(template, separator)
        #expect(Redactor().redact(line).hasPrefix("mail [REDACTED]"), "\(line.debugDescription) -> \(Redactor().redact(line).debugDescription)")
        #expect(!Redactor().redact(body: Data(line.utf8), contentType: "text/plain").contains(Self.name), "\(line.debugDescription)")
        #expect(!LogStore.redacted(line, with: .default).contains(Self.name), "\(line.debugDescription)")
    }

    @Test("no part of the address shows in any place free text is read", arguments: cases)
    func noPartShows(template: String, separator: String) throws {
        let line = "mail " + Self.written(template, separator) + " end"
        for (place, output) in try Self.places(line) where !output.hasPrefix("[body omitted") {
            #expect(!output.contains(Self.name) && !output.contains("@example"), "\(place): \(line.debugDescription) -> \(output.debugDescription)")
        }
    }

    // The finding is the address as far as its top-level domain reaches: across the separator
    // when letters go on after it, and up to the separator when a digit or `-` does.
    @Test("the finding ends where the top-level domain ends", arguments: separators)
    func findingEnds(separator: String) {
        for (text, expected) in [
            ("x alice.smith@example.com\(separator)1 y", "alice.smith@example.com"),
            ("x alice.smith@example.com\(separator)-x y", "alice.smith@example.com"),
            ("x alice.smith@example.com.\(separator)1 y", "alice.smith@example.com"),
            ("x alice.smith@example.com\(separator)ok y", "alice.smith@example.com\(separator)ok"),
            ("x alice.smith@example.c\(separator)om y", "alice.smith@example.c\(separator)om"),
            ("x alice.smith@example.\(separator)com y", "alice.smith@example.\(separator)com"),
            ("x alice.smith@example.com\(separator)ok\(separator)1 y", "alice.smith@example.com\(separator)ok"),
        ] {
            let scalars = Array(text.unicodeScalars)
            let found = NormalizedText(scalars, compatibility: CompatibilityText(length: scalars.count)).emailSpans()
            #expect(found.map { String(String.UnicodeScalarView(scalars[$0.start..<$0.end])) } == [expected], "\(text.debugDescription)")
        }
    }

    @Test("a domain without a top-level domain on either side of the separator is no address", arguments: separators)
    func noTopLevelDomain(separator: String) {
        for text in ["x a@example.c\(separator)1 y", "x a@example\(separator)1 y", "x a@example\(separator)com y", "x a@.\(separator)com y"] {
            let scalars = Array(text.unicodeScalars)
            #expect(NormalizedText(scalars, compatibility: CompatibilityText(length: scalars.count)).emailSpans().isEmpty, "\(text.debugDescription)")
        }
    }

    @Test("a long run of separators and digits after an address is read in linear time")
    func longRun() {
        let tail = String(repeating: "\u{0B}1", count: 200_000)
        let scalars = Array(("alice.smith@example.com" + tail).unicodeScalars)
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            let found = NormalizedText(scalars, compatibility: CompatibilityText(length: scalars.count)).emailSpans()
            #expect(found.map { $0.end } == [23])
        }
        #expect(elapsed < .seconds(5))
    }
}
