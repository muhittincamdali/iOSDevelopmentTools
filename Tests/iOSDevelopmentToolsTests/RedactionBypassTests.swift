import Foundation
import Testing
@testable import iOSDevelopmentTools

/// One test per bypass class of the shared redaction spec, plus every bypass that was reported
/// against earlier versions. Each case holds the secret `hunter2`, which must not be stored.
@Suite("Redaction: bypass attempts")
struct RedactionBypassTests {
    let policy = RedactionPolicy.default
    static let secret = "hunter2"

    private func stored(_ body: String, _ contentType: String?) -> String {
        String(decoding: policy.redact(body: Data(body.utf8), contentType: contentType).body, as: UTF8.self)
    }

    /// The key in a JSON body, a form body, a query, a header and three kinds of free text.
    private func expectHidden(key: String, _ comment: Comment? = nil) throws {
        let secret = Self.secret
        let jsonBody = try JSONSerialization.data(withJSONObject: [key: secret])
        let json = policy.redact(body: jsonBody, contentType: "application/json").body
        #expect(!String(decoding: json, as: UTF8.self).contains(secret), comment)
        let encoded = percentEncodedASCII(key)
        #expect(!stored("\(encoded)=\(secret)&a=1", "application/x-www-form-urlencoded").contains(secret), comment)
        #expect(!stored("\(key)=\(secret)&a=1", "application/x-www-form-urlencoded").contains(secret), comment)
        let url = try #require(URL(string: "https://e.com/p?\(encoded)=\(secret)"))
        #expect(!policy.redact(url: url).contains(secret), comment)
        let headers = RedactionPolicy(allowedHeaders: [key]).redact(headers: [HTTPHeader(name: key, value: secret)])
        #expect(headers.first?.value != secret, comment)
        for line in ["\(key)=\(secret) x", "\(key): \(secret) x", "{\"\(key)\":\"\(secret)\",\"a\":1}"] {
            #expect(!policy.redact(text: line).contains(secret), "\(line)")
        }
    }

    @Test("Confusable letters: Cyrillic, Greek, mathematical, circled and full-width", arguments: [
        "раssword", "pаssword", "tοken", "pαssword", "𝐩𝐚𝐬𝐬𝐰𝐨𝐫𝐝", "𝓉ℴ𝓀ℯ𝓃", "ⓟⓐⓢⓢⓦⓞⓡⓓ", "ｐａｓｓｗｏｒｄ", "ＡＰＩ＿ＫＥＹ",
    ])
    func confusableLetters(key: String) throws { try expectHidden(key: key) }

    @Test("Format characters: ZWJ, ZWNJ, soft hyphen and zero-width space", arguments: [
        "pass\u{200D}word", "to\u{200C}ken", "se\u{00AD}cret", "api\u{200B}key", "\u{FEFF}token",
    ])
    func formatCharacters(key: String) throws { try expectHidden(key: key) }

    @Test("Combining marks in keys and after delimiters", arguments: [
        "pa\u{301}ssword", "token\u{301}", "\u{301}session", "ssn\u{20DD}",
    ])
    func combiningMarks(key: String) throws {
        try expectHidden(key: key)
        // Werkzeug 3.1.9 reads the first of these as {"password": "\u{301}hunter2"}.
        for body in ["password=\u{301}hunter2", "user=ada&\u{301}password=hunter2", "user=ada;\u{301}token=hunter2"] {
            #expect(!stored(body, "application/x-www-form-urlencoded").contains(Self.secret))
        }
    }

    @Test("Escapes: \\u, % and &#", arguments: [
        "\\u0070assword", "pass%77ord", "pass%2577ord", "API%5FKEY", "%EF%BD%90assword", "pass&#119;ord", "&#x74;oken",
        "pass%77ord%ZZ", "%ZZpass%2577ord", "pass\u{600}%77ord",
    ])
    func escapes(key: String) throws {
        try expectHidden(key: key)
        // In JSON text, the parser decodes the escape: the key is "password".
        #expect(!stored(#"{"\u0070assword":"hunter2"}"#, "application/json").contains(Self.secret))
    }

    @Test("Separators: _, -, ., space and any other separator", arguments: [
        "pass_word", "pass-word", "pass.word", "pass word", "pass/word", "pass:word", "pass;word", "user[password]", "pass\tword",
    ])
    func separators(key: String) throws { try expectHidden(key: key) }

