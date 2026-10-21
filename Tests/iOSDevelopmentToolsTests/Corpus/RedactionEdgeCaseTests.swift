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
    // ends. Markup is not parsed: the text is cut at the `<` of the first tag.
    @Test("finds secret fields in form, XML and percent-encoded syntax", arguments: [
        ("password[]=hunter2", "password[REDACTED]"),
        ("password[0]=a&password[1]=b", "password[REDACTED]"),
        ("user[password]=hunter2&user[name]=bob", "user[password[REDACTED]"),
        ("user[password][confirmation]=x", "user[password[REDACTED]"),
        ("<password>hunter2</password><user>bob</user>", "[REDACTED]"),
        ("<ApiKey>\nk-1\n</ApiKey>", "[REDACTED]"),
        ("<token>unclosed\nnext line", "[REDACTED]"),
        ("<password type=\"text\">hunter2</password>", "[REDACTED]"),
        ("<password >hunter2</password>", "[REDACTED]"),
        ("<Token\n  kind=\"a>b\">abc</Token>", "[REDACTED]"),
        ("<ns:password>hunter2</ns:password>", "[REDACTED]"),
        ("<wsse:Password Type=\"PasswordText\">hunter2</wsse:Password>", "[REDACTED]"),
        ("password%3Dhunter2", "password[REDACTED]"),
        ("q=password%3dhunter2", "q=[REDACTED]"),
        ("status=password%3dhunter2", "status=password[REDACTED]"),
        ("secret%3Ax", "secret[REDACTED]"),
        ("user%5Bpassword%5D=hunter2&user%5Bname%5D=bob", "user[REDACTED]"),
        ("password%5B%5D=hunter2", "password[REDACTED]"),
        ("user%5bpassword%5d%3dhunter2", "user[REDACTED]"),
        ("user%5Bpassword%5D%5Bconfirmation%5D=x", "user[REDACTED]"),
        ("password+%3D+hunter2", "password[REDACTED]"),
        ("q=password+%3A+hunter2&x=1", "q=[REDACTED]"),
        ("status=password+%3A+hunter2&x=1", "status=password[REDACTED]"),
        ("password%20%3D%20hunter2", "password[REDACTED]"),
        ("q=password%20%3A%20hunter2&x=1", "q=[REDACTED]"),
        ("status=password%20%3A%20hunter2&x=1", "status=password[REDACTED]"),
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

    @Test("names that only look like a secret name keep their value in structured input, and in text when allowed", arguments: [
        "passport", "bypass", "compass", "passed",
    ])
    func lookalikeNames(name: String) {
        #expect(redactor.redact(body: Data("{\"\(name)\":\"x\"}".utf8), contentType: "application/json") == "{\"\(name)\":\"x\"}")
        #expect(Redactor(allowedTextKeys: [name]).redact("\(name)=x") == "\(name)=x")
        #expect(redactor.redact("\(name)=x") == "\(name)=[REDACTED]")
    }

    // A `<` is a comparison only before white space, a line break, an ASCII digit, `=` or the end
    // of the text.
    @Test("keeps a comparison sign", arguments: ["if a < b", "a <3", "a <\tb", "a <\nb", "a <", "1 < 2 and 3 < 4"])
    func comparison(input: String) {
        #expect(redactor.redact(input) == input)
    }

    // Markup is not parsed and no tag keeps its text, whatever its name: the text is cut at the
    // `<` of the first tag, an end tag, a comment or a type parameter.
    @Test("markup cuts the text at its first <", arguments: [
        ("</status>", "[REDACTED]"), ("<private>", "[REDACTED]"), ("<br/> <p>\n</p>", "[REDACTED]"), ("if a<b", "if a[REDACTED]"),
        ("<br/> <p>hi</p>", "[REDACTED]"), ("if a<b && c>d then", "if a[REDACTED]"),
        ("<user>bob</user>", "[REDACTED]"), ("<status>200</status> done", "[REDACTED]"),
        ("</password>", "[REDACTED]"), ("</pin 1234", "[REDACTED]"), ("login </token SECRET", "login [REDACTED]"),
        ("<count>\n  3\n</count>", "[REDACTED]"), ("Loaded Array<Item> in 3 ms", "Loaded Array[REDACTED]"),
    ])
    func markup(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }
}

extension RedactionEdgeCaseTests {
    // Brackets, `%` escapes and an empty prefix make a name that is not plain ASCII, whatever it
    // spells, so its value is hidden.
    @Test("hides the value of form names that are not plain", arguments: [
        ("password[=x", "password[REDACTED]"),
        ("user%5Bpassport%5D=X1234", "user[REDACTED]"),
        ("%5B=x", "[REDACTED]"),
    ])
    func namesThatAreNotPlain(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    // An element in free text is markup, which is not parsed: whether its tag is plain ASCII,
    // names a secret or is allowed, the text is cut at its `<`. A body of XML or a property list
    // is a structured body (see ``RedactionPolicy/redact(body:contentType:isComplete:)``).
    @Test("an XML element in free text is cut at its <, whatever its tag")
    func xmlElements() {
        #expect(redactor.redact("<\u{540D}\u{524D}>bob</\u{540D}\u{524D}>") == "[REDACTED]")
        #expect(Redactor(allowedTextKeys: ["user"]).redact("<user>bob</user>") == "[REDACTED]")
        #expect(redactor.redact("<p\u{0430}ssword>bob</p\u{0430}ssword>") == "[REDACTED]")
        #expect(redactor.redact("status=200 <user>bob</user>") == "status=200 [REDACTED]")
    }

    // Free text keeps a value only after an allowed key, so comparisons, times and object
    // descriptions written as `key: value` are hidden unless the app allows their keys.
    @Test("pairs in free text keep their value only after an allowed key", arguments: [
        ("<a href=\"x\">y</a>", "[REDACTED]"),
        ("count>=5", "count>=[REDACTED]"),
        ("a <= b", "a <= [REDACTED]"),
        ("x == y", "x == [REDACTED]"),
        ("count == 3", "count == 3"),
        ("time: 12:30:45", "time: [REDACTED]"),
        ("Error: connection refused", "Error: [REDACTED]"),
        ("<a:b:c>x</a:b:c>", "[REDACTED]"),
        ("finished: <NSHTTPURLResponse: 0x600> { URL: https://example.com/v2/items?id=7 } { Status Code: 200 }", "finished: [REDACTED]"),
        ("<UIView: 0x7f8; frame = (0 0; 375 812); layer = <CALayer: 0x600>>", "[REDACTED]"),
    ])
    func pairsInText(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("the value of an allowed key is read on: a secret name in it hides the rest")
    func valuesAreReadOn() {
        let allowing = Redactor(allowedTextKeys: ["error"])
        #expect(allowing.redact("error: wrong password hunter2") == "error: wrong password [REDACTED]")
        #expect(allowing.redact("error: bad input\ntoken hunter2\nnext") == "error: bad input\ntoken [REDACTED]")
        #expect(redactor.redact("error: wrong password hunter2") == "error: [REDACTED]")
    }
}
