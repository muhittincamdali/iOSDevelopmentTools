import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The required test set of the shared redaction specification (§8), continued from
/// RedactionSpecTests.swift: the cut point of free text (§8.5), the shared secret names (§2 K3)
/// and the limits (§7). Item numbers are the specification's.
@Suite("Redaction spec §8: the cut point")
struct RedactionSpecCutPointTests {
    let policy = RedactionPolicy.default

    @Test("#49–#64", arguments: [
        ("GET /api/items status=200 method=GET duration_ms=12", "GET /api/items status=200 method=GET duration_ms=12"),
        ("login user=bob status=401 password=hunter2", "login user=[REDACTED]"),
        ("Error: connection refused\nretrying in 5 s", "Error: [REDACTED]"),
        // #52, C3: what may follow a clean URL.
        ("see https://x.example/a. Next", "see https://x.example/a. Next"),
        ("see https://x.example/a, then", "see https://x.example/a, then"),
        ("see https://x.example/a! wow", "see https://x.example/a! wow"),
        ("see https://x.example/a). ok", "see [REDACTED]"),
        ("see https://x.example/a.. ok", "see [REDACTED]"),
        ("see https://x.example/a: ok", "see [REDACTED]"),
        ("see https://x.example/a; then", "see [REDACTED]"),
        ("see https://x.example/a]", "see [REDACTED]"),
        ("see https://x.example/a>", "see [REDACTED]"),
        ("see https://x.example/a\"", "see [REDACTED]"),
        ("see https://x.example/a'#token", "see [REDACTED]"),
        ("see \"https://x.example/a\" ok", "see \"[REDACTED]"),
        // #53–#54.
        ("GET https://api.example.com/users/12345678 200", "GET https://api.example.com/users/:id 200"),
        ("GET https://api.example.com/items?page=2 done", "GET [REDACTED]"),
        ("see https://x.example:8080/a ok", "see [REDACTED]"),
        ("see https://pin.example/a ok", "see [REDACTED]"),
        ("https://x.example/to ken hunter2", "https://x.example/to ken [REDACTED]"),
        // #55, C4: quoted keys.
        (#"cache miss for "session Qz9Wk7rX": refetching"#, "cache miss for [REDACTED]"),
        ("`status`: 200 and `x`: 1", "`status`: 200 and [REDACTED]"),
        ("'status'=200 'x'=1", "'status'=200 [REDACTED]"),
        ("x\"status\": 200", "[REDACTED]"),
        (#"{"status":200,"user":"bob"} done"#, #"{"status":200,[REDACTED]"#),
        (#"log [["X-User","bob"]]"#, "log [[[REDACTED]"),
        // #56, C5: the ASCII skeleton and one wildcard.
        ("login t\u{0366}ken hunter2", "login t\u{0366}ken [REDACTED]"),
        ("p\u{0251}ssword hunter2", "p\u{0251}ssword [REDACTED]"),
        ("passw\u{3007}rd hunter2", "passw\u{3007}rd [REDACTED]"),
        ("t\u{1040}ken hunter2", "t\u{1040}ken [REDACTED]"),
        ("yap\u{0131}n 1234", "yap\u{0131}n [REDACTED]"),
        ("pass word hunter2", "pass [REDACTED]"),
        ("PIN 1234", "PIN [REDACTED]"),
        ("bypass ok", "bypass ok"),
        // #57, C6: markup.
        ("if a < b then", "if a < b then"),
        ("1<2 and <3 and a<=b", "1<2 and <3 and a<=[REDACTED]"),
        ("x << 1", "x [REDACTED]"),
        ("<_id>7</_id>", "[REDACTED]"),
        ("Optional<String>(x)", "Optional[REDACTED]"),
        ("<\u{661}>", "[REDACTED]"),
        // #58, C7: a backslash cuts at the start of its word.
        ("login pa\\x{73}sword hunter2", "login [REDACTED]"),
        ("copied to \\\\nas\\backup", "copied to [REDACTED]"),
        ("pattern ^\\d+$ matched", "pattern [REDACTED]"),
        ("path ends with \\ here", "path ends with \\ here"),
        ("trailing backslash \\", "trailing backslash \\"),
        ("s\\\u{3000}t", "[REDACTED]"),
        // #59, C8: other escapes.
        ("user&colon;hunter2", "[REDACTED]"),
        ("status=200&count=3", "status=200&count=3"),
        ("R&D team", "[REDACTED]"),
        // #60, C10: a number and a colon.
        ("user1:2345678 at 12:30", "user1:[REDACTED]"),
        ("at 12:30 id 7:9hunter2", "at 12:30 id 7:[REDACTED]"),
        ("t 1:482913", "t 1:[REDACTED]"),
        ("at 10.0.0.1:8080 ok", "at 10.0.0.1:8080 ok"),
        ("at 2026-10-19T12:30:45.123+03:00 ok", "at 2026-10-19T12:30:45.123+03:00 ok"),
        ("line 42:10", "line 42:10"),
        // #61, C11: the safe alphabet.
        ("user\u{A789} hunter2", "user[REDACTED]"),
        ("status=200 note\u{2192} hunter2", "status=200 note[REDACTED]"),
        ("Merhaba dünya \u{1F44B} bye", "Merhaba dünya [REDACTED]"),
        ("\u{1F101}status=200", "[REDACTED]"),
        ("a\u{00A0}b", "a[REDACTED]"),
        ("login pa\u{115F}ssword hunter2", "login [REDACTED]"),
        ("\u{2028}status=200", "[REDACTED]"),
        ("status=200\u{0B}ok", "status=200[REDACTED]"),
        // #62, C12: quotes and brackets.
        ("note \"a\nhunter2\": 1", "note [REDACTED]"),
        ("password: 'abc\n  hunter2'", "password: [REDACTED]"),
        ("say (hello", "say ([REDACTED]"),
        ("say (hello) ok", "say (hello) ok"),
        // #63, C13: names held in free text.
        ("field name=\"password\" hunter2", "field name=[REDACTED]"),
        ("<key>password</key>\n<string>k-1</string>", "[REDACTED]"),
        // #64: mixed scripts.
        ("p\u{0430}ssword=hunter2", "p\u{0430}ssword=[REDACTED]"),
        ("t\u{043E}ken hunter2", "[REDACTED]"),
    ])
    func cutPoint(input: String, expected: String) {
        #expect(policy.redact(text: input) == expected)
    }

    @Test("#50: an app that allows a key reads on after it")
    func allowedKey() {
        #expect(RedactionPolicy(allowedTextKeys: ["user"]).redact(text: "login user=bob status=401 password=hunter2")
            == "login user=bob status=401 password=[REDACTED]")
    }
}

@Suite("Redaction spec: the shared names and the limits")
struct RedactionSpecNamesAndLimitsTests {
    /// §2 K3: the 26 names every package that follows the specification hides.
    static let sharedNames = [
        "password", "passwd", "pwd", "secret", "token", "access_token", "refresh_token", "id_token", "api_key", "apikey", "key", "auth",
        "authorization", "cookie", "set-cookie", "session", "sid", "otp", "pin", "cvv", "card", "iban", "ssn", "private_key",
        "client_secret", "signature",
    ]

    @Test("K3: every shared secret name hides its value", arguments: sharedNames)
    func sharedName(name: String) {
        #expect(RedactionPolicy.default.isSensitive(name: name))
        let body = RedactionPolicy.default.redact(body: Data(#"{"\#(name)":"Qz71"}"#.utf8), contentType: "application/json").body
        #expect(String(decoding: body, as: UTF8.self) == #"{"\#(name)":"[REDACTED]"}"#)
    }

    @Test("§7: the limits are the specification's")
    func limits() {
        #expect(RedactionPolicy.defaultMaximumBodySize == 256 * 1_024)
        #expect(RedactionPolicy.maximumTextLength == (1 << 28) - 1)
        #expect(RedactionPolicy.maximumJSONDepth == 64 && RedactionPolicy.maximumNestedDocuments == 4)
        #expect(ReadingBudget.inputMultiple == 4)
        #expect(FreeTextScanner.longestJSON == 65_536)
        #expect(PlainName.maximumKeyLength == 256 && FreeTextScanner.longestWord == 256)
        #expect(RedactionPolicy.maximumPathSegments == 64 && RedactionPolicy.maximumQueryParameters == 128)
        #expect(CompatibilityText.fewestSlots == 16 && CompatibilityText.mostSlots == 8_192)
        #expect(MultipartBody.maximumPartCount == 1_000)
    }
}
