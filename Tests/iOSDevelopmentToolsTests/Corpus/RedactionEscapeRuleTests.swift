import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Escapes in free text without a list of their forms: a backslash before anything but an ASCII
/// space, a tab, a line break or the end of the text, `%` and two hex digits, and `&` before a
/// letter or `#` cut the text where they start, on every path that reads free text. JSON escapes
/// are read by the JSON parser and are no escapes of free text.
@Suite("Redaction corpus: the escape rule of free text")
struct RedactionEscapeRuleTests {
    let redactor = Redactor()

    /// The inputs of the review that the list of backslash forms (an octal digit or one of
    /// `xuUNo`) and of references (`&` with a name and `;`, `&#` with a digit) let through
    /// unchanged on all six paths, with the text each is stored as in a log line.
    static let reviewInputs: [(input: String, line: String)] = [
        ("status dir\\data\\hunter2Zq ok", "status dir[REDACTED]"),
        ("status line1\\nhunter2Zq", "status line1[REDACTED]"),
        ("status a\\thunter2Zq", "status a[REDACTED]"),
        ("status He said \\\"hi\\\" hunter2Zq", "status He said [REDACTED]"),
        ("status a\\\\b hunter2Zq", "status a[REDACTED]"),
        ("status \\p{L} hunter2Zq", "status [REDACTED]"),
        ("status \\e8m hunter2Zq", "status [REDACTED]"),
        ("status \\8 hunter2Zq", "status [REDACTED]"),
        ("status \\cJ hunter2Zq", "status [REDACTED]"),
        ("status \\kx hunter2Zq", "status [REDACTED]"),
        ("status a\\/b hunter2Zq", "status a[REDACTED]"),
        ("status R&D hunter2Zq", "status R[REDACTED]"),
        ("status &amp hunter2Zq", "status [REDACTED]"),
        ("status &#x; hunter2Zq", "status [REDACTED]"),
        ("status &#q hunter2Zq", "status [REDACTED]"),
    ]

    /// Escapes that were cut before as well: the review's control group.
    static let controls: [(input: String, line: String)] = [
        ("status \\x41 hunter2Zq", "status [REDACTED]"),
        ("status %41 hunter2Zq", "status [REDACTED]"),
        ("status &lt; hunter2Zq", "status [REDACTED]"),
    ]

    @Test("the review's escapes cut the text where they start, on every path", arguments: reviewInputs + controls)
    func reviewEscapes(input: String, line: String) {
        #expect(redactor.redact(input) == line)
        for (path, output) in RedactionCutRuleTests.everyPath(input) {
            #expect(!output.contains("hunter2Zq"), "\(path): \(input.debugDescription) -> \(output.debugDescription)")
        }
    }

    @Test("a backslash cuts the text before any character but an ASCII space, a tab or a line break")
    func backslashBeforeEveryCharacter() {
        var followers = (0x21...0x7E).compactMap(Unicode.Scalar.init).map(String.init)
        // Characters outside ASCII, a mark and invisible ones, which the scanning copy leaves out
        // or reads as a space.
        followers += ["\u{E9}", "\u{0436}", "\u{540D}", "\u{0301}", "\u{200B}", "\u{00A0}", "\u{3000}", "\u{2028}", "\u{1F600}"]
        for follower in followers {
            let input = "status ok \\\(follower)rest hunter2Zq"
            #expect(redactor.redact(input) == "status ok [REDACTED]", "\(input.debugDescription)")
        }
    }

    @Test("a backslash before an ASCII space, a tab or a line break, or at the end of the text, is text", arguments: [
        "status a \\ b ok", "status ok\\", "status a\\\tb", "status a\\\nb", "status a\\\r\nb", "path=dir\\ ok",
    ])
    func backslashBeforeBlank(input: String) {
        #expect(redactor.redact(input) == input)
        #expect(redactor.redact(body: Data(input.utf8), contentType: "text/plain") == input)
    }

    @Test("`&` cuts the text before any letter or `#`, and is text before anything else")
    func ampersands() {
        for follower in Array("abcxyzABCXYZ#") + ["\u{0131}", "\u{00E9}", "\u{0436}"] {
            let input = "status a&\(follower)1 hunter2Zq"
            #expect(redactor.redact(input) == "status a[REDACTED]", "\(input.debugDescription)")
        }
        for input in ["Tom & Jerry", "a && b", "a&1", "a&;", "a&-b", "a&"] {
            #expect(redactor.redact(input) == input)
        }
    }

