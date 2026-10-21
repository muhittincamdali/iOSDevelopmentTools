import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Section 6 of the redaction spec: the detectors bridge line separators. VT, FF, U+0085, U+2028
/// and U+2029 count as white space when a card number, an IBAN, an email address or a token is
/// matched, and a cut that falls inside one moves back to its start. The eighteenth review found
/// that the card and IBAN detectors did not read across them: each cuts free text, so
/// `paid 4111 1111 1111` and U+2028 before `1111` was stored as `paid 4111 1111 1111[REDACTED]`,
/// with 12 of the 16 digits, and `DE89 3704 0044 0532 0130` and U+2029 before `00` kept 20 of the
/// 22 characters, in free text, JSON strings, plain-text bodies and LogStore lines alike.
@Suite("Redaction corpus: line separators inside findings")
struct RedactionBridgedLineBreakTests {
    static let separators = ["\u{0B}", "\u{0C}", "\u{85}", "\u{2028}", "\u{2029}"]

    /// Findings with `{S}` where a line separator is written; the review's two first.
    static let values = [
        "4111 1111 1111{S}1111", "DE89 3704 0044 0532 0130{S}00", "4111{S}1111 1111 1111", "4242 4242{S}4242 4242",
        "4111{S}1111{S}1111{S}1111", "4111-1111-1111{S}1111", "5555 5555 5555 {S}4444", "3782 822463{S}10005",
        "DE89{S}3704 0044 0532 0130 00", "GB82 WEST 1234 5698 7654{S}32", "NL91 ABNA 0417{S}1643 00",
        "alice.smith{S}@example.com", "alice.smith@example{S}.com", "eyJhbGciOiJIUzI1NiJ9.eyJzdWIi{S}OiIxMjM0In0.c2lnbmF0dXJl",
        "eyJhbGciOiJIUzI1NiJ9{S}.eyJzdWIiOiIxMjM0In0.c2lnbmF0dXJl", "0123456789abcdef{S}0123456789abcdef",
        "Zk9vYmFyQmF6UXV1eDEyMzQ1Njc4{S}OTBhYmNkZWZnaA",
    ]

    static var cases: [(String, String)] {
        separators.flatMap { separator in values.map { ($0, separator) } }
    }

    static func written(_ template: String, _ separator: String) -> String {
        template.replacingOccurrences(of: "{S}", with: separator)
    }

    /// The parts of a value between its separators, which none of the places may show.
    static func fragments(_ value: String) -> [String] {
        value.unicodeScalars.split { " -\t\u{0B}\u{0C}\u{85}\u{2028}\u{2029}".unicodeScalars.contains($0) }.map { String($0) }
            .filter { $0.unicodeScalars.count >= 4 }
    }

    static func digitCount(_ text: String) -> Int {
        text.unicodeScalars.filter { ("0"..."9").contains($0) }.count
    }

    /// Every place free text is read, with the digits each writes around the line.
    static func places(_ line: String) -> [(String, String, Int)] {
        let header = RedactionPolicy.default.redact(headers: [HTTPHeader(name: "User-Agent", value: "MyApp/1.0 " + line)])[0].value
        let escaped = line.unicodeScalars.map { $0.value < 0x20 || $0.value == 0x85 ? String(format: "\\u%04x", $0.value) : String($0) }.joined()
        let json = Redactor().redact(body: Data("{\"note\":\"\(escaped)\"}".utf8), contentType: "application/json")
        return RedactionWrittenURLTests.places(line).map { ($0.0, $0.1, $0.0 == "allowed key" ? 3 : 0) } + [
            ("User-Agent", header, 2), ("JSON with escapes", json, 0), ("LogStore.redacted", LogStore.redacted(line, with: .default), 0),
        ]
    }

    @Test("the finding is hidden from its start in free text, a plain-text body and a log line", arguments: cases)
    func hiddenFromStart(template: String, separator: String) {
        let line = "paid " + Self.written(template, separator) + " ok"
        #expect(Redactor().redact(line) == "paid [REDACTED]", "\(line.debugDescription)")
        #expect(Redactor().redact(body: Data(line.utf8), contentType: "text/plain") == "paid [REDACTED]", "\(line.debugDescription)")
        #expect(LogStore.redacted(line, with: .default) == "paid [REDACTED]", "\(line.debugDescription)")
    }

