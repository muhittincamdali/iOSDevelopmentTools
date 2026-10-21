import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The rules of free text that keep no state while it is read: markup is not parsed, so the
/// first `<` that is not a comparison cuts the text there, whatever follows it; a quote that does
/// not close on its line cuts the text at the quote; and a quoted key that is not allowed cuts it
/// at its opening quote. A `<` is a comparison only before an ASCII space, tab or line break, an
/// ASCII digit, `=` or the end of the text. Each is checked on the six paths that read free text
/// (see ``RedactionCutRuleTests/everyPath(_:)``). The tenth review of this package found a tag
/// allowlist and element text kept for allowed tags, comments, CDATA, processing instructions and
/// end tags kept with the text after them, quotes that closed on a later line keeping the lines
/// in between, and quoted keys whose text showed before the cut.
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
        // The tenth review's inputs.
        ("<![CDATA[hunter2Zq]]>", "[REDACTED]"), ("<!-- hunter2Zq -->", "[REDACTED]"), ("<?pi hunter2Zq?>", "[REDACTED]"),
        ("</x> hunter2Zq", "[REDACTED]"), ("<!DOCTYPE html> hunter2Zq", "[REDACTED]"), ("<br/> hunter2Zq", "[REDACTED]"),
        ("a <b c", "a [REDACTED]"), ("a <# c", "a [REDACTED]"), ("a <- c", "a [REDACTED]"), ("1 <> 2", "1 [REDACTED]"),
        ("<status>200</status> hunter2Zq", "[REDACTED]"), ("<status>hunter2Zq</status>", "[REDACTED]"),
        ("<b>bold</b> text", "[REDACTED]"), ("<hunter2Zq>v", "[REDACTED]"), ("List<String> items", "List[REDACTED]"),
        ("note <!-- hunter2Zq --> end", "note [REDACTED]"), ("log <![CDATA[x=1 hunter2Zq]]> end", "log [REDACTED]"),
        ("<?xml version=\"1.0\"?> hunter2Zq", "[REDACTED]"), ("a <_x c", "a [REDACTED]"), ("a <:x c", "a [REDACTED]"),
        ("a <\u{0661} c", "a [REDACTED]"), ("a <( c", "a [REDACTED]"), ("a <<< c", "a [REDACTED]"), ("x <ok> y", "x [REDACTED]"),
        ("Optional<Int>.none", "Optional[REDACTED]"), ("status=200 <b>", "status=200 [REDACTED]"), ("see <https://a.example/v1> ok", "see [REDACTED]"),
        ("</password> hunter2Zq", "[REDACTED]"), ("<!-- password --> hunter2Zq", "[REDACTED]"),
        // Other shapes of the same rule.
        ("<user>bob</user>", "[REDACTED]"), ("msg <status>ok</status> done", "msg [REDACTED]"), ("closed </user> bob", "closed [REDACTED]"),
        ("<\u{0130}sim>bob</\u{0130}sim>", "[REDACTED]"), ("<\u{0436}>bob", "[REDACTED]"), ("msg \"<user>bob</user>\" done", "msg \"[REDACTED]"),
        ("'<user>bob</user>'", "'[REDACTED]"), ("<_id>bob</_id>", "[REDACTED]"), ("<.x>bob</.x>", "[REDACTED]"), ("login <@x>bob", "login [REDACTED]"),
        ("login <$x>bob", "login [REDACTED]"), ("login <%x>bob", "login [REDACTED]"), ("<\u{0966}>bob</\u{0966}>", "[REDACTED]"),
        ("<\u{2070}>bob</\u{2070}>", "[REDACTED]"), ("<\u{FF13}>bob", "[REDACTED]"), ("<\u{00A0}x>bob", "[REDACTED]"), ("<\u{200B}3>bob", "[REDACTED]"),
        ("msg \"<\" user>bob</user>", "msg \"[REDACTED]"), ("x << 1", "x [REDACTED]"), ("<>bob", "[REDACTED]"),
    ])
    func markupCuts(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a `<` before an ASCII space, tab or line break, an ASCII digit, `=` or the end of the text is a comparison", arguments: [
        "a < b", "if count < 10 then", "1<2 ok", "<3 love", "a<", "a <\tb", "a <\nb", "a <\r\nb", "<1x> bob", "a < b > c", "a < 3", "a <3",
    ])
    func comparisonsStay(input: String) {
        #expect(redactor.redact(input) == input)
        #expect(redactor.redact(body: Data(input.utf8), contentType: "text/plain") == input)
    }

    /// Element text after other markup, which the earlier design kept.
    static let nestedShapes = [
        "<user><![CDATA[S]]></user>", "<phone><![CDATA[S]]></phone>", "<user><!-- c -->S</user>", "<user>\n<!-- c -->\nS\n</user>",
        "<user><br/>S</user>", "<user><count/>S</user>", "<address><line/>S</address>", "<user><count>1</count>S</user>",
        "<user><status>ok</status>S</user>", "<user></x>S", "<user><?pi?>S", "<user><!x>S", "<user>< S", "<user><1>S", "<user><_a>S",
        "<_x>S</_x>", "<_user>\nS\n</_user>", "<_x a='1'>S", "<\u{0966}>S</\u{0966}>", "<-x>S", "<.x>S</.x>", "<status>S</status>",
        "<path>S</path>", "<count>\nS\n</count>",
    ]

    static let prefixes = ["", "msg ", "status=200 ", "note: ", "x=1 "]

    @Test("element text never shows, whatever comes before it", arguments: nestedShapes)
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
        #expect(redactor.redact("status=200 <status>200</status>") == "status=200 [REDACTED]")
    }

    // MARK: Quotes

    @Test("a quote that does not close on its line cuts the text at the quote", arguments: [
        // The tenth review's inputs.
        ("msg \"abc\nhunter2Zq\" done", "msg [REDACTED]"), ("msg 'abc\nhunter2Zq' done", "msg [REDACTED]"),
        ("msg \"line1\nline2\nline3 hunter2Zq\" end", "msg [REDACTED]"), ("status=\"ok\nhunter2Zq\"", "status=[REDACTED]"),
        ("\"multi\nline key\": hunter2Zq", "[REDACTED]"), ("say \"a\" \"b\nhunter2Zq\"", "say \"a\" [REDACTED]"),
        ("msg \"a\r\nhunter2Zq\" done", "msg [REDACTED]"), ("\"status\":\"ok\nhunter2Zq\"", "\"status\":[REDACTED]"),
        ("`abc\nhunter2Zq`", "[REDACTED]"),
        // Other shapes of the same rule.
        ("say \"hunter2", "say [REDACTED]"), ("\"note\nQZ9WK7RXV\": 1", "[REDACTED]"), ("status=200 'a\nQZ9WK7RXV': 1", "status=200 [REDACTED]"),
        ("x `a\nQZ9WK7RXV`: 1", "x [REDACTED]"), ("x \\\"a\nQZ9WK7RXV\\\": 1", "x [REDACTED]"), ("\"note\rQZ9WK7RXV\": 1", "[REDACTED]"),
        ("x \"a \u{2254} b\" c", "x \"a [REDACTED]"), ("status=\"ok\u{2028}QZ9WK7RXV\"", "status=[REDACTED]"),
        // An escaped quote is a kind of its own: one with no partner on its line inside a plain
        // quote overlaps it, and the text is cut at the plain quote.
        ("\"a \\\" b\" done", "[REDACTED]"), ("status=\"a\\\"b\" count=1", "status=[REDACTED]"),
    ])
    func unclosedQuotes(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("the tenth review's quotes over lines are cut in a text/plain body and a JSON string too")
    func unclosedQuotesInBodies() {
        let text = "msg \"abc\nhunter2Zq\" done"
        #expect(redactor.redact(body: Data(text.utf8), contentType: "text/plain") == "msg [REDACTED]")
        let json = try! JSONSerialization.data(withJSONObject: ["a": text])
        #expect(redactor.redact(body: json, contentType: "application/json") == #"{"a":"msg [REDACTED]"}"#)
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

    @Test("quotes that close on their line, apostrophes and escaped quotes keep the text", arguments: [
        "say \"hello world\" done", "msg 'ok' and \"fine\"\nnext \"line\"", "don't stop\nwe're done", "it\\'s ok",
        "\"a \\\"b\\\" c\" done", "status=200 count=3 `cmd` ran", "{\"status\":\"say \\\"hi\\\"\"} done", "İstanbul'a gitti",
        "status=\"a\\\"b\\\"\" count=1", "'a \"b\" c' done", "\"say 'hi' now\" done", "`echo \"x\"` ran", "\"Ayşe'nin 'kitabı'\"",
    ])
    func closedQuotesStay(input: String) {
        #expect(redactor.redact(input) == input)
        #expect(redactor.redact(body: Data(input.utf8), contentType: "text/plain") == input)
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

    // MARK: Quoted keys

    @Test("a quoted key that is not allowed cuts the text at its opening quote", arguments: [
        // The tenth review's inputs.
        ("\"x\":\"hunter2Zq\"", "[REDACTED]"), ("\"x\"=\"hunter2Zq\"", "[REDACTED]"), ("\"hunter2Zq\":\"v\"", "[REDACTED]"),
        ("'x': 'hunter2Zq'", "[REDACTED]"),
        // Other shapes of the same rule.
        ("\"x\": hunter2Zq", "[REDACTED]"), ("\"my id hunter2Zq\": 1", "[REDACTED]"), ("\"x\" = hunter2Zq", "[REDACTED]"),
        ("`x`: hunter2Zq", "[REDACTED]"), ("'x'=>hunter2Zq", "[REDACTED]"), ("\"x\"\n: hunter2Zq", "[REDACTED]"),
        ("\"status\": 200, \"x\": hunter2Zq", "\"status\": 200, [REDACTED]"), ("\"status\":\"ok\" 'limit':5", "\"status\":\"ok\" [REDACTED]"),
        ("say \\\"x\\\": hunter2Zq", "say [REDACTED]"), ("\\\"x\\\":\\\"hunter2Zq\\\"", "[REDACTED]"), ("\"\": hunter2Zq", "[REDACTED]"),
        ("\"stat\u{200B}us\": hunter2Zq", "[REDACTED]"), ("\"\u{FF53}tatus\": hunter2Zq", "[REDACTED]"), ("msg \"abc def\": hunter2Zq", "msg [REDACTED]"),
        ("don't 'x': hunter2Zq", "don't [REDACTED]"),
    ])
    func quotedKeysCut(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a quoted key on the allowlist keeps its value", arguments: [
        "\"status\": 200, \"count\": 3", "'status': 'ok'", "`status`: ok", "\"status\"=\"ok\"", "\"method\" : GET",
    ])
    func allowedQuotedKeys(input: String) {
        #expect(redactor.redact(input) == input)
        #expect(Redactor(allowedTextKeys: ["user"]).redact("\"user\": \"bob\"") == "\"user\": \"bob\"")
    }
}
