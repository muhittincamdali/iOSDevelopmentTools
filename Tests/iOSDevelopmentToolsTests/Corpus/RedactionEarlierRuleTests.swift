import Foundation
import Testing
@testable import iOSDevelopmentTools

// See RedactionEarlierQuoteTests.swift: the earlier corpus tests that the iOSSecurityTools corpus
// has none of the same name for, kept with the outputs the shared rules now give.

/// Rules of free text, names, numbers, URLs and the scaling of JSON strings, from the earlier
/// reviews of this package and of iOSDevelopmentTools.
@Suite("Redaction corpus: earlier rule reviews")
struct RedactionEarlierRuleTests {
    let redactor = Redactor()
    static let secret = "2345678901"

    private func json(_ text: String) -> String { redactor.redact(body: Data(text.utf8), contentType: "application/json") }


    /// The URLs the review measured, each with what is recorded: a host that names a secret is
    /// hidden with everything after it.
    static let measured = [
        ("myapp://pin/4831", "myapp://[REDACTED]"), ("myapp://password/hunter2", "myapp://[REDACTED]"),
        ("myapp://token/abc123", "myapp://[REDACTED]"), ("myapp://session/s3cr3t", "myapp://[REDACTED]"),
        ("https://pin/4831", "https://[REDACTED]"), ("https://auth.example.com/x/4831", "https://[REDACTED]"),
    ]

    /// What is recorded for a URL whose host is hidden: the scheme as `URLComponents` reads it
    /// and ``RedactionPolicy/replacement``.
    static func hiddenHost(_ text: String) throws -> String {
        try #require(URLComponents(string: text)?.scheme) + "://" + RedactionPolicy.replacement
    }

    /// The value of a probe.
    static func value(in text: String) throws -> String {
        let range = try #require(text.range(of: #"Qz[0-9]{3}Wk5m"#, options: .regularExpression))
        return String(text[range])
    }

    @Test("an IBAN and a long token next to each other are hidden apart")
    func ibanAndToken() {
        let text = "DE89370400440532013000 2c73d1a49804c8035388364230944e541f8e6e2c"
        #expect(redactor.redact(text) == "[REDACTED] [REDACTED]")
    }

    // A `<` is a comparison only before white space, a line break, an ASCII digit, `=` or the end
    // of the text.
    @Test("keeps a comparison sign", arguments: ["if a < b", "a <3", "a <\tb", "a <\nb", "a <", "1 < 2 and 3 < 4"])
    func comparison(input: String) {
        #expect(redactor.redact(input) == input)
    }

    @Test("the value of an allowed key is read on: a secret name in it hides the rest")
    func valuesAreReadOn() {
        let allowing = Redactor(allowedTextKeys: ["error"])
        #expect(allowing.redact("error: wrong password hunter2") == "error: wrong password [REDACTED]")
        #expect(allowing.redact("error: bad input\ntoken hunter2\nnext") == "error: bad input\ntoken [REDACTED]")
        #expect(redactor.redact("error: wrong password hunter2") == "error: [REDACTED]")
    }

