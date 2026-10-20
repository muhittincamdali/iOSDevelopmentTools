import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Values found by what they look like, whatever field holds them: IBANs, long hex and base64
/// strings, card numbers and tokens.
@Suite("Redaction corpus: value detectors")
struct RedactionDetectorTests {
    let redactor = Redactor()

    @Test("finds IBANs that pass the mod-97 check", arguments: [
        ("pay to DE89370400440532013000", "pay to [REDACTED]"),
        ("to DE89 3704 0044 0532 0130 00 today", "to [REDACTED] today"),
        ("GB82 WEST 1234 5698 7654 32", "[REDACTED]"),
        ("{\"note\":\"DE89370400440532013000\"}", "{\"note\":\"[REDACTED]\"}"),
    ])
    func ibans(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("leaves text that only looks like an IBAN", arguments: [
        "DE00370400440532013000", "DE89 3704", "XX12", "order AB12CD34EF56GH78 shipped",
    ])
    func notIBANs(input: String) {
        #expect(redactor.redact(input) == input)
    }

    @Test("finds runs of 32 or more hex digits and base64 strings", arguments: [
        ("commit 2c73d1a49804c8035388364230944e541f8e6e2c", "commit [REDACTED]"),
        ("fingerprint 0123456789abcdef0123456789abcdef ok", "fingerprint [REDACTED] ok"),
        // The `==` that pads base64 is a separator after a plain key, so only the token goes.
        ("b64 dGhpcyBpcyBhIHNlY3JldCB2YWx1ZSAxMjM0NTY3OA== end", "b64 [REDACTED] end"),
        ("{\"note\":\"sk_live_" + "51HxQ2wErTyUiOpAsDfGhJkLzXcVbNm1234\"}", "{\"note\":\"[REDACTED]\"}"),
    ])
    func longTokens(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("leaves identifiers, paths and words", arguments: [
        "uuid 550e8400-e29b-41d4-a716-446655440000", "path /var/mobile/Containers/Data/Application/1234",
        "NSLocationWhenInUseUsageDescription", "hash 0123456789abcdef0123456789abcde", "UIApplicationDidBecomeActiveNotification",
    ])
    func notLongTokens(input: String) {
        #expect(redactor.redact(input) == input)
    }

    @Test("an IBAN and a long token next to each other are hidden apart")
    func ibanAndToken() {
        let text = "DE89370400440532013000 2c73d1a49804c8035388364230944e541f8e6e2c"
        #expect(redactor.redact(text) == "[REDACTED] [REDACTED]")
    }

    @Test("card numbers grouped by tabs or dashes of any kind", arguments: [
        ("paid 4111\t1111\t1111\t1111", "paid [REDACTED]"),
        ("paid 4111\u{2010}1111\u{2010}1111\u{2010}1111", "paid [REDACTED]"),
        ("paid 4111\u{2013}1111\u{2013}1111\u{2013}1111 ok", "paid [REDACTED] ok"),
    ])
    func cardSeparators(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a token glued to an identifier with _ or - is still found")
    func gluedToken() {
        let token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ6cTAwMSJ9.c2lnbmF0dXJlMDAx"
        #expect(redactor.redact("id_\(token)") == "id_[REDACTED]")
        #expect(redactor.redact("x-\(token) ok") == "x-[REDACTED] ok")
    }

    @Test("an address on a domain with accented letters is found")
    func accentedDomain() {
        #expect(redactor.redact("mail alice@ex\u{00E4}mple.com ok") == "mail [REDACTED] ok")
    }
}
