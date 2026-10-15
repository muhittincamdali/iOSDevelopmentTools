import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Redaction: names, headers and URLs")
struct RedactionPolicyTests {
    let policy = RedactionPolicy.default
    let redacted = RedactionPolicy.replacement

    @Test("Spellings of the same name normalize to one form", arguments: [
        ("X-API-Key", "xapikey"),
        ("api_key", "apikey"),
        ("apiKey", "apikey"),
        ("API%5FKEY", "apikey"),
        ("pass%2577ord", "password"),
        ("pass\u{200B}word", "password"),
        ("Pass+Word", "password"),
        // Compatibility forms (full-width, ligatures), also when percent-encoded, fold to ASCII.
        ("ｐａｓｓｗｏｒｄ", "password"),
        ("ＡＰＩ＿ＫＥＹ", "apikey"),
        ("%EF%BD%90assword", "password"),
        ("ﬁle", "file"),
        // Each %-sequence is decoded on its own, so an invalid one does not stop the others.
        ("pass%77ord%ZZ", "passwordzz"),
        ("%ZZpass%2577ord", "zzpassword"),
        ("pass%7", "pass7"),
        ("pass%FFword", "password"),
        ("", ""),
    ])
    func normalization(name: String, expected: String) {
        #expect(RedactionPolicy.normalized(name) == expected)
    }

    @Test("Sensitive names are recognized however they are written", arguments: [
        "Authorization", "Proxy-Authorization", "Cookie", "Set-Cookie", "X-Api-Key", "x_auth_token",
        "access_token", "refreshToken", "client_secret", "PASSWORD", "new-password", "API%5FKEY",
        "pass%2577ord", "jsessionid", "X-Signature", "card_number", "cvv",
    ])
    func sensitiveNames(name: String) {
        #expect(policy.isSensitive(name: name))
    }

    @Test("Ordinary names are left alone", arguments: [
        "Content-Type", "Accept", "page", "limit", "User-Agent", "id", "name", "%", "",
    ])
    func ordinaryNames(name: String) {
        #expect(!policy.isSensitive(name: name))
    }

    @Test("Empty fragments are dropped instead of matching every name")
    func emptyFragments() {
        let custom = RedactionPolicy(nameFragments: ["", "--", "Ticket"])
        #expect(custom.nameFragments == ["ticket"])
        #expect(custom.isSensitive(name: "x-ticket-id"))
        #expect(!custom.isSensitive(name: "content-type"))
    }

    @Test("The disabled policy changes nothing")
    func disabledPolicy() {
        let disabled = RedactionPolicy.disabled
        #expect(!disabled.isEnabled)
        #expect(!disabled.isSensitive(name: "Authorization"))
        let url = URL(string: "https://user:pw@example.com/a?token=1")!
        #expect(disabled.redact(url: url) == url.absoluteString)
        let headers = [HTTPHeader(name: "Authorization", value: "Bearer abc")]
        #expect(disabled.redact(headers: headers) == headers)
    }

    @Test("Header values are replaced by name and by authentication scheme")
    func headers() {
        let headers = [
            HTTPHeader(name: "Authorization", value: "Bearer abc"),
            HTTPHeader(name: "X-Upstream", value: "  bearer abc.def"),
            HTTPHeader(name: "X-Note", value: "Basic"),
            HTTPHeader(name: "Accept", value: "application/json"),
        ]
        let result = policy.redact(headers: headers)
        #expect(result.map(\.value) == [redacted, redacted, "Basic", "application/json"])
        #expect(result.map(\.name) == headers.map(\.name))
    }

    @Test("Registered and vendor authentication schemes are recognized in any header", arguments: [
        "token ghp_abc", "Token abc", "Bot MTk4NjIy", "DPoP eyJhbGciOi", "AWS4-HMAC-SHA256 Credential=AKIA/x",
        "SharedKey account:c2ln", "SCRAM-SHA-256 data=biws", "Negotiate YIIG", "NTLM TlRMTVNT",
    ])
    func authenticationSchemes(value: String) {
        #expect(policy.redact(headers: [HTTPHeader(name: "X-Upstream", value: value)]).first?.value == redacted)
    }

    @Test("Sensitive query values are replaced and everything else keeps its encoding")
    func queryParameters() {
        let url = URL(string: "https://api.example.com/v1/search?q=a%20b&api_key=XYZ&Token=1&page=2")!
        #expect(policy.redact(url: url) == "https://api.example.com/v1/search?q=a%20b&api_key=\(redacted)&Token=\(redacted)&page=2")
    }

