import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Rule B4 of the shared redaction specification: a multipart part header name is a key of the
/// part. Besides the disposition and the content type, which are written again, only
/// `Content-Length`, `Content-Transfer-Encoding`, `Content-ID`, `Content-Description`,
/// `Content-Language`, `Content-Location` and `Content-Encoding` are written by name, and only the
/// first two with their value, written by its form and not read as free text: `Content-Length` as
/// ASCII digits, `Content-Transfer-Encoding` as one of five encodings in lowercase, and any other
/// value as `[REDACTED]`. ``RedactionPolicy/allowedHeaders`` is the allowlist of request and
/// response headers (B6) and does not apply to part headers.
@Suite("Redaction: multipart part headers (B4)")
struct RedactionPartHeaderTests {
    private static let contentType = "multipart/form-data; boundary=B0und"

    private static func body(_ headers: String) -> String {
        "--B0und\r\nContent-Disposition: form-data; name=\"note\"\r\n\(headers)\r\n\r\nok\r\n--B0und--"
    }

    private static func redacted(_ headers: String, with policy: RedactionPolicy = .default) -> String {
        String(decoding: policy.redact(body: Data(body(headers).utf8), contentType: contentType).body, as: UTF8.self)
    }

    /// The body written with `headers`, its content `ok` replaced by a note.
    private static func omittedContent(_ headers: String) -> String {
        "--B0und\r\nContent-Disposition: form-data; name=\"note\"\r\n\(headers)\r\n\r\n[body omitted: 2 bytes, text/plain]\r\n--B0und--"
    }

    // 2.1.0 wrote these with their values: it applied the request-header allowlist to part
    // headers.
    @Test("a header on the default request-header allowlist is hidden with its name in a part", arguments: [
        "User-Agent: hunter2", "ETag: \"hunter2\"", "Accept-Language: hunter2", "Cache-Control: max-age=hunter2",
        "Accept: hunter2", "Accept-Encoding: hunter2",
    ])
    func requestHeaderAllowlist(header: String) {
        #expect(Self.redacted(header) == Self.body("[REDACTED]: [REDACTED]"))
    }

    @Test("a name added to allowedHeaders is still hidden with its name in a part")
    func addedHeaderName() {
        let lenient = RedactionPolicy(allowedHeaders: RedactionPolicy.defaultAllowedHeaders + ["X-Note", "Content-ID"])
        let output = Self.redacted("X-Note: hunter2\r\nContent-ID: <hunter2>", with: lenient)
        #expect(output == Self.body("[REDACTED]: [REDACTED]\r\nContent-ID: [REDACTED]"))
    }

    @Test("the names of the part header list are written, their values hidden", arguments: [
        "Content-ID: <hunter2@example.com>", "Content-Description: hunter2", "Content-Language: hunter2",
        "Content-Location: https://example.com/hunter2", "Content-Encoding: gzip",
    ])
    func namedHeaders(header: String) throws {
        let name = try #require(header.split(separator: ":").first)
        #expect(Self.redacted(header) == Self.body("\(name): [REDACTED]"))
    }

    @Test("the names are matched in any letter case and written as sent")
    func letterCase() {
        let output = Self.redacted("content-id: hunter2\r\nCONTENT-LENGTH: 2\r\ncontent-transfer-encoding: 8BIT")
        #expect(output == Self.body("content-id: [REDACTED]\r\nCONTENT-LENGTH: 2\r\ncontent-transfer-encoding: 8bit"))
    }

    @Test("Content-Length and Content-Transfer-Encoding keep their value whatever allowedHeaders lists")
    func keptValues() {
        let headers = "Content-Length: 2\r\nContent-Transfer-Encoding: 8bit"
        #expect(Self.redacted(headers) == Self.body(headers))
        #expect(Self.redacted(headers, with: RedactionPolicy(allowedHeaders: [])) == Self.body(headers))
        let encoded = "Content-Transfer-Encoding: base64"
        let output = String(decoding: RedactionPolicy.default.redact(
            body: Data("--B0und\r\nContent-Disposition: form-data; name=\"note\"\r\n\(encoded)\r\n\r\naHVudGVyMg==\r\n--B0und--".utf8),
            contentType: Self.contentType).body, as: UTF8.self)
        #expect(output == "--B0und\r\nContent-Disposition: form-data; name=\"note\"\r\n\(encoded)\r\n\r\n[body omitted: 12 bytes, text/plain]\r\n--B0und--")
    }