    @Test("no part of the finding shows in any place free text is read", arguments: cases)
    func noPartShows(template: String, separator: String) {
        let value = Self.written(template, separator)
        for (place, output, context) in Self.places("paid " + value + " ok") where !output.hasPrefix("[body omitted") {
            #expect(Self.digitCount(output) <= context, "\(place): \(value.debugDescription) -> \(output.debugDescription)")
            for fragment in Self.fragments(value) {
                #expect(!output.contains(fragment), "\(place): \(value.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    @Test("the token after Bearer and a line separator is found", arguments: separators)
    func bearer(separator: String) {
        let span = NormalizedText(Array("Bearer\(separator)Zk9vYmFyQmF6 ok".unicodeScalars), compatibility: CompatibilityText(length: 20)).bearerSpans()
        #expect(span.map { $0.start..<$0.end } == [7..<19])
        for (place, output, _) in Self.places("auth: Bearer\(separator)Zk9vYmFyQmF6 ok") {
            #expect(!output.contains("Zk9vYmFyQmF6"), "\(place): \(output.debugDescription)")
        }
    }

    // A line feed or a carriage return written as such ends a line, and a finding with it; the
    // text before a line separator that holds no finding keeps it. A run of more than six digits
    // beside another group is no card group, as the guide says under "What it does not find".
    @Test("LF and CR end a finding, a long run of digits is no group, and text before a separator without a finding stays")
    func lineEnds() {
        #expect(Redactor().redact("paid 4111 1111 1111\n1111 ok") == "paid 4111 1111 1111\n1111 ok")
        #expect(Redactor().redact("paid 4111 1111 1111\r1111 ok") == "paid 4111 1111 1111\r1111 ok")
        #expect(Redactor().redact("mail alice.smith\n@example.com") == "mail alice.smith\n@example.com")
        #expect(Redactor().redact("paid 411111111111 1111 ok") == "paid 411111111111 1111 ok")
        for separator in Self.separators {
            #expect(Redactor().redact("paid 411111111111\(separator)1111 ok") == "paid 411111111111[REDACTED]")
            #expect(Redactor().redact("order 1234\(separator)shipped") == "order 1234[REDACTED]")
            #expect(Redactor().redact("status=200\(separator)ok") == "status=200[REDACTED]")
            let afterCard = Redactor().redact("paid 4111 1111 1111 1111\(separator)ok")
            #expect(afterCard.hasPrefix("paid [REDACTED]") && Self.digitCount(afterCard) == 0, "\(afterCard.debugDescription)")
            #expect(Redactor().redact("done\(separator)") == "done\(separator)")
        }
    }

    // A finding does not start or end with a separator: the span of the detector covers the
    // characters of the finding only.
    @Test("a finding read across a separator neither starts nor ends with one", arguments: separators)
    func findingEdges(separator: String) {
        for (text, expected) in [
            ("x \(separator)4111 1111 1111 1111\(separator) y", "4111 1111 1111 1111"),
            ("x DE89 3704 0044 0532 0130\(separator)00\(separator) y", "DE89 3704 0044 0532 0130\(separator)00"),
            ("x \(separator)alice.smith\(separator)@example.com\(separator) y", "alice.smith\(separator)@example.com"),
            ("x 0123456789abcdef\(separator)0123456789abcdef\(separator) y", "0123456789abcdef\(separator)0123456789abcdef"),
        ] {
            let scalars = Array(text.unicodeScalars)
            let found = RedactionPolicy.default.detectorSpans(in: NormalizedText(scalars, compatibility: CompatibilityText(length: scalars.count)))
            let spans = RedactionPolicy.merged(found)
            #expect(spans.map { String(String.UnicodeScalarView(scalars[$0.start..<$0.end])) } == [expected], "\(text.debugDescription)")
        }
    }
}

/// Generated card numbers and IBANs with line separators at generated places: none of their
/// characters may show.
@Suite("Redaction corpus: generated findings split by line separators")
struct RedactionBridgedLineBreakPropertyTests {
    static let blanks = [" ", "-", "\t", " \u{2028}", "\u{2029} "]

    /// A number of `length` digits whose last digit makes the Luhn check pass.
    static func cardNumber(length: Int, using random: inout SeededRandom) -> [UInt8] {
        var digits = (0..<(length - 1)).map { _ in UInt8.random(in: 0...9, using: &random) }
        digits[0] = UInt8.random(in: 2...6, using: &random)
        var sum = 0
        for (position, digit) in digits.reversed().enumerated() {
            var value = Int(digit)
            if position % 2 == 0 {
                value *= 2
                if value > 9 { value -= 9 }
            }
            sum += value
        }
        return digits + [UInt8((10 - sum % 10) % 10)]
    }

    /// The characters split into groups of `sizes`, joined by separators of which at least one is
    /// a line separator.
    static func written(_ characters: [String], groupSizes: () -> Int, separator: (Bool) -> String) -> String {
        var groups: [String] = []
        var index = 0
        while index < characters.count {
            let size = min(groupSizes(), characters.count - index)
            groups.append(characters[index..<(index + size)].joined())
            index += size
        }
        let lineBreakAt = groups.count > 1 ? Int.random(in: 1..<groups.count) : 0
        var text = groups[0]
        for (k, group) in groups.enumerated().dropFirst() { text += separator(k == lineBreakAt) + group }
        return text
    }

    @Test("a generated card number split by line separators shows none of its digits")
    func cards() throws {
        var random = SeededRandom(seed: 0x2028_0085)
        for _ in 0..<160 {
            let digits = Self.cardNumber(length: Int.random(in: 13...19, using: &random), using: &random)
            #expect(NormalizedText.passesLuhn(digits))
            let characters = digits.map { String($0) }
            let separators = RedactionBridgedLineBreakTests.separators
            let value = Self.written(characters, groupSizes: { Int.random(in: 1...6, using: &random) }) { isLineBreak in
                isLineBreak ? separators.randomElement(using: &random)! : (Self.blanks + separators).randomElement(using: &random)!
            }
            let line = "paid " + value + " ok"
            #expect(Redactor().redact(line) == "paid [REDACTED]", "\(line.debugDescription)")
            for (place, output, context) in RedactionBridgedLineBreakTests.places(line) where !output.hasPrefix("[body omitted") {
                #expect(RedactionBridgedLineBreakTests.digitCount(output) <= context, "\(place): \(line.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    @Test("a generated IBAN split by line separators shows none of its characters")
    func ibans() throws {
        var random = SeededRandom(seed: 0x2029_000B)
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)
        for _ in 0..<120 {
            let country = ["DE", "GB", "FR", "NL", "TR"].randomElement(using: &random)!
            let bank = country == "GB" || country == "NL" ? (0..<4).map { _ in letters.randomElement(using: &random)! } : []
            let account = (0..<Int.random(in: 12...20, using: &random)).map { _ in String(Int.random(in: 0...9, using: &random)) }
            let basic = bank + account
            let remainder = NormalizedText.ibanRemainder(ArraySlice(Array((country + "00" + basic.joined()).utf8)))
            let check = String(format: "%02d", 98 - remainder)
            let characters = (country + check).map(String.init) + basic
            try #require(NormalizedText.ibanRemainder(ArraySlice(Array(characters.joined().utf8))) == 1)
            let separators = RedactionBridgedLineBreakTests.separators
            let value = Self.written(characters, groupSizes: { 4 }) { isLineBreak in
                isLineBreak || Bool.random(using: &random) ? separators.randomElement(using: &random)! : " "
            }
            let line = "paid " + value + " ok"
            #expect(Redactor().redact(line) == "paid [REDACTED]", "\(line.debugDescription)")
            for (place, output, context) in RedactionBridgedLineBreakTests.places(line) where !output.hasPrefix("[body omitted") {
                #expect(RedactionBridgedLineBreakTests.digitCount(output) <= context, "\(place): \(line.debugDescription) -> \(output.debugDescription)")
                #expect(!output.contains(country + check), "\(place): \(line.debugDescription) -> \(output.debugDescription)")
            }
        }
    }
}
