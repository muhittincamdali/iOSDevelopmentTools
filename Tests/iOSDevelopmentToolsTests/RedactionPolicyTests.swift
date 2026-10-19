import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Redaction: keys, headers and URLs")
struct RedactionPolicyTests {
    let policy = RedactionPolicy.default
    let redacted = RedactionPolicy.replacement

    @Test("Keys are folded: escapes decoded, NFKC, case folded, _ - . and spaces removed", arguments: [
        ("X-API-Key", "xapikey"), ("api_key", "apikey"), ("apiKey", "apikey"), ("API%5FKEY", "apikey"),
        ("pass%2577ord", "password"), ("pass\\u0077ord", "password"), ("pass&#119;ord", "password"),
        ("pass&#x77;ord", "password"), ("ｐａｓｓｗｏｒｄ", "password"), ("ＡＰＩ＿ＫＥＹ", "apikey"),
        ("%EF%BD%90assword", "password"), ("𝐩𝐚𝐬𝐬𝐰𝐨𝐫𝐝", "password"), ("ⓟⓐⓢⓢⓦⓞⓡⓓ", "password"),
        ("ﬁle", "file"), ("ſession", "session"), ("Pass Word", "password"), ("", ""),
    ])
    func folding(key: String, folded: String) {
        let result = FoldedKey(key)
        #expect(result.folded == folded)
        #expect(result.isPlain)
    }

    @Test("Keys that are not plain ASCII after folding are not plain, so their values are hidden", arguments: [
        "раssword", "pαssword", "pass\u{200D}word", "pass\u{200C}word", "pass\u{00AD}word", "pa\u{301}ssword",
        "pass\u{200B}word", "pass\u{600}%77ord", "pass%FFword", "pass%77ord%ZZ", "pass+word", "pass/word",
        "user[name]", "a;b", "名前", "Kullanıcı", "%", "pass\\uZZZZword",
    ])
    func notPlainKeys(key: String) {
        #expect(!FoldedKey(key).isPlain)
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
        "spinner", "inside", "cardinality", "sessions_count", "", "q", "sort.order",
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

    @Test("Kept header values still go through the value detectors")
    func keptHeaderValues() {
        let lenient = RedactionPolicy(allowedHeaders: ["X-Upstream", "ETag"])
        let headers = [
            HTTPHeader(name: "X-Upstream", value: "Bearer abc.def"),
            HTTPHeader(name: "X-Upstream", value: "token ghp_abc"),
            HTTPHeader(name: "ETag", value: "\"33a64df551425fcc55e4d42a148795d9f25f89d4\""),
            HTTPHeader(name: "ETag", value: "W/\"v7\""),
        ]
        #expect(lenient.redact(headers: headers).map(\.value) == ["Bearer \(redacted)", "token \(redacted)", "\"\(redacted)\"", "W/\"v7\""])
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
        let url = try #require(URL(string: "https://e.com/s?q=a%20b&page=1;password=x&Q=z&token=t&pa%67e=3"))
        // "token" stays hidden: a secret name cannot be allowed.
        #expect(allowing.redact(url: url) == "https://e.com/s?q=a%20b&page=1%3Bpassword%3D\(redacted)&Q=z&token=\(redacted)&pa%67e=3")
    }

    @Test("Path segments that look like identifiers or secrets become :id", arguments: [
        ("/users/123456", "/users/:id"), ("/users/12345", "/users/12345"),
        ("/o/550e8400-e29b-41d4-a716-446655440000", "/o/:id"),
        ("/reset/abc123def456ghi789", "/reset/:id"), ("/files/report-final", "/files/report-final"),
        ("/k/0123456789abcdef0123456789abcdef", "/k/:id"),
        ("/t/eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2ln", "/t/:id"),
        ("/u/ada%40example.com/profile", "/u/:id/profile"), ("/bad/%FF", "/bad/:id"),
        ("/shop;jsessionid=ABC123/cart", "/shop;jsessionid=\(RedactionPolicy.replacement)/cart"),
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
        #expect(policy.redact(url: try #require(URL(string: "https://e.com/?page"))) == "https://e.com/?page")
        #expect(policy.redact(url: try #require(URL(string: "https://e.com/?&&token=&"))) == "https://e.com/?&&token=&")
        #expect(policy.redact(url: try #require(URL(string: "mailto:ada@example.com"))) == "mailto::id")
    }

    @Test("A very long query is processed")
    func longQuery() throws {
        let pairs = (0..<20_000).map { "k\($0)=v" }.joined(separator: "&")
        let result = policy.redact(url: try #require(URL(string: "https://e.com/?\(pairs)&token=x")))
        #expect(result.hasSuffix("&token=\(redacted)"))
        #expect(!result.contains("=v&"))
    }
}
