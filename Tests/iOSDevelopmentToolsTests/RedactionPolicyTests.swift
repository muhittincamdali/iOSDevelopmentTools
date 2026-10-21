import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Redaction: keys, headers and URLs")
struct RedactionPolicyTests {
    let policy = RedactionPolicy.default
    let redacted = RedactionPolicy.replacement

    @Test("Plain keys are folded: case folded, _ - . and spaces removed", arguments: [
        ("X-API-Key", "xapikey"), ("api_key", "apikey"), ("apiKey", "apikey"), ("Pass Word", "password"), ("sort.order", "sortorder"),
    ])
    func folding(key: String, folded: String) {
        #expect(PlainName(key.unicodeScalars)?.folded == folded)
    }

    @Test("Keys that are not plain ASCII are not compared, so their values are hidden", arguments: [
        "раssword", "pαssword", "pass\u{200D}word", "pass\u{200C}word", "pass\u{00AD}word", "pa\u{301}ssword",
        "pass\u{200B}word", "pass\u{600}%77ord", "pass%FFword", "pass%77ord%ZZ", "pass+word", "pass/word",
        "user[name]", "a;b", "名前", "Kullanıcı", "%", "pass\\uZZZZword", "ｐａｓｓｗｏｒｄ", "ＡＰＩ＿ＫＥＹ", "𝐩𝐚𝐬𝐬𝐰𝐨𝐫𝐝",
        "ⓟⓐⓢⓢⓦⓞⓡⓓ", "ﬁle", "ſession", "API%5FKEY", "pass%2577ord", "pass\\u0077ord", "pass&#119;ord", "", "---",
    ])
    func notPlainKeys(key: String) {
        #expect(PlainName(key.unicodeScalars) == nil)
        #expect(policy.isSensitive(name: key))
    }

    @Test("Secret names are recognized however they are written", arguments: [
        "Authorization", "Proxy-Authorization", "Cookie", "Set-Cookie", "X-Api-Key", "x_auth_token",
        "access_token", "refreshToken", "client_secret", "PASSWORD", "new-password", "API%5FKEY",
        "pass%2577ord", "jsessionid", "X-Signature", "card_number", "cvv", "userPin", "creditcard",
        "otp", "IBAN", "ssn", "private.key", "id-token", "pwd", "sid", "passphrase", "credentials",
    ])
    func secretNames(name: String) {
        #expect(policy.isSensitive(name: name))
    }

    @Test("Plain names that are not secret are kept", arguments: [
        "Content-Type", "Accept", "page", "limit", "User-Agent", "id", "name", "author", "keyboard",
        "spinner", "inside", "cardinality", "sessions_count", "q", "sort.order", "sidebar", "bypass", "passport",
    ])
    func ordinaryNames(name: String) {
        // "sessions_count" contains "session", a name of five letters or more, so it is hidden.
        #expect(policy.isSensitive(name: name) == (name == "sessions_count"))
    }

    @Test("Added secret names are folded; names that cannot match a plain key are dropped")
    func additionalSecretNames() {
        let custom = RedactionPolicy(additionalSecretNames: ["", "--", "Ticket", "名前"])
        #expect(custom.secretNames.contains("ticket"))
        #expect(!custom.secretNames.contains(""))
        #expect(custom.secretNames.isSuperset(of: RedactionPolicy.default.secretNames))
        #expect(custom.isSensitive(name: "x-ticket-id"))
        #expect(!custom.isSensitive(name: "content-type"))
    }

    @Test("The disabled policy changes nothing")
    func disabledPolicy() {
        let disabled = RedactionPolicy.disabled
        #expect(!disabled.isEnabled)
        #expect(!disabled.isSensitive(name: "Authorization"))
        let url = URL(string: "https://user:pw@example.com/a?token=1#x")!
        #expect(disabled.redact(url: url) == url.absoluteString)
        let headers = [HTTPHeader(name: "Authorization", value: "Bearer abc")]
        #expect(disabled.redact(headers: headers) == headers)
        #expect(disabled.redact(text: "password=hunter2") == "password=hunter2")
    }

