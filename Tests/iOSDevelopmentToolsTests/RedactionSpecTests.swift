import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The required test set of the shared redaction specification (REDACTION-SPEC 2.1-r2, §8), ported
/// to this package's API. The specification writes the replacement as `[R]`; here it is
/// ``RedactionPolicy/replacement``. This package has no masks and no detector kinds, so a finding
/// is replaced whole, and the items about kind selection keep only their URL part (§8 #48). Item
/// numbers are the specification's.
@Suite("Redaction spec §8: keys and bodies")
struct RedactionSpecKeyAndBodyTests {
    let policy = RedactionPolicy.default

    func body(_ text: String, _ type: String? = "application/json") -> String {
        String(decoding: policy.redact(body: Data(text.utf8), contentType: type).body, as: UTF8.self)
    }

    func omitted(_ text: String, _ note: String) -> String {
        "[body omitted: \(text.utf8.count) bytes, \(note)]"
    }

    @Test("#1–#7: the key rule in JSON bodies")
    func keyRule() {
        #expect(body(#"{"user":"bob","password":"hunter2"}"#) == #"{"user":"bob","password":"[REDACTED]"}"#)
        #expect(body(#"{"password":"hunter2","id":"7"}"#) == #"{"password":"[REDACTED]","id":"7"}"#)
        #expect(body(#"{"PASS-WORD":"a","pass.word":"b","created_at":"c"}"#) == #"{"PASS-WORD":"[REDACTED]","pass.word":"[REDACTED]","created_at":"c"}"#)
        #expect(body(#"{"pаssword":"x","şifre":"y","user[id]":"z","ok":"1"}"#) == #"{"pаssword":"[REDACTED]","şifre":"[REDACTED]","user[id]":"[REDACTED]","ok":"1"}"#)
        #expect(body(#"{"token":"a","token":"b"}"#) == #"{"token":"[REDACTED]","token":"[REDACTED]"}"#)
        #expect(body(#"{"password":{"a":[1,2]},"x":1}"#) == #"{"password":"[REDACTED]","x":1}"#)
        #expect(body(#"{"note":"password=hunter2","ok":"fine"}"#) == #"{"note":"password=[REDACTED]","ok":"fine"}"#)
    }

    @Test("#8–#10: names written as values")
    func namesAsValues() {
        #expect(body(#"[{"op":"replace","path":"/user/password","value":"hunter2"},{"op":"replace","path":"/status","value":"active"}]"#)
            == #"[{"op":"replace","path":"/user/password","value":"[REDACTED]"},{"op":"replace","path":"/status","value":"active"}]"#)
        #expect(body(#"[{"label":"Şifre","value":"hunter2"},{"label":"ⓟⓘⓝ","value":"1234"},{"label":"status","value":"ok"}]"#)
            == #"[{"label":"Şifre","value":"[REDACTED]"},{"label":"[REDACTED]","value":"[REDACTED]"},{"label":"status","value":"ok"}]"#)
        #expect(body(#"[["Authorization","Bearer abc"],["Accept","x"]]"#) == #"[["Authorization","[REDACTED]"],["Accept","x"]]"#)
    }

    @Test("#11–#13: JSON that servers could read differently, other types and depth", arguments: [#"{"a":1,}"#, #"{"a":NaN}"#, #"{"a":1}{"b":2}"#])
    func strictJSON(text: String) {
        #expect(body(text) == omitted(text, "application/json"))
    }

    @Test("#12–#13: unknown types and the depth limit")
    func typesAndDepth() {
        #expect(body("<password>hunter2</password>", "application/xml") == "[body omitted: 28 bytes, application/xml]")
        let deep = String(repeating: "[", count: 65) + String(repeating: "]", count: 65)
        #expect(body(deep) == "[body omitted: 130 bytes, application/json]")
        let inString = #"{"note":""# + String(repeating: "[", count: 64) + String(repeating: "]", count: 64) + #" ok"}"#
        #expect(body(inString) == #"{"note":"[REDACTED]"}"#)
    }

    @Test("#14–#16: forms")
    func forms() {
        let form = "application/x-www-form-urlencoded"
        #expect(body("p%D0%B0ssword=a&pass.word=b&user%5Bname%5D=c&user.name=bob", form)
            == "p%D0%B0ssword=[REDACTED]&pass.word=[REDACTED]&user%5Bname%5D=[REDACTED]&user.name=bob")
        for text in ["a=1;b=2", "a=100%&b=2", "a.b=1&a_b=2"] {
            #expect(body(text, form) == omitted(text, form))
        }
        #expect(body("label=Password&value=hunter2&x=1", form) == "label=Password&value=[REDACTED]&x=[REDACTED]")
    }

    @Test("#17–#18: multipart part headers and delimiters")
    func multipart() {
        let part = "--B0und\r\nContent-Disposition: form-data; name=\"a\"\r\nX-4111111111111111: 1\r\n" + "Content-Length: 1\r\n\r\nx\r\n--B0und--"
        #expect(body(part, "multipart/form-data; boundary=B0und")
            == "--B0und\r\nContent-Disposition: form-data; name=\"a\"\r\n[REDACTED]: [REDACTED]\r\nContent-Length: 1\r\n\r\nx\r\n--B0und--")
        // #17b: a kept part header value is written by its form, never read as free text.
        for (header, shown, content) in [
            ("Content-Length: pin-4831", "Content-Length: [REDACTED]", "x"),
            ("Content-Length: 12 hunter2", "Content-Length: [REDACTED]", "x"),
            ("Content-Transfer-Encoding: hunter2", "Content-Transfer-Encoding: [REDACTED]", "[body omitted: 1 byte, text/plain]"),
            ("Content-Transfer-Encoding: BASE64", "Content-Transfer-Encoding: base64", "[body omitted: 1 byte, text/plain]"),
        ] {
            let text = "--B0und\r\nContent-Disposition: form-data; name=\"a\"\r\n\(header)\r\n\r\nx\r\n--B0und--"
            #expect(body(text, "multipart/form-data; boundary=B0und")
                == "--B0und\r\nContent-Disposition: form-data; name=\"a\"\r\n\(shown)\r\n\r\n\(content)\r\n--B0und--")
        }
        let bareLineFeed = "--B0und\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nx\n--B0und\r\n"
            + "Content-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--B0und--"
        #expect(body(bareLineFeed, "multipart/form-data; boundary=B0und") == omitted(bareLineFeed, "multipart/form-data"))
    }

    @Test("#19: a content type that is not one type is unreadable")
    func unreadableContentType() {
        #expect(body(#"{"a":1}"#, "application/json, text/plain") == "[body omitted: 7 bytes, unreadable content type]")
    }
}

