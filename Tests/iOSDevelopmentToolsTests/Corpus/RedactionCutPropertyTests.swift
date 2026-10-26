import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Free text has one cut point: from the first trigger, everything to the end of the text is
/// hidden. Generated triggers of every kind, in generated contexts, never let a value after them
/// show; text before them, and text with no trigger at all, is kept as it is, so the redactor
/// stays useful.
@Suite("Redaction corpus: cut property tests")
struct RedactionCutPropertyTests {
    let redactor = Redactor()

    /// Text with no trigger in it, written before a trigger.
    static let prefixes = [
        "", "INFO ", "status=200 ", "GET /v1/items ", "[x] ", "- ", "2026-10-19T12:00:00Z ", "method=GET ", "Merhaba d\u{FC}nya ",
        "line one\nline two\n", "count: 3, ", "path=/api/items ", "{\"status\":\"ok\"} ", "took 12:30 ms | ",
    ]

    /// Secret names as code and logs write them.
    static let secretNames = [
        "password", "Password", "PASSWORD", "passwd", "pwd", "secret", "token", "access_token", "refreshToken", "id_token", "api_key",
        "apiKey", "X-Api-Key", "key", "auth", "Authorization", "cookie", "Set-Cookie", "session", "sid", "otp", "pin", "cvv", "card",
        "iban", "ssn", "private_key", "client_secret", "signature", "DB_PASS", "dbPassword", "pass word",
    ]

    /// A trigger of each kind, made from a secret name where it takes one.
    static let triggers: [@Sendable (String) -> String] = [
        // A secret name, with or without a separator, quoted or not.
        { "\($0)=" }, { "\($0): " }, { "\($0) " }, { "\"\($0)\":\"" }, { "'\($0)' = '" }, { "--\($0) " }, { "\($0)\n" },
        { "export \($0.uppercased())=" }, { "\($0)\u{FF1D}" },
        // A secret name written as a value, also in markup and in a multipart header.
        { "name=\"\($0)\" value=" }, { "key='\($0)' " }, { "<key>\($0)</key>\n<string>" }, { "<string name=\"\($0)\">" },
        { "Content-Disposition: form-data; name=\"\($0)\"\r\n\r\n" }, { "{\"name\":\"\($0)\",\"value\":\"" },
        // A key that is not on the allowed text keys, plain or not.
        { _ in "user=" }, { _ in "x: " }, { _ in "note = \"" }, { _ in "{\"x\":\"" }, { _ in "[\"user\",\"" }, { _ in "user\u{FF1A}" },
        // A key that is not plain ASCII or has no letter, whatever name it shows.
        { _ in "p\u{430}ssword=" }, { _ in "Kullan\u{131}c\u{131}: " }, { _ in "\u{1F511}=" }, { _ in "user[name]=" }, { _ in "a$b=" },
        { _ in "\u{FF55}\u{FF53}\u{FF45}\u{FF52}=" }, { _ in "label=\u{41F}\u{430}\u{440}\u{43E}\u{43B}\u{44C} " },
        // A separator that is escaped or only looks like one.
        { _ in "user%3D" }, { _ in "user&#61;" }, { _ in "user%u003D" }, { _ in "user\u{A789}" }, { _ in "user \u{2254} " },
        // An ambiguous token.
        { _ in "us\u{200B}er " }, { _ in "p\u{430}ss " }, { _ in "ok\u{115F}x " }, { _ in "note=\"" }, { _ in "note='" },
        { _ in "(" }, { _ in "[" }, { _ in "{" }, { _ in "{\"a\": " },
    ]

    /// What separates the values after a trigger: they may be on the same line or any line below.
    static let joiners = [" ", "\n", "\r\n", "\u{2028}", " | ", ", ", "\n\n  ", " next=", "; status=200 ", "\n---\n", " -> "]

