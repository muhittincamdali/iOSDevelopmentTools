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
        #expect(policy.redact(text: "login user=ada status=401 password=hunter2") == "login user=[REDACTED]")
        #expect(RedactionPolicy(allowedTextKeys: ["user"]).redact(text: "login user=ada status=401 password=hunter2")
            == "login user=ada status=401 password=[REDACTED]")
        #expect(policy.redact(text: "status=200 method=GET path=/api/items") == "status=200 method=GET path=/api/items")
        #expect(policy.redact(text: "GET /v1/items status=200 duration_ms=35") == "GET /v1/items status=200 duration_ms=35")
        #expect(policy.redact(text: "x=hunter2") == "x=[REDACTED]")
        #expect(policy.redact(text: "curl -u bob:hunter2 https://x.example") == "curl -u bob:[REDACTED]")
        #expect(policy.redact(text: "password hunter2") == "password [REDACTED]")
        // A word is read with one letter without an ASCII form as any letter and as its ASCII
        // skeleton, without such letters; both readings hide more than the secret on purpose.
        #expect(policy.redact(text: "tokens\u{0131} hunter2") == "tokens[REDACTED]")
        #expect(policy.redact(text: "token\u{A78F}\u{A78F} hunter2") == "token[REDACTED]")
        #expect(policy.redact(text: "p\u{0131}n 1234") == "p\u{0131}n [REDACTED]")
        #expect(policy.redact(text: "login password=hunter2 status=200\nnext line") == "login password=[REDACTED]")
        #expect(policy.redact(text: "p\u{0430}ssword=hunter2") == "[REDACTED]")
        #expect(policy.redact(text: #"saved {"status":200,"name":"ada","card":"x"}"#) == #"saved {"status":200,"name":[REDACTED]"#)
        #expect(policy.redact(text: #"payload {"a": "hunter2""#) == "payload [REDACTED]")
        #expect(policy.redact(text: #"msg="unterminated hunter2"#) == "msg=[REDACTED]")
        #expect(policy.redact(text: #"field name="password" hunter2"#) == #"field name="[REDACTED]"#)
        #expect(policy.redact(text: #"<input value="hunter2" name="password">"#) == "[REDACTED]")
        #expect(policy.redact(text: "<key>password</key>\n<string>k-1</string>") == "[REDACTED]")
        #expect(policy.redact(text: "<status>200</status>") == "[REDACTED]")
        #expect(policy.redact(text: "status=200 <status>200</status> hunter2") == "status=200 [REDACTED]")
        #expect(policy.redact(text: "</password> hunter2") == "[REDACTED]")
        #expect(policy.redact(text: "if a < b") == "if a < b")
        #expect(policy.redact(text: "1<2 and <3") == "1<2 and <3")
        #expect(policy.redact(text: "Loaded Array<Item> in 3 ms") == "Loaded Array[REDACTED]")
        #expect(policy.redact(text: "msg \"abc\nhunter2\" done") == "msg [REDACTED]")
        #expect(policy.redact(text: "status='x \"y' \"c\nhunter2\" ok") == "status=[REDACTED]")
        #expect(policy.redact(text: "\"a \\\" b\" done") == "[REDACTED]")
        #expect(policy.redact(text: "'x \"y' z\"") == "[REDACTED]")
        for kept in ["'a \"b\" c'", "\"x \\\"y\\\" z\"", "say \"it's 'fine'\""] {
            #expect(policy.redact(text: kept) == kept)
        }
        #expect(policy.redact(text: #""x":"hunter2""#) == "[REDACTED]")
        #expect(policy.redact(text: #""hunter2":"v""#) == "[REDACTED]")
        #expect(policy.redact(text: #""status": 200, "x": hunter2"#) == #""status": 200, [REDACTED]"#)
        #expect(policy.redact(text: "see https://a.example/v1/x), ok") == "see [REDACTED]")
        #expect(policy.redact(text: #"see "https://a.example/v1" ok"#) == #"see "[REDACTED]"#)
        #expect(policy.redact(text: "see https://x.example/to ken hunter2") == "see https://x.example/to ken [REDACTED]")
        #expect(policy.redact(text: "git clone https://bob:hunter2@github.com/x/y.git") == "git clone [REDACTED]")
        #expect(policy.redact(text: "git clone https://github.com/x/y.git") == "git clone https://github.com/x/y.git")
        // The guide's table once wrote these with the URL showing; a URL that is not clean cuts
        // the text where it starts.
        #expect(policy.redact(text: "GET https://a.example/x?api_key= hunter2") == "GET [REDACTED]")
        #expect(policy.redact(text: "see https://a.example/cb#access_token= hunter2") == "see [REDACTED]")
        #expect(policy.redact(text: "see https://a.example/v1/password= hunter2") == "see [REDACTED]")
        #expect(policy.redact(text: "Payment failed: card declined") == "Payment failed: [REDACTED]")
        #expect(policy.redact(text: "Order 1234 shipped :(") == "Order 1234 shipped :[REDACTED]")
        // A clean URL stays with `:id` in its path; any other URL cuts the text where it starts,
        // whatever the allowed query parameters, and a colon after a key ending in digits is a
        // separator.
        #expect(policy.redact(text: "GET https://api.example.com/v1/users/12345678 done") == "GET https://api.example.com/v1/users/:id done")
        #expect(RedactionPolicy(allowedQueryParameters: ["page"]).redact(text: "GET https://api.example.com/v1/items?page=2 done") == "GET [REDACTED]")
        #expect(policy.redact(text: "health http://localhost:8080/health ok") == "health [REDACTED]")
        #expect(policy.redact(text: "user1:2345678901") == "user1:[REDACTED]")
        #expect(policy.redact(text: "at 12:30 from 10.0.0.1:8080 on 2026-10-19T12:30:00Z") == "at 12:30 from 10.0.0.1:8080 on 2026-10-19T12:30:00Z")
    }

    @Test("What it does not find, as the guide names it")
    func documentedLimits() {
        // A secret name disguised with two look-alike letters and no separator is not found.
        #expect(policy.redact(text: "p\u{0251}sswo\u{0280}d hunter2") == "p\u{0251}sswo\u{0280}d hunter2")
        // With a separator its key is not plain ASCII, and the value is hidden.
        #expect(policy.redact(text: "p\u{0251}sswo\u{0280}d=hunter2") == "p\u{0251}sswo\u{0280}d=[REDACTED]")
        // Such letters put in beside the name's own are left out of its skeleton.
        #expect(policy.redact(text: "p\u{0131}a\u{0131}ssword hunter2") == "p\u{0131}a\u{0131}ssword [REDACTED]")
        // A secret word in another language is not one of the names.
        #expect(policy.redact(text: "пароль hunter2") == "пароль hunter2")
        // In a body, a plain name that is not a secret name keeps its value; in free text the key
        // is not on the allowed text keys, so the value is hidden.
        #expect(String(decoding: policy.redact(body: Data(#"{"creds":"hunter2"}"#.utf8), contentType: "application/json").body, as: UTF8.self)
            == #"{"creds":"hunter2"}"#)
        #expect(policy.redact(text: "creds=hunter2") == "creds=[REDACTED]")
        // A value written before its name, with no key before it, shows.
        #expect(policy.redact(text: "hunter2 is my password") == "hunter2 is my password")
        // A short secret in a path segment is kept; a token of 16 or more letters and digits is not.
        #expect(policy.redact(url: URL(string: "https://e.com/reset/abc123")!) == "https://e.com/reset/abc123")
        #expect(policy.redact(url: URL(string: "https://e.com/reset/abc123def456ghi789")!) == "https://e.com/reset/:id")
        #expect(policy.redact(text: "see https://x.example/reset/abc123") == "see https://x.example/reset/abc123")
        // Beside a `name` in another script, a field that does not carry a value keeps it.
        #expect(String(decoding: policy.redact(body: Data(#"{"name":"Şifre","x":"hunter2"}"#.utf8), contentType: "application/json").body, as: UTF8.self)
            == #"{"name":"Şifre","x":"hunter2"}"#)
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
