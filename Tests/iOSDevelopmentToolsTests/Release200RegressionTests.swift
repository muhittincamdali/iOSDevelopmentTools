import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The redaction tests of release 2.0.0, run against the current rules: every value 2.0.0 hid
/// is still hidden, by name, by authentication scheme, in URLs and in bodies. Where 2.0.0 stored a
/// value it could not check, the current rules may omit the body instead; they never show more.
@Suite("Redaction: what 2.0.0 hid")
struct Release200RegressionTests {
    let policy = RedactionPolicy.default
    static let secret = "hunter2"

    private func stored(_ body: String, _ contentType: String?, isComplete: Bool = true) -> String {
        String(decoding: policy.redact(body: Data(body.utf8), contentType: contentType, isComplete: isComplete).body, as: UTF8.self)
    }

    @Test("Names 2.0.0 found sensitive hide their value in JSON, forms, queries and headers", arguments: [
        "X-API-Key", "api_key", "apiKey", "API%5FKEY", "pass%2577ord", "pass\u{200B}word", "Pass+Word", "ｐａｓｓｗｏｒｄ",
        "ＡＰＩ＿ＫＥＹ", "%EF%BD%90assword", "pass%77ord%ZZ", "%ZZpass%2577ord", "pass%FFword", "pass\u{600}%77ord",
        "Authorization", "Proxy-Authorization", "Cookie", "Set-Cookie", "x_auth_token", "access_token", "refreshToken",
        "client_secret", "PASSWORD", "new-password", "jsessionid", "X-Signature", "card_number", "cvv",
    ])
    func sensitiveNames(name: String) throws {
        let secret = Self.secret
        let json = try JSONSerialization.data(withJSONObject: [name: secret])
        #expect(!String(decoding: policy.redact(body: json, contentType: "application/json").body, as: UTF8.self).contains(secret))
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? name
        #expect(!stored("user=ada&\(encoded)=\(secret)", "application/x-www-form-urlencoded").contains(secret))
        let url = try #require(URL(string: "https://e.com/a?\(encoded)=\(secret)&page=2"))
        #expect(!RedactionPolicy(allowedQueryParameters: ["page"]).redact(url: url).contains(secret))
        let headers = RedactionPolicy(allowedHeaders: [name, "X-Upstream"]).redact(headers: [HTTPHeader(name: name, value: secret)])
        #expect(headers.first?.value != secret)
    }

    @Test("A custom name fragment hides its value", arguments: ["x-ticket-id", "ticket", "TicketNumber"])
    @available(*, deprecated)
    func customFragments(name: String) {
        let custom = RedactionPolicy(nameFragments: ["", "--", "Ticket"])
        #expect(custom.isSensitive(name: name))
        #expect(!custom.isSensitive(name: "content-type"))
    }

    @Test("Header values that start with an authentication scheme are hidden, also in an allowed header", arguments: [
        "Bearer abc", "  bearer abc.def", "token ghp_abc", "Token abc", "Bot MTk4NjIy", "DPoP eyJhbGciOi",
        "AWS4-HMAC-SHA256 Credential=AKIA/x", "SharedKey account:c2ln", "SCRAM-SHA-256 data=biws", "Negotiate YIIG",
        "NTLM TlRMTVNT",
    ])
    func authenticationSchemes(value: String) {
        for policy in [policy, RedactionPolicy(allowedHeaders: ["X-Upstream"])] {
            #expect(policy.redact(headers: [HTTPHeader(name: "X-Upstream", value: value)]).first?.value == RedactionPolicy.replacement)
        }
        // A scheme without credentials holds nothing to hide; 2.0.0 kept it too.
        let lenient = RedactionPolicy(allowedHeaders: ["X-Note"])
        #expect(lenient.redact(headers: [HTTPHeader(name: "X-Note", value: "Basic")]).first?.value == "Basic")
    }

