import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Every bypass reported against earlier versions of the redaction code, kept as a test. Each
/// case holds the secret `hunter2`, which must not be stored in any form.
@Suite("Redaction: earlier bypasses")
struct RedactionRegressionTests {
    let policy = RedactionPolicy.default
    static let secret = "hunter2"
    static let multipart = "multipart/form-data; boundary=B"
    static let form = "application/x-www-form-urlencoded"

    /// Whether the secret is in the stored bytes, read as UTF-8 or as UTF-16.
    private func leaks(_ data: Data) -> Bool {
        data.range(of: Data(Self.secret.utf8)) != nil
            || String(data: data, encoding: .utf16LittleEndian)?.contains(Self.secret) == true
            || String(data: data, encoding: .utf16BigEndian)?.contains(Self.secret) == true
    }

    private func leaks(_ body: Data, _ contentType: String?, isComplete: Bool = true) -> Bool {
        leaks(policy.redact(body: body, contentType: contentType, isComplete: isComplete).body)
    }

    private static func part(_ headers: String, _ content: String = "hunter2") -> String {
        "--B\r\n\(headers)\r\n\r\n\(content)\r\n--B--\r\n"
    }

    private static func nested(boundary: String) -> String {
        let inner = "--B1\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--B1--\r\n"
        return "--\(boundary)\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\n\(inner)\r\n--\(boundary)--\r\n"
    }

    @Test("JSON bodies", arguments: [
        #"{"password":"hunter2"}"#, "{\"ｐａｓｓｗｏｒｄ\":\"hunter2\",\"ｔｉｔｌｅ\":\"x\"}",
        "{\"password\u{301}\":\"hunter2\"}", #"{"a":1e400,"password":"hunter2"}"#, #"{"a":1e999,"password":"hunter2"}"#,
        #"{"a":-0,"b":123456789012345678901234567890,"token":"hunter2"}"#, #""{\"token\":\"hunter2\"}""#,
        #"{"variables":"{\"password\":\"hunter2\"}"}"#, "\u{0B}{\"password\":\"hunter2\"}",
        "{\"caf\u{E9}\":1,\"cafe\u{301}\":{\"token\":\"hunter2\"}}", #"{"a":{"pass_word":"hunter2"}}"#,
        #"[[{"Token":"hunter2"}]]"#, #"{"password":"hunter2"#,
    ])
    func jsonBodies(body: String) {
        #expect(!leaks(Data(body.utf8), "application/json"))
        #expect(!leaks(Data(body.utf8), "application/json", isComplete: false))
    }

    @Test("JSON in UTF-16 and UTF-32, with and without a byte order mark, under any content type", arguments: [
        String.Encoding.utf16LittleEndian, .utf16BigEndian, .utf32LittleEndian, .utf32BigEndian,
    ], [
        "application/json", "text/plain", nil,
    ] as [String?])
    func wideJSON(encoding: String.Encoding, contentType: String?) throws {
        for text in [" {\"password\":\"hunter2\"}", "\u{FEFF} {\"password\":\"hunter2\"}"] {
            let body = try #require(text.data(using: encoding))
            #expect(!leaks(body, contentType))
            let wide = try #require("hunter2".data(using: encoding))
            #expect(policy.redact(body: body, contentType: contentType).body.range(of: wide) == nil)
        }
    }

