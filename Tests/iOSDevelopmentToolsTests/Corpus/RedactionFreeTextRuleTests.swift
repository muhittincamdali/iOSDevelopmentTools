import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The free-text rule: one cut point. A plain key that names no secret keeps its value; from the
/// first trigger (a secret name, a key that is not plain, a separator that is escaped or only looks
/// like one, a token that cannot be read) the rest of the text is hidden, the lines below too.
@Suite("Redaction corpus: free-text rule")
struct RedactionFreeTextRuleTests {
    let redactor = Redactor()

    @Test("plain keys that name no secret keep their value; a secret name or a key that is not plain hides the rest", arguments: [
        ("status=200 method=GET path=/a duration_ms=12 count=3", "status=200 method=GET path=/a duration_ms=12 count=3"),
        ("status: 500, attempt: 2, level: warn", "status: 500, attempt: 2, level: warn"),
        ("--status=1 (count=2) [page=3]", "--status=1 (count=2) [page=3]"),
        ("\"status\":\"ok\" 'limit':5", "\"status\":\"ok\" 'limit':5"),
        ("status=200 user=bob", "status=200 user=bob"),
        ("user=bob status=200", "user=bob status=200"),
        ("db_pw=ft1 pw=ft2", "db_pw=[REDACTED]"),
        ("refresh=ft42", "refresh=ft42"),
        ("Status=1 STATUS_CODE=2 status-code=3", "Status=1 STATUS_CODE=2 status-code=3"),
        ("ｓｔａｔｕｓ=200", "ｓｔａｔｕｓ=[REDACTED]"),
        ("st%61tus=200", "st%61tus=[REDACTED]"),
        ("status\u{0301}=200", "status\u{0301}=[REDACTED]"),
        ("status=200&user=bob", "status=200&user=bob"),
        ("status=200;user=bob", "status=200;user=bob"),
        ("status=200,user=bob", "status=200,user=bob"),
        ("path=/x?token=abc", "path=/x?token=[REDACTED]"),
        ("status=200 password=x", "status=200 password=[REDACTED]"),
    ])
    func plainKeys(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a plain key after the cut stays hidden")
    func keysAfterTheCut() {
        #expect(redactor.redact("user=bob token=abc request-id=7") == "user=bob token=[REDACTED]")
    }

    @Test("separators are = and :, runs of them and their compatibility forms; a : between digits is a time; a separator with no key hides the rest", arguments: [
        ("user:=bob", "user:=bob"),
        ("user == bob", "user == bob"),
        ("user => bob", "user => bob"),
        ("user ::= bob", "user ::= bob"),
        ("user\u{FF1D}bob", "user＝bob"),
        ("user\u{FF1A}bob", "user：bob"),
        ("user\u{FE13}bob", "user︓bob"),
        ("user\u{2260}bob", "user≠bob"),
        ("user\u{203F}bob", "user[REDACTED]"),
        ("a \u{203F} b", "a \u{203F} b"),
        ("at 12:30:45 done", "at 12:30:45 done"),
        ("2026-10-19T12:30:45Z ok", "2026-10-19T12:30:45Z ok"),
        ("host:8080", "host:8080"),
        ("=bob", "=[REDACTED]"),
        ("x = = bob", "x = = [REDACTED]"),
    ])
    func separators(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("after a secret name everything is hidden, whatever quotes, JSON or lines follow; a plain key keeps a quoted value or JSON", arguments: [
        ("user=\"bob smith\" status=1", "user=\"bob smith\" status=1"),
        ("user='bob smith' status=1", "user='bob smith' status=1"),
        ("user=`bob` status=1", "user=`bob` status=1"),
        ("user=\"a\\\"b\" status=1", "user=\"a\\[REDACTED]"),
        ("{\\\"password\\\":\\\"x\\\"}", "{\\\"password[REDACTED]"),
        ("data={\"a\":[1,2]} status=1", "data={\"a\":[1,2]} status=1"),
        ("data=[\"a\",\"b\"],status=1", "data=[\"a\",\"b\"],status=1"),
        ("password=hunter 2 status=ok", "password=[REDACTED]"),
        ("password=(hunter2)tail", "password=[REDACTED]"),
        ("token=abc) tail", "token=[REDACTED]"),
        ("password=[hunter]2 x", "password=[REDACTED]"),
        ("password={hunter}2 x", "password=[REDACTED]"),
        ("password=\"x\"y z", "password=\"[REDACTED]"),
        ("password='x'\"y\" z", "password='[REDACTED]"),
        ("password=\"x\", status=1", "password=\"[REDACTED]"),
        ("password=", "password="),
    ])
    func valueExtent(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("the lines below a trigger are hidden, whatever the layout of the value", arguments: [
        ("password:\n  hunter2\nnext", "password:\n  [REDACTED]"),
        ("password:\n\n\nhunter2", "password:\n\n\n[REDACTED]"),
        ("config:\n  password: x\n  user: bob\nstatus=1", "config:\n  password: [REDACTED]"),
        ("key: |\n  line one\n  line two\nstatus=1", "key: [REDACTED]"),
        ("export TOKEN=abc \\\ndef\nstatus=1", "export TOKEN=[REDACTED]"),
        ("password: // rotate\nhunter2", "password: [REDACTED]"),
        ("password: /* x */\nhunter2", "password: [REDACTED]"),
        ("password: # later\nhunter2", "password: [REDACTED]"),
        ("password=\"abc\ndef\" status=1", "password=\"[REDACTED]"),
        ("password=\"abc\nnext line", "password=\"[REDACTED]"),
        ("password\n= hunter2", "password\n= [REDACTED]"),
        ("password\n:\n\"hunter2\" status=1", "password\n:\n\"[REDACTED]"),
    ])
    func laterLines(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a secret name without a separator hides the rest of the text", arguments: [
        ("password hunter2", "password [REDACTED]"),
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
        ("<password>hunter2</password>", "<password[REDACTED]"),
        ("wrong password", "wrong password"),
    ])
    func secretNameWithoutSeparator(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a secret name that ends its line, also in markup, hides the lines below", arguments: [
        ("<password>\nhunter2\n</password>", "<password[REDACTED]"),
        // The text of a property list's key is a name: a secret one hides everything after it.
        ("<key>password</key>\n<string>hunter2</string>", "<key>[REDACTED]"),
        ("password\nhunter2", "password\n[REDACTED]"),
        ("<password>\u{2028}hunter2\u{2028}</password>", "<password[REDACTED]"),
    ])
    func secretNameBeforeNextLine(input: String, expected: String) {
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

    @Test("a word that mixes scripts, or an unbalanced double quote, hides the rest of the text", arguments: [
        ("login p\u{0430}ssword hunter2", "login [REDACTED]"),
        ("\u{0440}\u{0430}\u{0455}\u{0455}\u{051D}\u{043E}\u{0433}d hunter2", "[REDACTED]"),
        ("t\u{03BF}ken hunter2", "[REDACTED]"),
        ("p%D0%B0ssword hunter2", "[REDACTED]"),
        ("status=\u{043E}k", "status=[REDACTED]"),
        ("say \"hunter2", "say [REDACTED]"),
        ("say \"hi\" and 5\" more", "say \"hi\" and 5[REDACTED]"),
    ])
    func ambiguity(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // Review probes 71, 80 and 401–414: the scanning copy leaves out an invisible character, so a
    // key or word that starts with one was read without it, as the plain key `status` or a plain
    // word. The character belongs to the word, which cannot be read with certainty then.
    @Test("an invisible character right before a key or a word belongs to it and hides the rest", arguments: [
        ("\u{200D}status=Qz080Wk7r", "[REDACTED]"),
        ("x \u{200B}status=hunter2", "x [REDACTED]"),
        ("\u{2060}status=hunter2", "[REDACTED]"),
        ("\u{115F}status=hunter2", "[REDACTED]"),
        ("\u{AD}status: hunter2", "[REDACTED]"),
        ("\u{FEFF}status=200", "[REDACTED]"),
        ("status=200 \u{200B}", "status=200 \u{200B}"),
        ("\u{202E}drowssap Qz071Wk7r", "[REDACTED]"),
        ("login \u{202E}zyx2retnuh drowssap", "login [REDACTED]"),
        ("\u{2066}\u{202E}drowssap hunter2", "[REDACTED]"),
    ])
    func invisibleBeforeKeyOrWord(input: String, expected: String) {
        let output = redactor.redact(input)
        #expect(Array(output.unicodeScalars) == Array(expected.unicodeScalars), "\(output.debugDescription)")
    }

    @Test("prose, other scripts and quoted text stay as they are", arguments: [
        "Merhaba Kullanıcı giriş yaptı", "Straße naïve café", "заказ отправлен", "東京 ログイン成功", "iPhoneで決済しました",
        "say \"hi\" now", "[INFO] started in 12 ms", "keyboard layout changed", "tokenizer ready", "bypass mode",
    ])
    func unchanged(input: String) {
        #expect(redactor.redact(input) == input)
    }

    @Test("U+2028, U+2029, U+0085, VT and FF end a line and are kept as they are, and the cut runs over them")
    func lineSeparators() {
        #expect(redactor.redact("password\u{2028}=hunter2") == "password\u{2028}=[REDACTED]")
        #expect(redactor.redact("user\u{2028}=bob") == "user\u{2028}=bob")
        #expect(redactor.redact("a\u{2029}b\u{85}c\u{0B}d\u{0C}e") == "a\u{2029}b\u{85}c\u{0B}d\u{0C}e")
        #expect(redactor.redact("status=1\r\nuser=bob\r\nstatus=2") == "status=1\r\nuser=bob\r\nstatus=2")
        #expect(redactor.redact("status=1\r\ntoken=abc\rstatus=2") == "status=1\r\ntoken=[REDACTED]")
        #expect(redactor.redact("password=hunter\u{2028}2") == "password=[REDACTED]")
        #expect(redactor.redact("password=hunter\u{0B}2\nstatus=3") == "password=[REDACTED]")
    }
}