@Suite("Redaction spec §8: control characters and held names")
struct RedactionSpecHeldNameTests {
    let policy = RedactionPolicy.default

    func body(_ text: String, _ type: String = "application/json") -> String {
        String(decoding: policy.redact(body: Data(text.utf8), contentType: type).body, as: UTF8.self)
    }

    @Test("#20–#21: a control character in a name names a secret")
    func controlInName() {
        #expect(body(#"{"name":"Hello\nWorld","value":"x"}"#).contains(#""value":"[REDACTED]""#))
        #expect(body(#"{"note":"pass\nword","id":"7"}"#).contains(#""id":"[REDACTED]""#))
    }

    @Test("#22: a string of only control characters and spaces names a secret beside any field")
    func onlyControlCharacters() {
        #expect(body(#"{"title":"\n","data":"x"}"#) == #"{"title":"\n","data":"[REDACTED]"}"#)
        #expect(body(#"{"ParameterKey":"\t","ParameterValue":"x"}"#) == #"{"ParameterKey":"[REDACTED]","ParameterValue":"[REDACTED]"}"#)
        #expect(body("ParameterKey=%0A&ParameterValue=x", "application/x-www-form-urlencoded") == "ParameterKey=[REDACTED]&ParameterValue=[REDACTED]")
    }

    @Test("#23–#24: a sentence keeps its neighbours; a name with a control character in it does not")
    func sentencesAndNames() {
        #expect(body(#"{"message":"Hello\nWorld","id":"7"}"#) == #"{"message":"Hello\nWorld","id":"7"}"#)
        #expect(body(#"{"ParameterKey":"DbPassword\n","ParameterValue":"x"}"#).contains(#""ParameterValue":"[REDACTED]""#))
        #expect(body(#"{"OptionName":"pa\nssword","Value":"x"}"#).contains(#""Value":"[REDACTED]""#))
    }
}

@Suite("Redaction spec §8: value detectors")
struct RedactionSpecDetectorTests {
    let policy = RedactionPolicy.default

    @Test("#25–#33: findings in free text", arguments: [
        ("paid 4111 1111 1111 1111 ok", "paid [REDACTED] ok"),
        ("ok 4111-1111-1111-1111 ok", "ok [REDACTED] ok"),
        ("\u{664}\u{662}\u{664}\u{662} \u{664}\u{662}\u{664}\u{662} \u{664}\u{662}\u{664}\u{662} \u{664}\u{662}\u{664}\u{662}", "[REDACTED]"),
        ("ref DE89 3704 0044 0532 0130 00 ok", "ref [REDACTED] ok"),
        ("de89370400440532013000 lowercase", "de89370400440532013000 lowercase"),
        ("mail alice@example.com ok", "mail [REDACTED] ok"),
        ("contact alice%40example.com", "contact [REDACTED]"),
        ("tok eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U ok", "tok [REDACTED] ok"),
        // `bearer` is a secret name of this package (spec UN-2), so the text is cut after it.
        ("hdr Bearer abcdefgh12345678 ok", "hdr Bearer [REDACTED]"),
        ("hdr bearer abcdefgh12345678 ok", "hdr bearer [REDACTED]"),
        ("hex 0123456789abcdef0123456789abcdef ok", "hex [REDACTED] ok"),
        ("uuid 123e4567-e89b-12d3-a456-426614174000 ok", "uuid 123e4567-e89b-12d3-a456-426614174000 ok"),
        ("git clone https://bob:hunter2@github.com/x/y.git", "git clone [REDACTED]"),
        ("redis://:hunter2@host", "[REDACTED]"),
    ])
    func freeText(input: String, expected: String) {
        #expect(policy.redact(text: input) == expected)
    }

