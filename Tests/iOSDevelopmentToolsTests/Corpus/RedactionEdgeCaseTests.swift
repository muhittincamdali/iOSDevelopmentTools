import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Redaction corpus: edge cases")
struct RedactionEdgeCaseTests {
    let redactor = Redactor()

    // A value that runs into a card number used to keep the first finding and drop the second,
    // which showed 12 of the 16 digits.
    @Test("findings that partly overlap are hidden together", arguments: [
        ("token=abc_4111 1111 1111 1111", "token=[REDACTED]"),
        ("pwd=x-4111 1111 1111 1111 end", "pwd=[REDACTED]"),
        ("Bearer abcdefgh-4111 1111 1111 1111", "Bearer [REDACTED]"),
        ("Authorization: Bearer abcdefgh-4111 1111 1111 1111", "Authorization: [REDACTED]"),
        ("jwt eyJhbGciOi.eyJzdWIiOi.sig_4111 1111 1111 1111", "jwt [REDACTED]"),
    ])
    func partialOverlap(input: String, expected: String) {
        let output = redactor.redact(input)
        #expect(output == expected)
        #expect(!output.contains("1111"))
    }

    @Test("a finding inside another keeps the outer replacement")
    func containedFinding() {
        #expect(redactor.redact("password=alice@example.com next=1") == "password=[REDACTED]")
        #expect(redactor.redact("paid 4111 1111 1111 1111 and a@example.com") == "paid [REDACTED] and [REDACTED]")
    }

    @Test("findings that partly overlap are hidden as one")
    func joinedMatch() {
        #expect(redactor.redact("jwt eyJhbGciOi.eyJzdWIiOi.sig_4111 1111 1111 1111") == "jwt [REDACTED]")
    }

    @Test("findings that only touch stay separate")
    func adjacentFindings() {
        #expect(redactor.redact("a@example.com,4111 1111 1111 1111") == "[REDACTED],[REDACTED]")
    }

