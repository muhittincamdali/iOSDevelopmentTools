import Foundation
import Testing
@testable import iOSDevelopmentTools

/// One source for the safe alphabet: free text is judged on the same compatibility form the
/// scanner reads. A letter or digit whose form holds ASCII punctuation or a character outside
/// the alphabet (`🄁` is `0,`, `⒈` is `1.`, `⑴` is `(1)`, `½` is `1⁄2`) cuts the text, so its
/// punctuation cannot end a key in front of an allowed one.
@Suite("Redaction corpus: the compatibility form of the safe alphabet")
struct RedactionCompatibilityFormTests {
    let redactor = Redactor()

    /// U+1F101 to U+1F10A, digits with a comma (`0,` to `9,`): the only scalars the review found
    /// that let an allowed key after them keep its value.
    static let digitsWithComma = (0x1F101...0x1F10A).compactMap(Unicode.Scalar.init).map(String.init)

    /// The review's shapes: the scalar right before an allowed key, also after a letter, twice,
    /// before `:` and before a quoted key.
    static let shapes: [@Sendable (String) -> String] = [
        { "\($0)status=hunter2Zq" }, { "x\($0)status=hunter2Zq" }, { "\($0)count: hunter2Zq" }, { "\($0)path=hunter2Zq" },
        { "\($0)method=hunter2Zq" }, { "\($0)\"status\": hunter2Zq" }, { "\($0)\($0)status=hunter2Zq" },
    ]

    @Test("a digit with a comma before an allowed key hides the value on every path", arguments: digitsWithComma)
    func digitsWithCommaBeforeKeys(scalar: String) {
        for shape in Self.shapes {
            let input = shape(scalar)
            for (path, output) in RedactionCutRuleTests.everyPath(input) {
                #expect(!output.contains("hunter2Zq"), "\(path): \(input.debugDescription) -> \(output.debugDescription)")
            }
        }
        #expect(redactor.redact("\(scalar)status=hunter2Zq") == "[REDACTED]")
        #expect(redactor.redact("x\(scalar)status=hunter2Zq") == "x[REDACTED]")
    }

    @Test("the review's inputs in a JSON string, a form value and a text/plain body hide the value")
    func reviewBodies() {
        let json = redactor.redact(body: Data(#"{"note":"🄁count: X1hunter2Zq"}"#.utf8), contentType: "application/json")
        #expect(json == #"{"note":"[REDACTED]"}"#)
        let form = redactor.redact(body: Data("note=%F0%9F%84%81path%3Dhunter2Zq".utf8), contentType: "application/x-www-form-urlencoded")
        #expect(form == "note=[REDACTED]")
        #expect(redactor.redact(body: Data("🄁status=hunter2Zq".utf8), contentType: "text/plain") == "[REDACTED]")
    }

    // A space or an apostrophe in the compatibility form cuts the text too (`ﷺ` holds spaces,
    // `ŉ` a modifier apostrophe).
    @Test("a letter or digit whose compatibility form holds punctuation, a space or a symbol cuts the text", arguments: [
        "\u{1F101}", "\u{1F10A}", "\u{2488}", "\u{2474}", "\u{00BD}", "\u{215F}", "\u{33A1}", "\u{FDFA}", "\u{0149}",
    ])
    func formsWithPunctuation(scalar: String) {
        #expect(redactor.redact("ok \(scalar) hunter2Zq") == "ok [REDACTED]")
    }

    @Test("a letter or digit whose compatibility form is letters and digits is text", arguments: [
        "x\u{00B2} + y\u{00B2}", "\u{2460} first", "\u{FB01}le", "\u{2167} chapter", "\u{FF46}\u{FF55}\u{FF4C}\u{FF4C}", "\u{2081}\u{2082}",
        "\u{3007} zero", "\u{017F}tatus ok", "\u{1D400}\u{1D401}",
    ])
    func formsOfLetters(text: String) {
        #expect(redactor.redact(text) == text)
    }

    /// Whether a scalar is read as an ASCII space: a space that compatibility normalization reads
    /// as one, which the safe alphabet holds, so `status=` after it is a key.
    static func isSpace(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.generalCategory == .spaceSeparator && String(scalar).decomposedStringWithCompatibilityMapping == " "
    }

    /// Every scalar from U+0021 to U+3FFFF outside ASCII but the spaces.
    static let everyScalar = (UInt32(0x80)...0x3FFFF).compactMap(Unicode.Scalar.init).filter { !isSpace($0) }

    /// The scalars of ``everyScalar`` for which `leaks` holds. The sweep runs on the test's own
    /// thread: run on many threads, it took the cores from the suites beside it, and the network
    /// capture tests, which wait 10 s for the stub server, timed out on an iOS simulator.
    static func sweep(_ leaks: (Unicode.Scalar) -> Bool) -> [String] {
        everyScalar.filter(leaks).map { String(format: "U+%04X", $0.value) }
    }

    @Test("every scalar from U+0021 to U+3FFFF outside ASCII before an allowed key hides the value, unless it is a space")
    func everyScalarBeforeAnAllowedKey() {
        let policy = RedactionPolicy.default
        let leaks = Self.sweep { policy.redact(text: "\($0)status=hunter2Zq").contains("hunter2Zq") }
        #expect(leaks.isEmpty, "\(leaks.prefix(40))")
    }

    // ASCII is in the safe alphabet. Before an allowed key, `,`, `;`, `?` and `|` end the word,
    // `-`, `.` and `_` are folded away as separators and `&` starts a field, so the key reads as
    // `status`; any other
    // ASCII character joins the key, is an escape, or opens a quote or bracket that does not close.
    @Test("every ASCII character before an allowed key hides the value, unless the key still reads as allowed")
    func everyASCIICharacterBeforeAnAllowedKey() {
        for value in UInt32(0x21)...0x7E {
            let character = String(Unicode.Scalar(value)!)
            let output = redactor.redact("\(character)status=hunter2Zq")
            #expect(output.contains("hunter2Zq") == ",-.;?_|&".contains(character), "\(character) -> \(output)")
        }
    }

    @Test("every scalar whose compatibility form differs, in every shape, hides the value")
    func everyCompatibilityFormInEveryShape() {
        let policy = RedactionPolicy.default
        let leaks = Self.sweep { scalar in
            let character = String(scalar)
            guard character.precomposedStringWithCompatibilityMapping != character else { return false }
            return Self.shapes.contains { policy.redact(text: $0(character)).contains("hunter2Zq") }
        }
        #expect(leaks.isEmpty, "\(leaks.prefix(40))")
    }
}
