import Foundation
@testable import iOSDevelopmentTools

/// Megabytes of findings written across line separators, which the value detectors read across
/// (spec section 6): one chain of card groups, IBAN groups, an email name and a long token, each as
/// long as the text, and JWT headers with many separators after each `eyJ`. Each separator must be
/// read a fixed number of times, so a detector that read the separators after every `eyJ` again
/// for the next one would not keep to the time limit.
enum BridgedLineBreakShapes {
    private static let size = RedactionTimeLimitTests.size

    private static func repeated(_ unit: String, prefix: String = "paid ", suffix: String = " ok") -> String {
        prefix + String(repeating: unit, count: (size - prefix.utf8.count - suffix.utf8.count) / unit.utf8.count) + suffix
    }

    static let text: [TimedInput] = {
        let redactor = Redactor.largeBodies
        let shapes: [(String, String, String, String)] = [
            ("card digits split by U+2028", "4\u{2028}", "paid ", " ok"),
            ("card groups split by VT", "4242\u{0B}", "paid ", " ok"),
            ("IBAN groups split by U+2029", "DE89\u{2029}", "paid ", " ok"),
            ("an email name split by U+0085", "a\u{85}", "mail ", "@example.com"),
            ("JWT starts with 64 U+2028 after each", "eyJ" + String(repeating: "\u{2028}", count: 64), "paid ", " ok"),
            ("a JWT header of line separators", "\u{2028}", "eyJ", ".eyJ"),
            ("JWT headers split by FF", "eyJhbGci\u{0C}.", "paid ", " ok"),
            ("a long token split by U+2028", "0123456789abcdef\u{2028}", "paid ", " ok"),
            ("Bearer and U+2029", "Bearer\u{2029}", "auth ", " ok"),
        ]
        return shapes.flatMap { name, unit, prefix, suffix in
            [
                TimedInput(testDescription: "a megabyte of text of \(name)", make: { repeated(unit, prefix: prefix, suffix: suffix) }, redact: redactor.redact),
                TimedInput(testDescription: "a plain-text body of a megabyte of \(name)", make: { repeated(unit, prefix: prefix, suffix: suffix) }, redact: {
                    redactor.redact(body: Data($0.utf8), contentType: "text/plain")
                }),
            ]
        }
    }()
}
