import Foundation
import Testing
@testable import iOSDevelopmentTools

/// JSON read with the parser, as a body, as a whole text and inside a log line. Redacted JSON is
/// still JSON.
@Suite("Redaction corpus: JSON")
struct RedactionJSONTests {
    let redactor = Redactor()

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

    /// The same documents in free text: the text is cut at the opening quote of the first member
    /// name that is not on the allowlist of keys in text, so the name does not show either.
    static let textCuts: [(String, String)] = [
        (#"{"credentials":{"email":"alice@example.com"}}"#, #"{[REDACTED]"#),
        (#"{"otp":[4111111111111111]}"#, #"{[REDACTED]"#),
        (#"{"password":["\#(jwt)"]}"#, #"{[REDACTED]"#),
        (#"{"amount":4111111111111111}"#, #"{[REDACTED]"#),
        (#"{"note":"paid 4111 1111 1111 1111","user":"bob"}"#, #"{[REDACTED]"#),
        (#"[{"token":"\#(jwt)"},{"id":7}]"#, #"[{[REDACTED]"#),
        (#"{"a":{"b":[{"api_key":true}]},"c":null}"#, #"{[REDACTED]"#),
        (#"{"status":200,"count":3}"#, #"{"status":200,"count":3}"#),
        (#"[{"status":200},{"count":2}]"#, #"[{"status":200},{"count":2}]"#),
    ]

    @Test("a text that is JSON is cut at its first member that is not allowed", arguments: textCuts)
    func textCutsJSON(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("JSON inside a line cuts the line at the same place", arguments: textCuts)
    func embeddedCutsJSON(input: String, expected: String) {
        let kept = expected == input
        #expect(redactor.redact("response \(input) done") == "response \(expected)" + (kept ? " done" : ""))
    }

    @Test("names are compared at every depth, after their escapes are decoded, for every repetition")
    func names() {
        func body(_ json: String) -> String { redactor.redact(body: Data(json.utf8), contentType: "application/json") }
        #expect(body(#"{"password":"x","user":"bob"}"#) == #"{"password":"[REDACTED]","user":"bob"}"#)
        #expect(body(#"{"a":{"b":{"c":{"token":"x"}}}}"#) == #"{"a":{"b":{"c":{"token":"[REDACTED]"}}}}"#)
        #expect(body(#"{"password":"a","password":"b"}"#) == #"{"password":"[REDACTED]","password":"[REDACTED]"}"#)
        #expect(body(#"{"pаssword":"x"}"#) == #"{"pаssword":"[REDACTED]"}"#)
        #expect(body("{\"p\u{0430}ssword\":\"x\"}") == "{\"p\u{0430}ssword\":\"[REDACTED]\"}")
        #expect(body(#"{"user name":"bob","user.id":7,"user-role":"admin"}"#) == #"{"user name":"bob","user.id":7,"user-role":"admin"}"#)
        #expect(body(#"{"user[name]":"bob","café":"x"}"#) == #"{"user[name]":"[REDACTED]","café":"[REDACTED]"}"#)
    }

    @Test("a pair written as an array or as a name and value object hides its value", arguments: [
        (#"{"headers":[["X-Api-Key","k125"]]}"#, #"{"headers":[["X-Api-Key","[REDACTED]"]]}"#),
        (#"["password","e11"]"#, #"["password","[REDACTED]"]"#),
        (#"["user","bob","token","abc","next"]"#, #"["user","bob","token","[REDACTED]","[REDACTED]"]"#),
        (#"[{"name":"Authorization","value":"Basic x"},{"name":"Accept","value":"*/*"}]"#,
         #"[{"name":"Authorization","value":"[REDACTED]"},{"name":"Accept","value":"*/*"}]"#),
        ("{\"key\":\"p\u{0430}ss\",\"value\":\"x\"}", "{\"key\":\"[REDACTED]\",\"value\":\"[REDACTED]\"}"),
        ("{\"key\":\"p\u{0430}ss word\",\"value\":\"x\"}", "{\"key\":\"[REDACTED]\",\"value\":\"[REDACTED]\"}"),
    ])
    func pairs(input: String, expected: String) {
        #expect(redactor.redact(body: Data(input.utf8), contentType: "application/json") == expected)
    }

    // In free text the first string of a two-element array is a key: one that is not allowed cuts
    // the line where it starts, as a member name that is not allowed does.
    @Test("a pair written as an array in a line cuts the line at its key", arguments: [
        (#"login ["password","e11"]"#, #"login [[REDACTED]"#),
        (#"["user","bob","token","abc","next"]"#, #"["user","bob","token",[REDACTED]"#),
        (#"got [["Authorization","Basic x"]] ok"#, #"got [[[REDACTED]"#),
        ("got [[\"\u{15E}ifre\",\"1234\"]] ok", "got [[[REDACTED]"),
        (#"got [["X-Custom","v"]] ok"#, #"got [[[REDACTED]"#),
        (#"log ["user","v"]"#, #"log [[REDACTED]"#),
        (#"log {"status":[["user","v"]]}"#, #"log {"status":[[[REDACTED]"#),
        (#"got [["status","200"],["count","3"]] ok"#, #"got [["status","200"],["count","3"]] ok"#),
    ])
    func pairsInText(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a pair in a line keeps its value when the app allows its key")
    func allowedPairsInText() {
        let allowing = Redactor(allowedTextKeys: ["X-Custom", "user"])
        #expect(allowing.redact(#"got [["X-Custom","v"],["user","bob"]] ok"#) == #"got [["X-Custom","v"],["user","bob"]] ok"#)
        #expect(allowing.redact(#"got [["X-Custom","v"],["Cookie","c"]] ok"#) == #"got [["X-Custom","v"],[[REDACTED]"#)
    }

    @Test("JSON in a line is parsed with the parser; a key before it hides it", arguments: [
        (#"headers=[["X-Api-Key","k123"]]"#, "headers=[REDACTED]"),
        (#"data={"user":"bob"} status=1"#, "data=[REDACTED]"),
        (#"got {"user":"bob","password":"x"} and [{"pin":1}]"#, #"got {[REDACTED]"#),
        ("log {\n  \"token\": \"abc\",\n  \"user\": \"bob\"\n} status=1", "log {\n  [REDACTED]"),
        (#"{"wrapper":"{\"password\":\"x\"}"}"#, #"{[REDACTED]"#),
        (#"{"msg":"user=bob status=1"}"#, #"{[REDACTED]"#),
        (#"got [{"status":200},{"count":2}] and [1,"a"] ok"#, #"got [{"status":200},{"count":2}] and [1,"a"] ok"#),
        (#"got [{"status":200},{"count":2}] and ["a",1] ok"#, #"got [{"status":200},{"count":2}] and [[REDACTED]"#),
    ])
    func embedded(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("JSON that does not parse hides everything from its first bracket", arguments: [
        (#"login {"pass" "word":"e8"}"#, "login [REDACTED]"),
        (#"login {"pass" "word":"e8"} next"#, "login [REDACTED]"),
        ("x {\"a\":1,\n\"password\" \"e9\"}\nstatus=1", "x [REDACTED]"),
        ("x {\"a\":1,\n\"password\":\"e9\"}\nstatus=1", "x {[REDACTED]"),
        ("x {\"a\":1,\n\"password\":\"e9\"", "x [REDACTED]"),
        (#"x ["a" "b"] y"#, "x [REDACTED]"),
        (#"x {"a":1,} y"#, "x [REDACTED]"),
        (#"x {"a":"\ud800"} y"#, "x [REDACTED]"),
    ])
    func unparsed(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // A tree of the JSON takes memory in proportion to its length, so JSON in free text is parsed
    // only up to 64 Ki scalars; longer JSON is not read.
    @Test("JSON longer than 64 Ki scalars in free text cuts the text at its first bracket")
    func longJSONInText() {
        func json(_ length: Int) -> String { "{\"status\":[" + String(repeating: "1,", count: (length - 13) / 2) + "1]}" }
        let fits = json(FreeTextScanner.longestJSON)
        #expect(fits.unicodeScalars.count <= FreeTextScanner.longestJSON)
        #expect(redactor.redact("log " + fits + " done") == "log " + fits + " done")
        let long = json(FreeTextScanner.longestJSON + 2)
        #expect(long.unicodeScalars.count > FreeTextScanner.longestJSON)
        #expect(redactor.redact("log " + long + " done") == "log [REDACTED]")
        let body = try! JSONSerialization.data(withJSONObject: ["note": "log " + long])
        #expect(redactor.redact(body: body, contentType: "application/json") == #"{"note":"log [REDACTED]"}"#)
    }

    @Test("brackets that do not open JSON are text", arguments: ["[INFO] ok", "[1/3] done", "{x} done", "user[0] ok", "[] {} ok"])
    func notJSON(input: String) {
        #expect(redactor.redact(input) == input)
    }
}