    @Test("Bodies sent with another content type than what they hold", arguments: [
        (#"{"password":"hunter2"}"#, "text/plain"), ("password=hunter2", "text/plain"),
        ("  \n{\"secret\":\"hunter2\"}", "text/plain"), ("\u{FEFF} {\"password\":\"hunter2\"}", "text/plain"),
        (#"{"password":hunter2}"#, "text/plain"), (#"{"password":NaN,"token":hunter2}"#, "application/json"),
        ("\u{0C}{\"password\":\"hunter2\"}", "text/plain"), (#"{"password":"hunter2"}"#, nil),
        (" \n{\"password\":\"hunter2\"}", form), (#"{"user":"ada","password":"hunter2"}"#, form),
        (#"{"x":"1&password=hunter2"}"#, form), (#"{"x":"1&password=hunter2"}"#, nil), (#"["&password=hunter2"]"#, form),
        (#"{"token":"hunter2==","n":1}"#, form), (#"{"token":"hunter2==","n":1}"#, nil), ("{\"a\":1&password=hunter2", form),
        ("password=hunter2", "application/x-www-form-urlencoded\u{301}"), ("password=hunter2", "application/xml"),
        ("password=hunter2", "image/png"), ("password=hunter2", "application/octet-stream"),
    ] as [(String, String?)])
    func mislabeledBodies(body: String, contentType: String?) {
        #expect(!leaks(Data(body.utf8), contentType))
    }

    @Test("Form bodies", arguments: [
        "user=ada&pass%77ord=hunter2", "pass%2577ord=hunter2", "pass+word=hunter2", "pass%u0077ord=hunter2",
        "PASSWORD=hunter2", "a=1;password=hunter2", "a=1&token;x=hunter2&pass;word=hunter2", "token;x=hunter2",
        "a=1&pass;word=hunter2", "password=\u{301}hunter2", "user=ada&\u{301}password=hunter2", "user=ada;\u{301}token=hunter2",
        "data=%7B%22password%22%3A%22hunter2%22%7D", "d=%7B%22token%22%3A%22hunter2%22%7D",
        "q=%7B%22a%22:1,%22a%22:%7B%22token%22:%22hunter2%22%7D%7D", "user=ada&password=hunter2&x=%E0%A4",
    ])
    func formBodies(body: String) {
        #expect(!leaks(Data(body.utf8), Self.form))
        #expect(!leaks(Data(body.utf8), Self.form + "; charset=utf-8"))
        #expect(!leaks(Data(body.utf8), nil))
    }

    @Test("A form body in UTF-16 is omitted")
    func wideForm() {
        let body = Data("password=hunter2".utf16.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] })
        #expect(!leaks(body, Self.form + "; charset=utf-16le"))
    }

    @Test("Multipart part headers that servers read differently", arguments: [
        part("Content-Disposition: form-data;\r\n name=\"password\""), part("Content-Disposition: form-data;\r\n\tname=\"password\""),
        part("Content-Disposition: form-data; name*0=\"pass\"; name*1=\"word\""),
        part("Content-Disposition: form-data; NAME*0*=utf-8''pass; name*1*=word"),
        part("content-disposition : form-data; name=password"), part("Content-Disposition\t: form-data; name=password"),
        part("Content-Disposition\u{0C}: form-data; name=password"), part("Content-Disposition\u{301}: form-data; name=password"),
        part("Content Disposition: form-data; name=password"), part("Content-Disposition:\u{301} form-data; name=password"),
        part("Content-Disposition: form-data; name = \"password\""), part("Content-Disposition: form-data; x =\"; name=password\""),
        part("Content-Disposition: form-data; name=\"note\"; x =\"; name=password\""),
        part("Content-Disposition: form-data; a@b=\"; name=password\""), part("Content-Disposition: form-data; x= \"; name=password\""),
        part("Content-Disposition: form-data; x=@\"; name=password\""), part("Content-Disposition: form-data; name=\"a\"\u{301}; name=\"password\""),
        part("Content-Disposition: form-data; name=a;\u{301} name=password"), part("Content-Disposition: form-data; x=\"\u{301}; name=password"),
        part("Content-Disposition: form-data; name=\"note\"\r\nContent-Disposition: form-data; name=\"password\""),
        part("Content-Disposition: form-data; name=\"note\"; name=\"password\""),
        part("Content-Disposition: form-data; name=\"note\"; name*=utf-8''password"),
        part("Content-Disposition: form-data; name=\"pass;word\""), part("Content-Disposition: form-data; name=\"a;password\""),
        part("Content-Disposition: form-data; name=\"a\"\r\nContent-Type: text/plain\r\nContent-Type: application/json", #"{"token":"hunter2"}"#),
        part("Content-Disposition: form-data; name=\"note\"\r\nContent-Type: application/x-www-form-urlencoded", #"{"x":"1&password=hunter2"}"#),
        part("Content-Disposition: form-data; name=\"note\"\r\nContent-Type: application/x-www-form-urlencoded", "token;x=hunter2"),
        part("Content-Disposition: form-data; name=\"q\"\r\nContent-Type: application/json", #"{"a":{"pass_word":"hunter2"}}"#),
        part("Content-Disposition: form-data; name=\"upload\"; filename=\"creds.txt\"\r\nContent-Type: application/octet-stream", "password=hunter2"),
    ])
    func multipartHeaders(body: String) {
        #expect(!leaks(Data(body.utf8), Self.multipart))
    }

    @Test("A part in a transfer encoding other than 7bit, 8bit or binary is omitted", arguments: [
        "base64", "quoted-printable", "x-custom", "BASE64",
    ])
    func transferEncoding(encoding: String) {
        let encoded = Data("password=hunter2".utf8).base64EncodedString()
        let body = Self.part("Content-Disposition: form-data; name=\"blob\"\r\nContent-Type: application/x-www-form-urlencoded\r\n"
            + "Content-Transfer-Encoding: \(encoding)", encoded)
        let stored = String(decoding: policy.redact(body: Data(body.utf8), contentType: Self.multipart).body, as: UTF8.self)
        #expect(!stored.contains(encoded))
        #expect(stored.contains("[body omitted: \(encoded.utf8.count) bytes, application/x-www-form-urlencoded]"))
        // 8bit leaves the content as it is, so it is parsed.
        let plain = Self.part("Content-Disposition: form-data; name=\"a\"\r\nContent-Transfer-Encoding: 8bit", "password=hunter2")
        #expect(!leaks(Data(plain.utf8), Self.multipart))
    }

    @Test("Multipart structure that servers read differently", arguments: [
        ("multipart/form-data; boundary=X; boundary=Y", "--X\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\n--Y\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--Y--\r\n--X--\r\n"),
        ("multipart/form-data; boundary=X; Boundary=Y", "--X\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\n--Y\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--Y--\r\n--X--\r\n"),
        ("multipart/form-data; boundary=X; boundary*=utf-8''Y", "--Y\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--Y--\r\n"),
        ("multipart/form-data; boundary*=utf-8''Y", "--Y\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--Y--\r\n"),
        ("multipart/form-data; boundary=B1/x", nested(boundary: "B1/x")), ("multipart/form-data; boundary=B1 x", nested(boundary: "B1 x")),
        ("multipart/form-data; boundary=B1\u{301}x", nested(boundary: "B1\u{301}x")),
        ("multipart/form-data; boundary=\"a;b\"", "--a;b\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--a;b--\r\n"),
        ("multipart/\u{301}form-data; boundary=B", part("Content-Disposition: form-data; name=\"password\"")),
        (multipart, "--B\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\nhi\n--B\nContent-Disposition: form-data; name=\"password\"\n\nhunter2\r\n--B--"),
        (multipart, "--B\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\nhi\r--B\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--B--"),
        (multipart, "\n--B\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--B--"),
        (multipart, "--B\r\nContent-Disposition: form-data; name=\"password\"\n\nhunter2\r\n\r\nv\r\n--B--"),
        (multipart, "--B\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nabc\r\n--BX\r\n\r\nhunter2\r\n--B--"),
        (multipart, "--B \r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--B x\r\n\r\nhunter2\r\n--B--"),
        (multipart, "preamble hunter2\r\n--B\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--B--\r\n"),
        (multipart, "--B\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--B--\r\nepilogue hunter2"),
        (multipart, "--B\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--B--\r\n--B\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--B--\r\n"),
        (multipart, "--B\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\nhello--B--\r\n--B\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--B--\r\n"),
        (multipart, "--B\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2"),
        ("multipart/form-data", "--B\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--B--"),
    ])
    func multipartStructure(contentType: String, body: String) {
        #expect(!leaks(Data(body.utf8), contentType))
    }

    @Test("URLs", arguments: [
        "https://u:hunter2@h.example/p;jsessionid=hunter2?a=1&pass%77ord=hunter2#token=hunter2",
        "https://h.example/p?a=1&%2570assword=hunter2&api%5Fkey=hunter2", "https://ghp_hunter2@example.com/a",
        "https://e.com/?pass%77ord%ZZ=hunter2&api_key%=hunter2", "https://e.com/a?x=1;secret=hunter2",
        "https://e.com/p?token;x=hunter2", "https://e.com/p?pass;word=1;token=hunter2&b=3", "https://e.com/p?a=1&token%3Bx=hunter2",
        "https://x.test/a?q=%7B%22password%22%3A%22hunter2%22%7D", "https://x.test/a?q=%7B%22a%22:1,%22a%22:%7B%22token%22:%22hunter2%22%7D%7D",
        "https://example.com/callback#access_token=hunter2&state=xyz", "https://e.com/shop;jsessionid=hunter2/cart;color=red?x=1",
    ])
    func urls(url: String) throws {
        let parsed = try #require(URL(string: url))
        #expect(!policy.redact(url: parsed).contains(Self.secret))
        let lenient = RedactionPolicy(allowedQueryParameters: ["a", "b", "q", "x", "state", "page"])
        #expect(!lenient.redact(url: parsed).contains(Self.secret))
    }

    @Test("URLs with a combining mark after a delimiter", arguments: [
        "https://e.com/p?\u{301}token=hunter2", "https://e.com/p?a=1&token=\u{301}hunter2",
        "https://e.com/cb#\u{301}access_token=hunter2", "https://e.com/shop;\u{301}jsessionid=hunter2/x",
        "https://alice:hunter2@\u{301}e.com/a",
    ])
    func combiningMarkURLs(url: String) {
        // Depending on the platform, URL(string:) percent-encodes the mark or rejects the URL.
        guard let parsed = URL(string: url) else { return }
        #expect(!policy.redact(url: parsed).contains(Self.secret))
        #expect(!RedactionPolicy(allowedQueryParameters: ["a"]).redact(url: parsed).contains(Self.secret))
    }

    @Test("Header values", arguments: [
        "Bearer hunter2", "Bearer\thunter2", "bearer\thunter2", "Bearer \u{301}hunter2", "Bearer\u{A0}hunter2",
        "Basic, hunter2", "token hunter2", "Token hunter2", "Bot hunter2", "DPoP hunter2",
        "AWS4-HMAC-SHA256 Credential=hunter2", "SharedKey account:hunter2", "SCRAM-SHA-256 data=hunter2",
        "Negotiate hunter2", "NTLM hunter2", "a=hunter2",
    ])
    func headerValues(value: String) {
        // Headers that are not on the allowlist, and headers that are always hidden.
        for name in ["X-Custom", "X-Upstream", "Authorization", "Cookie", "Set-Cookie", "Proxy-Authorization"] {
            #expect(!policy.redact(headers: [HTTPHeader(name: name, value: value)]).contains { $0.value.contains(Self.secret) })
        }
    }

    @Test("Bearer credentials are found in an allowed header whatever separates them from the word", arguments: [
        "Bearer hunter2", "Bearer\thunter2", "bearer\thunter2", "Bearer \u{301}hunter2", "Bearer\u{A0}hunter2", "x, Bearer\u{2003}hunter2",
    ])
    func bearerInAllowedHeader(value: String) {
        let lenient = RedactionPolicy(allowedHeaders: ["X-Upstream"])
        #expect(lenient.redact(headers: [HTTPHeader(name: "X-Upstream", value: value)]).first?.value.contains(Self.secret) == false)
    }

    @Test("Log messages", arguments: [
        "password=hunter2", "login PASSWORD: hunter2", "token hunter2", "tOkEn hunter2", "{\"pass_word\":\"hunter2\"}",
        "ok\u{2028}password=hunter2", "Authorization: Bearer hunter2", "kEy_name=hunter2",
    ])
    func logMessages(message: String) {
        let store = LogStore(configuration: .init(systemLogSubsystem: nil))
        store.info(message)
        #expect(store.entries.first?.message.contains(Self.secret) == false)
    }

    @Test("A long message of combining marks is redacted and cut off quickly")
    func combiningMarkMessage() {
        let store = LogStore(configuration: .init(systemLogSubsystem: nil))
        let start = Date()
        store.info("a" + String(repeating: "\u{301}", count: 1_000_000) + " password=hunter2", category: "c" + String(repeating: "\u{301}", count: 500_000))
        #expect(Date().timeIntervalSince(start) < 10)
        #expect(store.entries.first?.message.contains(Self.secret) == false)
        #expect(store.entries.first?.isTruncated == true)
    }
}
