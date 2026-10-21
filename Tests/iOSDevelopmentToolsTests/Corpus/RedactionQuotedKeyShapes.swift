import Foundation
@testable import iOSDevelopmentTools

/// A megabyte of free text held by quoted keys, as the sixteenth review of the shared rules
/// measured it in iOSSecurityTools: a key that takes the whole text, one inside another, and lines
/// of keys that are allowed and that are not. A `ﬁ` before them makes the scanning copy keep the
/// offset of every byte, its largest form. A quoted key is compared where it is in the text, so
/// none is copied, and one longer than any key is turned down before it is read.
enum QuotedKeyShapes {
    private static func prose() -> String { String(repeating: "ab cd ", count: RedactionTimeLimitTests.size / 6) }

    private static func lines(_ line: String) -> String {
        String(repeating: line, count: max(1, RedactionTimeLimitTests.size / line.utf8.count))
    }

    static let text: [TimedInput] = {
        let redactor = Redactor()
        let shapes: [(String, @Sendable () -> String)] = [
            ("one quoted key of a megabyte", { "\"" + prose() + "\": 1" }),
            ("one quoted key of a megabyte, every offset kept", { "\u{FB01}\"\u{FB01}" + prose() + "\": 1" }),
            ("a quoted key in a quoted key of a megabyte", { "\"\\\"" + prose() + "\\\":1\": 2" }),
            ("a quoted key in a quoted key of a megabyte, every offset kept", { "\u{FB01}\"\u{FB01}\\\"\u{FB01}" + prose() + "\\\":1\": 2" }),
            ("lines of allowed quoted keys", { lines("\"status\": \"ok\", \"count\": 3\n") }),
            ("lines of quoted keys in brackets", { lines("\"(status\": 1, ") }),
            ("lines of escaped quoted keys in quoted text", { lines("\"\\\"status\\\":1 \" ok, ") }),
            ("a line of single-quoted allowed keys", { lines("'status': 'ok', ") }),
        ]
        return shapes.map { name, make in TimedInput(testDescription: name, make: make, redact: redactor.redact) }
    }()
}
