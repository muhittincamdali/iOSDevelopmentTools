import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The nesting budget: JSON objects and arrays open at once, counted across JSON written in
/// strings, and documents one inside another.
@Suite("Redaction corpus: nesting budget")
struct RedactionNestingTests {
    /// Documents are nested in the member `note`, which is allowed in text, so that free text reads
    /// on into the document in it instead of being cut at its value.
    let redactor = Redactor(allowedTextKeys: ["note"])

    private func redact(_ body: String, _ contentType: String = "application/json") -> String {
        redactor.redact(body: Data(body.utf8), contentType: contentType)
    }

    private static func brackets(_ count: Int, around inner: String = "") -> String {
        String(repeating: "[", count: count) + inner + String(repeating: "]", count: count)
    }

    /// `{"note":"…"}` with the text as the string, escaped.
    private static func noted(_ text: String) -> String {
        "{\"note\":\"" + RedactionStackTests.escaped(text) + "\"}"
    }

    private static func noted(_ text: String, times: Int) -> String {
        (0..<times).reduce(text) { inner, _ in noted(inner) }
    }

    @Test("the limits are 64 objects and arrays and four documents")
    func limits() {
        #expect(Nesting.maximumDepth == 64)
        #expect(Nesting.maximumLevel == 4)
    }

    @Test("reads a body 64 objects and arrays deep and omits one a level deeper")
    func bodyDepth() {
        let read = Self.brackets(64, around: "\"password=hunter2\"")
        #expect(redact(read) == Self.brackets(64, around: "\"password=[REDACTED]\""))
        let tooDeep = Self.brackets(65, around: "\"password=hunter2\"")
        #expect(redact(tooDeep) == "[body omitted: \(tooDeep.utf8.count) bytes, application/json]")
    }

    // The string is inside one object, so the JSON in it may open 63 more.
    @Test("a string holds JSON as deep as the depth left, and is hidden whole when it holds deeper JSON")
    func depthAcrossStrings() {
        let fits = Self.noted(Self.brackets(63, around: "\"status=ok\""))
        #expect(redact(fits) == fits)
        #expect(redactor.redact("log " + fits) == "log " + fits)
        let tooDeep = Self.noted(Self.brackets(64, around: "\"status=ok\""))
        #expect(redact(tooDeep) == #"{"note":"[REDACTED]"}"#)
        #expect(redactor.redact("log " + tooDeep) == #"log {"note":"[REDACTED]"}"#)
    }

    @Test("reads four documents one inside another and hides the string that holds a fifth")
    func documentLevels() {
        let innermost = #"{"status":"ok"}"#
        let four = Self.noted(innermost, times: 3)
        #expect(redact(four) == four)
        #expect(redactor.redact("log " + four) == "log " + four)
        let five = Self.noted(innermost, times: 4)
        let fifthHidden = Self.noted(#"{"note":"[REDACTED]"}"#, times: 3)
        #expect(redact(five) == fifthHidden)
        #expect(redactor.redact("log " + five) == "log " + fifthHidden)
    }

    @Test("a URL counts as a document")
    func urlLevel() {
        // A clean URL in text is read as `redact(url:)` reads it, as one more document.
        let url = "see https://example.com/users/12345678 ok"
        #expect(redact(Self.noted(url, times: 3)) == Self.noted("see https://example.com/users/:id ok", times: 3))
        #expect(redact(Self.noted(url, times: 4)) == Self.noted(#"{"note":"[REDACTED]"}"#, times: 3))
        // A URL with a query is not clean: it cuts the text where it starts, so a chain of URLs in
        // query values is never read one inside another.
        let allowed = Redactor(allowedQueryParameters: ["q"])
        let chain = String(repeating: "https://a.example/?q=", count: 5) + "x"
        #expect(allowed.redact(chain) == "[REDACTED]")
        #expect(allowed.redact("see " + String(repeating: "https://a.example/?q=", count: 2) + "x") == "see [REDACTED]")
    }

    @Test("a multipart part is a document inside the body")
    func multipartLevel() {
        let content = Self.noted(#"{"status":"ok"}"#, times: 3)
        let body = "--B\r\nContent-Disposition: form-data; name=\"a\"\r\nContent-Type: application/json\r\n\r\n\(content)\r\n--B--"
        let expected = "--B\r\nContent-Disposition: form-data; name=\"a\"\r\nContent-Type: application/json\r\n\r\n"
            + Self.noted(#"{"note":"[REDACTED]"}"#, times: 2) + "\r\n--B--"
        #expect(redact(body, "multipart/form-data; boundary=B") == expected)
    }

    @Test("the logging guide's examples of the limits")
    func guideExamples() {
        let deep = String(repeating: "[", count: 65) + String(repeating: "]", count: 65)
        #expect(redact(deep) == "[body omitted: 130 bytes, application/json]")
        let note = #"{"note":""# + String(repeating: "[", count: 64) + String(repeating: "]", count: 64) + #" ok"}"#
        #expect(redact(note) == #"{"note":"[REDACTED]"}"#)
    }

    @Test("JSON deeper than the limit in a log line hides the text from its first bracket")
    func deepJSONInFreeText() {
        let line = "note " + Self.brackets(65, around: "\"status=ok\"") + " status=200\nstatus=200"
        #expect(redactor.redact(line) == "note [REDACTED]")
    }
}
