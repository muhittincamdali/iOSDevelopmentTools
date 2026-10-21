import Foundation
@testable import iOSDevelopmentTools

/// A megabyte of free text of `<`, quotes, quoted keys and URLs, timed and measured as the other
/// shapes are. Quotes are read in one pass of their own that keeps where a quote of each of six
/// kinds is open, and a quoted key is compared where it is in the text: a quote before a megabyte
/// of escaped ones, backslash runs before quotes, quotes of every style, quotes inside quotes of
/// other kinds, quoted keys, comparisons and URLs that a mark ends are
/// read in time and memory linear in the text, also with every offset of the scanning copy kept
/// (`ﬁ` before them).
enum MarkupQuoteShapes {
    private static func lines(_ line: String) -> String {
        String(repeating: line, count: max(1, RedactionTimeLimitTests.size / line.utf8.count))
    }

    static let text: [TimedInput] = {
        let redactor = Redactor()
        let shapes: [(String, @Sendable () -> String)] = [
            ("a quote before a megabyte of escaped quotes", { "\"" + lines("\\\" a ") }),
            ("an escaped quote before a megabyte of quotes", { "\\\"" + lines("\" a ") }),
            ("backslash runs before quotes", { lines(String(repeating: "\\", count: 200) + "\" ") }),
            ("quotes of every style", { lines("\"a\" 'b' `c` ") }),
            ("quotes of every style, every offset kept", { "\u{FB01}" + lines("\u{FB01}\"a\" 'b' `c` ") }),
            ("a quote that closes on the last line", { "\"" + lines("ab cd ") + "\"" }),
            ("lines that close their quotes", { lines("msg \"ok\" and 'fine'\n") }),
            ("quotes inside quotes of other kinds that close", { lines("'a \"b\" c' \"d 'e' f\" `g \\\"h\\\" i` ") }),
            ("a quote of every kind open before a megabyte line", { "'x \"y `z \\\"w " + lines("ab cd ") }),
            ("allowed quoted keys", { lines("\"status\": 200, 'count': 3, `method`: GET ") }),
            ("a megabyte line of quotes that close with no separator after them", { lines("\"a b\" ") }),
            ("comparisons", { lines("a < b and 1<2 ") }),
            ("comparisons, every offset kept", { "\u{FB01}" + lines("\u{FB01}a < b and 1<2 ") }),
            ("clean URLs that one mark ends", { lines("see https://x.example/a/b. (https://x.example/c) ok\n") }),
            ("brackets that close", { lines("(a [b {c}]) ") }),
        ]
        return shapes.map { name, make in TimedInput(testDescription: name, make: make, redact: redactor.redact) }
    }()
}