    @Test("#34: the detectors read JSON names")
    func jsonNames() {
        let redacted = policy.redact(body: Data(#"{"4111111111111111":1,"alice@example.com":2}"#.utf8), contentType: "application/json").body
        #expect(String(decoding: redacted, as: UTF8.self) == #"{"[REDACTED]":1,"[REDACTED]":"[REDACTED]"}"#)
    }

    @Test("#35–#36: VT, FF, NEL, LS and PS are bridged; LF and CR end a finding", arguments: [
        ("paid with 4111 1111 1111\u{2028}1111", "paid with [REDACTED]"),
        ("paid with 4111 1111 1111\u{0B}1111", "paid with [REDACTED]"),
        ("paid 4111\u{0C}1111\u{85}1111\u{2029}1111", "paid [REDACTED]"),
        ("mail ali\u{2028}ce@example.com ok", "mail [REDACTED]"),
        ("4111 1111 1111\n1111", "4111 1111 1111\n1111"),
    ])
    func bridgedSeparators(input: String, expected: String) {
        #expect(policy.redact(text: input) == expected)
    }
}

@Suite("Redaction spec §8: URLs")
struct RedactionSpecURLTests {
    let policy = RedactionPolicy.default

    func url(_ text: String) throws -> String {
        policy.redact(url: try #require(URL(string: text)))
    }

    @Test("#38–#39: user info, fragment, identifiers and the segment after a secret name")
    func pathAndQuery() throws {
        #expect(try url("https://bob:pw@example.com/users/12345678/reset?code=x#y") == "https://example.com/users/:id/reset?code=[REDACTED]")
        #expect(try url("https://example.com/v1/cards/4242/pin/4831") == "https://example.com/v1/cards/:id/pin/:id")
    }

    @Test("#40: a path that servers resolve differently keeps only the scheme and host", arguments: [
        "https://example.com/pin/./4831", "https://example.com/token/x/../4831", "https://example.com/a;pin/4831",
        "https://example.com/a%2Fb/c", "https://example.com/a%25/x", "https://example.com/a%5Cb/x", "https://example.com/a%3Bb/x",
        "https://example.com/pin%2F4831/x", "https://example.com/a%2fb/c", "https://example.com/a%5cb/x",
    ])
    func resolvesDifferently(input: String) throws {
        #expect(try url(input) == "https://example.com")
    }

    @Test("#41–#42: limits and the host rule")
    func limitsAndHost() throws {
        #expect(try url("https://example.com" + String(repeating: "/a", count: 65)) == "https://example.com")
        #expect(try url("https://h.example;password=hunter2/db") == "https://[REDACTED]")
        #expect(try url("https://4111111111111111.example.com/a") == "https://[REDACTED]")
    }

    @Test("#43 and G1: a host that names a secret is hidden with everything after it", arguments: [
        ("myapp://pin/4831", "myapp://[REDACTED]"),
        ("myapp://user@pin/Qz743Wk5m", "myapp://[REDACTED]"),
        ("myapp://password.hunter2", "myapp://[REDACTED]"),
        ("myapp://pin-4831", "myapp://[REDACTED]"),
        ("https://pin-4831.example.com/a", "https://[REDACTED]"),
        ("myapp://pin:4831/x", "myapp://[REDACTED]"),
        ("https://auth.example.com/login", "https://[REDACTED]"),
        ("https://10.0.0.1/pin/4831", "https://10.0.0.1/pin/:id"),
    ])
    func secretHost(input: String, expected: String) throws {
        #expect(try url(input) == expected)
    }

    @Test("#44–#45: labels outside plain ASCII, and `:id` is no label")
    func labels() throws {
        #expect(try url("https://example.com/caf%C3%A9/menu") == "https://example.com/caf%C3%A9/:id")
        #expect(try url("https://example.com/p%0Ain/4831") == "https://example.com/p%0Ain/:id")
        #expect(try url("https://example.com/a,b/c") == "https://example.com/a,b/:id")
        #expect(try url("https://example.com/users/:id/x") == "https://example.com/users/:id/x")
    }

    @Test("#46–#48: the query, an unparsed URL, user info and fragment")
    func queryAndUnparsed() throws {
        #expect(try url("https://example.com/a?page=2&flag") == "https://example.com/a?page=[REDACTED]&[REDACTED]")
        #expect(try url("https://example.com/a?a=1;b=2") == "https://example.com/a?[REDACTED]")
        #expect(try url("mailto:ada@example.com") == "<unparsed URL>")
        #expect(try url("https://bob:pw@example.com/a#frag") == "https://example.com/a")
    }
}