    @Test("no value after a generated trigger shows, on its line or any line below; the text before it is kept")
    func nothingAfterATriggerShows() {
        var random = SeededRandom(seed: 0xC07_0001)
        for _ in 0..<20_000 {
            let prefix = Self.prefixes.randomElement(using: &random)!
            let trigger = Self.triggers.randomElement(using: &random)!(Self.secretNames.randomElement(using: &random)!)
            let values = (0..<Int.random(in: 1...4, using: &random)).map { _ in RedactionCorpusPropertyTests.value(using: &random) }
            var input = prefix + trigger
            for value in values { input += value + Self.joiners.randomElement(using: &random)! }
            let output = redactor.redact(input)
            let leaked = values.filter { RedactionCorpusPropertyTests.leaks($0, in: output) }
            #expect(leaked.isEmpty, "\(input.debugDescription) -> \(output.debugDescription)")
            #expect(output.hasPrefix(prefix), "\(input.debugDescription) -> \(output.debugDescription)")
            #expect(output.hasSuffix(RedactionPolicy.replacement), "\(input.debugDescription) -> \(output.debugDescription)")
        }
    }

    @Test("a trigger anywhere in a long text hides everything after it, the lines below included")
    func cutRunsToTheEnd() {
        var random = SeededRandom(seed: 0xC07_0002)
        for _ in 0..<300 {
            let lines = (0..<40).map { "line \($0) status=200 method=GET path=/api/items/\($0)" }
            let at = Int.random(in: 0..<lines.count, using: &random)
            let trigger = Self.triggers.randomElement(using: &random)!(Self.secretNames.randomElement(using: &random)!)
            let value = RedactionCorpusPropertyTests.value(using: &random)
            var written = lines
            written[at] += " " + trigger + value
            let input = written.joined(separator: "\n")
            let output = redactor.redact(input)
            let before = lines[..<at].joined(separator: "\n")
            #expect(output.hasPrefix(before), "\(trigger.debugDescription)")
            #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(trigger.debugDescription)")
            for line in lines[(at + 1)...] { #expect(!output.contains(line), "\(trigger.debugDescription)") }
        }
    }

    @Test("text with no trigger is kept exactly", arguments: [
        "status=200 method=GET path=/api/items",
        "GET /v1/users status=200 duration_ms=12 count=3",
        "status: 200 method: GET path: /v1/orders/42",
        "retry 2 of 3, limit 50, offset 100, page 3",
        "{\"status\":\"ok\",\"count\":3}",
        "[{\"status\":200},[\"count\",3]]",
        "Order 1234 shipped to Istanbul at 12:30",
        "Request finished in 12 ms",
        "Kullan\u{131}c\u{131} giri\u{15F} yapt\u{131} status=200",
        "status=200\r\ncount=2\npath=/a\rmethod=GET\n\ncount=5\r\n",
        "loaded (3 items) [cache] {hit}",
        "status=\"it's done\" method='GET' path=`x`",
    ])
    func textWithoutTrigger(input: String) {
        #expect(redactor.redact(input) == input)
    }

    @Test("text whose keys the app allows is kept exactly; by default the first of them hides the rest", arguments: [
        "status=200 user=bob path=/api/items",
        "retry attempt=2 limit=50 offset=100 page=3 level=info",
        "login user=bob region=eu-west-1 build_number=512",
        "a=1\r\nb=2\rc=3\nd=4\r\n",
        "msg=\"it's done\" ok='yes' code=`x`",
        "{\"user\":\"bob\",\"list\":[[\"region\",\"eu\"]]}",
    ])
    func textWithAllowedKeys(input: String) {
        let allowing = Redactor(allowedTextKeys: [
            "user", "attempt", "limit", "offset", "page", "level", "region", "build_number", "a", "b", "c", "d", "e", "f", "g", "h", "msg", "ok",
            "code", "list",
        ])
        #expect(allowing.redact(input) == input)
        let output = redactor.redact(input)
        #expect(output != input && output.hasSuffix(RedactionPolicy.replacement), "\(output.debugDescription)")
    }

    /// Plain ASCII names that hold no secret word as a word.
    static let keptNames = [
        "user", "username", "name", "id", "user_id", "requestId", "X-Request-Id", "Content-Type", "status", "region", "lang", "page",
        "limit", "city", "order-id", "retry_after", "keynote", "authority", "bypass", "compass", "passport", "keyboard", "spinner", "author", "description", "app.version", "first name",
    ]
    static let keptValues = ["bob", "42", "eu-west-1", "ok", "Istanbul", "v2"]

    @Test("plain ASCII names that hold no secret word keep their value in structured input, and in text when allowed", arguments: keptNames)
    func keptNamesKeepTheirValue(name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? name
        // In text a key is one word: `first name=` is the key `name`.
        let allowing = Redactor(allowedTextKeys: [name, String(name.split(separator: " ").last!), "list"])
        for value in Self.keptValues {
            let json = "{\"\(name)\":\"\(value)\",\"list\":[{\"\(name)\":\"\(value)\"}]}"
            #expect(redactor.redact(body: Data(json.utf8), contentType: "application/json") == json)
            // JSON in a log line is read by the rule for keys in text, where a key with a space
            // is never allowed: it cuts the line at its opening quote.
            #expect(allowing.redact("log \(json)") == (name.contains(" ") ? "log {" + RedactionPolicy.replacement : "log \(json)"))
            let form = "a=1&\(encoded)=\(value)"
            #expect(redactor.redact(body: Data(form.utf8), contentType: "application/x-www-form-urlencoded") == form)
            #expect(allowing.redact("\(name)=\(value) done") == "\(name)=\(value) done")
            guard !RedactionPolicy.defaultAllowedTextKeys.contains(name) else { continue }
            // A member name that is not allowed cuts the line at its opening quote.
            #expect(redactor.redact("log \(json)") == "log {" + RedactionPolicy.replacement)
            #expect(!redactor.redact("\(name)=\(value) done").hasSuffix("\(value) done"))
        }
    }

    /// Words that hold no secret word, for names made of several of them.
    static let plainWords = ["user", "name", "order", "id", "city", "status", "page", "item", "count", "region", "build", "app", "version", "request", "color", "first", "last"]

    @Test("generated plain ASCII names keep their value in structured input and in text")
    func generatedPlainNamesKeepTheirValue() {
        var random = SeededRandom(seed: 0x9A1D_5E)
        for _ in 0..<600 {
            let words = (0..<Int.random(in: 1...3, using: &random)).map { _ in
                let word = Self.plainWords.randomElement(using: &random)!
                return Bool.random(using: &random) ? word.capitalized : word
            }
            let name = words.joined(separator: ["_", "-", ".", ""].randomElement(using: &random)!)
            let spaced = words.joined(separator: " ")
            let value = Self.keptValues.randomElement(using: &random)!
            let allowing = Redactor(allowedTextKeys: [name, "other"])
            for (json, key) in [("{\"\(name)\":\"\(value)\"}", name), ("{\"\(spaced)\":[\"\(value)\"]}", spaced)] {
                #expect(redactor.redact(body: Data(json.utf8), contentType: "application/json") == json)
                // A key with a space is never allowed in text.
                let expected = key.contains(" ") ? "got {" + RedactionPolicy.replacement : "got \(json) in 3 ms"
                #expect(allowing.redact("got \(json) in 3 ms") == expected)
            }
            let form = "a=1&\(name)=\(value)"
            #expect(redactor.redact(body: Data(form.utf8), contentType: "application/x-www-form-urlencoded") == form)
            for input in ["\(name)=\(value)", "log \(name): \(value) done", "\(name) = \(value), other=\(value)"] {
                #expect(allowing.redact(input) == input)
            }
        }
    }

    static let keyCharacters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.")
    /// Put inside a key, between two of its characters: letters outside ASCII, invisible
    /// characters, a mark, a full-width letter, brackets, punctuation, escapes, a filler and a
    /// control character. Each makes the key one that is not plain ASCII.
    static let insertions = [
        "\u{E9}", "\u{131}", "\u{430}", "\u{DF}", "\u{540D}", "\u{200B}", "\u{301}", "\u{FF53}", "[0]", "()", "$", "@", "/", "%41",
        "\\u0041", "\u{115F}", "\u{7F}", "\\", "\u{AD}",
    ]
    static let separators = ["=", ":", ": ", " = ", " : ", ":=", "=>", "\u{FF1D}", "\u{FF1A}", "\u{FE13}", "==", "\t=\t", " :\n  ", "=\n"]
    static let contexts: [(before: String, after: String)] = [
        ("", ""), ("INFO ", " next"), ("status=200 ", " count=3"), ("a, ", ", b"), ("[x] ", "\nline2"), ("- ", ""),
        ("2026-10-19T12:00:00Z ", ""), ("| ", " |"), ("x;", ";y"),
    ]

    /// Put anywhere into a name made for structured input: the insertions above and escapes and
    /// separators that structured input reads in other ways.
    static let nameInsertions = insertions + ["&#65;", "\u{2028}"]

    /// A name of 1 to 10 name characters, with something put into a third of them, for the
    /// property tests of structured input.
    static func name(using random: inout SeededRandom) -> String {
        var name = String((0..<Int.random(in: 1...10, using: &random)).map { _ in keyCharacters.randomElement(using: &random)! })
        if Int.random(in: 0..<3, using: &random) == 0 {
            let offset = Int.random(in: 0...name.count, using: &random)
            name.insert(contentsOf: nameInsertions.randomElement(using: &random)!, at: name.index(name.startIndex, offsetBy: offset))
        }
        return name
    }

    /// A key of 2 to 10 name characters, with something put inside it in half of them.
    static func key(using random: inout SeededRandom) -> (key: String, isPlain: Bool) {
        var key = String((0..<Int.random(in: 2...10, using: &random)).map { _ in keyCharacters.randomElement(using: &random)! })
        guard Bool.random(using: &random) else { return (key, true) }
        let offset = Int.random(in: 1..<key.count, using: &random)
        key.insert(contentsOf: insertions.randomElement(using: &random)!, at: key.index(key.startIndex, offsetBy: offset))
        return (key, false)
    }

    @Test("a generated key that is not plain ASCII hides the rest of the text; a plain one that names no secret keeps its value when allowed")
    func generatedKeys() {
        var random = SeededRandom(seed: 0xC3C3_0001)
        let policy = RedactionPolicy.default
        var hidden = 0
        var kept = 0
        for _ in 0..<20_000 {
            let (key, isPlain) = Self.key(using: &random)
            // A key made only of separators and digits is no name; the rule for it is checked elsewhere.
            guard key.contains(where: \.isLetter), key.first.map({ $0.isLetter || $0.isNumber }) == true else { continue }
            let context = Self.contexts.randomElement(using: &random)!
            let separator = Self.separators.randomElement(using: &random)!
            if isPlain, !policy.isSensitive(name: key), separator.unicodeScalars.allSatisfy(\.isASCII) {
                let value = Self.keptValues.randomElement(using: &random)!
                let input = context.before + key + separator + value + context.after
                #expect(Redactor(allowedTextKeys: [key]).redact(input) == input, "\(input.debugDescription)")
                let output = redactor.redact(input)
                // A `:` between two digits is part of a time, not a separator.
                let isTime = separator == ":" && key.last?.isNumber == true && value.first?.isNumber == true
                if !RedactionPolicy.defaultAllowedTextKeys.contains(key), !isTime {
                    #expect(output.hasPrefix(context.before) && output.hasSuffix(RedactionPolicy.replacement), "\(input.debugDescription) -> \(output.debugDescription)")
                }
                kept += 1
            } else {
                let value = RedactionCorpusPropertyTests.value(using: &random)
                let input = context.before + key + separator + value + context.after
                let output = redactor.redact(input)
                #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(input.debugDescription) -> \(output.debugDescription)")
                #expect(output.hasPrefix(context.before), "\(input.debugDescription) -> \(output.debugDescription)")
                hidden += 1
            }
        }
        #expect(hidden > 8_000 && kept > 4_000, "\(hidden) hidden, \(kept) kept")
    }

    // A plain name that holds a secret word as a word hides its value even when it only
    // describes the secret: telling the two apart would take a list of exceptions.
    @Test("names that hold a secret word as a word hide their value in structured input and in text", arguments: [
        "passwordHint", "token_type", "pin_length", "pass_count", "password_policy", "keyPath", "card_type", "auth_method",
        "otp_enabled", "cookie_policy", "secret_name", "signature_version", "session_start", "sessionCount",
    ])
    func describingNamesHideTheirValue(name: String) {
        #expect(redactor.redact(body: Data("{\"\(name)\":\"bob\"}".utf8), contentType: "application/json") == "{\"\(name)\":\"[REDACTED]\"}")
        #expect(redactor.redact(body: Data("\(name)=bob".utf8), contentType: "application/x-www-form-urlencoded") == "\(name)=[REDACTED]")
        #expect(!redactor.redact("status=200 \(name)=bob count=3").contains("bob"))
    }
}