    // 2.1.0 and the earlier commits of 2.1.1 read a kept value as free text, which keeps the text
    // before a finding and all of a value that holds no trigger: `pin-4831` was written as
    // `pin[REDACTED]`, and `12 hunter2` and a transfer encoding `hunter2` as they were sent.
    @Test("a Content-Length that is not ASCII digits is hidden whole", arguments: [
        ("Content-Length: pin-4831", "Content-Length: [REDACTED]"),
        ("Content-Length: 12 hunter2", "Content-Length: [REDACTED]"),
        ("Content-Length: ok hunter2", "Content-Length: [REDACTED]"),
        ("Content-Length: hunter2", "Content-Length: [REDACTED]"),
        ("Content-Length: 0x10 hunter2", "Content-Length: [REDACTED]"),
        ("Content-Length: 1e3 hunter2", "Content-Length: [REDACTED]"),
        ("Content-Length: -1 hunter2", "Content-Length: [REDACTED]"),
        ("content-length: 3 hunter2", "content-length: [REDACTED]"),
        ("Content-Length: 12abc", "Content-Length: [REDACTED]"),
        ("Content-Length: +12", "Content-Length: [REDACTED]"),
        ("Content-Length: 1 2", "Content-Length: [REDACTED]"),
        ("Content-Length: \u{0661}\u{0662}", "Content-Length: [REDACTED]"),
        ("Content-Length: \u{FF11}\u{FF12}", "Content-Length: [REDACTED]"),
        ("Content-Length: 12\u{00A0}", "Content-Length: [REDACTED]"),
        ("Content-Length: password=hunter2", "Content-Length: [REDACTED]"),
        ("Content-Length: Bearer hunter2hunter2", "Content-Length: [REDACTED]"),
        ("Content-Length: 4111 1111 1111 1111", "Content-Length: [REDACTED]"),
        ("Content-Length:", "Content-Length: [REDACTED]"),
    ])
    func lengthForm(header: String, expected: String) {
        #expect(Self.redacted(header) == Self.body(expected))
    }

    // Digits alone are the form of a length, but a card number written as one still is a card
    // number; the free-text rule used to hide it, so the value detectors still read the digits.
    @Test("a Content-Length that the value detectors read as a value is hidden whole")
    func lengthFinding() {
        #expect(Self.redacted("Content-Length: 4111111111111111") == Self.body("Content-Length: [REDACTED]"))
        #expect(Self.redacted("Content-Length: " + String(repeating: "1", count: 32)) == Self.body("Content-Length: [REDACTED]"))
    }

    @Test("a Content-Length of ASCII digits is written without the white space around it", arguments: [
        ("Content-Length: 12", "Content-Length: 12"), ("Content-Length:   12 \t", "Content-Length: 12"),
        ("Content-Length:\t007", "Content-Length: 007"), ("Content-Length: 0", "Content-Length: 0"),
    ])
    func lengthKept(header: String, expected: String) {
        #expect(Self.redacted(header) == Self.body(expected))
    }

    @Test("a Content-Transfer-Encoding is written in lowercase when it is one of the five encodings", arguments: [
        ("Content-Transfer-Encoding: 7BIT", "Content-Transfer-Encoding: 7bit", true),
        ("Content-Transfer-Encoding: 8Bit", "Content-Transfer-Encoding: 8bit", true),
        ("Content-Transfer-Encoding: \tBinary ", "Content-Transfer-Encoding: binary", true),
        ("Content-Transfer-Encoding: BASE64", "Content-Transfer-Encoding: base64", false),
        ("Content-Transfer-Encoding: Quoted-Printable", "Content-Transfer-Encoding: quoted-printable", false),
    ])
    func transferEncodingKept(header: String, expected: String, readsContent: Bool) {
        #expect(Self.redacted(header) == (readsContent ? Self.body(expected) : Self.omittedContent(expected)))
    }

    // A value the header does not take hides the content too: the reading of the header decides
    // both, so a server that reads `8bit` after the space outside ASCII cannot see content this
    // package did not read.
    @Test("any other Content-Transfer-Encoding is hidden whole, and so is the content", arguments: [
        "hunter2", "7bit hunter2", "x-tok3n", "base64; hunter2", "quoted-printable hunter2", "8b\u{0131}t",
        "8bit\u{00A0}", "\u{FF18}bit", "password=hunter2", "",
    ])
    func transferEncodingForm(value: String) {
        let output = Self.redacted("Content-Transfer-Encoding: " + value)
        #expect(output == Self.omittedContent("Content-Transfer-Encoding: [REDACTED]"))
    }
}