    @Test("`%` cuts the text before two hex digits, and is text before anything else")
    func percents() {
        for escape in ["%00", "%3D", "%3d", "%7e", "%FF", "%u003D"] {
            #expect(redactor.redact("status a\(escape)b hunter2Zq") == "status a[REDACTED]")
        }
        for input in ["100% done", "50%off", "%ZZ", "a %4", "%g1"] {
            #expect(redactor.redact(input) == input)
        }
    }

    @Test("generated escapes before a value hide it on every path", arguments: 0..<3)
    func generatedEscapes(seed: Int) {
        var random = SeededRandom(seed: 0x1A_E500 + UInt64(seed))
        let printable = (0x21...0x7E).compactMap(Unicode.Scalar.init).map(String.init)
        let letters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ#").map(String.init)
        let hex = Array("0123456789abcdefABCDEF").map(String.init)
        for _ in 0..<120 {
            let value = RedactionCorpusPropertyTests.value(using: &random)
            let escape: String
            switch Int.random(in: 0..<3, using: &random) {
            case 0: escape = "\\" + printable.randomElement(using: &random)!
            case 1: escape = "%" + hex.randomElement(using: &random)! + hex.randomElement(using: &random)!
            default: escape = "&" + letters.randomElement(using: &random)!
            }
            let prefix = ["", "status=200 ", "msg ", "path=/a "].randomElement(using: &random)!
            let glue = ["", "x", " "].randomElement(using: &random)!
            let text = prefix + glue + escape + ["", " ", "x "].randomElement(using: &random)! + value + [" done", "", "\nnext"].randomElement(using: &random)!
            for (path, output) in RedactionCutRuleTests.everyPath(text) {
                #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(path): \(text.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    // A JSON body and JSON written into a line are read by the JSON parser: their escapes are
    // decoded, and the strings are free text again.
    @Test("JSON escapes are decoded by the parser, not cut as escapes of free text")
    func jsonEscapes() {
        let body = #"{"note":"line1\nline2\tend","status":"\u0041BC"}"#
        let stored = redactor.redact(body: Data(body.utf8), contentType: "application/json")
        let parsed = try? JSONSerialization.jsonObject(with: Data(stored.utf8)) as? [String: String]
        #expect(parsed == ["note": "line1\nline2\tend", "status": "ABC"])
        for line in [#"log {"status":"a\nb"} done"#, #"log {"status":"say \"hi\""} done"#, #"log {"status":"tab\there"} done"#] {
            #expect(redactor.redact(line) == line)
        }
        // The decoded string is free text: a backslash in it is an escape.
        #expect(redactor.redact(#"log {"status":"dir\\x"} done"#) == #"log {"status":"dir[REDACTED]"} done"#)
    }

    // A JSON member name is no free text: its value is hidden by the key rule. A backslash escape
    // in it may stand for a separator in any form, so the name is cut at the backslash.
    @Test("a backslash escape in a JSON name cuts the name there, whatever its form", arguments: [
        #"{"pass\\x3dhunter2Zq":1}"#, #"{"pass\\075hunter2Zq":1}"#, #"{"pass\\u{3d}hunter2Zq":1}"#, #"{"pass\\N{EQUALS SIGN}hunter2Zq":1}"#,
    ])
    func backslashInNames(body: String) {
        let stored = redactor.redact(body: Data(body.utf8), contentType: "application/json")
        #expect(!stored.contains("hunter2Zq"), "\(stored)")
    }

    // A name read for secret words (a URL path segment, a name written as a value) with a
    // backslash escape in it cannot be read, so it counts as one that names a secret.
    @Test("a path segment with a backslash escape hides the segment after it")
    func backslashInPathSegments() throws {
        for segment in ["pa%5Cx%7B73%7Dsword", "pa%5Cu0073sword", "pa%5C163sword", "x%5Cqy"] {
            let url = try #require(URL(string: "https://h.example/v1/\(segment)/4831"))
            #expect(redactor.redact(url: url) == "https://h.example/v1/:id/:id")
        }
    }
}
