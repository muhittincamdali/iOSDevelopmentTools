import Foundation
import os
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

    @Test("a letter or digit whose compatibility form holds punctuation or a symbol cuts the text", arguments: [
        "\u{1F101}", "\u{1F10A}", "\u{2488}", "\u{2474}", "\u{00BD}", "\u{215F}", "\u{33A1}",
    ])
    func formsWithPunctuation(scalar: String) {
        #expect(redactor.redact("ok \(scalar) hunter2Zq") == "ok [REDACTED]")
    }

    @Test("a letter or digit whose compatibility form is letters and digits is text", arguments: [
        "x\u{00B2} + y\u{00B2}", "\u{2460} first", "\u{FB01}le", "\u{2167} chapter", "\u{FF46}\u{FF55}\u{FF4C}\u{FF4C}", "\u{2081}\u{2082}",
        "\u{3007} zero", "\u{017F}tatus ok", "\u{1D400}\u{1D401}", "\u{FDFA} done", "\u{0149} ok",
    ])
    func formsOfLetters(text: String) {
        #expect(redactor.redact(text) == text)
    }

    /// Whether a scalar is read as an ASCII space: a space that compatibility normalization reads
    /// as one, which the safe alphabet holds, so `status=` after it is a key.
    static func isSpace(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.generalCategory == .spaceSeparator && String(scalar).decomposedStringWithCompatibilityMapping == " "
    }

    /// Every scalar from U+0021 to U+3FFFF, chunked so that the chunks run at the same time.
    static let everyScalar: [[Unicode.Scalar]] = {
        let scalars = (UInt32(0x21)...0x3FFFF).compactMap(Unicode.Scalar.init)
        return stride(from: 0, to: scalars.count, by: 8_192).map { Array(scalars[$0..<min($0 + 8_192, scalars.count)]) }
    }()

    @Test("every scalar from U+0021 to U+3FFFF outside ASCII before an allowed key hides the value, unless it is a space")
    func everyScalarBeforeAnAllowedKey() {
        let policy = RedactionPolicy.default
        let leaks = OSAllocatedUnfairLock<[String]>(initialState: [])
        DispatchQueue.concurrentPerform(iterations: Self.everyScalar.count) { chunk in
            var found: [String] = []
            for scalar in Self.everyScalar[chunk] where !scalar.isASCII && !Self.isSpace(scalar) {
                if policy.redact(text: "\(scalar)status=hunter2Zq").contains("hunter2Zq") {
                    found.append(String(format: "U+%04X", scalar.value))
                }
            }
            let chunkLeaks = found
            leaks.withLock { $0 += chunkLeaks }
        }
        #expect(leaks.withLock { $0 }.isEmpty, "\(leaks.withLock { $0.prefix(40) })")
    }

    @Test("every scalar whose compatibility form differs, in every shape, hides the value")
    func everyCompatibilityFormInEveryShape() {
        let policy = RedactionPolicy.default
        let leaks = OSAllocatedUnfairLock<[String]>(initialState: [])
        DispatchQueue.concurrentPerform(iterations: Self.everyScalar.count) { chunk in
            var found: [String] = []
            for scalar in Self.everyScalar[chunk] where !scalar.isASCII && !Self.isSpace(scalar) {
                let character = String(scalar)
                guard character.precomposedStringWithCompatibilityMapping != character else { continue }
                for shape in Self.shapes where policy.redact(text: shape(character)).contains("hunter2Zq") {
                    found.append(String(format: "U+%04X", scalar.value))
                }
            }
            let chunkLeaks = found
            leaks.withLock { $0 += chunkLeaks }
        }
        #expect(leaks.withLock { $0 }.isEmpty, "\(leaks.withLock { $0.prefix(40) })")
    }
}
