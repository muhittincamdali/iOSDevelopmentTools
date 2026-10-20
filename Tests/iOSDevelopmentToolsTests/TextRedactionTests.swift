import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Redaction: free text and value detectors")
struct TextRedactionTests {
    let policy = RedactionPolicy.default
    let redacted = RedactionPolicy.replacement

    @Test("key=value, key: value and \"key\":\"value\" keep a value only under an allowlisted key", arguments: [
        ("user=ada password=hunter2 status=200", "user=[REDACTED]"),
        ("status=200 method=GET path=/v1/items duration_ms=35 count=3", "status=200 method=GET path=/v1/items duration_ms=35 count=3"),
        ("status=200 user=ada", "status=200 user=[REDACTED]"),
        ("Response took 1.2s, size: 1234 bytes", "Response took 1.2s, size: 1234 bytes"),
        ("password = hunter2", "password = [REDACTED]"),
        (#"api_key: 'hunter2' ok"#, #"api_key: '[REDACTED]' ok"#),
        (#"note: "a b" status=ok"#, #"note: "[REDACTED]" status=ok"#),
        (#"payload {\"token\":\"hunter2\"} sent"#, #"payload {\"token\":\"[REDACTED]\"} sent"#),
        ("Authorization: Bearer abc", "Authorization: [REDACTED]"), ("Bearer: abc", "Bearer: [REDACTED]"),
        ("data[password]=hunter2", "data[password]=[REDACTED]"),
        ("api key: hunter2", "api key: [REDACTED]"),
        ("Kullanıcı: ada", "Kullanıcı: [REDACTED]"),
        ("user：ada", "user：[REDACTED]"),
        ("Payment failed: card declined", "Payment failed: [REDACTED]"),
    ])
    func keyedValues(text: String, expected: String) {
        #expect(policy.redact(text: text) == expected)
    }

    @Test("Keys the app allowlists keep their values; secret names stay hidden when listed")
    func appAllowlist() {
        let policy = RedactionPolicy(allowedTextKeys: ["user", "order-id", "password"])
        #expect(policy.redact(text: "user=ada orderID: 42 password=hunter2") == "user=ada orderID: 42 password=\(redacted)")
        #expect(policy.redact(text: #"{"user":"ada","password":"hunter2"}"#) == #"{"user":"ada","password":"[REDACTED]"}"#)
        #expect(policy.allowedTextKeys.isSuperset(of: ["status", "durationms", "user", "orderid"]))
        #expect(RedactionPolicy.default.redact(text: "user=ada") == "user=\(redacted)")
    }

    @Test("JSON in a line is parsed; a member keeps its value only under an allowlisted key; JSON that does not parse hides the rest", arguments: [
        (#"payload {"status":200,"pass":"hunter2"} done"#, #"payload {"status":200,"pass":"[REDACTED]"} done"#),
        (#"{"user":"ada","password":"hun\"ter2","time":"12:30"}"#, #"{"user":"[REDACTED]","password":"[REDACTED]","time":"[REDACTED]"}"#),
        (#"payload {"a": "hunter2""#, "payload [REDACTED]"),
        (#"payload {"a": hunter2} done"#, "payload [REDACTED]"),
        (#"["token","hunter2","x"] done"#, #"["token","[REDACTED]","[REDACTED]"] done"#),
        (#"got [{"count":2,"items":["a"]}]"#, #"got [{"count":2,"items":"[REDACTED]"}]"#),
        (#"dict ["token": "hunter2"]"#, "dict [REDACTED]"),
        ("[INFO] started {0} of [1/3]", "[INFO] started {0} of [1/3]"),
        ("{\n  \"status\": 200,\n  \"token\": \"hunter2\"\n}", "{\n  \"status\": 200,\n  \"token\": \"[REDACTED]\"\n}"),
    ])
    func embeddedJSON(text: String, expected: String) {
        #expect(policy.redact(text: text) == expected)
    }

    @Test("URLs in text follow the URL rules")
    func urlsInText() {
        #expect(policy.redact(text: "Opened https://example.com/docs/getting-started.") == "Opened https://example.com/docs/getting-started.")
        #expect(policy.redact(text: "GET https://ada:pw@api.x.com/v1/users/123456?page=2&token=hunter2#top done")
            == "GET https://api.x.com/v1/users/:id?page=\(redacted)&token=\(redacted) done")
        #expect(policy.redact(text: #"opened "https://e.com/a?q=1" now"#) == #"opened "https://e.com/a?q=[REDACTED]" now"#)
        let lenient = RedactionPolicy(allowedQueryParameters: ["page"], urlDetail: .full)
        #expect(lenient.redact(text: "see https://e.com/list?page=2&token=x") == "see https://e.com/list?page=2&token=\(redacted)")
        #expect(RedactionPolicy(urlDetail: .hostOnly).redact(text: "see https://e.com/a/b?c=d") == "see https://e.com")
        // A path segment that holds a secret key or word becomes :id, in text and in requests.
        // `oauth` ends with `auth`, so the segment after it is a value too.
        #expect(policy.redact(text: "see https://e.com/a,token:hunter2/b,password=x/oauth/token") == "see https://e.com/:id/:id/:id/:id")
    }

    @Test("A line that cannot be read with certainty is hidden from the ambiguity on", arguments: [
        (#"msg="unterminated hunter2"#, #"msg="[REDACTED]"#),
        ("status='ok hunter2", "status='[REDACTED]"),
        (#"said "hello" and 5" of hunter2"#, #"said "hello" and 5[REDACTED]"#),
        ("ok t\u{043E}ken hunter2", "ok [REDACTED]"),
        ("p\u{0430}ssword hunter2", "[REDACTED]"),
        ("t\u{03BF}ken=1 status=2", "t\u{03BF}ken=[REDACTED]"),
        ("ok creds%3Dhunter2 x", "ok creds[REDACTED]"), ("status=ok path=%2Fcb%3Ftoken%3Dhunter2", "status=ok path=%2Fcb%3Ftoken[REDACTED]"),
        ("ok creds\\u003ahunter2", "ok creds[REDACTED]"),
        ("Signed in with token abc123 for ada", "Signed in with token [REDACTED]"),
        ("session started", "session [REDACTED]"),
        ("password∶hunter2", "password[REDACTED]"),
        ("ｔｏｋｅｎ hunter2", "ｔｏｋｅｎ [REDACTED]"),
        // A secret name hides what follows it, even when it only names the secret.
        ("Refreshing token.", "Refreshing token[REDACTED]"),
        ("tokens refreshed", "tokens [REDACTED]"),
    ])
    func ambiguousLines(text: String, expected: String) {
        #expect(policy.redact(text: text) == expected)
    }

    @Test("Words of one writing system, times and dates are kept", arguments: [
        "iPhoneで設定を保存しました", "Загружено 5 элементов", "sent hello%20world & 100% done", "Giriş başarılı, 3 öğe yüklendi", "took 120µs",
        "Sync finished at 12:30:45, 3 changes", "at 2026-10-19T10:30:00Z done", "between 9:05 and 10:30:00.250+03:00.",
    ])
    func readableText(text: String) {
        #expect(policy.redact(text: text) == text)
    }

    @Test("A colon that is not inside a time is a key's", arguments: [
        ("pin1:1234", "pin[REDACTED]"), ("localhost:8080", "localhost:[REDACTED]"), ("12:ab", "12:[REDACTED]"),
        // Between two digits a `:` is a time or a ratio.
        ("12:34hunter2", "12:34hunter2"), ("1:2:3", "1:2:3"), ("ratio 16:9", "ratio 16:9"),
    ])
    func colonsThatAreKeys(text: String, expected: String) {
        #expect(policy.redact(text: text) == expected)
    }

    @Test("A hidden key at the end of a line hides the next line with text")
    func valueOnNextLine() {
        #expect(policy.redact(text: "password:\n\n  hunter2\nnext") == "password:\n\n  \(redacted)\nnext")
        #expect(policy.redact(text: "note:\nhello") == "note:\n\(redacted)")
        #expect(policy.redact(text: "password\n= hunter2\nnext") == "password\n= \(redacted)\nnext")
        #expect(policy.redact(text: "status:\n  200\ncount = 3") == "status:\n  200\ncount = 3")
    }

    @Test("U+2028, U+2029, U+0085, VT and FF are folded to LF; CR and CRLF end a line and are kept")
    func lineBreaks() {
        let lenient = RedactionPolicy(allowedTextKeys: ["a", "b", "c", "d", "e", "f", "g", "h"])
        let text = "a=1\r\nb=2\u{2028}c=3\u{2029}d=4\u{85}e=5\u{0B}f=6\u{0C}g=7\rh=8\n"
        #expect(Array(lenient.redact(text: text).unicodeScalars) == Array("a=1\r\nb=2\nc=3\nd=4\ne=5\nf=6\ng=7\rh=8\n".unicodeScalars))
        // A value hidden to a line separator may go on after it, so the next line is hidden too.
        #expect(policy.redact(text: "ok\u{2028}token=hunter2\u{2029}after") == "ok\ntoken=\(redacted)\n\(redacted)")
        #expect(policy.redact(text: "ok\u{2028}token=hunter2\nafter") == "ok\ntoken=\(redacted)\nafter")
    }

    @Test("JWTs, bearer tokens, long hex and Base64, card numbers, IBANs and emails are found anywhere", arguments: [
        ("jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl end", "jwt [REDACTED] end"),
        ("got Bearer abc.DEF-123_x here", "got Bearer [REDACTED] here"),
        ("got Bearer abc.DEF-123_x= here", "got Bearer [REDACTED] [REDACTED]"),
        ("hash 0123456789abcdef0123456789abcdef end", "hash [REDACTED] end"),
        // The key ends in `KEY`, a secret word, so the rest of the line goes too.
        ("aws wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY end", "aws [REDACTED] [REDACTED]"),
        ("paid with 4111 1111 1111 1111 today", "paid with [REDACTED] today"),
        ("paid with 4111-1111-1111-1112 today", "paid with 4111-1111-1111-1112 today"),
        ("to DE89 3704 0044 0532 0130 00 now", "to [REDACTED] now"),
        ("to DE89 3704 0044 0532 0130 02 now", "to DE89 3704 0044 0532 0130 02 now"),
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
        #expect(NormalizedText.passesLuhn([4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]))
        #expect(!NormalizedText.passesLuhn([4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2]))
        for iban in ["GB82 WEST 1234 5698 7654 32", "FR1420041010050500013M02606", "TR330006100519786457841326"] {
            #expect(policy.redact(text: "to \(iban) now") == "to \(redacted) now")
            #expect(NormalizedText.ibanRemainder(ArraySlice(iban.utf8.filter { $0 != UInt8(ascii: " ") })) == 1)
        }
    }

    @Test("Long and hostile lines are scanned in linear time")
    func longLines() {
        // CPU time of this thread, so that other tests running at the same time do not count.
        let start = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        let long = String(repeating: "count=1&", count: 20_000) + "token=hunter2"
        #expect(policy.redact(text: long).hasSuffix("token=\(redacted)"))
        let quotes = String(repeating: "\"x\":", count: 20_000)
        #expect(!policy.redact(text: quotes).isEmpty)
        let ats = String(repeating: "a@", count: 20_000)
        #expect(policy.redact(text: ats) == ats)
        let times = String(repeating: "12:30:45 ", count: 20_000)
        #expect(policy.redact(text: times) == times)
        // Between two digits a `:` is a time, so nothing is hidden.
        let ratios = String(repeating: "1:", count: 50_000)
        #expect(policy.redact(text: ratios) == ratios)
        let objects = String(repeating: #"{"count":1} "#, count: 10_000)
        #expect(policy.redact(text: objects) == objects)
        #expect(policy.redact(text: String(repeating: #"{""#, count: 50_000)) == redacted)
        let urls = String(repeating: "https://e.com/a ", count: 10_000)
        #expect(policy.redact(text: urls) == urls)
        let word = String(repeating: "\u{043E}", count: 200_000) + "o hunter2"
        #expect(policy.redact(text: word) == redacted)
        #expect(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - start < 20_000_000_000)
    }

    @Test("Log messages are redacted before they are kept and passed on")
    func logStore() {
        let store = LogStore(configuration: .init(maximumMessageLength: 40, systemLogSubsystem: nil))
        store.info("login password=hunter2 for ada")
        store.info("Order E621E1F8-C36C-495A-93FC-0C247A3E6E5F placed")
        store.info("login user=ada")
        #expect(store.entries.map(\.message) == ["login password=\(redacted)", "Order E621E1F8-C36C-495A-93FC-0C247A3E6E…", "login user=\(redacted)"])
        let raw = LogStore(configuration: .init(systemLogSubsystem: nil, redaction: .disabled))
        raw.info("password=hunter2")
        #expect(raw.entries.first?.message == "password=hunter2")
    }

    @Test("Emoji sequences, skin tones and the micro sign are text, not disguises", arguments: [
        "Family 👩‍👩‍👧‍👦 joined", "Liked 👍🏽 twice", "coder 👩🏽‍💻 online", "❤️‍🔥 streak", "took 120µs", "reacted 👍🏽x",
    ])
    func emojiAndSigns(text: String) {
        #expect(policy.redact(text: text) == text)
    }

    @Test("A joiner or skin tone between letters still hides what a disguised name hides", arguments: [
        "pass\u{200D}word hunter2", "to\u{200D}ken: hunter2", "password🏽hunter2", "a👍\u{200D}b hunter2 token hunter2",
    ])
    func joinersInWords(text: String) {
        #expect(!policy.redact(text: text).contains("hunter2"))
    }

    @Test("An allowed value in single quotes or backticks that does not close hides the rest of the line", arguments: [
        ("status='ok hunter2", "status='[REDACTED]"), ("status=`ok hunter2", "status=`[REDACTED]"),
        ("status='ok' done", "status='ok' done"), ("status=\"ok hunter2", "status=[REDACTED]"),
    ])
    func allowedQuotedValues(text: String, expected: String) {
        #expect(policy.redact(text: text) == expected)
    }

    @Test("The digits of a UUID are not a card number", arguments: [
        "Order 73297603-2915-4643-B7F3-FD58D90F216C placed", "id ab123456-1234-4234-8230-abcdef123456 ok",
        "ref 12345678-1234-4234-8234-123456789012 done",
    ])
    func uuidsAreNotCards(text: String) {
        #expect(policy.redact(text: text) == text)
        // Grouped card numbers are still found.
        #expect(policy.redact(text: "paid 4111-1111-1111-1111 ok") == "paid \(redacted) ok")
    }

    @Test("JSON in a log line keeps a member only under an allowlisted key; JSON in a string of a body follows the key rule")
    func jsonInTextAndInBodies() {
        #expect(policy.redact(text: #"saved {"status":200,"name":"ada","card":"x"}"#) == #"saved {"status":200,"name":"[REDACTED]","card":"[REDACTED]"}"#)
        let body = Data(#"{"note":"{\"name\":\"ada\",\"card\":\"x\"}"}"#.utf8)
        #expect(String(decoding: policy.redact(body: body, contentType: "application/json").body, as: UTF8.self)
            == #"{"note":"{\"name\":\"ada\",\"card\":\"[REDACTED]\"}"}"#)
        // A text/plain body is free text, like a log message.
        #expect(String(decoding: policy.redact(body: Data(#"{"name":"ada"}"#.utf8), contentType: "text/plain").body, as: UTF8.self)
            == #"{"name":"[REDACTED]"}"#)
    }
}
