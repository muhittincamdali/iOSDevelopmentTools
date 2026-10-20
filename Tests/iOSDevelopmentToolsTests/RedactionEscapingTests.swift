import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A JSON string that redaction changed is written again, escaped, into the document it came from.
@Suite("Redaction: strings written again into JSON")
struct RedactionEscapingTests {
    @Test("quotes, backslashes and control characters are escaped; other scalars are kept as they are")
    func escapes() {
        #expect(JSONDocument.escaped("a\"b\\c\nd\re\tf\u{01}g\u{1F}h") == #"a\"b\\c\nd\re\tf\u0001g\u001fh"#)
        #expect(JSONDocument.escaped("Iğdır ılık 张伟 😀 \u{2028} e\u{301} \u{7F} /") == "Iğdır ılık 张伟 😀 \u{2028} e\u{301} \u{7F} /")
        #expect(JSONDocument.escaped("") == "")
    }

    @Test("a string written again reads back, scalar for scalar, as the text it was made from")
    func roundTrip() throws {
        var random = SeededRandom(seed: 0xE5C_0001)
        let pieces = ["\"", "\\", "\n", "\r", "\t", "\u{0}", "\u{1F}", "\u{7F}", "a", "ı", "Ş", "张", "😀", "\u{2028}", "\u{301}", " ", "/", "\\u0041"]
        for _ in 0..<1_000 {
            let text = (0..<Int.random(in: 0...40, using: &random)).map { _ in pieces.randomElement(using: &random)! }.joined()
            let json = Data(("\"" + JSONDocument.escaped(text) + "\"").utf8)
            let decoded = try JSONSerialization.jsonObject(with: json, options: .fragmentsAllowed) as? String
            #expect(decoded.map { Array($0.unicodeScalars) } == Array(text.unicodeScalars), "\(text.debugDescription)")
        }
    }

    @Test("a megabyte string of quotes that a detector changes is written again, and hides what it found")
    func longStringOfQuotes() {
        let body = RedactionTimeLimitTests.oneLongString("say \\\"hi\\\" ", then: "ayse@ornek.com")
        let output = Redactor.largeBodies.redact(body: Data(body.utf8), contentType: "application/json")
        #expect(!output.contains("ayse@ornek.com"))
        #expect(output.hasPrefix("{\"msg\":\"say \\\"hi\\\" say \\\"hi\\\" "))
        #expect((try? JSONSerialization.jsonObject(with: Data(output.utf8))) != nil)
    }
}