    @Test("a secret name that ends its line, also in markup, hides the lines below", arguments: [
        // Markup is cut at its first `<`, so a tag that ends its line hides the lines below.
        ("<password>\nhunter2\n</password>", "[REDACTED]"),
        ("<key>password</key>\n<string>hunter2</string>", "[REDACTED]"),
        ("password\nhunter2", "password[REDACTED]"),
        ("<password>\u{2028}hunter2\u{2028}</password>", "[REDACTED]"),
    ])
    func secretNameBeforeNextLine(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("an allowed key that holds a name is read for the name, and a route under path stays")
    func keysThatHoldNames() {
        let allowing = Redactor(allowedTextKeys: ["type", "name"])
        #expect(allowing.redact("type=Пароль S3CR3Tq") == "type=[REDACTED]")
        #expect(allowing.redact("type=status kept") == "type=status kept")
        #expect(redactor.redact("method=GET path=/v1/users/me status=200") == "method=GET path=/v1/users/me status=200")
        #expect(allowing.redact(#"name="status" kept"#) == #"name="status" kept"#)
        #expect(redactor.redact("type=status kept") == "type=[REDACTED]")
        #expect(redactor.redact(#"name="status" kept"#) == "name=[REDACTED]")
    }

    /// The cost of the default, named in the documentation: a name in another script hides the
    /// value beside it, and under a field that only pairs use, every member beside it. Under
    /// `name`, `id` and `type` it may be a person, a place, a product or a media type, so the rest
    /// of the record stays.
    @Test("a held name in another script hides the value beside it; under name, id and type the rest of a record stays")
    func nonASCIINamesHideValues() {
        // The shared rule hides the rest of the record too (see RedactionRecordUsefulnessTests).
        #expect(json(#"{"id":1,"name":"Ayşe","role":"admin"}"#) == #"{"id":"[REDACTED]","name":"Ayşe","role":"[REDACTED]"}"#)
        #expect(json(#"{"name":"Ayşe","value":"x","role":"admin"}"#) == #"{"name":"Ayşe","value":"[REDACTED]","role":"[REDACTED]"}"#)
        #expect(json(#"{"type":"image/png","data":"AAAA"}"#) == #"{"type":"image/png","data":"[REDACTED]"}"#)
        #expect(json(#"{"label":"Ayşe","role":"admin"}"#) == #"{"label":"Ayşe","role":"[REDACTED]"}"#)
        #expect(json(#"{"name":"ⓢⓣⓐⓣⓤⓢ","role":"admin"}"#) == #"{"name":"[REDACTED]","role":"[REDACTED]"}"#)
    }

    @Test("in a line, JSON members follow the allowed keys; a body reads JSON by the key rule of structured input")
    func membersOfJSONInText() {
        #expect(redactor.redact(#"log {"user":"bob","status":200,"list":[1]}"#) == "log {[REDACTED]")
        let allowing = Redactor(allowedTextKeys: ["user", "list"])
        #expect(allowing.redact(#"log {"user":"bob","status":200,"list":[1]}"#) == #"log {"user":"bob","status":200,"list":[1]}"#)
        #expect(allowing.redact(#"log {"user":"bob","pin":1234} done"#) == #"log {"user":"bob",[REDACTED]"#)
        #expect(redactor.redact(body: Data(#"{"user":"bob","status":200}"#.utf8), contentType: "application/json") == #"{"user":"bob","status":200}"#)
    }

    @Test("names that are not secret keep what follows them over lines after allowed keys")
    func usefulness() {
        #expect(redactor.redact("status=[\n1,\n2\n] ok") == "status=[\n1,\n2\n] ok")
        #expect(Redactor(allowedTextKeys: ["name"]).redact("name=\"title\"\nHello") == "name=\"title\"\nHello")
        // Markup is not parsed: the first tag cuts the text, whatever its name and whatever keys
        // the app allows.
        let allowing = Redactor(allowedTextKeys: ["name", "string"])
        #expect(redactor.redact("<key>CFBundleName</key>\n<string/>\nMyApp") == "[REDACTED]")
        #expect(redactor.redact("<key>user</key>\n<string>bob</string>\nstatus=200") == "[REDACTED]")
        #expect(redactor.redact("<string name=\"title\"></string>\nHello") == "[REDACTED]")
        #expect(allowing.redact("<string name=\"title\"></string>\nHello") == "[REDACTED]")
        #expect(allowing.redact("status=200\n<string name=\"title\">Hello</string>") == "status=200\n[REDACTED]")
        #expect(redactor.redact("<key>password</key>\n<string>k-1</string>\nnext") == "[REDACTED]")
    }

    /// The sixth review: the colon was read as part of a number from its left side alone, so a
    /// number used as a key (a user name, a database index) let the value after it through.
    @Test("a colon is part of a number only when the number goes on to a whole time or port", arguments: [
        "curl -u 42:2345678901 https://x.example", "curl -u 7:9xQ7mP2kL8 https://x.example", "redis-cli -a 0:2345678901 ping",
        "uid 7:9xQ7mP2kL8 ok", "login 12:34hunter2 ok", "creds 1:2-hunter-two ok", "10.0.0.1:8080secretvalue ok",
        "at 12:30:4f9a2c7b ok", "at 12:30:45.hunter2", "at 12:30:45,hunter2 ok", "id 12:345 ok", "1.234:56 ok", "10.0.0.1:123456 ok",
        "at 12:30,hunter2", "1-1-1:2345",
    ])
    func numberUsedAsKey(line: String) {
        // `12:345` has the shape of a line and column, which the spec keeps, so `345` shows.
        let secrets = ["2345678901", "9xQ7mP2kL8", "hunter", "secretvalue", "4f9a2c7b", "56", "123456", "2345"]
        var outputs = RedactionWrittenURLTests.places(line).map(\.1)
        outputs.append(RedactionPolicy.default.redact(headers: [HTTPHeader(name: "User-Agent", value: "app " + line)])[0].value)
        for output in outputs {
            for secret in secrets where line.contains(secret) {
                #expect(!output.contains(secret), "\(line.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    /// The reviews' commands and lines, in every place free text is read.
    @Test("the review's commands hide the value after the key in every place", arguments: [
        "curl -u admin1:\(secret) https://x.example", "redis-cli -a db1:\(secret) ping", "user1:\(secret)", "login user1:\(secret) ok",
    ])
    func reviewCommands(line: String) {
        var outputs = RedactionWrittenURLTests.places(line).map(\.1)
        let header = RedactionPolicy.default.redact(headers: [HTTPHeader(name: "User-Agent", value: line)])[0].value
        outputs.append(header)
        let encoded = "note=" + line.replacingOccurrences(of: ":", with: "%3A").replacingOccurrences(of: " ", with: "+")
        outputs.append(Redactor(allowedTextKeys: ["note"]).redact(body: Data(encoded.utf8), contentType: "application/x-www-form-urlencoded"))
        for output in outputs {
            #expect(!output.contains(Self.secret), "\(line.debugDescription) -> \(output.debugDescription)")
        }
    }

    // `refresh` is not on the list of secret names: a body keeps its value, a limitation that the
    // guide names ("What it does not find"). In free text it is not an allowed key, so the text
    // is cut at its value.
    @Test("a name that is not on the list keeps its value in a body and hides it in free text")
    func nameNotOnTheList() {
        #expect(redactor.redact(body: Data(#"{"refresh":"ft42"}"#.utf8), contentType: "application/json") == #"{"refresh":"ft42"}"#)
        #expect(redactor.redact("refresh=ft42") == "refresh=[REDACTED]")
        #expect(redactor.redact("refresh_token=ft42") == "refresh_token=[REDACTED]")
    }

    // JSON in a line follows the key rule of free text member by member: a member name that is
    // not allowed cuts the text at its opening quote, so nothing in it shows.
    @Test("JSON in a line is cut at the opening quote of the first member name that is not allowed", arguments: [
        (#"{"status":200,"user":"bob"}"#, #"{"status":200,[REDACTED]"#),
        (#"got {"password hunter2": 1} ok"#, "got {[REDACTED]"),
        (#"got ["user","bob"] ok"#, "got [[REDACTED]"),
    ])
    func embeddedJSON(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    /// A host that is hidden is not followed by its path: the path of `myapp://pin_x/4831` was
    /// kept as `/4831` in the network inspector of the library this corpus was written for.
    @Test("a hidden host leaves the recorded path empty", arguments: ["myapp://pin_x/4831", "https://my_host.local/pin/4831", "myapp://password=hunter2"])
    func hiddenHostLeavesNoPath(text: String) throws {
        let url = try #require(URL(string: text))
        #expect(redactor.redact(url: url).hasSuffix("://[REDACTED]"))
        #expect(RedactionPolicy.default.redactedPath(of: url).isEmpty)
    }

    @Test("the network log and the cURL command record no value", arguments: RedactionURLHostNameTests.probes)
    func inspectorAndExports(text: String) throws {
        let value = try Self.value(in: text)
        let url = try #require(URL(string: text))
        let logged = LoggedOutput.request(URLRequest(url: url))
        #expect(logged.contains(" GET \(try Self.hiddenHost(text))\n"), "\(logged)")
        #expect(!logged.contains(value), "\(logged)")
    }

    @Test("the review's URLs record the scheme only", arguments: measured)
    func measuredURLs(text: String, expected: String) throws {
        let url = try #require(URL(string: text))
        #expect(redactor.redact(url: url) == expected)
        #expect(RedactionPolicy.default.redactedPath(of: url).isEmpty)
        #expect(redactor.redact("open \(text) now") == "open [REDACTED]")
    }

    @Test("a host that is not a host name or an address, or holds a finding, is hidden with the rest of the URL", arguments: [
        ("myapp://password=hunter2", "myapp://[REDACTED]"), ("myapp://token;hunter2/x", "myapp://[REDACTED]"),
        ("https://my_host.local/x", "https://[REDACTED]"), ("https://4111111111111111.example.com/a", "https://[REDACTED]"),
        ("https://0123456789abcdef0123456789abcdef.example.com/", "https://[REDACTED]"), ("https://-x.example.com/", "https://[REDACTED]"),
        ("https://a..b/", "https://[REDACTED]"), ("https://[fe80::1%25en0]/x", "https://[REDACTED]"),
        ("https://xn--mnchen-3ya.de/", "https://[REDACTED]"),
    ])
    func hiddenHosts(url: String, expected: String) throws {
        #expect(redactor.redact(url: try #require(URL(string: url))) == expected)
        // In text such a URL is not clean, so the text is cut where it starts; a URL that is
        // clean but whose host is hidden (`xn--…`) is written with its host hidden.
        let host = try #require(URL(string: url)?.host)
        #expect(!redactor.redact("see \(url) now").contains(host))
    }

    @Test("host names and addresses are written", arguments: [
        ("https://api.example.com:8443/a", "https://api.example.com:8443/a"), ("https://127.0.0.1/x", "https://127.0.0.1/x"),
        ("https://[::1]:8080/x", "https://[::1]:8080/x"), ("https://[2001:db8::1]/", "https://[2001:db8::1]/"),
        ("file:///tmp/a", "file:///tmp/a"), ("https://localhost./", "https://localhost./"),
    ])
    func shownHosts(url: String, expected: String) throws {
        #expect(redactor.redact(url: try #require(URL(string: url))) == expected)
    }

    @Test("the user info and fragment are dropped and the detectors run on the path")
    func userInfoFragmentAndDetectors() throws {
        let url = try #require(URL(string: "https://bob:pw@example.com/pay?card=4111111111111111&email=alice@example.com#frag"))
        let output = redactor.redact(url: url)
        #expect(output == "https://example.com/pay?card=[REDACTED]&email=[REDACTED]")
        for leaked in ["bob", "pw", "frag", "4111111111111111", "alice"] {
            #expect(!output.contains(leaked))
        }
        let path = try #require(URL(string: "https://example.com/users/alice@example.com/cards/4111-1111-1111-1111?b=1&flag"))
        #expect(redactor.redact(url: path) == "https://example.com/users/:id/:id/:id?b=[REDACTED]&[REDACTED]")
        let hostOnly = Redactor(urlDetail: .hostOnly)
        #expect(hostOnly.redact(url: try #require(URL(string: "https://bob:pw@example.com:8443/a?email=alice@example.com#x"))) == "https://example.com:8443")
    }

    // The one wildcard rule of section 0 of the redaction spec: a mark (M*) or a number (N*) with
    // no ASCII form stands for any letter as a letter does. The sixteenth review found
    // `t\u{0366}ken` and `passw\u{3007}rd` (see RedactionOneWildcardTests).
    @Test("a mark after an ASCII letter or a number without an ASCII form in place of one letter stands for it", arguments: [
        "t\u{0366}ken hunter2", "p\u{0301}ssword hunter2", "passw\u{3007}rd hunter2", "toke\u{0366} hunter2",
    ])
    func markOrNumberInPlaceOfALetter(line: String) {
        #expect(!redactor.redact(line).contains("hunter2"), "\(line)")
        let separated = line.replacingOccurrences(of: " hunter2", with: ": hunter2")
        #expect(!redactor.redact(separated).contains("hunter2"), "\(separated)")
    }

    // A mark of a letter that is a wildcard belongs to it, and marks on every letter are left out.
    @Test("marks on a wildcard or on every letter leave the name found", arguments: [
        "p\u{0251}\u{0301}ssword hunter2", "t\u{0337}o\u{0337}k\u{0337}e\u{0337}n\u{0337} hunter2", "pa\u{FE0F}ssphrase hunter2",
    ])
    func marksOnLetters(line: String) {
        #expect(!redactor.redact(line).contains("hunter2"), "\(line)")
    }

    // The eighteenth review of this package: with one character in place of a letter of a name,
    // another put in elsewhere in it hid the name (`tͦkenͦ`, U+0366 after the `t` and after the
    // `n`, 300 of them in the review). Each counts as nothing or as one letter on its own.
    @Test("one character in place of a letter and more put in elsewhere leave the name found, on every path", arguments: [
        "t\u{0366}ken\u{0366} hunter2", "t\u{0366}ken" + String(repeating: "\u{0366}", count: 300) + " hunter2", "tıkenı hunter2", "pını hunter2",
        "t\u{3007}ken\u{3007} hunter2", "t\u{0366}k\u{0366}en hunter2", "p\u{0366}n\u{0366} hunter2", "t\u{0366}ken\u{0366}s hunter2",
        "tıken\u{1040} hunter2", "ıtıken hunter2",
    ])
    func oneInPlaceAndMorePutIn(line: String) {
        for (path, output) in RedactionCutRuleTests.everyPath(line) {
            #expect(!output.contains("hunter2"), "\(path): \(line.debugDescription) -> \(output.debugDescription)")
        }
    }

    @Test("one letter without an ASCII form stands for a letter or for none", arguments: [
        "pɑssword hunter2", "passwıord hunter2", "passꞏword hunter2", "ıd_token hunter2", "tokɛns hunter2", "ɑpi_key hunter2",
        "Authorizɑtion hunter2", "user_pın hunter2", "sɛcret hunter2",
        // Before the last letter of a short word, read as no letter (the sixth review of the spec branch).
        "tokeꞏn hunter2", "piın hunter2", "secreꞏt hunter2", "keıy hunter2", "userPiłn hunter2", "my piꞏn is hunter2",
    ])
    func oneWildcard(line: String) {
        #expect(!redactor.redact(line).contains("hunter2"), "\(line)")
    }

    // The eighth review of the spec branch: letters without an ASCII form put into a name are
    // left out of its skeleton, however many there are.
    @Test("letters without an ASCII form put into a name are left out of its skeleton", arguments: [
        "passꞏwoꞏrd hunter2", "pıaıssword hunter2", "passıwoırd hunter2", "seıcreıt hunter2", "tokenꞏꞏ hunter2",
        "tokenıı hunter2", "ꞏtoꞏkeꞏnꞏ hunter2",
    ])
    func skeleton(line: String) {
        #expect(!redactor.redact(line).contains("hunter2"), "\(line)")
    }

    // The logging guide names this limit under "What it does not find": free text without a
    // separator is a best effort, and no list of look-alikes is kept to chase it.
    @Test("a name written without a separator with two or more letters replaced by ones without an ASCII form is not found", arguments: [
        "pɑsswoʀd hunter2", "tɵkɛn hunter2",
    ])
    func twoWildcards(line: String) {
        #expect(redactor.redact(line).contains("hunter2"), "\(line) is found: update the guide")
        let separated = line.replacingOccurrences(of: " hunter2", with: ": hunter2")
        #expect(!redactor.redact(separated).contains("hunter2"), "\(separated)")
    }

}
