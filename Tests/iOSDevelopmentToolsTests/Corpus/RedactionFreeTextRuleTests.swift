import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The free-text rule: the first trigger hides everything after it, to the end of the text. A
/// trigger is a key that is not on the allowlist, a secret name with or without a separator, a
/// word that cannot be read and a quote or bracket that does not close.
@Suite("Redaction corpus: free-text rule")
struct RedactionFreeTextRuleTests {
    let redactor = Redactor()

    @Test("only allowed keys are read on", arguments: [
        ("status=200 method=GET path=/a duration_ms=12 count=3", "status=200 method=GET path=/a duration_ms=12 count=3"),
        ("status: 500, count: 2, method: GET", "status: 500, count: 2, method: GET"),
        ("--status=1 (count=2) [path=/a]", "--status=1 (count=2) [path=/a]"),
        ("\"status\":\"ok\" 'count':5", "\"status\":\"ok\" 'count':5"),
        ("Status=1 STATUS=2 Duration-MS=3 duration.ms=4", "Status=1 STATUS=2 Duration-MS=3 duration.ms=4"),
        ("status==200 x", "status==200 x"),
        ("status=200 user=bob", "status=200 user=[REDACTED]"),
        ("user=bob status=200", "user=[REDACTED]"),
        ("status=200 attempt=2 level=warn", "status=200 attempt=[REDACTED]"),
        ("--status=1 (count=2) [page=3]", "--status=1 (count=2) [page=[REDACTED]"),
        ("x=hunter2", "x=[REDACTED]"),
        ("db_pw=ft1 pw=ft2", "db_pw=[REDACTED]"),
        ("refresh=ft42", "refresh=[REDACTED]"),
        ("Status=1 STATUS_CODE=2 status-code=3", "Status=1 STATUS_CODE=[REDACTED]"),
        ("\u{FF53}\u{FF54}\u{FF41}\u{FF54}\u{FF55}\u{FF53}=200", "\u{FF53}\u{FF54}\u{FF41}\u{FF54}\u{FF55}\u{FF53}=[REDACTED]"),
        ("st%61tus=200", "[REDACTED]"),
        ("status\u{0301}=200", "status\u{0301}=[REDACTED]"),
        ("status=200&user=bob", "status=200&user=[REDACTED]"),
        ("status=200;user=bob", "status=200;user=[REDACTED]"),
        ("status=200,user=bob", "status=200,user=[REDACTED]"),
        ("path=/x?token=abc", "path=/x?token=[REDACTED]"),
        ("status=200 password=x", "status=200 password=[REDACTED]"),
        ("user=\"bob smith\" status=1", "user=[REDACTED]"),
        ("data={\"a\":[1,2]} status=1", "data=[REDACTED]"),
        ("Error: connection refused", "Error: [REDACTED]"),
        ("[INFO] app: started", "[INFO] app: [REDACTED]"),
        ("curl -u bob:Vq302Lm8x https://x.example", "curl -u bob:[REDACTED]"),
    ])
    func allowlist(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("the app can allow more keys, but never a secret one")
    func customAllowlist() {
        let custom = Redactor(allowedTextKeys: ["user", "request_id", "token"])
        #expect(custom.redact("user=bob request-id=7 token=abc") == "user=bob request-id=7 token=[REDACTED]")
        #expect(custom.redact("login user=bob status=401 password=hunter2") == "login user=bob status=401 password=[REDACTED]")
    }

    // A separator outside ASCII is outside the safe alphabet: it cuts the text where it is,
    // whatever key comes before it.
    @Test("separators are = and :, and runs of them; one outside ASCII cuts the text; a : between digits is a time", arguments: [
        ("user:=bob", "user:=[REDACTED]"),
        ("user == bob", "user == [REDACTED]"),
        ("user => bob", "user => [REDACTED]"),
        ("user ::= bob", "user ::= [REDACTED]"),
        ("user\u{FF1D}bob", "user[REDACTED]"),
        ("user\u{FF1A}bob", "user[REDACTED]"),
        ("user\u{FE13}bob", "user[REDACTED]"),
        ("user\u{2260}bob", "user[REDACTED]"),
        ("user\u{203F}bob", "user[REDACTED]"),
        ("a \u{203F} b", "a [REDACTED]"),
        ("status\u{A789} ok", "status[REDACTED]"),
        ("at 12:30:45 done", "at 12:30:45 done"),
        ("2026-10-19T12:30:45Z ok", "2026-10-19T12:30:45Z ok"),
        ("host:8080", "host:[REDACTED]"),
        ("=bob", "=[REDACTED]"),
        ("x = = bob", "x = [REDACTED]"),
    ])
    func separators(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // Nothing is carried from one line to the next: the cut covers them all.
    @Test("everything after the first trigger is hidden, to the end of the text", arguments: [
        ("status=200\nlogin ok\nuser=bob\nstatus=201\nmore text", "status=200\nlogin ok\nuser=[REDACTED]"),
        ("password:\n  hunter2\nnext", "password:[REDACTED]"),
        ("config:\n  password: x\n  user: bob\nstatus=1", "config:[REDACTED]"),
        ("key: |\n  line one\n  line two\nstatus=1", "key: [REDACTED]"),
        ("export TOKEN=abc \\\ndef\nstatus=1", "export TOKEN=[REDACTED]"),
        ("password=\"abc\ndef\" status=1", "password=[REDACTED]"),
        ("password\n= hunter2", "password\n= [REDACTED]"),
        ("password\n:\n\"hunter2\" status=1", "password\n:[REDACTED]"),
        ("status=1 msg=\"a\nb\" status=2\nlast line", "status=1 msg=[REDACTED]"),
        ("done in 12 ms\nError: x\nstatus=200", "done in 12 ms\nError: [REDACTED]"),
        ("status=1\r\nuser=bob\r\nstatus=2", "status=1\r\nuser=[REDACTED]"),
        ("status=1\r\nuser=bob\rstatus=2", "status=1\r\nuser=[REDACTED]"),
        ("password=hunter\u{2028}2", "password=[REDACTED]"),
        ("password=hunter\u{0B}2\nstatus=3", "password=[REDACTED]"),
    ])
    func cutToTheEnd(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a secret name without a separator hides everything after it", arguments: [
        ("password hunter2", "password [REDACTED]"),
        ("password hunter2\nnext line", "password [REDACTED]"),
        ("login secret e32", "login secret [REDACTED]"),
        ("login api_key e33", "login api_key [REDACTED]"),
        ("--client-secret k128", "--client-secret [REDACTED]"),
        ("export AWS_SECRET_ACCESS_KEY k129", "export AWS_SECRET[REDACTED]"),
        ("PIN 1234 entered", "PIN [REDACTED]"),
        ("the token expired", "the token [REDACTED]"),
        ("Session ID abc123", "Session [REDACTED]"),
        ("my_password_is_hunter2 x", "my_password[REDACTED]"),
        ("setPassword(hunter2)", "setPassword[REDACTED]"),
        ("\"password\" hunter2", "\"password\" [REDACTED]"),
        ("password\u{A789}hunter2 next", "password[REDACTED]"),
        ("password \u{2236} hunter2", "password [REDACTED]"),
        ("password\u{2254}hunter2", "password[REDACTED]"),
        ("pass word=hunter2", "pass [REDACTED]"),
        ("<password>hunter2</password>", "[REDACTED]"),
        ("<password>\nhunter2\n</password>", "[REDACTED]"),
        ("<key>password</key>\n<string>hunter2</string>", "[REDACTED]"),
        ("password\nhunter2", "password[REDACTED]"),
        ("wrong password", "wrong password"),
    ])
    func secretNameWithoutSeparator(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("secret names are found behind styles, invisible characters, marks and escapes", arguments: [
        "\u{1D429}\u{1D41A}\u{1D42C}\u{1D42C}\u{1D430}\u{1D428}\u{1D42B}\u{1D41D} hunter2", "\u{24DF}assword hunter2",
        "\u{FF50}\u{FF41}\u{FF53}\u{FF53}\u{FF57}\u{FF4F}\u{FF52}\u{FF44} hunter2", "pass\u{200B}word hunter2",
        "pa\u{0301}ssword hunter2", "pass\u{00AD}word hunter2", "PASS-WORD hunter2", "pass.word hunter2",
        "p&#97;ssword hunter2", "p&#x61;ssword hunter2", "pass%77ord hunter2", "pass%2577ord hunter2", "\\u0070assword hunter2",
        "\\u{70}assword hunter2", "pass\\x77ord hunter2", "password%3Dhunter2", "password&#61;hunter2", "password\\u003Dhunter2",
    ])
    func disguisedSecretNames(input: String) {
        let output = redactor.redact(input)
        #expect(!output.contains("hunter2"), "\(input.debugDescription) -> \(output.debugDescription)")
        #expect(output.hasSuffix("[REDACTED]"))
    }

    @Test("a word that mixes scripts, or a quote that does not close on its line, hides everything from it", arguments: [
        ("login p\u{0430}ssword hunter2", "login [REDACTED]"),
        ("\u{0440}\u{0430}\u{0455}\u{0455}\u{051D}\u{043E}\u{0433}d hunter2", "[REDACTED]"),
        ("t\u{03BF}ken hunter2", "[REDACTED]"),
        ("p%D0%B0ssword hunter2", "[REDACTED]"),
        ("status=\u{043E}k", "status=[REDACTED]"),
        ("say \"hunter2", "say [REDACTED]"),
        ("say \"hi\" and 5\" more", "say \"hi\" and 5[REDACTED]"),
        ("say \"hi\nhunter2\"", "say [REDACTED]"),
    ])
    func ambiguity(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // Review probes 71, 80 and 401–414: the scanning copy leaves out an invisible character, so a
    // key or word that starts with one was read without it, as the allowed key `status` or a
    // plain word. An invisible character is outside the safe alphabet: it cuts the text there.
    @Test("an invisible character cuts the text where it is", arguments: [
        ("\u{200D}status=Qz080Wk7r", "[REDACTED]"),
        ("x \u{200B}status=hunter2", "x [REDACTED]"),
        ("\u{2060}status=hunter2", "[REDACTED]"),
        ("\u{115F}status=hunter2", "[REDACTED]"),
        ("\u{AD}status: hunter2", "[REDACTED]"),
        ("\u{FEFF}status=200", "[REDACTED]"),
        ("status=200 \u{200B}", "status=200 [REDACTED]"),
        ("status=2\u{200B}00", "status=[REDACTED]"),
        ("\u{202E}drowssap Qz071Wk7r", "[REDACTED]"),
        ("login \u{202E}zyx2retnuh drowssap", "login [REDACTED]"),
        ("\u{2066}\u{202E}drowssap hunter2", "[REDACTED]"),
    ])
    func invisibleBeforeKeyOrWord(input: String, expected: String) {
        let output = redactor.redact(input)
        #expect(Array(output.unicodeScalars) == Array(expected.unicodeScalars), "\(output.debugDescription)")
    }

    @Test("text without a trigger stays as it is", arguments: [
        "Merhaba Kullanıcı giriş yaptı", "Straße naïve café", "заказ отправлен", "東京 ログイン成功", "iPhoneで決済しました",
        "say \"hi\" now", "[INFO] started in 12 ms", "keyboard layout changed", "keynote ready", "bypass mode",
        "user logged in at 12:30 from 10.0.0.1", "status=200 method=GET path=/api/items",
    ])
    func unchanged(input: String) {
        #expect(redactor.redact(input) == input)
    }

    // Only LF and CR end a line of the safe alphabet; any other line break is a control character
    // or a separator outside ASCII, which cuts the text.
    @Test("U+2028, U+2029, U+0085, VT and FF cut the text; LF and CR are kept")
    func lineSeparators() {
        #expect(redactor.redact("a\nb\r\nc\rd") == "a\nb\r\nc\rd")
        #expect(redactor.redact("a\u{2029}b\u{85}c\u{0B}d\u{0C}e") == "a[REDACTED]")
        #expect(redactor.redact("a\u{85}b") == "a[REDACTED]")
        #expect(redactor.redact("a\u{0B}b") == "a[REDACTED]")
        #expect(redactor.redact("a\u{0C}b") == "a[REDACTED]")
        #expect(redactor.redact("password\u{2028}=hunter2") == "password[REDACTED]")
        #expect(redactor.redact("user\u{2028}=bob") == "user[REDACTED]")
        #expect(redactor.redact("status=1\u{2029}user=bob\u{85}status=2") == "status=1[REDACTED]")
    }

    @Test("JSON in a line follows the allowlist member by member", arguments: [
        ("{\"status\":200,\"count\":3} tail", "{\"status\":200,\"count\":3} tail"),
        ("{\"status\":200,\"user\":\"bob\"} tail", "{\"status\":200,[REDACTED]"),
        ("{\"status\":\"ok\",\"items\":[1,2]} {\"count\":1}", "{\"status\":\"ok\",[REDACTED]"),
        ("{\"path\":\"/a\",\"items\":[{\"count\":1},{\"name\":\"x\"}]} tail", "{\"path\":\"/a\",[REDACTED]"),
        ("{\"status\":\"x password=1\"} tail", "{\"status\":\"[REDACTED]"),
        ("[\"a\",\"b\"] ok", "[[REDACTED]"),
        ("[\"a\",\"b\",\"c\"] ok", "[\"a\",\"b\",\"c\"] ok"),
        ("[[\"\u{15E}ifre\",\"1234\"]] ok", "[[[REDACTED]"),
    ])
    func jsonMembers(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }
}
