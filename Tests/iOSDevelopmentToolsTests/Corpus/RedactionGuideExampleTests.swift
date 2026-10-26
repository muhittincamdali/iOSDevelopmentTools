import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The examples of the logging guide's sections on free text, bodies and URLs, as the guide writes
/// them, so that the guide shows what the redactor does.
@Suite("Redaction corpus: logging guide examples")
struct RedactionGuideExampleTests {
    let redactor = Redactor()

    @Test("the free-text examples", arguments: [
        ("GET /api/items status=200 method=GET duration_ms=12", "GET /api/items status=200 method=GET duration_ms=12"),
        ("login user=bob status=401 password=hunter2", "login user=[REDACTED]"),
        ("Error: connection refused\nretrying in 5 s", "Error: [REDACTED]"),
        ("user\u{A789} hunter2", "user[REDACTED]"),
        ("status=200 note\u{2192} hunter2", "status=200 note[REDACTED]"),
        ("user&colon;hunter2", "[REDACTED]"),
        ("contact alice%40example.com", "contact [REDACTED]"),
        (#"log [["X-User","bob"]]"#, #"log [[[REDACTED]"#),
        (#"cache miss for "session Qz9Wk7rX": refetching"#, "cache miss for [REDACTED]"),
        ("<user>bob</user>", "[REDACTED]"),
        ("password hunter2", "password [REDACTED]"),
        ("p\u{0430}ssword=hunter2", "p\u{0430}ssword=[REDACTED]"),
        ("login pa\u{115F}ssword hunter2", "login [REDACTED]"),
        ("password: 'abc\n  hunter2'", "password: [REDACTED]"),
        ("| password | hunter2 |", "| password [REDACTED]"),
        ("field name=\"password\" hunter2", "field name=[REDACTED]"),
        (#"<string name="api_key">k-1</string>"#, "[REDACTED]"),
        ("<key>password</key>\n<string>k-1</string>", "[REDACTED]"),
        ("upload ok status=200\n--B\r\nContent-Disposition: form-data; name=\"pin\"\r\n\r\n4831\r\n--B--",
         "upload ok status=200\n--B\r\nContent-Disposition: [REDACTED]"),
        (#"{"status":200,"user":"bob"} done"#, #"{"status":200,[REDACTED]"#),
        ("git clone https://bob:hunter2@github.com/x/y.git", "git clone [REDACTED]"),
        ("connect myapp://password=hunter2 ok", "connect [REDACTED]"),
        ("see https://x.example/a?token= hunter2", "see [REDACTED]"),
        ("GET https://api.example.com/items 200", "GET https://api.example.com/items 200"),
        ("GET https://api.example.com/users/12345678 200", "GET https://api.example.com/users/:id 200"),
        ("user1:2345678 at 12:30", "user1:[REDACTED]"),
        ("at 12:30 id 7:9hunter2", "at 12:30 id 7:[REDACTED]"),
        ("login t\u{0366}ken hunter2", "login t\u{0366}ken [REDACTED]"),
        ("paid with 4111 1111 1111\u{2028}1111", "paid with [REDACTED]"),
        ("see https://x.example/a?q=1 ok", "see [REDACTED]"),
        ("Merhaba dünya \u{1F44B} bye", "Merhaba dünya [REDACTED]"),
        ("Optional<String>(x)", "Optional[REDACTED]"),
        ("note \"a\nhunter2\": 1", "note [REDACTED]"),
        ("if a < b then", "if a < b then"),
        ("login pa\\x{73}sword hunter2", "login [REDACTED]"),
        ("copied to \\\\nas\\backup", "copied to [REDACTED]"),
        ("pattern ^\\d+$ matched", "pattern [REDACTED]"),
        ("x\"status\": 200", "[REDACTED]"),
        ("\u{1F101}\"status\": 200", "[REDACTED]"),
        ("\u{1F101}status=200", "[REDACTED]"),
    ])
    func freeText(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("an app that allows a key reads on after it")
    func allowedKey() {
        let allowing = Redactor(allowedTextKeys: ["user"])
        #expect(allowing.redact("login user=bob status=401 password=hunter2") == "login user=bob status=401 password=[REDACTED]")
    }

    @Test("the body and URL examples")
    func bodiesAndURLs() throws {
        let part = "--B0und\r\nContent-Disposition: form-data; name=\"a\"\r\nX-4111111111111111: 1\r\n" + "Content-Length: 1\r\n\r\nx\r\n--B0und--"
        #expect(redactor.redact(body: Data(part.utf8), contentType: "multipart/form-data; boundary=B0und")
            == "--B0und\r\nContent-Disposition: form-data; name=\"a\"\r\n[REDACTED]: [REDACTED]\r\nContent-Length: 1\r\n\r\nx\r\n--B0und--")
        #expect(redactor.redact(url: try #require(URL(string: "https://h.example;password=hunter2/db"))) == "https://[REDACTED]")
        #expect(redactor.redact(url: try #require(URL(string: "https://example.com/pin/./4831"))) == "https://example.com")
        #expect(redactor.redact(url: try #require(URL(string: "https://example.com/a;pin/4831"))) == "https://example.com")
        #expect(redactor.redact(url: try #require(URL(string: "myapp://pin/4831"))) == "myapp://[REDACTED]")
        #expect(redactor.redact(url: try #require(URL(string: "myapp://password.hunter2"))) == "myapp://[REDACTED]")
        #expect(redactor.redact(url: try #require(URL(string: "https://bob:pw@example.com/users/12345678/reset?code=x#y")))
            == "https://example.com/users/:id/reset?code=[REDACTED]")
        let body = Data(("{\"a\":\"" + String(repeating: "abc ", count: 70_000) + "\"}").utf8)
        #expect(redactor.redact(body: body, contentType: "application/json") == "[body omitted: \(body.count) bytes, application/json]")
        #expect(Redactor(maximumBodySize: 1_048_576).redact(body: body, contentType: "application/json") == String(decoding: body, as: UTF8.self))
    }
}
