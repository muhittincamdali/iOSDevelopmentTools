import Testing
@testable import iOSDevelopmentTools

/// Field names written to get past the redactor: look-alike letters, styled letters, invisible
/// characters, escapes, punctuation and unusual whitespace.
@Suite("Redaction corpus: obfuscated names")
struct RedactionObfuscationTests {
    let redactor = Redactor()

    @Test("hides the value of a name with letters outside ASCII", arguments: [
        ("p\u{0430}ssword=hunter2", "[REDACTED]"),
        ("\u{0440}assword=hunter2", "[REDACTED]"),
        ("{\"p\u{0430}ssword\":\"hunter2\"}", "{\"p\u{0430}ssword\":[REDACTED]"),
        ("\u{0420}\u{0410}SSWORD=hunter2", "[REDACTED]"),
        ("t\u{03BF}ken=hunter2", "[REDACTED]"),
        ("t\u{0254}ken=hunter2", "t\u{0254}ken=[REDACTED]"),
        ("\u{1D429}\u{1D41A}\u{1D42C}\u{1D42C}\u{1D430}\u{1D428}\u{1D42B}\u{1D41D}=hunter2",
         "\u{1D429}\u{1D41A}\u{1D42C}\u{1D42C}\u{1D430}\u{1D428}\u{1D42B}\u{1D41D}=[REDACTED]"),
        ("\u{24DF}assword=hunter2", "\u{24DF}assword=[REDACTED]"),
        ("\u{FF50}\u{FF41}\u{FF53}\u{FF53}\u{FF57}\u{FF4F}\u{FF52}\u{FF44}=hunter2", "\u{FF50}\u{FF41}\u{FF53}\u{FF53}\u{FF57}\u{FF4F}\u{FF52}\u{FF44}=[REDACTED]"),
        ("p\u{00E1}ssword=hunter2", "p\u{00E1}ssword=[REDACTED]"),
        ("pa\u{00DF}word=hunter2", "pa\u{00DF}word=[REDACTED]"),
        ("user_\u{043F}\u{0430}\u{0440}\u{043E}\u{043B}\u{044C}: hunter2", "[REDACTED]"),
        // A word that mixes scripts cannot be read: the rest of the text goes with it.
        ("<passw\u{0434}rd>hunter2</passw\u{0434}rd>", "<[REDACTED]"),
    ])
    func lettersOutsideASCII(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // No list of look-alikes is complete, so a name in another script is not compared at all:
    // its value is hidden even when the name means nothing secret.
    @Test("hides the value of a name written in another script", arguments: [
        ("\u{0442}\u{043E}\u{043A}\u{0435}\u{043D}: \u{043D}\u{0435}\u{0442}", "\u{0442}\u{043E}\u{043A}\u{0435}\u{043D}: [REDACTED]"),
        ("\u{0441}\u{0442}\u{0430}\u{0442}\u{0443}\u{0441}=ok", "\u{0441}\u{0442}\u{0430}\u{0442}\u{0443}\u{0441}=[REDACTED]"),
        ("caf\u{00E9}=open", "caf\u{00E9}=[REDACTED]"),
        ("stra\u{00DF}e=Hauptstra\u{00DF}e 1", "stra\u{00DF}e=[REDACTED]"),
        ("\u{6CE8}\u{610F}\u{FF1A}\u{8BF7}\u{7A0D}\u{5019}", "\u{6CE8}\u{610F}\u{FF1A}[REDACTED]"),
    ])
    func otherScriptNames(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("text in other scripts without a field stays as it is", arguments: [
        "\u{30D1}\u{30B9}\u{30EF}\u{30FC}\u{30C9}\u{3092}\u{5909}\u{66F4}\u{3057}\u{307E}\u{3057}\u{305F}",
        "Merhaba d\u{00FC}nya status=200",
        "\u{6771}\u{4EAC} 3:00",
    ])
    func otherScriptText(input: String) {
        #expect(redactor.redact(input) == input)
    }

    // Punctuation and symbols outside ASCII are outside the safe alphabet: the text after them is
    // hidden, in every script.
    @Test("punctuation and symbols of other scripts hide the text after them", arguments: [
        ("\u{4F60}\u{597D}\u{3001}\u{4E16}\u{754C}", "\u{4F60}\u{597D}[REDACTED]"),
        ("\u{6771}\u{4EAC}\u{30FB}\u{5927}\u{962A}", "\u{6771}\u{4EAC}[REDACTED]"),
        ("100\u{20AC}/month", "100[REDACTED]"),
        ("\u{8A2D}\u{5B9A}\u{3002}", "\u{8A2D}\u{5B9A}\u{3002}"),
    ])
    func otherScriptPunctuation(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("hides the value of a name with invisible characters or marks", arguments: [
        ("pass\u{200B}word=hunter2", "[REDACTED]"),
        ("pass\u{2060}word=hunter2", "[REDACTED]"),
        ("pass\u{00AD}word=hunter2", "[REDACTED]"),
        ("pa\u{FE0F}ssword=hunter2", "pa\u{FE0F}ssword=[REDACTED]"),
        ("pa\u{0301}ssword=hunter2", "pa\u{0301}ssword=[REDACTED]"),
        ("\u{202E}drowssap=hunter2", "[REDACTED]"),
        ("pass\u{E0061}word=hunter2", "[REDACTED]"),
        ("password \u{200B}= hunter2", "password \u{200B}= [REDACTED]"),
        ("password=\u{0301}hunter2", "password=[REDACTED]"),
    ])
    func invisibleCharacters(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("hides the value of a name with escapes", arguments: [
        // An escape in free text is a trigger where it starts.
        ("pass%77ord=hunter2", "pass[REDACTED]"),
        ("%70%61%73%73%77%6F%72%64=hunter2", "[REDACTED]"),
        ("p&#97;ssword=hunter2", "p[REDACTED]"),
        ("p&#x61;ssword=hunter2", "p[REDACTED]"),
        ("&quot;password&quot;:&quot;hunter2&quot;", "[REDACTED]"),
        ("{\"pass\\u0077ord\":\"hunter2\"}", "{\"pass\\u0077ord\":[REDACTED]"),
        ("log {\"pass\\u0077ord\":\"hunter2\"}", "log {\"pass\\u0077ord\":[REDACTED]"),
        ("password=abc&#100;ef next=1", "password=[REDACTED]"),
        ("password=hunter%32 next=1", "password=[REDACTED]"),
    ])
    func escapedNames(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("reads = and : written as escapes", arguments: [
        ("password&#61;hunter2", "password[REDACTED]"),
        ("password&equals;hunter2", "password[REDACTED]"),
        ("password&colon;hunter2", "password[REDACTED]"),
        ("password\\u003Ahunter2", "password[REDACTED]"),
        ("password\\x3Dhunter2", "password[REDACTED]"),
        ("password%253Dhunter2", "password[REDACTED]"),
        ("password%25253Ahunter2", "password[REDACTED]"),
    ])
    func escapedSeparators(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("escapes of characters that end a value are not decoded")
    func escapedTerminators() {
        #expect(redactor.redact("password=a%26b%20c next=1") == "password=[REDACTED]")
        #expect(redactor.redact("count=50%25 of %ZZ & more") == "count=50[REDACTED]")
        #expect(redactor.redact("count=50% of %ZZ & more") == "count=50% of %ZZ & more")
    }

    @Test("folds . like _ and - and still finds the secret word", arguments: [
        ("pass.word=hunter2", "pass.word=[REDACTED]"),
        ("api.key=hunter2", "api.key=[REDACTED]"),
        ("client.secret=hunter2", "client.secret=[REDACTED]"),
        ("user.session=abc", "user.session=[REDACTED]"),
        ("{\"api key\":\"hunter2\"}", "{\"api key\":[REDACTED]"),
    ])
    func foldedNames(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // Punctuation outside ASCII may be a separator: the value is hidden from there.
    @Test("hides the value of a name with punctuation other than _, -, . and spaces", arguments: [
        ("pass/word=hunter2", "pass/word=[REDACTED]"),
        ("pass#word=hunter2", "pass#word=[REDACTED]"),
        ("pass\u{00B7}word=hunter2", "pass[REDACTED]"),
        ("pass\"word\"=hunter2", "pass\"[REDACTED]"),
        ("\"pass\"word: hunter2", "\"pass\"[REDACTED]"),
    ])
    func punctuationInNames(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // `pass` is a secret word of its own; split names are read with the next word.
    @Test("reads a secret word split by whitespace", arguments: [
        ("pass word=hunter2", "pass [REDACTED]"),
        ("pass  word=hunter2", "pass  [REDACTED]"),
        ("pass\tword=hunter2", "pass\t[REDACTED]"),
        ("pass\u{00A0}word=hunter2", "pass\u{00A0}[REDACTED]"),
        ("p a s s w o r d=hunter2", "p a s s w o r d=[REDACTED]"),
        ("pa.ss word=hunter2", "pa.ss [REDACTED]"),
        ("API key: hunter2", "API key: [REDACTED]"),
        ("Session ID: abc123", "Session [REDACTED]"),
        ("to ken hunter2", "to ken [REDACTED]"),
        ("my pa ssword hunter2", "my pa ssword [REDACTED]"),
        ("c|vv | 123", "c|vv [REDACTED]"),
        ("verification code 123456", "verification code [REDACTED]"),
    ])
    func splitNames(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a secret word split by whitespace inside a longer name", arguments: [
        ("mypa ssword=hunter2", "mypa ssword=[REDACTED]"),
        ("myto ken=hunter2", "myto ken=[REDACTED]"),
        ("mysec ret=hunter2", "mysec ret=[REDACTED]"),
        ("myapi Key: hunter2", "myapi Key: [REDACTED]"),
        ("dbp wd=hunter2", "dbp wd=[REDACTED]"),
        ("myPa* ss=hunter2", "myPa* ss=[REDACTED]"),
        ("mypa ssword hunter2", "mypa ssword [REDACTED]"),
    ])
    func splitInsideLongerName(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a word that cannot be read hides the rest of the text", arguments: [
        ("p\u{0430}ss word=hunter2", "[REDACTED]"),
        ("login pa\u{115F}ssword hunter2 ok", "login [REDACTED]"),
        ("login pa\u{7F}ssword hunter2 ok", "login [REDACTED]"),
        ("got Bearer\u{3164}abc123", "got [REDACTED]"),
        ("mail alice\u{115F}smith@example.com", "mail [REDACTED]"),
        // A letter without an ASCII form may stand for any letter of a secret word.
        ("login Authoriz\u{0251}tion hunter2", "login Authoriz\u{0251}tion [REDACTED]"),
    ])
    func unreadableWords(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a secret word hides the rest of the text, also before a pair", arguments: [
        ("pass rate=0.9", "pass [REDACTED]"),
        ("the token count: 5", "the token [REDACTED]"),
        ("a long bypassword x=1", "a long bypassword [REDACTED]"),
        ("Authorization failed for user=bob", "Authorization [REDACTED]"),
        ("p%61ss word=hunter2", "p[REDACTED]"),
    ])
    func secretWordsBeforePairs(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("words that only hold the letters of a secret word are left alone", arguments: [
        "compass heading north", "user id 42", "v1.2 status=5", "GET /api/v1 status=7", "keyboard layout changed",
        "Kullan\u{0131}c\u{0131} giri\u{015F} yapt\u{0131}",
    ])
    func wordsWithoutSecrets(input: String) {
        #expect(redactor.redact(input) == input)
    }
}
