import Foundation
import Testing
@testable import iOSDevelopmentTools

// The tests of the shared redaction corpus that earlier versions of this package ran, from its
// own reviews and those of iOSDevelopmentTools, where the iOSSecurityTools corpus that replaced
// them has none of the same name. Every input that got past an earlier rule stays a test: where
// the rules of iOSSecurityTools cut the text at another place, the test checks that the secret
// does not show, and the outputs they now give.

/// Quotes over lines, quotes inside quotes of another kind and quoted keys, from the eleventh and
/// twelfth reviews of the corpus.
@Suite("Redaction corpus: earlier quote reviews")
struct RedactionEarlierQuoteTests {
    let redactor = Redactor()
    static let secret = "QZ9WK7RXV"


    static func expectHidden(_ text: String, _ secret: String = secret, sourceLocation: SourceLocation = #_sourceLocation) {
        for (path, output) in RedactionCutRuleTests.everyPath(text) {
            #expect(!output.contains(secret), "\(path): \(text.debugDescription) -> \(output.debugDescription)", sourceLocation: sourceLocation)
        }
    }

    static let prefixes = ["", "msg ", "status=200 ", "user logged in ", "count=3 path=/a ", "a < b and "]

    static let quotes = ["\"", "'", "`", "\\\""]

    static let lineBreaks = ["\n", "\r\n", "\r", "\n \n"]

    static let separators = [": ", "=", " = ", ":=", "=>", ":\n"]

    private static let word = -1

    private static let space = -2

    /// Whether the quote at token `i` can open: a `'` only where no word ends right before it.
    private static func opens(_ tokens: [Int], at i: Int) -> Bool {
        tokens[i] != 1 || i == 0 || tokens[i - 1] != word
    }

    private static func oneSlotLeavesOpen(_ tokens: [Int]) -> Bool {
        var open: Int?
        for (i, token) in tokens.enumerated() where token >= 0 {
            if let kind = open {
                if kind == token { open = nil }
            } else if opens(tokens, at: i) {
                open = token
            }
        }
        return open != nil
    }

    private static func eachKindLeavesOpen(_ tokens: [Int]) -> Bool {
        var open = Set<Int>()
        for (i, token) in tokens.enumerated() where token >= 0 {
            if open.contains(token) {
                open.remove(token)
            } else if opens(tokens, at: i) {
                open.insert(token)
            }
        }
        return !open.isEmpty
    }

    /// The eleventh review's inputs: one quote slot let a quote of one kind inside a quote of
    /// another (`'x "y'`, `"x \"y"`, `"x 'y"`) open nothing, so it did not cut the text although
    /// it did not close on its line, and the value on the next line showed. The inner quote is
    /// still open where the outer one closes, so the quotes overlap and the text is cut at the
    /// outer one.
    static let nestedQuoteInputs = [
        ("status=x \"y\nhunter2Zq\" ok", "status=x [REDACTED]", "hunter2Zq"),
        ("status='x \"y'\nhunter2Zq\" ok", "status=[REDACTED]", "hunter2Zq"),
        ("status=`x \"y`\nhunter2Zq\" ok", "status=[REDACTED]", "hunter2Zq"),
        ("status=\"x \\\"y\"\nhunter2Zq\\\" ok", "status=[REDACTED]", "hunter2Zq"),
        ("status=\"x 'y\"\nhunter2Zq' ok", "status=[REDACTED]", "hunter2Zq"),
        ("'\"note'\nQx31\": 1", "[REDACTED]", "Qx31"),
    ]

