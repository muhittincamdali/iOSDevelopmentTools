import Foundation
import Testing
@testable import iOSDevelopmentTools

/// One table of readings serves a whole input: every field of a form, every part of a multipart
/// body, the host, segments and parameters of a URL and every header of a list (spec §7 L9). A
/// scalar outside ASCII is worked out once for the input, however many fields hold it.
@Suite("Redaction corpus: one table of readings per input")
struct RedactionCompatibilityTableTests {
    /// A table of the largest size, in which two scalars never take each other's slot: each slot
    /// holds two readings.
    static func table() -> CompatibilityText { CompatibilityText(length: CompatibilityText.mostSlots) }

    @Test("a form, a multipart body, a URL and a header read with one table")
    func oneTablePerInput() throws {
        let policy = RedactionPolicy.default
        let form = String(repeating: "note=caf%C3%A9&", count: 50) + "x=%C3%A9"
        let formTable = Self.table()
        let type = try #require(MediaType("application/x-www-form-urlencoded"))
        _ = policy.redact(body: Data(form.utf8), as: type, nesting: .document(length: form.utf8.count), compatibility: formTable)
        #expect(formTable.uncachedReadings == 1)

        let part = "--B\r\nContent-Disposition: form-data; name=\"note\"\r\nContent-Language: fr\r\n\r\ncafé\r\n"
        let multipart = String(repeating: part, count: 20) + "--B--\r\n"
        let multipartTable = Self.table()
        let multipartType = try #require(MediaType("multipart/form-data; boundary=B"))
        _ = policy.redact(body: Data(multipart.utf8), as: multipartType, nesting: .document(length: multipart.utf8.count), compatibility: multipartTable)
        #expect(multipartTable.uncachedReadings == 1)

        let url = "https://x.example/caf%C3%A9/men%C3%BC/caf%C3%A9-x/m%C3%BCnchen?q=%C3%A9&r=%C3%BC"
        let urlTable = Self.table()
        _ = RedactionPolicy(allowedQueryParameters: ["q", "r"]).redactedURL(url, nesting: .document(length: url.utf8.count), compatibility: urlTable)
        #expect(urlTable.uncachedReadings == 2)

        let headerTable = Self.table()
        for value in ["text/html; charset=utf-8 é", "MyApp/1.0 é ü", "ü"] {
            _ = policy.redactedHeaderValue(name: "User-Agent", value: value, compatibility: headerTable)
        }
        #expect(headerTable.uncachedReadings == 2)
    }
}