    @Test("Duplicate keys: no occurrence is stored", arguments: [
        #"{"token":"a","token":"hunter2"}"#, #"{"token":"hunter2","token":"a"}"#,
        #"{"a":1,"a":{"password":"hunter2"}}"#, #"{"a":{"password":"hunter2"},"a":1}"#,
        #"[{"a":{"token":"hunter2"},"a":0}]"#, #"{"x":{"y":[1,{"a":1,"a":{"secret":"hunter2"}}]}}"#,
        #"{"😀":1,"😀":{"password":"hunter2"}}"#, "{\"\u{E9}\":1,\"e\u{301}\":{\"password\":\"hunter2\"}}",
        #"{"variables":"{\"a\":1,\"a\":{\"password\":\"hunter2\"}}"}"#, #"{"t":{"token":"x","token":"hunter2"}}"#,
    ])
    func duplicateKeys(body: String) throws {
        #expect(!stored(body, "application/json").contains(Self.secret))
        // The same bytes as UTF-16 are read the same way.
        let wide = try #require(body.data(using: .utf16LittleEndian))
        let data = policy.redact(body: wide, contentType: "application/json").body
        #expect(!String(decoding: data, as: UTF8.self).contains(Self.secret))
    }

    @Test("Nested objects and arrays: a secret key hides its whole value")
    func nested() {
        let body = #"{"auth":{"user":"ada","pass":"hunter2"},"list":[[{"pin":["hunter2"]}]],"pwd":[1,"hunter2"]}"#
        #expect(!stored(body, "application/json").contains(Self.secret))
    }