    @Test("URL values 2.0.0 hid are still hidden", arguments: [
        "https://api.example.com/v1/search?q=a%20b&api_key=hunter2&Token=hunter2&page=2",
        "https://example.com/?API%5FKEY=hunter2&token=a&token=hunter2&pass%2577ord=hunter2",
        "https://e.com/?pass%77ord%ZZ=hunter2&api_key%=hunter2&page=2",
        "https://x.test/a?q=%7B%22password%22%3A%22hunter2%22%2C%22page%22%3A2%7D&n=%7B%22a%22:1%7D",
        "https://x.test/a?q=%7B%22a%22:1,%22a%22:%7B%22token%22:%22hunter2%22%7D%7D&page=2",
        "https://example.com/a?x=1;secret=hunter2", "https://e.com/p?session;id=hunter2&a=1", "https://e.com/p?token;x=hunter2",
        "https://e.com/p?a=1;password=hunter2", "https://e.com/p?pass;word=1;token=hunter2&b=3",
        "https://example.com/shop;jsessionid=hunter2/cart;color=red?x=1", "https://example.com/callback#access_token=hunter2&state=xyz",
        "https://alice:hunter2@example.com/a", "https://hunter2@example.com/a",
    ])
    func urls(url: String) throws {
        let parsed = try #require(URL(string: url))
        for policy in [policy, RedactionPolicy(allowedQueryParameters: ["q", "page", "x", "a", "b", "n", "state"])] {
            #expect(!policy.redact(url: parsed).contains(Self.secret))
        }
    }

    @Test("Bodies 2.0.0 redacted or withheld show no secret", arguments: [
        (#"{"user":{"name":"Ada","password":"hunter2","tokens":[{"refresh_token":"hunter2"}]},"items":[{"api_key":"hunter2"}],"page":2}"#, "application/json"),
        (#"{"password":"hunter2"}"#, "application/json"), (#"{"ｐａｓｓｗｏｒｄ":"hunter2","ｔｉｔｌｅ":"x"}"#, "application/json"),
        (#"{"token":"a","token":"hunter2"}"#, "application/json"), (#"{"a":1,"a":{"password":"hunter2"}}"#, "application/json"),
        (#"[{"a":{"token":"hunter2"},"a":0}]"#, "application/json"), (#"{"x":{"y":[1,{"a":1,"a":{"secret":"hunter2"}}]}}"#, "application/json"),
        (#"{"variables":"{\"a\":1,\"a\":{\"password\":\"hunter2\"}}"}"#, "application/json"),
        ("  \n{\"secret\":\"hunter2\"}", "text/plain"),
        (#"{"query":"{ me }","variables":"{\"input\":{\"password\":\"hunter2\",\"name\":\"ada\"}}"}"#, "application/json"),
        ("\u{FEFF} {\"password\":\"hunter2\"}", "text/plain"), (#"{"password":"x","n":1e400,"password2":"hunter2"}"#, "application/json"),
        ("user=ada&pass%77ord=hunter2&remember=1", "application/x-www-form-urlencoded; charset=utf-8"),
        ("a=1&token;x=hunter2&pass;word=hunter2", "application/x-www-form-urlencoded"), ("a=1&token;x=hunter2&pass;word=hunter2", nil),
        ("password=\u{301}hunter2", "application/x-www-form-urlencoded"), ("user=ada&\u{301}password=hunter2", nil),
        ("user=ada;\u{301}token=hunter2", "application/x-www-form-urlencoded"), ("password=hunter2", "application/x-www-form-urlencoded\u{301}"),
        (#"{"user":"ada","password":"hunter2"}"#, "application/x-www-form-urlencoded"),
        ("--XyZ\r\nContent-Disposition: form-data; name=\"note\"\r\nContent-Type: application/x-www-form-urlencoded\r\n\r\ntoken;x=hunter2\r\n--XyZ--\r\n",
         "multipart/form-data; boundary=XyZ"),
        ("--XyZ\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--XyZ--\r\n", "multipart/\u{301}form-data; boundary=XyZ"),
    ] as [(String, String?)])
    func bodies(body: String, contentType: String?) {
        #expect(!stored(body, contentType).contains(Self.secret))
        #expect(!stored(body, contentType, isComplete: false).contains(Self.secret))
    }

    @Test("UTF-16 and UTF-32 JSON, with and without a byte order mark, shows no secret", arguments: [
        String.Encoding.utf16LittleEndian, .utf16BigEndian, .utf32LittleEndian, .utf32BigEndian,
    ], ["application/json", "text/plain", nil] as [String?])
    func wideJSON(encoding: String.Encoding, contentType: String?) throws {
        for text in ["\u{FEFF} {\"password\":\"hunter2\"}", " {\"password\":\"hunter2\"}"] {
            let body = try #require(text.data(using: encoding))
            let data = policy.redact(body: body, contentType: contentType).body
            #expect(!String(decoding: data, as: UTF8.self).contains(Self.secret))
            #expect(data.range(of: try #require(Self.secret.data(using: encoding))) == nil)
        }
    }
}
