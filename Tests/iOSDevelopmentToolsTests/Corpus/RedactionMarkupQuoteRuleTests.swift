import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The two rules of free text that keep no state while it is read: markup is not parsed, so the
/// first `<` that is not a comparison cuts the text there, whatever follows it; and a quote that
/// does not close on its line cuts the text at the quote. A `<` is a comparison only before an
/// ASCII space, tab or line break, an ASCII digit, `=` or the end of the text. Each is checked on the six paths
/// that read free text (see ``RedactionCutRuleTests/everyPath(_:)``).
@Suite("Redaction corpus: markup and quotes in free text")
struct RedactionMarkupQuoteRuleTests {
    let redactor = Redactor()
    static let secret = "QZ9WK7RXV"

    static func expectHidden(_ text: String, _ secret: String = secret, sourceLocation: SourceLocation = #_sourceLocation) {
        for (path, output) in RedactionCutRuleTests.everyPath(text) {
            #expect(!output.contains(secret), "\(path): \(text.debugDescription) -> \(output.debugDescription)", sourceLocation: sourceLocation)
        }
    }

    // MARK: Markup

    @Test("the first `<` that is not a comparison cuts the text there", arguments: [
        ("<user>bob</user>", "[REDACTED]"),
        ("msg <status>ok</status> done", "msg [REDACTED]"),
        ("closed </user> bob", "closed [REDACTED]"),
        ("x <!-- note --> bob", "x [REDACTED]"),
        ("x <![CDATA[bob]]>", "x [REDACTED]"),
        ("<?xml version=\"1.0\"?><a>bob</a>", "[REDACTED]"),
        ("<!DOCTYPE html>", "[REDACTED]"),
        ("status=200 <br/> bob", "status=200 [REDACTED]"),
        ("Optional<String>(bob)", "Optional[REDACTED]"),
        ("<\u{0130}sim>bob</\u{0130}sim>", "[REDACTED]"),
        ("<\u{0436}>bob", "[REDACTED]"),
        ("msg \"<user>bob</user>\" done", "msg \"[REDACTED]"),
        ("'<user>bob</user>'", "'[REDACTED]"),
        // The nineteenth review: a tag name may start with `_` or `:`, and a digit outside ASCII
        // is no digit of a comparison; what follows `<` is never listed.
        ("<_id>bob</_id>", "[REDACTED]"),
        ("login <_x>bob", "login [REDACTED]"),
        ("a <_user>bob</_user>", "a [REDACTED]"),
        ("<_csrf_x>bob</_csrf_x>", "[REDACTED]"),
        ("<__v>bob</__v>", "[REDACTED]"),
        ("<_>bob</_>", "[REDACTED]"),
        ("<:x>bob", "[REDACTED]"),
        ("<-x>bob", "[REDACTED]"),
        ("<.x>bob</.x>", "[REDACTED]"),
        ("login <#x>bob", "login [REDACTED]"),
        ("login <@x>bob", "login [REDACTED]"),
        ("login <$x>bob", "login [REDACTED]"),
        ("login <%x>bob", "login [REDACTED]"),
        ("<\u{0966}>bob</\u{0966}>", "[REDACTED]"),
        ("<\u{0E50}>bob</\u{0E50}>", "[REDACTED]"),
        ("<\u{2070}>bob</\u{2070}>", "[REDACTED]"),
        ("login <\u{0661}>bob", "login [REDACTED]"),
        ("msg \"<\" user>bob</user>", "msg \"[REDACTED]"),
        ("x << 1", "x [REDACTED]"),
        ("a <- b", "a [REDACTED]"),
        ("<<<", "[REDACTED]"),
        ("<>bob", "[REDACTED]"),
    ])
    func markupCuts(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a `<` before an ASCII space, tab or line break, an ASCII digit, `=` or the end of the text is a comparison", arguments: [
        "a < b", "if count < 10 then", "1<2 ok", "<3 love", "a<", "a <\tb", "a <\nb", "a <\r\nb", "<1x> bob", "a < b > c",
    ])
    func comparisonsStay(input: String) {
        #expect(redactor.redact(input) == input)
        #expect(redactor.redact(body: Data(input.utf8), contentType: "text/plain") == input)
    }

    /// The shapes the review found: element text after other markup, in every path.
    static let nestedShapes = [
        "<user><![CDATA[S]]></user>", "<phone><![CDATA[S]]></phone>", "<user><!-- c -->S</user>", "<user>\n<!-- c -->\nS\n</user>",
        "<user><br/>S</user>", "<user><count/>S</user>", "<address><line/>S</address>", "<user><count>1</count>S</user>",
        "<user><status>ok</status>S</user>", "<user></x>S", "<user><?pi?>S", "<user><!x>S", "<user>< S", "<user><1>S", "<user><_a>S",
        "<_x>S</_x>", "<_user>\nS\n</_user>", "<_x a='1'>S", "<\u{0966}>S</\u{0966}>", "<-x>S", "<.x>S</.x>",
    ]

    static let prefixes = ["", "msg ", "status=200 ", "note: ", "x=1 "]

    @Test("element text after other markup never shows, whatever comes before it", arguments: nestedShapes)
    func nestedMarkup(shape: String) {
        for prefix in Self.prefixes {
            Self.expectHidden(prefix + shape.replacingOccurrences(of: "S", with: Self.secret))
        }
    }

    @Test("element text in quotes never shows, for every quote and prefix", arguments: ["\"", "'", "`", "\\\"", ""])
    func quotedMarkup(quote: String) {
        for prefix in Self.prefixes {
            for tag in ["user", "phone", "status", "count"] {
                for suffix in ["", " done", "\nnext"] {
                    Self.expectHidden("\(prefix)\(quote)<\(tag)>\(Self.secret)</\(tag)>\(quote)\(suffix)")
                }
            }
        }
    }

    @Test("no tag is allowed: allowing a key never shows the text of an element of that name")
    func noTagIsAllowed() {
        let allowing = Redactor(allowedTextKeys: ["user", "phone"])
        #expect(allowing.redact("user=bob <user>bob</user>") == "user=bob [REDACTED]")
        #expect(allowing.redact("\"<phone>555</phone>\"") == "\"[REDACTED]")
    }

    // MARK: Quotes

    @Test("a quote that does not close on its line cuts the text at the quote", arguments: [
        ("say \"hunter2", "say [REDACTED]"),
        ("say \"hunter2\nnext\" line", "say [REDACTED]"),
        ("\"note\nQZ9WK7RXV\": 1", "[REDACTED]"),
        ("status=200 'a\nQZ9WK7RXV': 1", "status=200 [REDACTED]"),
        ("x `a\nQZ9WK7RXV`: 1", "x [REDACTED]"),
        ("x \\\"a\nQZ9WK7RXV\\\": 1", "x [REDACTED]"),
        ("\"note\rQZ9WK7RXV\": 1", "[REDACTED]"),
        // Where a character outside the safe alphabet cuts the text, a quote still open cuts it at the quote.
        ("x \"a \u{2254} b\" c", "x [REDACTED]"),
    ])
    func unclosedQuotes(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("quotes that close on their line and apostrophes keep the text", arguments: [
        "say \"hello world\" done", "msg 'ok' and \"fine\"\nnext \"line\"", "don't stop\nwe're done", "status=200 count=3 `cmd` ran",
        "{\"status\":\"say hi\"} done",
    ])
    func closedQuotesStay(input: String) {
        #expect(redactor.redact(input) == input)
        #expect(redactor.redact(body: Data(input.utf8), contentType: "text/plain") == input)
    }

    /// A backslash before a quote is an escape like any other, which cuts the text at the start of
    /// its word, and a backslash escape in JSON written into a line cuts the text after the JSON,
    /// as a word that cannot be read does.
    @Test("an escaped quote cuts the text at its word", arguments: [
        // `"a \" b"`: the escaped quote opens inside the plain one, which then closes while the
        // escaped one is still open, so the quotes overlap and the text is cut at the first quote.
        ("it\\'s ok", "[REDACTED]"), ("\"a \\\" b\" done", "[REDACTED]"), ("note \\\"status\\\": 1", "note [REDACTED]"),
        ("{\"status\":\"say \\\"hi\\\"\"} done", "{\"status\":\"say \\\"hi\\\"\"} [REDACTED]"),
    ])
    func escapedQuotesCut(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
        #expect(redactor.redact(body: Data(input.utf8), contentType: "text/plain") == expected)
    }

    @Test("a quoted key with a line break in it never shows, for every quote, line break and separator")
    func lineBreakInQuotedKeys() {
        for quote in ["\"", "'", "`", "\\\""] {
            for lineBreak in ["\n", "\r\n", "\r", "\n\n"] {
                for separator in [": ", "=", " => ", ":= "] {
                    for prefix in ["", "status=200 ", "log ", "a \"b\" "] {
                        let s = Self.secret
                        Self.expectHidden("\(prefix)\(quote)note\(lineBreak)\(s)\(quote)\(separator)1")
                        Self.expectHidden("\(prefix)\(quote)\(s)\(lineBreak)note\(quote)\(separator)1")
                        Self.expectHidden("\(prefix)\(quote)a\(lineBreak)\(quote) \(quote)\(s)\(quote)\(separator)1")
                    }
                }
            }
        }
    }
}