    @available(*, deprecated)
    @Test("The 2.0.0 names still build and hide at least as much as before")
    func deprecatedNames() {
        let policy = RedactionPolicy(nameFragments: RedactionPolicy.defaultNameFragments + ["license_number"])
        #expect(policy.isSensitive(name: "licenseNumber") && policy.isSensitive(name: "password"))
        #expect(policy.nameFragments == policy.secretNames && policy.withholdsUncheckedBodies)
        // An empty list no longer turns redaction off, and unparsed bodies are omitted either way.
        let lenient = RedactionPolicy(nameFragments: [], withholdsUncheckedBodies: false)
        #expect(lenient.isSensitive(name: "token"))
        #expect(RedactionPolicy(withholdsUncheckedBodies: false) == .default)
        #expect(lenient.redact(body: Data(#"{"a":"#.utf8), contentType: "application/json").outcome == .withheld)
    }

    // MARK: Headers

    @Test("Only allowlisted headers keep their values")
    func headerAllowlist() {
        let headers = [
            HTTPHeader(name: "Accept", value: "application/json"),
            HTTPHeader(name: "Content-Type", value: "application/json; charset=utf-8"),
            HTTPHeader(name: "User-Agent", value: "MyApp/1.0 (iPhone; iOS 18.0)"),
            HTTPHeader(name: "X-Request-ID", value: "42"),
            HTTPHeader(name: "Location", value: "https://e.com/next?code=abc"),
            HTTPHeader(name: "Authorization", value: "Bearer abc"),
        ]
        let result = policy.redact(headers: headers)
        #expect(result.map(\.name) == headers.map(\.name))
        #expect(result.map(\.value) == [
            "application/json", "application/json; charset=utf-8", "MyApp/1.0 (iPhone; iOS 18.0)", redacted, redacted, redacted,
        ])
    }

    @Test("Some headers are hidden even when the app allows them", arguments: [
        "Authorization", "Proxy-Authorization", "Cookie", "Set-Cookie", "X-Api-Key", "X-Auth-Token",
        "X-Client-Secret", "X-Session-Id", "X-Amz-Signature", "Monkey-Key", "X-Ａuth", "X\u{200B}Note", "Nöte",
    ])
    func alwaysHiddenHeaders(name: String) {
        let lenient = RedactionPolicy(allowedHeaders: [name, "Accept"])
        #expect(lenient.redact(headers: [HTTPHeader(name: name, value: "v")]).first?.value == redacted)
    }

    @Test("Kept header values still go through the value detectors; credentials after a scheme hide the whole value")
    func keptHeaderValues() {
        let lenient = RedactionPolicy(allowedHeaders: ["X-Upstream", "ETag"])
        let headers = [
            HTTPHeader(name: "X-Upstream", value: "Bearer abc.def"),
            HTTPHeader(name: "X-Upstream", value: "token ghp_abc"),
            HTTPHeader(name: "ETag", value: "\"33a64df551425fcc55e4d42a148795d9f25f89d4\""),
            HTTPHeader(name: "ETag", value: "W/\"v7\""),
            HTTPHeader(name: "X-Upstream", value: "route=eu, user=ada"),
            HTTPHeader(name: "X-Upstream", value: "charset=utf-8; max-age=60"),
            HTTPHeader(name: "X-Upstream", value: "text/plain; x=hunter2"),
            HTTPHeader(name: "X-Upstream", value: "status=200 q=0.5"),
        ]
        // A kept value is free text that also reads on after the parameters of header values.
        #expect(lenient.redact(headers: headers).map(\.value) == [
            redacted, redacted, "\"\(redacted)\"", "W/\"v7\"", "route=\(redacted)", "charset=utf-8; max-age=60", "text/plain; x=\(redacted)",
            "status=200 q=0.5",
        ])
        // The parameters count only in header values, not in other free text.
        #expect(lenient.redact(text: "charset=utf-8") == "charset=\(redacted)")
    }

    // MARK: URLs

    @Test("User info and fragments are dropped, query values hidden, identifiers replaced")
    func urls() throws {
        let url = try #require(URL(string: "https://alice:pw@api.example.com:8443/v1/users/123456/orders/550e8400-e29b-41d4-a716-446655440000/items?q=swift&page=2&api_key=XYZ#access_token=abc"))
        #expect(policy.redact(url: url) == "https://api.example.com:8443/v1/users/:id/orders/:id/items?q=\(redacted)&page=\(redacted)&api_key=\(redacted)")
        #expect(policy.redactedPath(of: url) == "/v1/users/:id/orders/:id/items")
    }

    @Test("Allowlisted query parameters keep their values, which go through the value rule")
    func allowedQueryParameters() throws {
        let allowing = RedactionPolicy(allowedQueryParameters: ["q", "page", "token"])
        let url = try #require(URL(string: "https://e.com/s?q=a%20b&page=1%26password%3Dx&token=t&sort=asc"))
        // "token" stays hidden: a secret name cannot be allowed.
        // `&` before a letter is an escape in the value, so the value is cut there.
        #expect(allowing.redact(url: url) == "https://e.com/s?q=a%20b&page=1\(redacted)&token=\(redacted)&sort=\(redacted)")
        // A query that servers could split differently (`;`, a name spelled two ways) is hidden whole.
        for query in ["q=a&page=1;password=x", "q=a&Q=z", "page=1&pa%67e=3"] {
            #expect(allowing.redact(url: try #require(URL(string: "https://e.com/s?\(query)"))) == "https://e.com/s?\(redacted)")
        }
    }

    @Test("Path segments that look like identifiers or secrets become :id", arguments: [
        ("/users/123456", "/users/:id"), ("/users/12345", "/users/12345"),
        ("/o/550e8400-e29b-41d4-a716-446655440000", "/o/:id"),
        ("/reset/abc123def456ghi789", "/reset/:id"), ("/files/report-final", "/files/report-final"),
        ("/k/0123456789abcdef0123456789abcdef", "/k/:id"),
        ("/t/eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2ln", "/t/:id"),
        ("/u/ada%40example.com/profile", "/u/:id/profile"), ("/bad/%FF", "/bad/:id"),
        // A `;` in the path is not read: only the scheme and host are written.
        ("/shop;jsessionid=ABC123/cart", ""),
    ])
    func pathSegments(path: String, expected: String) throws {
        let url = try #require(URL(string: "https://e.com\(path)"))
        #expect(policy.redact(url: url) == "https://e.com\(expected)")
    }

    @Test("Host only records the scheme, host and port")
    func hostOnly() throws {
        let hostOnly = RedactionPolicy(urlDetail: .hostOnly)
        let url = try #require(URL(string: "https://u:p@api.example.com:8443/v1/users/7?x=1#f"))
        #expect(hostOnly.redact(url: url) == "https://api.example.com:8443")
        #expect(hostOnly.redactedPath(of: url).isEmpty)
    }

    @Test("Names without a value and empty queries survive")
    func edgeQueries() throws {
        #expect(policy.redact(url: try #require(URL(string: "https://e.com/?"))) == "https://e.com/?")
        // A parameter without `=` may be a value on its own, so it is kept only when allowed.
        #expect(policy.redact(url: try #require(URL(string: "https://e.com/?page"))) == "https://e.com/?\(redacted)")
        #expect(RedactionPolicy(allowedQueryParameters: ["page"]).redact(url: try #require(URL(string: "https://e.com/?page"))) == "https://e.com/?page")
        #expect(policy.redact(url: try #require(URL(string: "https://e.com/?&&token=&"))) == "https://e.com/?&&token=&")
        #expect(policy.redact(url: try #require(URL(string: "mailto:ada@example.com"))) == "mailto::id")
    }

    @Test("A query or path over the limits records only the scheme, host and port")
    func longQuery() throws {
        let pairs = (0..<20_000).map { "k\($0)=v" }.joined(separator: "&")
        #expect(policy.redact(url: try #require(URL(string: "https://e.com/?\(pairs)&token=x"))) == "https://e.com")
        let fits = (1..<RedactionPolicy.maximumQueryParameters).map { "k\($0)=v" }.joined(separator: "&")
        #expect(policy.redact(url: try #require(URL(string: "https://e.com/?\(fits)&token=x"))).hasSuffix("&token=\(redacted)"))
        let segments = String(repeating: "/a", count: RedactionPolicy.maximumPathSegments + 1)
        let deep = try #require(URL(string: "https://e.com:8443\(segments)"))
        #expect(policy.redact(url: deep) == "https://e.com:8443")
        #expect(policy.redactedPath(of: deep).isEmpty)
    }
}