    /// The twelfth review's inputs: with each kind of quote read on its own, a second quote of the
    /// inner kind after the outer one closed (`'x "y' "c`) was read as closing the inner quote, so
    /// the quote it opens over the line break was taken for closed and the value on the next line
    /// showed. The inner quote is still open where the outer one closes, so the quotes overlap
    /// and the text is cut at the outer one.
    static let overlappingQuoteInputs = [
        ("status='x \"y' \"c\nhunter2Zq\" ok", "status=[REDACTED]", "hunter2Zq"),
        ("status=200 `a\"b` \"c\nhunter2Zq\"", "status=200 [REDACTED]", "hunter2Zq"),
        ("status=\"x 'y\" 'c\nhunter2Zq' ok", "status=[REDACTED]", "hunter2Zq"),
        ("status=`x \"y` \"c\nhunter2Zq\" ok", "status=[REDACTED]", "hunter2Zq"),
        ("status=\"x \\\"y\" \\\"c\nhunter2Zq\\\" ok", "status=[REDACTED]", "hunter2Zq"),
        ("'\"note' \"a\nQx31\": 1", "[REDACTED]", "Qx31"),
        ("status='x \"y' \"c\r\nhunter2Zq\" ok", "status=[REDACTED]", "hunter2Zq"),
        ("msg 'x \"y' \"c\nhunter2Zq\" ok", "msg [REDACTED]", "hunter2Zq"),
        ("ad='Ayşe \"q' \"c\nhunter2Zq\" ok", "ad=[REDACTED]", "hunter2Zq"),
        ("x 'y \"z' \"c\nhunter2Zq\" ok", "x [REDACTED]", "hunter2Zq"),
    ]

    @Test("a quoted key on the allowlist keeps its value", arguments: [
        "\"status\": 200, \"count\": 3", "'status': 'ok'", "`status`: ok", "\"status\"=\"ok\"", "\"method\" : GET",
    ])
    func allowedQuotedKeys(input: String) {
        #expect(redactor.redact(input) == input)
        #expect(Redactor(allowedTextKeys: ["user"]).redact("\"user\": \"bob\"") == "\"user\": \"bob\"")
    }

    // An escaped quote outside JSON is cut at its backslash: a backslash before anything but white
    // space is an escape. Escaped quotes in JSON written into the text are read by its parser.
    @Test("a backslash before a quote cuts free text at the start of its word", arguments: [
        ("it\\'s ok", "[REDACTED]"), ("\"a \\\"b\\\" c\" done", "\"a [REDACTED]"),
        ("status=\"a\\\"b\\\"\" count=1", "status=\"[REDACTED]"),
    ])
    func escapedQuotes(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
        #expect(redactor.redact(body: Data(input.utf8), contentType: "text/plain") == expected)
    }

