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

    /// The same documents in free text: the text is cut at the value of the first member whose
    /// name is not on the allowed text keys.
    static let textCuts: [(String, String)] = [
        (#"{"credentials":{"email":"alice@example.com"}}"#, #"{"credentials":[REDACTED]"#),
        (#"{"otp":[4111111111111111]}"#, #"{"otp":[REDACTED]"#),
        (#"{"password":["\#(jwt)"]}"#, #"{"password":[REDACTED]"#),
        (#"{"amount":4111111111111111}"#, #"{"amount":[REDACTED]"#),
        (#"{"note":"paid 4111 1111 1111 1111","user":"bob"}"#, #"{"note":[REDACTED]"#),
        (#"[{"token":"\#(jwt)"},{"id":7}]"#, #"[{"token":[REDACTED]"#),
        (#"{"a":{"b":[{"api_key":true}]},"c":null}"#, #"{"a":[REDACTED]"#),
        (#"{"status":200,"count":3}"#, #"{"status":200,"count":3}"#),
        (#"[{"status":200},{"count":2}]"#, #"[{"status":200},{"count":2}]"#),
        (#"{"count":4111111111111111}"#, #"{"count":"[REDACTED]"}"#),
    ]

    @Test("a text that is JSON is cut at its first member that is not allowed", arguments: textCuts)
    func textCutsJSON(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("JSON inside a line cuts the line at the same place", arguments: textCuts)
    func embeddedCutsJSON(input: String, expected: String) {
        let isCut = expected.hasSuffix("[REDACTED]")
        #expect(redactor.redact("response \(input) done") == "response \(expected)" + (isCut ? "" : " done"))
    }

    @Test("names are compared at every depth, after their escapes are decoded, for every repetition")
    func names() {
        func body(_ json: String) -> String { redactor.redact(body: Data(json.utf8), contentType: "application/json") }
        #expect(body(#"{"pass\u0077ord":"x","user":"bob"}"#) == #"{"pass\u0077ord":"[REDACTED]","user":"bob"}"#)
        #expect(body(#"{"a":{"b":{"c":{"token":"x"}}}}"#) == #"{"a":{"b":{"c":{"token":"[REDACTED]"}}}}"#)
        #expect(body(#"{"password":"a","password":"b"}"#) == #"{"password":"[REDACTED]","password":"[REDACTED]"}"#)
        #expect(body(#"{"p\u0430ssword":"x"}"#) == #"{"p\u0430ssword":"[REDACTED]"}"#)
        #expect(body("{\"p\u{0430}ssword\":\"x\"}") == "{\"p\u{0430}ssword\":\"[REDACTED]\"}")
        #expect(body(#"{"user name":"bob","user.id":7,"user-role":"admin"}"#) == #"{"user name":"bob","user.id":7,"user-role":"admin"}"#)
        #expect(body(#"{"user[name]":"bob","café":"x"}"#) == #"{"user[name]":"[REDACTED]","café":"[REDACTED]"}"#)
        // In free text, a name with its escapes decoded is compared with the allowed keys.
        #expect(redactor.redact(#"{"st\u0061tus":200,"pass\u0077ord":"x"}"#) == #"{"st\u0061tus":200,"pass\u0077ord":[REDACTED]"#)
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

    // In free text the first string of a two-element array is its key, as a member's name is.
    @Test("a pair written as an array in a line cuts the line at its value unless its name is allowed", arguments: [
        (#"login ["password","e11"]"#, #"login ["password",[REDACTED]"#),
        (#"got [["Authorization","Basic x"]] ok"#, #"got [["Authorization",[REDACTED]"#),
        ("got [[\"\u{15E}ifre\",\"1234\"]] ok", "got [[\"\u{15E}ifre\",[REDACTED]"),
        (#"got [["X-Custom","v"]] ok"#, #"got [["X-Custom",[REDACTED]"#),
        (#"got [["status","ok"],["count",2]] ok"#, #"got [["status","ok"],["count",2]] ok"#),
        (#"["user","bob","token","abc","next"]"#, #"["user","bob","token","[REDACTED]","[REDACTED]"]"#),
    ])
    func pairsInText(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("JSON in a line is parsed with the parser; a key before it hides it", arguments: [
        (#"headers=[["X-Api-Key","k123"]]"#, "headers=[REDACTED]"),
        (#"data={"user":"bob"} status=1"#, "data=[REDACTED]"),
        (#"got {"user":"bob","password":"x"} and [{"pin":1}]"#, #"got {"user":[REDACTED]"#),
        ("log {\n  \"token\": \"abc\",\n  \"user\": \"bob\"\n} status=1", "log {\n  \"token\": [REDACTED]"),
        (#"{"wrapper":"{\"password\":\"x\"}"}"#, #"{"wrapper":[REDACTED]"#),
        (#"{"msg":"label=bob status=1"}"#, #"{"msg":[REDACTED]"#),
        (#"got [{"status":200},{"count":2}] and [1,"a"] ok"#, #"got [{"status":200},{"count":2}] and [1,"a"] ok"#),
        (#"status={"count":1} path=/a"#, #"status={"count":1} path=/a"#),
    ])
    func embedded(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("JSON that does not parse hides the rest of the text", arguments: [
        (#"login {"pass" "word":"e8"}"#, "login [REDACTED]"),
        (#"login {"pass" "word":"e8"} next"#, "login [REDACTED]"),
        ("x {\"a\":1,\n\"password\" \"e9\"}\nstatus=1", "x [REDACTED]"),
        ("x {\"a\":1,\n\"password\":\"e9\"}\nstatus=1", "x {\"a\":[REDACTED]"),
        ("x {\"a\":1,\n\"password\":\"e9\"", "x [REDACTED]"),
        (#"x ["a" "b"] y"#, "x [REDACTED]"),
        (#"x {"a":1,} y"#, "x [REDACTED]"),
        (#"x {"a":"\ud800"} y"#, "x [REDACTED]"),
    ])
    func unparsed(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("in a line, JSON members follow the allowed keys; a body reads JSON by the key rule of structured input")
    func membersOfJSONInText() {
        #expect(redactor.redact(#"log {"user":"bob","status":200,"list":[1]}"#) == #"log {"user":[REDACTED]"#)
        let allowing = Redactor(allowedTextKeys: ["user", "list"])
        #expect(allowing.redact(#"log {"user":"bob","status":200,"list":[1]}"#) == #"log {"user":"bob","status":200,"list":[1]}"#)
        #expect(allowing.redact(#"log {"user":"bob","pin":1234} done"#) == #"log {"user":"bob","pin":[REDACTED]"#)
        #expect(redactor.redact(body: Data(#"{"user":"bob","status":200}"#.utf8), contentType: "application/json") == #"{"user":"bob","status":200}"#)
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