    // A secret name hides the rest of the text from where its value may start, whatever
    // brackets, markup or escapes follow it; free text has no grammar to tell where the value
    // ends.
    @Test("finds secret fields in form, XML and percent-encoded syntax", arguments: [
        ("password[]=hunter2", "password[REDACTED]"),
        ("password[0]=a&password[1]=b", "password[REDACTED]"),
        ("user[password]=hunter2&user[name]=bob", "user[password[REDACTED]"),
        ("user[password][confirmation]=x", "user[password[REDACTED]"),
        ("<password>hunter2</password><user>bob</user>", "<password[REDACTED]"),
        ("<ApiKey>\nk-1\n</ApiKey>", "<ApiKey[REDACTED]"),
        ("<token>unclosed\nnext line", "<token[REDACTED]"),
        ("<password type=\"text\">hunter2</password>", "<password [REDACTED]"),
        ("<password >hunter2</password>", "<password [REDACTED]"),
        ("<Token\n  kind=\"a>b\">abc</Token>", "<Token\n  [REDACTED]"),
        ("<ns:password>hunter2</ns:password>", "<ns:password[REDACTED]"),
        ("<wsse:Password Type=\"PasswordText\">hunter2</wsse:Password>", "<wsse:Password [REDACTED]"),
        ("password%3Dhunter2", "password[REDACTED]"),
        ("q=password%3dhunter2", "q=password[REDACTED]"),
        ("secret%3Ax", "secret[REDACTED]"),
        ("user%5Bpassword%5D=hunter2&user%5Bname%5D=bob", "user%5Bpassword[REDACTED]"),
        ("password%5B%5D=hunter2", "password[REDACTED]"),
        ("user%5bpassword%5d%3dhunter2", "user%5bpassword[REDACTED]"),
        ("user%5Bpassword%5D%5Bconfirmation%5D=x", "user%5Bpassword[REDACTED]"),
        ("password+%3D+hunter2", "password+[REDACTED]"),
        ("q=password+%3A+hunter2&x=1", "q=password+[REDACTED]"),
        ("password%20%3D%20hunter2", "password[REDACTED]"),
        ("q=password%20%3A%20hunter2&x=1", "q=password[REDACTED]"),
        ("password%20=%20hunter2", "password[REDACTED]"),
        ("password: <hunter2>", "password: [REDACTED]"),
        ("token=<abc 123>; next", "token=[REDACTED]"),
        ("password: <hunter2", "password: [REDACTED]"),
        ("password=<hunter2\n>", "password=[REDACTED]"),
        ("password:<a password:<b>", "password:[REDACTED]"),
    ])
    func otherSyntaxes(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("hides the value after assignment and comparison operators", arguments: [
        ("PASSWORD := hunter2", "PASSWORD := [REDACTED]"),
        ("password:=hunter2", "password:=[REDACTED]"),
        ("apiKey := \"k-1\"", "apiKey := \"[REDACTED]"),
        ("API_TOKEN ?= abc123", "API_TOKEN [REDACTED]"),
        ("SECRET += abc123", "SECRET [REDACTED]"),
        ("password=>hunter2", "password=[REDACTED]"),
        ("password == \"hunter2\"", "password == \"[REDACTED]"),
        ("token!=abc123", "token[REDACTED]"),
        ("password === hunter2", "password === [REDACTED]"),
        ("password === \"hunter2\"", "password === \"[REDACTED]"),
        ("password=== hunter2", "password=== [REDACTED]"),
        ("password!==hunter2", "password[REDACTED]"),
        ("password :== hunter2", "password :== [REDACTED]"),
        ("password ::= hunter2", "password ::= [REDACTED]"),
        ("password = = hunter2", "password = = [REDACTED]"),
        ("password%3D%3Dhunter2", "password[REDACTED]"),
        ("password == hunter2 && token === abc123", "password == [REDACTED]"),
        ("password \u{2254} hunter2", "password [REDACTED]"),
        ("password \u{2A74} hunter2", "password \u{2A74} [REDACTED]"),
        ("password\u{2A75}hunter2", "password\u{2A75}[REDACTED]"),
        ("password\u{2A76}hunter2", "password\u{2A76}[REDACTED]"),
        ("password\u{FE66}hunter2", "password\u{FE66}[REDACTED]"),
        ("password\u{FE55} hunter2", "password\u{FE55} [REDACTED]"),
        ("password \u{2236} hunter2", "password [REDACTED]"),
    ])
    func assignmentOperators(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("reads every Unicode space as a space", arguments: [
        "\u{A0}", "\u{1680}", "\u{2000}", "\u{2001}", "\u{2002}", "\u{2003}", "\u{2004}", "\u{2005}",
        "\u{2006}", "\u{2007}", "\u{2008}", "\u{2009}", "\u{200A}", "\u{202F}", "\u{205F}", "\u{3000}",
    ])
    func unicodeSpaces(space: String) {
        #expect(redactor.redact("password\(space)=\(space)hunter2") == "password\(space)=\(space)[REDACTED]")
        #expect(redactor.redact("Bearer\(space)abc.DEF-123") == "Bearer\(space)[REDACTED]")
        #expect(redactor.redact(["4242", "4242", "4242", "4242"].joined(separator: space)) == "[REDACTED]")
    }

    // A secret name hides the rest of the text: `;` does not end a value.
    @Test("pass and session names hold secrets", arguments: [
        ("pass=hunter2", "pass=[REDACTED]"),
        ("DB_PASS=hunter2", "DB_PASS=[REDACTED]"),
        ("smtpPass: hunter2", "smtpPass: [REDACTED]"),
        ("session=abc123", "session=[REDACTED]"),
        ("Session: abc123", "Session: [REDACTED]"),
        ("sessionId=abc123", "session[REDACTED]"),
        ("SESSION_KEY=abc123", "SESSION[REDACTED]"),
        ("PHPSESSID=abc123; lang=en", "PHPSESSID=[REDACTED]"),
        ("JSESSIONID=abc123; Path=/", "JSESSION[REDACTED]"),
        ("Cookie: PHPSESSID=abc123; lang=en", "Cookie: [REDACTED]"),
        ("Set-Cookie: JSESSIONID=abc123; Path=/", "Set-Cookie: [REDACTED]"),
        ("jsessionid=abc123", "jsession[REDACTED]"),
        ("ASP.NET_SessionId=abc123", "ASP.NET_Session[REDACTED]"),
    ])
    func passAndSessionNames(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("names that only look like a secret name keep their value in structured input and in text", arguments: [
        "passport", "bypass", "compass", "passed",
    ])
    func lookalikeNames(name: String) {
        #expect(redactor.redact(body: Data("{\"\(name)\":\"x\"}".utf8), contentType: "application/json") == "{\"\(name)\":\"x\"}")
        #expect(redactor.redact("\(name)=x") == "\(name)=x")
    }

    @Test("leaves markup without a secret name", arguments: ["</password>", "<private>", "<br/> <p>hi</p>", "if a<b && c>d then"])
    func markup(input: String) {
        #expect(redactor.redact(input) == input)
    }
}

extension RedactionEdgeCaseTests {
    // Brackets, `%` escapes and an empty prefix make a name that is not plain ASCII, whatever it
    // spells, so its value is hidden.
    @Test("hides the value of form names that are not plain", arguments: [
        ("password[=x", "password[REDACTED]"),
        ("user%5Bpassport%5D=X1234", "user%5Bpassport%5D=[REDACTED]"),
        ("%5B=x", "%5B=[REDACTED]"),
    ])
    func namesThatAreNotPlain(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // Free text is not parsed as XML: an element is not a pair, so only a secret name or a word
    // that cannot be read in it hides what follows.
    @Test("an XML element is not read as a pair")
    func xmlElements() {
        #expect(redactor.redact("<\u{540D}\u{524D}>bob</\u{540D}\u{524D}>") == "<\u{540D}\u{524D}>bob</\u{540D}\u{524D}>")
        #expect(redactor.redact("<p\u{0430}ssword>bob</p\u{0430}ssword>") == "<[REDACTED]")
    }

    // Comparisons, times and object descriptions written as `key: value` keep their value under a
    // plain key; a key that is not plain, such as `</a`, hides the rest.
    @Test("pairs in free text keep their value under a plain key", arguments: [
        ("<a href=\"x\">y</a>", "<a href=\"x\">y</a>"),
        ("count>=5", "count>=[REDACTED]"),
        ("a <= b", "a <= [REDACTED]"),
        ("x == y", "x == y"),
        ("time: 12:30:45", "time: 12:30:45"),
        ("Error: connection refused", "Error: connection refused"),
        ("<a:b:c>x</a:b:c>", "<a:b:c>x</a:[REDACTED]"),
        ("finished: <NSHTTPURLResponse: 0x600> { URL: https://example.com/v2/items?id=7 } { Status Code: 200 }", "finished: <NSHTTPURLResponse: 0x600> { URL: https://example.com/v2/items?id=[REDACTED] } { Status Code: 200 }"),
        ("<UIView: 0x7f8; frame = (0 0; 375 812); layer = <CALayer: 0x600>>", "<UIView: 0x7f8; frame = (0 0; 375 812); layer = <CALayer: 0x600>>"),
    ])
    func pairsInText(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("the value of a plain key is read on: a secret name in it hides the rest")
    func valuesAreReadOn() {
        #expect(redactor.redact("error: wrong password hunter2") == "error: wrong password [REDACTED]")
        #expect(redactor.redact("error: bad input\ntoken hunter2\nnext") == "error: bad input\ntoken [REDACTED]")
    }
}