    @Test("quotes that overlap cut the text at the earliest one, also when a quote of the inner kind follows", arguments: overlappingQuoteInputs)
    func overlappingQuotes(input: String, expected: String, secret: String) throws {
        #expect(redactor.redact(input) == expected)
        #expect(Redactor(allowedTextKeys: ["ad"]).redact(input) == expected)
        #expect(redactor.redact(body: Data(input.utf8), contentType: "text/plain") == expected)
        let json = try JSONSerialization.data(withJSONObject: ["status": input])
        let output = redactor.redact(body: json, contentType: "application/json")
        let object = try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: String]
        #expect(object?["status"] == expected, "\(output)")
        Self.expectHidden(input, secret)
    }

    @Test("quotes that overlap on one line cut the text there", arguments: [
        ("'a \"b' c\" done", "[REDACTED]"), ("msg \"a 'b\" c' done", "msg [REDACTED]"), ("x `a 'b` c' d", "x [REDACTED]"),
        ("'say \"don't\" ok'", "[REDACTED]"), ("status='x \"y' ok \"z\" done", "status=[REDACTED]"),
    ])
    func overlappingQuotesOnOneLine(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
        #expect(redactor.redact(body: Data(input.utf8), contentType: "text/plain") == expected)
    }

    @Test("a quote inside a quote of another kind that does not close on its line cuts the text at it", arguments: nestedQuoteInputs)
    func quotesInsideOtherQuotes(input: String, expected: String, secret: String) throws {
        #expect(redactor.redact(input) == expected)
        #expect(redactor.redact(body: Data(input.utf8), contentType: "text/plain") == expected)
        let json = try JSONSerialization.data(withJSONObject: ["a": input])
        let output = redactor.redact(body: json, contentType: "application/json")
        let object = try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: String]
        #expect(object?["a"] == expected, "\(output)")
        Self.expectHidden(input, secret)
    }

    @Test("the tenth review's quotes over lines are cut in a text/plain body and a JSON string too")
    func unclosedQuotesInBodies() {
        let text = "msg \"abc\nhunter2Zq\" done"
        #expect(redactor.redact(body: Data(text.utf8), contentType: "text/plain") == "msg [REDACTED]")
        let json = try! JSONSerialization.data(withJSONObject: ["a": text])
        #expect(redactor.redact(body: json, contentType: "application/json") == #"{"a":"msg [REDACTED]"}"#)
    }

    /// A first line of quotes of the four kinds that the generator writes, words and spaces, read
    /// as the two earlier designs read it: one quote open at a time, the quotes inside it opening
    /// nothing; and each kind on its own. When either reading leaves a quote open at the line
    /// break, the value on the next line never shows.
    @Test("no value after a line that either earlier reading of quotes leaves open shows on any path", arguments: 0..<4)
    func linesEitherReadingLeavesOpen(seed: Int) {
        var random = SeededRandom(seed: 0x1D_3F00 + UInt64(seed))
        var checked = 0
        for _ in 0..<400 {
            // A token is the index of a quote in `quotes`, `word` or `space`.
            let tokens: [Int] = (0..<Int.random(in: 2...7, using: &random)).map { _ in
                Bool.random(using: &random) ? Int.random(in: 0..<Self.quotes.count, using: &random) : [Self.word, Self.space].randomElement(using: &random)!
            }
            guard Self.oneSlotLeavesOpen(tokens) || Self.eachKindLeavesOpen(tokens) else { continue }
            checked += 1
            let value = RedactionCorpusPropertyTests.value(using: &random)
            let line = tokens.map { token in
                switch token {
                case Self.word: ["x", "note", "ok"].randomElement(using: &random)!
                case Self.space: [" ", "  "].randomElement(using: &random)!
                default: Self.quotes[token]
                }
            }.joined()
            let text = Self.prefixes.randomElement(using: &random)! + ["", "status="].randomElement(using: &random)! + line
                + Self.lineBreaks.randomElement(using: &random)! + value + [" ok", "\"", "'", ": 1"].randomElement(using: &random)!
            for (path, output) in RedactionCutRuleTests.everyPath(text) {
                #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(path): \(text.debugDescription) -> \(output.debugDescription)")
            }
        }
        #expect(checked > 100)
    }

    @Test("no value after quotes that overlap and a quote of the inner kind opened over the line break shows on any path", arguments: 0..<4)
    func overlappingQuotesOverLines(seed: Int) {
        var random = SeededRandom(seed: 0x1C_3F00 + UInt64(seed))
        for _ in 0..<150 {
            let value = RedactionCorpusPropertyTests.value(using: &random)
            let outer = Self.quotes.randomElement(using: &random)!
            let inner = Self.quotes.filter { $0 != outer }.randomElement(using: &random)!
            // `<outer><inner…><outer> <inner>…`, then the line break, the value and the inner quote:
            // read kind by kind, the second inner quote closes the first one.
            let opening = outer + ["", "x ", "note "].randomElement(using: &random)! + inner + ["y", "note", ""].randomElement(using: &random)! + outer
                + [" ", "  ", " ok "].randomElement(using: &random)! + inner + ["c", "a", ""].randomElement(using: &random)!
            let text = Self.prefixes.randomElement(using: &random)! + ["", "status="].randomElement(using: &random)! + opening
                + Self.lineBreaks.randomElement(using: &random)! + value + inner + [" ok", "", ": 1", "\nnext"].randomElement(using: &random)!
            for (path, output) in RedactionCutRuleTests.everyPath(text) {
                #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(path): \(text.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    @Test("neither a quoted key that is not allowed nor its value shows on any path", arguments: 0..<4)
    func quotedKeysOnOneLine(seed: Int) {
        var random = SeededRandom(seed: 0x18_3E00 + UInt64(seed))
        for _ in 0..<150 {
            let key = RedactionCorpusPropertyTests.value(using: &random)
            let value = RedactionCorpusPropertyTests.value(using: &random)
            let quote = Self.quotes.randomElement(using: &random)!
            let words = [key, ["", "note", "a b"].randomElement(using: &random)!].shuffled(using: &random).joined(separator: " ")
            let shown = ["", "\(quote)status\(quote): 200, "].randomElement(using: &random)!
            let text = Self.prefixes.randomElement(using: &random)! + shown + quote + words + quote
                + Self.separators.randomElement(using: &random)! + [value, "\"\(value)\"", "'\(value)'"].randomElement(using: &random)!
            for (path, output) in RedactionCutRuleTests.everyPath(text) {
                #expect(!RedactionCorpusPropertyTests.leaks(key, in: output), "\(path): \(text.debugDescription) -> \(output.debugDescription)")
                #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(path): \(text.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    @Test("no quoted key with a line break in it shows on any path", arguments: 0..<4)
    func quotedKeysOverLines(seed: Int) {
        var random = SeededRandom(seed: 0x18_3B00 + UInt64(seed))
        for _ in 0..<150 {
            let value = RedactionCorpusPropertyTests.value(using: &random)
            let quote = Self.quotes.randomElement(using: &random)!
            let lineBreak = Self.lineBreaks.randomElement(using: &random)!
            let words = ["note", "a", "", "status", value].shuffled(using: &random)
            let split = Int.random(in: 0...words.count, using: &random)
            let key = words[..<split].joined(separator: " ") + lineBreak + words[split...].joined(separator: " ")
            let text = Self.prefixes.randomElement(using: &random)! + quote + key + quote + Self.separators.randomElement(using: &random)! + "1"
            for (path, output) in RedactionCutRuleTests.everyPath(text) {
                #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(path): \(text.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    @Test("no value after a quote opened inside a quote of another kind and closed on a later line shows on any path", arguments: 0..<4)
    func quotesInsideOtherQuotesOverLines(seed: Int) {
        var random = SeededRandom(seed: 0x1B_3F00 + UInt64(seed))
        for _ in 0..<150 {
            let value = RedactionCorpusPropertyTests.value(using: &random)
            let outer = Self.quotes.randomElement(using: &random)!
            let inner = Self.quotes.filter { $0 != outer }.randomElement(using: &random)!
            // The inner quote opens at the start of a word, right after the outer one or after a
            // word and a space; the outer one closes on the first line.
            let opening = outer + ["", "x ", "note "].randomElement(using: &random)! + inner + ["y", "note", ""].randomElement(using: &random)! + outer
            let text = Self.prefixes.randomElement(using: &random)! + ["", "status="].randomElement(using: &random)! + opening
                + Self.lineBreaks.randomElement(using: &random)! + value + inner + [" ok", "", ": 1", "\nnext"].randomElement(using: &random)!
            for (path, output) in RedactionCutRuleTests.everyPath(text) {
                #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(path): \(text.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    @Test("no value after a quote that closes on a later line shows on any path", arguments: 0..<4)
    func quotesOverLines(seed: Int) {
        var random = SeededRandom(seed: 0x18_3F00 + UInt64(seed))
        for _ in 0..<150 {
            let value = RedactionCorpusPropertyTests.value(using: &random)
            let quote = Self.quotes.randomElement(using: &random)!
            let lines = (0..<Int.random(in: 1...3, using: &random)).map { _ in ["abc", "line", "ok fine", ""].randomElement(using: &random)! }
            let inner = (lines + [value]).joined(separator: Self.lineBreaks.randomElement(using: &random)!)
            let text = Self.prefixes.randomElement(using: &random)! + ["", "status="].randomElement(using: &random)! + quote + inner + quote
                + [" done", "", "\nnext"].randomElement(using: &random)!
            for (path, output) in RedactionCutRuleTests.everyPath(text) {
                #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(path): \(text.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

}
