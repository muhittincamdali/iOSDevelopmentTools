import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A quoted key in free text (`"…": value`, `"…"=value`, `'…': value`) follows the key rule:
/// unless its folded form is on `allowedTextKeys`, the text is cut at its opening quote, so
/// nothing written in the quotes shows. The tenth review of this package found the cut after the
/// separator, so the key showed (`"hunter2":"v"` was stored as `"hunter2":"[REDACTED]`); the
/// sixteenth review of the shared rules in iOSSecurityTools got secrets written in such keys past
/// a reading of them as JSON names. JSON that parses is read by the key rule of structured input,
/// which shows the names of its members and hides their values.
@Suite("Redaction corpus: quoted keys in free text")
struct RedactionQuotedKeyTests {
    let redactor = Redactor()

    /// The review lines, which showed the secret in the quotes.
    static let reviewLines = [
        #""password hunter2": x"#, #"cache miss for "session Qz9Wk7rX": refetching"#, #"wrong "pin 4321": retry"#,
        "\"p\u{0430}ssword hunter2\": x", #""<password>hunter2</password>": x"#, #""status=ok password hunter2": 1"#,
        #""pass word hunter2": x"#, #""p|wd hunter2": x"#, #""my token is hunter2": ok"#, #""status: password hunter2": 1"#,
        #""password hunter2"=x"#, "\"password hunter2\"\n: x", #"{\"password hunter2\": 1}"#, #""\"password hunter2\":1": 2"#,
        #""hunter2":"v""#, #"'hunter2': 'v'"#, #"`hunter2`: v"#, #""x":"hunter2""#, #"'x': 'hunter2'"#, #""x"="hunter2""#,
    ]

