import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Rule B4 of the shared redaction specification: a multipart part header name is a key of the
/// part. Besides the disposition and the content type, which are written again, only
/// `Content-Length`, `Content-Transfer-Encoding`, `Content-ID`, `Content-Description`,
/// `Content-Language`, `Content-Location` and `Content-Encoding` are written by name, and only the
/// first two with their value. ``RedactionPolicy/allowedHeaders`` is the allowlist of request and
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
        #expect(output == Self.body("content-id: [REDACTED]\r\nCONTENT-LENGTH: 2\r\ncontent-transfer-encoding: 8BIT"))
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

    @Test("a kept value is read as free text", arguments: [
        ("Content-Length: password=hunter2", "Content-Length: password=[REDACTED]"),
        ("Content-Length: Bearer hunter2hunter2", "Content-Length: Bearer [REDACTED]"),
        ("Content-Length: 4111 1111 1111 1111", "Content-Length: [REDACTED]"),
    ])
    func keptValueAsText(header: String, expected: String) {
        let output = Self.redacted(header)
        #expect(output == Self.body(expected))
        #expect(!output.contains("hunter2") && !output.contains("4111"))
    }
}
