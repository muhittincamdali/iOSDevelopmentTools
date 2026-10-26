import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Redaction corpus: ")
struct RedactorTests {
    let redactor = Redactor()

    @Test("redacts the documentation examples")
    func documentationExamples() {
        let body = #"{"user":"alice@example.com","password":"hunter2"}"#
        #expect(redactor.redact(body: Data(body.utf8), contentType: "application/json") == #"{"user":"[REDACTED]","password":"[REDACTED]"}"#)
        #expect(redactor.redact("login failed user=alice status=401") == "login failed user=[REDACTED]")
        #expect(redactor.redact("sent receipt to alice@example.com") == "sent receipt to [REDACTED]")
        #expect(redactor.redact("GET /orders status=200 duration_ms=41") == "GET /orders status=200 duration_ms=41")
    }

    @Test("finds card numbers that pass the Luhn check", arguments: [
        ("paid with 4242424242424242 today", "paid with [REDACTED] today"),
        ("paid 4242 4242 4242 4242.", "paid [REDACTED]."),
        ("paid 4242-4242-4242-4242", "paid [REDACTED]"),
        ("amex 3782 822463 10005", "amex [REDACTED]"),
        ("order 1234 paid 4242 4242 4242 4242 ok", "order 1234 paid [REDACTED] ok"),
        ("fullwidth ４２４２４２４２４２４２４２４２", "fullwidth [REDACTED]"),
        // A word with an invisible character in it cannot be read with certainty: it goes whole.
        ("zero width 4242\u{200B}4242\u{200B}4242\u{200B}4242", "zero width [REDACTED]"),
        ("combining 4\u{301}242424242424242", "combining [REDACTED]"),
        // A space outside ASCII cuts the text there, and the card number is hidden whole with it.
        ("nbsp 4242\u{A0}4242\u{A0}4242\u{A0}4242", "nbsp [REDACTED]"),
    ])
    func cards(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("leaves numbers that are not card numbers", arguments: [
        "order 4242424242424241", "timestamp 1700000000000", "id ab4242424242424242", "4242424242424242ab",
        "uuid 123456789012345678901234", "phone +90 555 123 45 67",
    ])
    func notCards(input: String) {
        #expect(redactor.redact(input) == input)
    }

    @Test("finds email addresses", arguments: [
        ("contact alice@example.com.", "contact [REDACTED]."),
        ("(bob.smith+news@mail.example.org)", "([REDACTED])"),
        // Before a letter, `<` starts markup, which cuts free text: the address goes with it.
        ("<bob.smith+news@mail.example.org>", "[REDACTED]"),
        ("fullwidth ａｌｉｃｅ@ｅｘａｍｐｌｅ.ｃｏｍ", "fullwidth [REDACTED]"),
        // `＠` is punctuation outside ASCII, which cuts the text: the address is hidden whole.
        ("fullwidth ａｌｉｃｅ＠ｅｘａｍｐｌｅ．ｃｏｍ", "fullwidth [REDACTED]"),
        ("hidden al\u{200D}ice@example.com", "hidden [REDACTED]"),
    ])
    func emails(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("leaves text with @ that is not an address", arguments: ["@mention", "user@localhost", "a @ b.com", "price 5@3.5", "@@@"])
    func notEmails(input: String) {
        #expect(redactor.redact(input) == input)
    }

    @Test("replaces JSON Web Tokens, including unsigned ones")
    func jsonWebTokens() {
        let signed = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        #expect(redactor.redact("sent \(signed) end") == "sent [REDACTED] end")
        #expect(redactor.redact("eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIn0.") == "[REDACTED]")
        #expect(redactor.redact("eyJ is not a token") == "eyJ is not a token")
        #expect(redactor.redact("eyJabc.def") == "eyJabc.def")
    }

    @Test("replaces bearer tokens wherever they appear")
    func bearerTokens() {
        #expect(redactor.redact("sent token sk_live_0123456789 Bearer  sk_live_0123456789") == "sent token [REDACTED]")
        // `bearer` is a secret name too, so the rest of the text goes with the token.
        #expect(redactor.redact("sent bearer  sk_live_0123456789 to server") == "sent bearer  [REDACTED]")
        #expect(redactor.redact("got Bearer abc.DEF-123_x here") == "got Bearer [REDACTED]")
        // Whatever its length: as 2.0.0 read `Bearer` in a header.
        #expect(redactor.redact("bearer short") == "bearer [REDACTED]")
        #expect(redactor.redact("Authorization: Bearer abc.DEF-123_456") == "Authorization: [REDACTED]")
    }

    @Test("each detector finds only its own kind")
    func kinds() {
        let emailsOnly = DetectorRedactor(kinds: .emailAddresses)
        #expect(emailsOnly.redact("alice@example.com password=x 4242424242424242") == "[REDACTED] password=x 4242424242424242")
    }

    @Test("matches report kind and range in the original text")
    func matches() {
        let text = "mail bob@example.com, paid=4242424242424242 ok"
        let found = redactor.matches(in: text)
        #expect(found.map(\.kind) == [.emailAddresses, .secretFields])
        #expect(found.map { String(text[$0.range]) } == ["bob@example.com", "4242424242424242 ok"])
        #expect(redactor.matches(in: "a b").isEmpty)
        // A line separator outside ASCII cuts the text: the cut is a match of its own.
        let separated = "a\u{2028}b"
        #expect(redactor.matches(in: separated).map { String(separated[$0.range]) } == ["\u{2028}b"])
    }

    @Test("leaves text in other scripts unchanged; an emoji, a dash or a symbol outside ASCII cuts it")
    func unchangedText() {
        let text = "Merhaba dünya, заказ 42 отправлен; 東京 3:00 iPhoneで決済しました"
        #expect(redactor.redact(text) == text)
        // `№` is a symbol, though compatibility normalization reads it as `No`.
        #expect(redactor.redact("заказ №42 отправлен") == "заказ [REDACTED]")
        // An emoji or a dash outside ASCII is outside the safe alphabet and hides what follows it.
        #expect(redactor.redact("Merhaba dünya 👋🏽 — заказ") == "Merhaba dünya [REDACTED]")
        #expect(redactor.redact("") == "")
        #expect(redactor.redact("Merhaba dünya 👋🏽 bye") == "Merhaba dünya [REDACTED]")
        #expect(redactor.redact("заказ — №42") == "заказ [REDACTED]")
        #expect(redactor.redact("заказ №42") == "заказ [REDACTED]")
    }

    @Test("the allowlists are folded, and secret or non-ASCII names cannot be added")
    func allowlists() {
        let custom = Redactor(allowedTextKeys: ["Request-ID", "api_key", "ｓｔａｔｅ"], allowedQueryParameters: ["Page", "token"])
        #expect(custom.allowedTextKeys == ["status", "method", "path", "durationms", "count", "requestid"])
        #expect(!custom.allowedTextKeys.contains("apikey"))
        #expect(custom.allowedTextKeys.allSatisfy { $0.unicodeScalars.allSatisfy(\.isASCII) })
        #expect(custom.allowedQueryParameters == ["page"])
        #expect(custom.redact("request_id=42 api_key=k1") == "request_id=42 api_key=[REDACTED]")
        #expect(Redactor().allowedQueryParameters.isEmpty)
    }
}
