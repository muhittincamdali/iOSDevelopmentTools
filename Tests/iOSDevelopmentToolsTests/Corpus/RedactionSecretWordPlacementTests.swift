import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A review of iOS-Networking-Architecture-Pro after the twenty-sixth found that `secret` (six
/// letters) counted in a key only as a word or at the end, while the logging guide said that a
/// secret word of five or more letters counts anywhere; this library's 2.1.0 guide said the same,
/// while its rules read `token`, `secret` and `bearer` only as a word or at the end too. `{"secretanswer":…}`, `secretvalue=…`, `[["secretvalue",…]]`,
/// `{"name":"secretvalue","value":…}`, a JSON Patch path `/secretanswer`, `/v1/secretanswer/…` and
/// `myapp://secretanswer/…` all showed the value, 96 of 96, and `allowedTextKeys` and
/// `allowedQueryParameters` took `secretanswer` as a name to allow. `token` (five letters) read the
/// same way. Both now count anywhere: every word of five or more letters does, as the header rule
/// already read them, and `secretary` and `tokenizer` are hidden with them.
@Suite("Redaction corpus: where a secret word counts in a key")
struct RedactionSecretWordPlacementTests {
    private static let secret = "Qz27Wk5m"

    /// The keys of the review and the same shapes of `token`.
    static let keys = [
        "secretanswer", "secretvalue", "SECRETVALUE", "secretphrase", "secretid", "sharedsecretvalue", "SecretAnswer", "secret_answer2x",
        "tokenvalue", "TOKENID", "tokenstring", "mytokenhash",
    ]

    private static func json(_ text: String) -> String {
        Redactor().redact(body: Data(text.utf8), contentType: "application/json")
    }

    private static func form(_ text: String) -> String {
        Redactor().redact(body: Data(text.utf8), contentType: "application/x-www-form-urlencoded")
    }

    private static func multipart(_ name: String) -> String {
        let body = "--B0und\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(secret)\r\n--B0und--"
        return Redactor().redact(body: Data(body.utf8), contentType: "multipart/form-data; boundary=B0und")
    }

    private static func url(_ text: String) -> String {
        Redactor().redact(url: URL(string: text)!)
    }

    /// Every shape in which the review wrote the keys, and free text.
    static func shapes(_ key: String) -> [String] {
        let s = secret
        return [
            json(#"{"\#(key)":"\#(s)"}"#),
            json(#"{"user":{"\#(key)":"\#(s)"}}"#),
            form("\(key)=\(s)"),
            multipart(key),
            json(#"[["\#(key)","\#(s)"]]"#),
            json(#"{"name":"\#(key)","value":"\#(s)"}"#),
            json(#"{"headers":[{"name":"\#(key)","value":"\#(s)"}]}"#),
            json(#"[{"op":"add","path":"/\#(key)","value":"\#(s)"}]"#),
            json(#"{"Operations":[{"op":"replace","path":"\#(key)","value":"\#(s)"}]}"#),
            url("https://api.example.com/v1/\(key)/\(s)"),
            url("myapp://\(key)/\(s)"),
            url("https://api.example.com/v1/items?\(key)=\(s)"),
            Redactor().redact("\(key) \(s)"),
            Redactor().redact("\(key)=\(s)"),
        ]
    }

    @Test("a key that holds `secret` or `token` before more letters hides its value in every shape", arguments: keys)
    func everyShape(key: String) {
        let shown = Self.shapes(key).filter { $0.contains(Self.secret) }
        #expect(shown.isEmpty, "\(shown)")
    }

    @Test("no allowlist takes a name that holds `secret` or `token`", arguments: keys)
    func allowlists(key: String) {
        let redactor = Redactor(allowedTextKeys: [key], allowedQueryParameters: [key])
        #expect(redactor.allowedTextKeys == Redactor().allowedTextKeys)
        #expect(redactor.allowedQueryParameters.isEmpty)
        #expect(!redactor.allowsTextKey(key.unicodeScalars))
        #expect(!redactor.redact(url: URL(string: "https://api.example.com/v1/items?\(key)=\(Self.secret)")!).contains(Self.secret))
        #expect(!redactor.redact("\(key)=\(Self.secret)").contains(Self.secret))
    }

    /// The rule of the logging guide, checked on the list itself: a word of five or more letters
    /// counts anywhere in a key, so no such word waits for a word boundary.
    @Test("every secret word of five or more letters counts anywhere in a key")
    func longWordsCountAnywhere() {
        let bound = SecretNameTable.defaultEntries.filter { $0.letters.count >= 5 && $0.placement != .anywhere }
        #expect(bound.isEmpty, "\(bound.map { String(decoding: $0.letters, as: UTF8.self) })")
    }

    /// A property test: each word of five or more letters, with letters written before and after
    /// it and in either case, hides the value of the key in JSON and in a form.
    @Test("a word of five or more letters with letters around it hides the value", arguments: SecretNameTable.defaultWords.filter { $0.count >= 5 })
    func generated(word: String) {
        let s = Self.secret
        let keys = ["x\(word)y", "my\(word)", "\(word)value", "\(word.uppercased())ID", "a1\(word)2b"]
        var shown: [String] = []
        for key in keys {
            for output in [Self.json(#"{"\#(key)":"\#(s)"}"#), Self.form("\(key)=\(s)"), Self.json(#"{"name":"\#(key)","value":"\#(s)"}"#)]
            where output.contains(s) {
                shown.append(output)
            }
        }
        #expect(shown.isEmpty, "\(shown)")
    }

    /// The words of four letters or fewer still count only as a word of the key or at its end,
    /// as the guide says, so these keep their values; `secretary` and `tokenizer` are hidden.
    @Test("short secret words inside longer words keep the value; long ones hide it")
    func usefulness() {
        for key in ["keyboard", "spinner", "author", "bypass", "inside", "signal", "keynote", "authority", "passport"] {
            #expect(Self.json(#"{"\#(key)":"v1","status":"ok"}"#) == #"{"\#(key)":"v1","status":"ok"}"#, "\(key)")
            #expect(Self.form("\(key)=v1&status=ok") == "\(key)=v1&status=ok", "\(key)")
        }
        for key in ["secretary", "tokenizer"] {
            #expect(Self.json(#"{"\#(key)":"v1","status":"ok"}"#) == #"{"\#(key)":"[REDACTED]","status":"ok"}"#, "\(key)")
        }
    }
}
