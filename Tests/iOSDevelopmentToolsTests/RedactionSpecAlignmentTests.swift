import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The places where 2.1.0 followed an earlier generation of the shared redaction specification
/// (REDACTION-SPEC 2.1-r2, §0.5 UN-4 to UN-8 and §9.2 G1 to G2), each with an input that showed
/// more than the specification allows or read the input otherwise. 2.1.1 follows §1 to §7.
@Suite("Redaction spec alignment: the 2.1.0 deviations")
struct RedactionSpecAlignmentTests {
    let policy = RedactionPolicy.default

    func body(_ text: String, _ type: String = "application/json") -> String {
        String(decoding: policy.redact(body: Data(text.utf8), contentType: type).body, as: UTF8.self)
    }

    @Test("C11 (UN-6b): white space outside ASCII and the line breaks VT, FF, NEL, LS and PS cut the text", arguments: [
        ("ok\u{00A0}status=1\u{00A0}x=hunter2", "ok[REDACTED]"),
        ("login\u{00A0}password\u{00A0}hunter2", "login[REDACTED]"),
        ("ok\u{3000}x=hunter2", "ok[REDACTED]"),
        ("a\u{2009}b x=1", "a[REDACTED]"),
        ("status=200\u{0C}ok", "status=200[REDACTED]"),
        ("status=200\u{85}ok", "status=200[REDACTED]"),
        ("status=200\u{2029}ok", "status=200[REDACTED]"),
        ("Bearer\u{2028}abcdefgh12345678", "Bearer[REDACTED]"),
    ])
    func whiteSpaceOutsideASCII(input: String, expected: String) {
        #expect(policy.redact(text: input) == expected)
    }

    @Test("C2 (UN-6b): a word that mixes scripts with no separator after it cuts at its start")
    func mixedScripts() {
        #expect(policy.redact(text: "120\u{00B5}s elapsed") == "[REDACTED]")
    }

    @Test("C7 (UN-6a): a backslash cuts at the start of its word, so no letter of the word shows")
    func backslashAtWordStart() {
        #expect(policy.redact(text: "login pa\\x{73}sword hunter2") == "login [REDACTED]")
        #expect(policy.redact(text: "s\\\u{0300}t") == "[REDACTED]")
    }

    @Test("C4, C8, C10, C12 and U1 (UN-6c): cuts at the place the specification gives", arguments: [
        ("x\"status\": 200", "[REDACTED]"),
        (#"{"status":200,"user":"bob"} done"#, #"{"status":200,[REDACTED]"#),
        ("status=200&count=3", "status=200&count=3"),
        ("R&D team", "[REDACTED]"),
        ("field name=\"password\" hunter2", "field name=[REDACTED]"),
        ("say (hello", "say ([REDACTED]"),
        ("line 42:10: error", "line 42:10: [REDACTED]"),
    ])
    func cutPlaces(input: String, expected: String) {
        #expect(policy.redact(text: input) == expected)
    }

    @Test("K11 (UN-8, G4): a string of only control characters and spaces names a secret beside any field", arguments: [
        #"{"ParameterKey":"\t","ParameterValue":"x"}"#, #"{"title":"\t","data":"x"}"#, #"{"title":" \n ","data":"x"}"#,
        #"{"title":"\u0000","data":"x"}"#,
    ])
    func onlyControlCharacters(input: String) {
        #expect(!body(input).contains(#""x""#))
    }

    @Test("K11 (UN-8, G4): the same in a form")
    func onlyControlCharactersInForm() {
        #expect(body("ParameterKey=%0A&ParameterValue=x", "application/x-www-form-urlencoded") == "ParameterKey=[REDACTED]&ParameterValue=[REDACTED]")
    }

    @Test("K10 (UN-7, G5): a name outside ASCII in a field that holds names is no record value")
    func noRecordValue() {
        #expect(body(#"{"id":42,"name":"Ayşe Yılmaz","price":12.5}"#) == #"{"id":"[REDACTED]","name":"Ayşe Yılmaz","price":"[REDACTED]"}"#)
        #expect(body(#"{"name":"Şifre","x":"hunter2"}"#) == #"{"name":"Şifre","x":"[REDACTED]"}"#)
    }

    @Test("U5 (UN-4, G2): an escaped `/`, `\\` or `%` in the path keeps only the scheme and host", arguments: [
        "https://example.com/a%2Fb/c", "https://example.com/pin%2F4831/x", "https://example.com/a%25/x", "https://example.com/a%5Cb/x",
        "https://example.com/a%2fb/c", "https://example.com/a%5cb/x",
    ])
    func escapedSeparators(input: String) throws {
        #expect(policy.redact(url: try #require(URL(string: input))) == "https://example.com")
        #expect(policy.redactedPath(of: try #require(URL(string: input))) == "")
    }

    @Test("U7 (UN-5): `:id` is no label, so a path that is already redacted reads the same again")
    func identifierIsNoLabel() throws {
        let url = try #require(URL(string: "https://example.com/users/:id/x"))
        #expect(policy.redact(url: url) == "https://example.com/users/:id/x")
    }

    @Test("U4 (G1): a host that names a secret is not written, also as the request's host")
    func secretHost() throws {
        for text in ["myapp://password.hunter2", "myapp://pin-4831", "https://pin-4831.example.com/a", "myapp://pin/4831"] {
            let url = try #require(URL(string: text))
            #expect(!policy.redact(url: url).contains("4831") && !policy.redact(url: url).contains("hunter2"))
            #expect(policy.redactedHost(of: url) == RedactionPolicy.replacement)
            #expect(policy.redactedPath(of: url) == "")
        }
    }

    @Test("U1 (UN-6c): a URL without a host is unparsed")
    func unparsedURL() throws {
        #expect(policy.redact(url: try #require(URL(string: "mailto:ada@example.com"))) == RedactionPolicy.unparsedURL)
    }
}