    @Test("JSON embedded in a string, a form field or a query value", arguments: [
        (#"{"variables":"{\"input\":{\"password\":\"hunter2\"}}"}"#, "application/json"),
        (#"{"v":"{\"pass\\u0077ord\":\"hunter2\"}"}"#, "application/json"),
        (#"{"v":"{\"password\":\"hunter2\""}"#, "application/json"),
        ("data=%7B%22password%22%3A%22hunter2%22%7D", "application/x-www-form-urlencoded"),
        ("q=%7B%22a%22:1,%22a%22:%7B%22token%22:%22hunter2%22%7D%7D", "application/x-www-form-urlencoded"),
    ])
    func embeddedJSON(body: String, contentType: String) {
        #expect(!stored(body, contentType).contains(Self.secret))
    }

    @Test("Mixed form and JSON: each body is read only as its content type says", arguments: [
        (#"{"x":"1&password=hunter2"}"#, "application/x-www-form-urlencoded"),
        (#"["&password=hunter2"]"#, "application/x-www-form-urlencoded"),
        (#"{"user":"ada","password":"hunter2"}"#, "application/x-www-form-urlencoded"),
        (#"{"token":"hunter2==","n":1}"#, "application/x-www-form-urlencoded"),
        (#"{"x":"1&password=hunter2"}"#, "application/json"),
        (#"{"password":"hunter2"}"#, nil), ("password=hunter2", nil), ("  \n{\"secret\":\"hunter2\"}", "text/plain"),
        ("a=1&token;x=hunter2&pass;word=hunter2", "application/x-www-form-urlencoded"),
    ] as [(String, String?)])
    func mixedFormAndJSON(body: String, contentType: String?) {
        #expect(!stored(body, contentType).contains(Self.secret))
    }

    @Test("Unicode line separators end a line, and a secret after one is still found", arguments: [
        "ok\u{2028}password=hunter2", "ok\u{2029}token: hunter2", "ok\u{85}secret=hunter2", "ok\u{0B}pwd=hunter2",
        "ok\u{0C}api_key=hunter2", "ok\rpassword=hunter2", "password=\u{2028}hunter2",
    ])
    func lineSeparators(text: String) {
        let result = policy.redact(text: text)
        #expect(!result.contains(Self.secret))
        #expect(result.hasPrefix(text.hasPrefix("ok") ? "ok" : "password="))
    }

    @Test("URLs: user info, fragments, path tokens and encoded parameter names", arguments: [
        "https://alice:hunter2@example.com/a", "https://hunter2@example.com/a", "https://e.com/cb#access_token=hunter2&state=x",
        "https://e.com/cb#hunter2", "https://e.com/reset/hunter2abcdef0123", "https://e.com/p?API%5FKEY=hunter2",
        "https://e.com/p?pass%2577ord=hunter2", "https://e.com/p?session;id=hunter2&a=1", "https://e.com/p?a=1;password=hunter2",
        "https://e.com/shop;jsessionid=hunter2/cart", "https://e.com/p?q=%7B%22password%22%3A%22hunter2%22%7D",
        "https://e.com/p?%CC%81token=hunter2", "https://e.com/shop;%CC%81jsessionid=hunter2/x",
    ])
    func urls(url: String) throws {
        let parsed = try #require(URL(string: url))
        #expect(!policy.redact(url: parsed).contains(Self.secret))
        #expect(!RedactionPolicy(allowedQueryParameters: ["a", "q", "id"]).redact(url: parsed).contains(Self.secret))
    }

    @Test("Malformed bodies are omitted, not stored", arguments: [
        (#"{"password": }"#, "application/json"), (#"{"password":"hunter2"#, "application/json"),
        ("password=hunter2&x=%E0%A4", "application/x-www-form-urlencoded"),
        ("--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nhunter2", "multipart/form-data; boundary=XyZ"),
    ])
    func malformedBodies(body: String, contentType: String) {
        let (data, outcome) = policy.redact(body: Data(body.utf8), contentType: contentType)
        #expect(outcome == .omitted)
        #expect(!String(decoding: data, as: UTF8.self).contains(Self.secret))
    }

    @Test("Multipart: fields by name, file parts omitted, malformed structure omitted", arguments: [
        "--B\r\nContent-Disposition: form-data; name=\"pass\u{200D}word\"\r\n\r\nhunter2\r\n--B--\r\n",
        "--B\r\nContent-Disposition: form-data; name=\"pass%77ord\"\r\n\r\nhunter2\r\n--B--\r\n",
        "--B\r\nContent-Disposition: form-data; name=\"note\"\r\nContent-Type: application/json\r\n\r\n{\"token\":\"hunter2\"}\r\n--B--\r\n",
        "--B\r\nContent-Disposition: form-data; name=\"a\"; filename=\"a.txt\"\r\n\r\nhunter2\r\n--B--\r\n",
        "--B\r\nContent-Disposition: form-data; name=\"a\"\r\nContent-Transfer-Encoding: base64\r\n\r\nhunter2\r\n--B--\r\n",
        "--B\r\nContent-Disposition: form-data; name=\"a\"; name=\"password\"\r\n\r\nhunter2\r\n--B--\r\n",
        "--B\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--B--\r\nhunter2",
    ])
    func multipart(body: String) {
        #expect(!stored(body, "multipart/form-data; boundary=B").contains(Self.secret))
    }

    @Test("Oversized and cut-off bodies are omitted before they are parsed")
    func oversizedBodies() {
        let padding = String(repeating: "x", count: RedactionPolicy.maximumCheckedBodySize)
        for (body, contentType) in [
            ("{\"a\":\"\(padding)\",\"note\":\"hunter2\"}", "application/json"), ("a=\(padding)&note=hunter2", "application/x-www-form-urlencoded"),
            ("\(padding) hunter2", "text/plain"),
        ] {
            let (data, outcome) = policy.redact(body: Data(body.utf8), contentType: contentType)
            #expect(outcome == .omitted)
            #expect(String(decoding: data, as: UTF8.self) == "[body omitted: \(body.utf8.count) bytes, \(contentType)]")
        }
        let prefix = Data(#"{"note":"hunter2","a":1}"#.utf8)
        #expect(policy.redact(body: prefix, contentType: "application/json", isComplete: false).outcome == .omitted)
    }

    @Test("Duplicate keys in forms and queries: every occurrence is hidden")
    func duplicateFormAndQueryKeys() throws {
        let form = "token=a&token=hunter2&TOKEN=hunter2&pass%77ord=hunter2&password=hunter2"
        #expect(!stored(form, "application/x-www-form-urlencoded").contains(Self.secret))
        let url = try #require(URL(string: "https://e.com/p?token=a&token=hunter2&Token=hunter2&a=1&a=2"))
        #expect(!RedactionPolicy(allowedQueryParameters: ["a", "token"]).redact(url: url).contains(Self.secret))
    }

    @Test("A secret word with format characters, combining marks or compatibility forms still ends the line", arguments: [
        "to\u{200D}ken hunter2", "pass\u{200C}word hunter2", "se\u{AD}cret hunter2", "pa\u{301}ssword hunter2", "ｔｏｋｅｎ hunter2",
        "𝐩𝐚𝐬𝐬𝐰𝐨𝐫𝐝 hunter2", "ⓣⓞⓚⓔⓝ hunter2", "my to\u{200B}ken is hunter2",
    ])
    func secretWordsInText(text: String) {
        #expect(!policy.redact(text: text).contains(Self.secret))
    }

    @Test("JSON in a charset that JSONSerialization does not detect is omitted", arguments: [
        "application/json; charset=iso-8859-1", "application/json; charset=windows-1252", "application/json; charset=\"utf-8",
    ])
    func jsonCharset(contentType: String) {
        let (data, outcome) = policy.redact(body: Data(#"{"note":"hunter2"}"#.utf8), contentType: contentType)
        #expect(outcome == .omitted)
        #expect(!String(decoding: data, as: UTF8.self).contains(Self.secret))
    }
}
