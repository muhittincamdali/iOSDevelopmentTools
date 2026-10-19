import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Redaction: free text and value detectors")
struct TextRedactionTests {
    let policy = RedactionPolicy.default
    let redacted = RedactionPolicy.replacement

    @Test("key=value, key: value and \"key\":\"value\" are matched with the key rule", arguments: [
        ("user=ada password=hunter2 status=200", "user=ada password=[REDACTED]"),
        ("password = hunter2", "password = [REDACTED]"),
        (#"api_key: 'hunter2' ok"#, #"api_key: '[REDACTED]' ok"#),
        (#"{"user":"ada","password":"hun\"ter2","time":"12:30"}"#, #"{"user":"ada","password":"[REDACTED]","time":"12:30"}"#),
        (#"payload {\"token\":\"hunter2\"} sent"#, #"payload {\"token\":\"[REDACTED]\"} sent"#),
        (#"{"pass word":"hunter2"}"#, #"{"pass word":"[REDACTED]"}"#),
        ("Authorization: Bearer abc", "Authorization: [REDACTED]"),
        ("https://api.x.com/v1?password=hunter2&page=2", "https://api.x.com/v1?password=[REDACTED]"),
        ("data[password]=hunter2", "data[password]=[REDACTED]"),
        ("api key: hunter2", "api key: [REDACTED]"),
        ("Kullanıcı: ada", "Kullanıcı: [REDACTED]"),
    ])
    func keyedValues(text: String, expected: String) {
        #expect(policy.redact(text: text) == expected)
    }

    @Test("A secret word without = or : makes the rest of the line ambiguous", arguments: [
        ("Signed in with token abc123 for ada", "Signed in with token [REDACTED]"),
        ("session started", "session [REDACTED]"),
        ("password∶hunter2", "[REDACTED]"),
        ("ｔｏｋｅｎ hunter2", "[REDACTED]"),
        ("Refreshing token.", "Refreshing token."),
        ("tokens refreshed", "tokens refreshed"),
    ])
    func ambiguousLines(text: String, expected: String) {
        #expect(policy.redact(text: text) == expected)
    }

    @Test("A hidden key at the end of a line hides the next line with text")
    func valueOnNextLine() {
        #expect(policy.redact(text: "password:\n\n  hunter2\nnext") == "password:\n\n  \(redacted)\nnext")
        #expect(policy.redact(text: "note:\nhello") == "note:\nhello")
        #expect(policy.redact(text: "password\n= hunter2\nnext") == "password\n= \(redacted)\nnext")
        #expect(policy.redact(text: "Status:\n=====\nTotal: 3") == "Status:\n=====\nTotal: 3")
    }

    @Test("U+2028, U+2029, U+0085, VT and FF are folded to LF; CR and CRLF end a line and are kept")
    func lineBreaks() {
        let text = "a=1\r\nb=2\u{2028}c=3\u{2029}d=4\u{85}e=5\u{0B}f=6\u{0C}g=7\rh=8\n"
        #expect(Array(policy.redact(text: text).unicodeScalars) == Array("a=1\r\nb=2\nc=3\nd=4\ne=5\nf=6\ng=7\rh=8\n".unicodeScalars))
        #expect(RedactionPolicy.lines(of: text).count == 9)
        #expect(policy.redact(text: "ok\u{2028}token=hunter2\u{2029}after") == "ok\ntoken=\(redacted)\nafter")
    }

    @Test("JWTs, bearer tokens, long hex and Base64, card numbers, IBANs and emails are found anywhere", arguments: [
        ("jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl end", "jwt [REDACTED] end"),
        ("got Bearer abc.DEF-123_x= here", "got Bearer [REDACTED] here"),
        ("hash 0123456789abcdef0123456789abcdef end", "hash [REDACTED] end"),
        ("aws wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY end", "aws [REDACTED] end"),
        ("paid with 4111 1111 1111 1111 today", "paid with [REDACTED] today"),
        ("paid with 4111-1111-1111-1112 today", "paid with 4111-1111-1111-1112 today"),
        ("to DE89 3704 0044 0532 0130 00 now", "to [REDACTED] now"),
        ("to DE89 3704 0044 0532 0130 01 now", "to DE89 3704 0044 0532 0130 01 now"),
        ("to DE89 3704 0044 0532 0130 00 and", "to [REDACTED] and"), ("DE89370400440532013000.", "[REDACTED]."),
        ("ref BF65030133E1 placed", "ref BF65030133E1 placed"),
        ("mail ada.l+x@example.co.uk now", "mail [REDACTED] now"),
        ("Order E621E1F8-C36C-495A-93FC-0C247A3E6E5F placed", "Order E621E1F8-C36C-495A-93FC-0C247A3E6E5F placed"),
        ("/Users/ada/Library/Developer/CoreSimulator/Devices/1A2B/data", "/Users/ada/Library/Developer/CoreSimulator/Devices/1A2B/data"),
        ("Supercalifragilisticexpialidociousness", "Supercalifragilisticexpialidociousness"),
    ])
    func detectors(text: String, expected: String) {
        #expect(policy.redact(text: text) == expected)
    }

    @Test("The checksums accept known values and reject near misses")
    func checksums() {
        #expect(ValueDetectors.Checksums.passesLuhn([4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]))
        #expect(!ValueDetectors.Checksums.passesLuhn([4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2]))
        let ibans = ["GB82 WEST 1234 5698 7654 32", "FR1420041010050500013M02606", "TR330006100519786457841326"]
        for iban in ibans {
            #expect(ValueDetectors.Checksums.ibans(in: Array(iban.unicodeScalars)) == [0..<iban.unicodeScalars.count])
        }
    }

    @Test("Long and hostile lines are scanned in linear time")
    func longLines() {
        let long = String(repeating: "a=b&", count: 20_000) + "token=hunter2"
        #expect(policy.redact(text: long).hasSuffix("token=\(redacted)"))
        let quotes = String(repeating: "\"x\":", count: 20_000)
        #expect(!policy.redact(text: quotes).isEmpty)
        let ats = String(repeating: "a@", count: 20_000)
        #expect(policy.redact(text: ats) == ats)
    }

    @Test("Log messages are redacted before they are kept and passed on")
    func logStore() {
        let store = LogStore(configuration: .init(maximumMessageLength: 40, systemLogSubsystem: nil))
        store.info("login password=hunter2 for ada")
        store.info("Order E621E1F8-C36C-495A-93FC-0C247A3E6E5F placed")
        #expect(store.entries.map(\.message) == ["login password=\(redacted)", "Order E621E1F8-C36C-495A-93FC-0C247A3E6E…"])
        let raw = LogStore(configuration: .init(systemLogSubsystem: nil, redaction: .disabled))
        raw.info("password=hunter2")
        #expect(raw.entries.first?.message == "password=hunter2")
    }
}