    @Test("Percent-encoded and repeated names are caught")
    func encodedNames() {
        let url = URL(string: "https://example.com/?API%5FKEY=1&token=a&token=b&pass%2577ord=c")!
        #expect(policy.redact(url: url) == "https://example.com/?API%5FKEY=\(redacted)&token=\(redacted)&token=\(redacted)&pass%2577ord=\(redacted)")
    }

    @Test("An invalid percent sequence does not hide a sensitive name")
    func invalidPercentSequence() {
        #expect(policy.redact(urlString: "https://e.com/?pass%77ord%ZZ=secret&api_key%=k&page=2")
            == "https://e.com/?pass%77ord%ZZ=\(redacted)&api_key%=\(redacted)&page=2")
    }

    @Test("Semicolons separate parameters as well")
    func semicolonSeparators() {
        let url = URL(string: "https://example.com/a?x=1;secret=2")!
        #expect(policy.redact(url: url) == "https://example.com/a?x=1;secret=\(redacted)")
    }

    @Test("Matrix parameters in the path are checked")
    func matrixParameters() {
        let url = URL(string: "https://example.com/shop;jsessionid=ABC123/cart;color=red?x=1")!
        #expect(policy.redact(url: url) == "https://example.com/shop;jsessionid=\(redacted)/cart;color=red?x=1")
    }

    @Test("Fragments with parameters are checked, as in OAuth implicit grants")
    func fragments() {
        let url = URL(string: "https://example.com/callback#access_token=abc&state=xyz")!
        #expect(policy.redact(url: url) == "https://example.com/callback#access_token=\(redacted)&state=xyz")
        let plain = URL(string: "https://example.com/docs#section-2")!
        #expect(policy.redact(url: plain) == plain.absoluteString)
    }

    @Test("User info is replaced, including a token used as the user name")
    func userInfo() {
        #expect(policy.redact(url: URL(string: "https://alice:pw@example.com/a")!) == "https://\(redacted)@example.com/a")
        #expect(policy.redact(url: URL(string: "https://ghp_abc@example.com/a")!) == "https://\(redacted)@example.com/a")
        // An @ in the path is not user info.
        let pathAt = URL(string: "https://example.com/users/@alice")!
        #expect(policy.redact(url: pathAt) == pathAt.absoluteString)
    }

    @Test("A combining mark after a delimiter does not hide a URL part", arguments: [
        ("https://e.com/p?\u{301}token=x", "https://e.com/p?\u{301}token=\(RedactionPolicy.replacement)"),
        ("https://e.com/p?a=1&token=\u{301}x", "https://e.com/p?a=1&token=\(RedactionPolicy.replacement)"),
        ("https://e.com/cb#\u{301}access_token=abc", "https://e.com/cb#\u{301}access_token=\(RedactionPolicy.replacement)"),
        ("https://e.com/shop;\u{301}jsessionid=ABC/x", "https://e.com/shop;\u{301}jsessionid=\(RedactionPolicy.replacement)/x"),
        ("https://alice:pw@\u{301}e.com/a", "https://\(RedactionPolicy.replacement)@\u{301}e.com/a"),
    ])
    func combiningMarkAfterDelimiter(url: String, expected: String) {
        // Compared as bytes: String equality would treat some different scalar sequences as equal.
        #expect(Array(policy.redact(urlString: url).utf8) == Array(expected.utf8))
    }

    @Test("Names without a value and empty queries survive")
    func edgeQueries() {
        #expect(policy.redact(urlString: "https://e.com/?") == "https://e.com/?")
        #expect(policy.redact(urlString: "https://e.com/?token") == "https://e.com/?token")
        #expect(policy.redact(urlString: "https://e.com/?&&token=&") == "https://e.com/?&&token=\(redacted)&")
        #expect(policy.redact(urlString: "https://e.com/?=1") == "https://e.com/?=1")
    }

    @Test("A very long query is processed in one pass")
    func longQuery() {
        let pairs = (0..<20_000).map { "k\($0)=v" }.joined(separator: "&")
        let result = policy.redact(urlString: "https://e.com/?\(pairs)&token=x")
        #expect(result.hasSuffix("&token=\(redacted)"))
        #expect(result.count == "https://e.com/?\(pairs)&token=\(redacted)".count)
    }
}
