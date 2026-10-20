import Foundation
import Testing
@testable import iOSDevelopmentTools

/// JSON read with the parser, as a body, as a whole text and inside a log line. Redacted JSON is
/// still JSON.
@Suite("Redaction corpus: JSON")
struct RedactionJSONTests {
    let redactor = Redactor()
    /// In free text a JSON member keeps its value only under an allowed key: the keys of these
    /// documents are allowed, so a text holds what a body holds.
    static let textKeys = [
        "a", "b", "c", "note", "user", "amount", "n", "id", "user name", "user.id", "user-role", "headers", "name", "value", "msg",
        "wrapper",
    ]
    let textRedactor = Redactor(allowedTextKeys: textKeys)

    static let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

    /// Documents where a detector finds something inside a hidden value or in a number. In 2.0.0
    /// the hidden value lost its quotes (`{"credentials":[REDACTED]}`) and numbers became
    /// masks (`{"amount":[REDACTED]}`).
    static let documents: [(String, String)] = [
        (#"{"credentials":{"email":"alice@example.com"}}"#, #"{"credentials":"[REDACTED]"}"#),
        (#"{"otp":[4111111111111111]}"#, #"{"otp":"[REDACTED]"}"#),
        (#"{"password":["\#(jwt)"]}"#, #"{"password":"[REDACTED]"}"#),
        (#"{"pin":{"x":"0123456789abcdef0123456789abcdef"}}"#, #"{"pin":"[REDACTED]"}"#),
        (#"{"amount":4111111111111111}"#, #"{"amount":"[REDACTED]"}"#),
        (#"{"a":-4111111111111111}"#, #"{"a":"-[REDACTED]"}"#),
        (#"{"n":12345678901234567890123456789012345}"#, #"{"n":"[REDACTED]"}"#),
        (#"{"note":"paid 4111 1111 1111 1111","user":"bob"}"#, #"{"note":"paid [REDACTED]","user":"bob"}"#),
        (#"[{"token":"\#(jwt)"},{"id":7}]"#, #"[{"token":"[REDACTED]"},{"id":7}]"#),
        (#"{"a":{"b":[{"api_key":true}]},"c":null}"#, #"{"a":{"b":[{"api_key":"[REDACTED]"}]},"c":null}"#),
    ]

    @Test("hidden values and masked numbers keep a body valid JSON", arguments: documents)
    func bodiesStayJSON(input: String, expected: String) throws {
        let output = redactor.redact(body: Data(input.utf8), contentType: "application/json")
        #expect(output == expected)
        #expect(try JSONSerialization.jsonObject(with: Data(output.utf8), options: .fragmentsAllowed) is NSObject)
    }

    @Test("a text that is JSON stays valid JSON too", arguments: documents)
    func textStaysJSON(input: String, expected: String) throws {
        let output = textRedactor.redact(input)
        #expect(output == expected)
        #expect(try JSONSerialization.jsonObject(with: Data(output.utf8), options: .fragmentsAllowed) is NSObject)
    }

    @Test("JSON inside a line stays valid JSON", arguments: documents)
    func embeddedStaysJSON(input: String, expected: String) throws {
        let output = textRedactor.redact("response \(input) done")
        #expect(output == "response \(expected) done")
    }

    @Test("names are compared at every depth, after their escapes are decoded, for every repetition")
    func names() {
        #expect(textRedactor.redact(#"{"pass\u0077ord":"x","user":"bob"}"#) == #"{"pass\u0077ord":"[REDACTED]","user":"bob"}"#)
        #expect(textRedactor.redact(#"{"a":{"b":{"c":{"token":"x"}}}}"#) == #"{"a":{"b":{"c":{"token":"[REDACTED]"}}}}"#)
        #expect(textRedactor.redact(#"{"password":"a","password":"b"}"#) == #"{"password":"[REDACTED]","password":"[REDACTED]"}"#)
        #expect(textRedactor.redact(#"{"p\u0430ssword":"x"}"#) == #"{"p\u0430ssword":"[REDACTED]"}"#)
        #expect(textRedactor.redact("{\"p\u{0430}ssword\":\"x\"}") == "{\"p\u{0430}ssword\":\"[REDACTED]\"}")
        #expect(textRedactor.redact(#"{"user name":"bob","user.id":7,"user-role":"admin"}"#) == #"{"user name":"bob","user.id":7,"user-role":"admin"}"#)
        #expect(textRedactor.redact(#"{"user[name]":"bob","café":"x"}"#) == #"{"user[name]":"[REDACTED]","café":"[REDACTED]"}"#)
    }

    @Test("a pair written as an array or as a name and value object hides its value", arguments: [
        (#"req {"headers":[["X-Api-Key","k125"]]}"#, #"req {"headers":[["X-Api-Key","[REDACTED]"]]}"#),
        (#"login ["password","e11"]"#, #"login ["password","[REDACTED]"]"#),
        (#"["user","bob","token","abc","next"]"#, #"["user","bob","token","[REDACTED]","[REDACTED]"]"#),
        (#"[{"name":"Authorization","value":"Basic x"},{"name":"Accept","value":"*/*"}]"#,
         #"[{"name":"Authorization","value":"[REDACTED]"},{"name":"Accept","value":"*/*"}]"#),
        ("{\"key\":\"p\u{0430}ss\",\"value\":\"x\"}", "{\"key\":\"[REDACTED]\",\"value\":\"[REDACTED]\"}"),
        ("{\"key\":\"p\u{0430}ss word\",\"value\":\"x\"}", "{\"key\":\"[REDACTED]\",\"value\":\"[REDACTED]\"}"),
    ])
    func pairs(input: String, expected: String) {
        #expect(textRedactor.redact(input) == expected)
    }

    @Test("JSON in a line is parsed with the parser; a key before it hides it whole", arguments: [
        (#"headers=[["X-Api-Key","k123"]]"#, #"headers=[["X-Api-Key","[REDACTED]"]]"#),
        (#"heads=[["X-Api-Key","k123"]]"#, "heads=[REDACTED]"),
        (#"data={"user":"bob"} status=1"#, "data=[REDACTED] status=1"),
        (#"got {"user":"bob","password":"x"} and [{"pin":1}]"#, #"got {"user":"bob","password":"[REDACTED]"} and [{"pin":"[REDACTED]"}]"#),
        ("log {\n  \"token\": \"abc\",\n  \"user\": \"bob\"\n} status=1", "log {\n  \"token\": \"[REDACTED]\",\n  \"user\": \"bob\"\n} status=1"),
        (#"{"wrapper":"{\"password\":\"x\"}"}"#, #"{"wrapper":"{\"password\":\"[REDACTED]\"}"}"#),
        (#"{"msg":"label=bob status=1"}"#, #"{"msg":"label=[REDACTED]"}"#),
    ])
    func embedded(input: String, expected: String) {
        #expect(textRedactor.redact(input) == expected)
    }

    @Test("JSON that does not parse hides the rest of the line, and on until its brackets close", arguments: [
        (#"login {"pass" "word":"e8"}"#, "login [REDACTED]"),
        (#"login {"pass" "word":"e8"} next"#, "login [REDACTED]"),
        ("x {\"a\":1,\n\"password\" \"e9\"}\nstatus=1", "x [REDACTED]\nstatus=1"),
        ("x {\"a\":1,\n\"password\":\"e9\"}\nstatus=1", "x {\"a\":1,\n\"password\":\"[REDACTED]\"}\nstatus=1"),
        ("x {\"a\":1,\n\"password\":\"e9\"", "x [REDACTED]"),
        (#"x ["a" "b"] y"#, "x [REDACTED]"),
        (#"x {"a":1,} y"#, "x [REDACTED]"),
        (#"x {"a":"\ud800"} y"#, "x [REDACTED]"),
    ])
    func unparsed(input: String, expected: String) {
        #expect(textRedactor.redact(input) == expected)
    }

    @Test("in a line, a JSON member keeps its value only under an allowed key")
    func membersOfJSONInText() {
        #expect(redactor.redact(#"log {"user":"bob","status":200,"list":[1]}"#) == #"log {"user":"[REDACTED]","status":200,"list":"[REDACTED]"}"#)
        #expect(redactor.redact(body: Data(#"{"user":"bob","status":200}"#.utf8), contentType: "application/json") == #"{"user":"bob","status":200}"#)
    }

    @Test("brackets that do not open JSON are text", arguments: ["[INFO] ok", "[1/3] done", "{x} done", "user[0] ok", "[] {} ok"])
    func notJSON(input: String) {
        #expect(redactor.redact(input) == input)
    }
}
