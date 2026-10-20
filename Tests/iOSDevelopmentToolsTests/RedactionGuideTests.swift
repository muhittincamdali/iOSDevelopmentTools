import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The examples of the "Redacting sensitive data" guide and the README, as they are written
/// there. Change an example here and in the guide together.
@Suite("Redaction: the guide's examples")
struct RedactionGuideTests {
    let policy = RedactionPolicy.default

    @Test("Free text is hidden from its first trigger to its end; text with no trigger is kept")
    func freeText() {
        #expect(policy.redact(text: "login user=ada status=401 password=hunter2") == "login user=ada status=401 password=[REDACTED]")
        #expect(policy.redact(text: "status=200 user=bob path=/api/items") == "status=200 user=bob path=/api/items")
        #expect(policy.redact(text: "GET /v1/items status=200 duration_ms=35") == "GET /v1/items status=200 duration_ms=35")
        #expect(policy.redact(text: "password hunter2") == "password [REDACTED]")
        #expect(policy.redact(text: "login password=hunter2 status=200\nnext line") == "login password=[REDACTED]")
        #expect(policy.redact(text: "p\u{0430}ssword=hunter2") == "[REDACTED]")
        #expect(policy.redact(text: #"saved {"status":200,"name":"ada","card":"x"}"#) == #"saved {"status":200,"name":"ada","card":"[REDACTED]"}"#)
        #expect(policy.redact(text: #"payload {"a": "hunter2""#) == "payload [REDACTED]")
        #expect(policy.redact(text: #"msg="unterminated hunter2"#) == "msg=[REDACTED]")
        #expect(policy.redact(text: #"field name="password" hunter2"#) == #"field name="[REDACTED]"#)
        #expect(policy.redact(text: #"<input value="hunter2" name="password">"#) == "[REDACTED]")
        #expect(policy.redact(text: "<key>password</key>\n<string>k-1</string>") == "<key>[REDACTED]")
        #expect(policy.redact(text: "git clone https://bob:hunter2@github.com/x/y.git") == "git clone https://github.com/x/y.git")
        #expect(policy.redact(text: "Payment failed: card declined") == "Payment failed: card [REDACTED]")
        #expect(policy.redact(text: "Order 1234 shipped :(") == "Order 1234 shipped :[REDACTED]")
    }

    @Test("What it does not find, as the guide names it")
    func documentedLimits() {
        // A secret name disguised with two look-alike letters and no separator is not found.
        #expect(policy.redact(text: "p\u{0251}sswo\u{0280}d hunter2") == "p\u{0251}sswo\u{0280}d hunter2")
        // With a separator its key is not plain ASCII, and the value is hidden.
        #expect(policy.redact(text: "p\u{0251}sswo\u{0280}d=hunter2") == "p\u{0251}sswo\u{0280}d=[REDACTED]")
        // A secret word in another language is not one of the names.
        #expect(policy.redact(text: "пароль hunter2") == "пароль hunter2")
        // A plain name that is not a secret name keeps its value, in a body and in free text.
        #expect(String(decoding: policy.redact(body: Data(#"{"creds":"hunter2"}"#.utf8), contentType: "application/json").body, as: UTF8.self)
            == #"{"creds":"hunter2"}"#)
        #expect(policy.redact(text: "creds=hunter2") == "creds=hunter2")
        #expect(policy.redact(text: "curl -u bob:hunter2 https://x.example") == "curl -u bob:hunter2 https://x.example")
        // A value written before its name, outside a tag, shows.
        #expect(policy.redact(text: "hunter2 is my password") == "hunter2 is my password")
        #expect(policy.redact(text: "value=hunter2 name=password") == "value=hunter2 name=[REDACTED]")
        // A short secret in a path segment is kept; a token of 16 or more letters and digits is not.
        #expect(policy.redact(url: URL(string: "https://e.com/reset/abc123")!) == "https://e.com/reset/abc123")
        #expect(policy.redact(url: URL(string: "https://e.com/reset/abc123def456ghi789")!) == "https://e.com/reset/:id")
    }

    @Test("Bodies, URLs and headers")
    func structuredInput() throws {
        let body = Data(#"{"user":"ada","password":"hunter2","note":"pin=1234"}"#.utf8)
        #expect(String(decoding: policy.redact(body: body, contentType: "application/json").body, as: UTF8.self)
            == #"{"user":"ada","password":"[REDACTED]","note":"pin=[REDACTED]"}"#)
        let deep = String(repeating: "[", count: 65) + String(repeating: "]", count: 65)
        #expect(String(decoding: policy.redact(body: Data(deep.utf8), contentType: "application/json").body, as: UTF8.self)
            == "[body omitted: 130 bytes, application/json]")
        let url = try #require(URL(string: "https://bob:pw@api.example.com/users/12345678/reset?code=x&page=2#y"))
        #expect(policy.redact(url: url) == "https://api.example.com/users/:id/reset?code=[REDACTED]&page=[REDACTED]")
        #expect(RedactionPolicy(allowedQueryParameters: ["page"]).redact(url: url) == "https://api.example.com/users/:id/reset?code=[REDACTED]&page=2")
        let headers = RedactionPolicy(allowedHeaders: RedactionPolicy.defaultAllowedHeaders + ["X-Request-ID"]).redact(headers: [
            HTTPHeader(name: "Content-Type", value: "application/json; charset=utf-8"), HTTPHeader(name: "X-Request-ID", value: "42"),
            HTTPHeader(name: "Cache-Control", value: "max-age=60"), HTTPHeader(name: "X-Upstream", value: "eu-1"),
            HTTPHeader(name: "Authorization", value: "Bearer abc"),
        ])
        #expect(headers.map(\.value) == ["application/json; charset=utf-8", "42", "max-age=60", "[REDACTED]", "[REDACTED]"])
    }
}