    @Test("a quoted key that is not allowed shows nothing of itself or what follows, on every path", arguments: reviewLines)
    func reviewLinesOnEveryPath(line: String) {
        for (path, output) in RedactionCutRuleTests.everyPath(line) {
            for secret in ["hunter2", "Qz9Wk7rX", "4321"] {
                #expect(!output.contains(secret), "\(path): \(line.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    @Test("the text is cut at the opening quote of a key that is not allowed", arguments: [
        (#"cache miss for "session Qz9Wk7rX": refetching"#, "cache miss for [REDACTED]"),
        (#""password hint": 1"#, "[REDACTED]"),
        (#"see "user=bob": 1"#, "see [REDACTED]"),
        (#"see \"user\": \"bob\""#, "see [REDACTED]"),
        (#"see \\\"user\\\": 1"#, "see [REDACTED]"),
        (#""status": "ok", "user": "bob""#, #""status": "ok", [REDACTED]"#),
        (#""status"="ok" "user"="bob""#, #""status"="ok" [REDACTED]"#),
        (#""(status": 1"#, "[REDACTED]"),
        // Spaces fold away, so `stat us` is the allowed key `status`; the last word before the
        // separator, `us`, is not allowed, so the value is hidden.
        (#""stat us": 1"#, #""stat us": [REDACTED]"#),
        ("\"\u{200B}status\": 1", "[REDACTED]"),
        ("\"st\u{0430}tus\": 1", "[REDACTED]"),
        (#"'user': 'bob'"#, "[REDACTED]"),
        (#"`user`: bob"#, "[REDACTED]"),
    ])
    func cuts(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // JSON that parses is structured input: the names of its members show, and the text is cut at
    // the value of the first member whose name is not allowed.
    @Test("JSON in a line shows its member names and cuts at the first value that is not allowed", arguments: [
        (#"{"status":200,"user":"bob"}"#, #"{"status":200,"user":[REDACTED]"#),
        (#"got {"password hunter2": 1} ok"#, #"got {"password hunter2": [REDACTED]"#),
        (#"got ["user","bob"] ok"#, #"got ["user",[REDACTED]"#),
    ])
    func embeddedJSON(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("allowed quoted keys keep their values, also when the app allows a key", arguments: [
        #""status": "ok", "count": 3"#, #""duration_ms": 12"#, #""STATUS": "ok""#, #"{"status":200,"count":1}"#, #""method"="GET""#,
        #"[["status","200"]]"#, "\"status\" : \"ok\"\n\"count\": 2", #"'status': 'ok'"#,
    ])
    func allowedKeys(line: String) {
        #expect(redactor.redact(line) == line)
        #expect(redactor.redact(body: Data(line.utf8), contentType: "text/plain") == line)
        let allowing = Redactor(allowedTextKeys: ["user"])
        #expect(allowing.redact(line + #" "user": "bob""#) == line + #" "user": "bob""#)
    }

    @Test("the names of members in structured JSON are shown and their values hidden")
    func structuredNames() {
        let body = #"{"password hunter2":"x","api key Qz9Wk7rX":1,"status":"ok"}"#
        #expect(redactor.redact(body: Data(body.utf8), contentType: "application/json")
            == #"{"password hunter2":"[REDACTED]","api key Qz9Wk7rX":"[REDACTED]","status":"ok"}"#)
    }

    @Test("a key longer than any allowed key is turned down before it is read")
    func longKeys() {
        let key = String(repeating: "a", count: PlainName.maximumKeyLength + 1)
        #expect(redactor.redact("ok \"\(key)\": 1") == "ok [REDACTED]")
        #expect(Redactor(allowedTextKeys: [key]).redact("ok \"\(key)\": 1") == "ok [REDACTED]")
    }

    // MARK: Property

    /// What generated keys are written of: secret names, words in two scripts, tags, keys and
    /// URLs written inside them, escapes, separators, and plain words.
    static let pieces: [@Sendable (inout SeededRandom) -> String] = [
        { random in DisguisedName.secretNames.randomElement(using: &random)! },
        { random in DisguisedName.make(using: &random) },
        { random in ["p\u{0430}ssword", "\u{0442}oken", "se\u{0441}ret", "pin\u{0441}", "к\u{0435}y"].randomElement(using: &random)! },
        { random in "<" + DisguisedName.secretNames.randomElement(using: &random)! + ">" },
        { random in "</" + ["password", "pin", "a"].randomElement(using: &random)! + ">" },
        { random in ["status=ok", "user=bob", "x: y", "a&#61;b", "%3D", "\\u003d", "https://x.example/?token=a"].randomElement(using: &random)! },
        { random in ["status", "count", "ok", "cache", "miss", "for", "the", "wrong", "my", "is"].randomElement(using: &random)! },
        { random in [" ", "  ", "|", ",", ";", "-", "_", ".", "/", "\t", "\u{00A0}", "\u{200B}", "\u{00AD}"].randomElement(using: &random)! },
    ]

    /// How the key is written: quotes, the separator after it, and what holds it. JSON that
    /// parses shows its member names by design, so no shape is JSON.
    static let shapes: [@Sendable (String, String) -> String] = [
        { k, v in "\"\(k)\": \(v)" }, { k, v in "\"\(k)\"=\(v)" }, { k, v in "\"\(k)\" : \(v)" }, { k, v in "\"\(k)\"\n: \(v)" },
        { k, v in "log \"\(k)\": \"\(v)\" done" }, { k, v in "\\\"\(k)\\\": \(v)" }, { k, v in "'\(k)': \(v)" },
        { k, v in "status=200 \"\(k)\":\(v)" }, { k, v in "\"status\": 1, \"\(k)\": \(v)" }, { k, v in "x `\(k)`=\(v)" },
    ]

    @Test("no generated quoted key shows a secret written in it or after it, on any path")
    func generatedKeys() {
        var random = SeededRandom(seed: 0x51_6B_E7)
        let policy = RedactionPolicy.default
        var checked = 0
        for _ in 0..<700 {
            let inside = RedactionCorpusPropertyTests.value(using: &random)
            var key: [String] = []
            for _ in 0..<Int.random(in: 1...4, using: &random) { key.append(Self.pieces.randomElement(using: &random)!(&random)) }
            key.insert(" " + inside, at: Int.random(in: 0...key.count, using: &random))
            let joined = key.joined().replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "`", with: "")
            // A key that holds a secret name or cannot be read is the point; a plain key on the
            // allowlist would be read on by design, and is checked by the usefulness tests.
            guard !policy.allowsTextKey(joined.unicodeScalars, in: policy.allowedTextKeys) else { continue }
            let value = RedactionCorpusPropertyTests.value(using: &random)
            let line = Self.shapes.randomElement(using: &random)!(joined, value)
            for (path, output) in RedactionCutRuleTests.everyPath(line) {
                #expect(!RedactionCorpusPropertyTests.leaks(inside, in: output), "\(path): \(line.debugDescription) -> \(output.debugDescription)")
                #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(path): \(line.debugDescription) -> \(output.debugDescription)")
            }
            checked += 1
        }
        #expect(checked > 600)
    }
}
