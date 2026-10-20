import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A URL in free text is not a safe island (section 6 of the redaction rules). The fourth review
/// of this branch got 153 values past the redactor that stood right after a URL whose end named
/// them: an empty query parameter (`?api_key= hunter2`), a fragment (`#access_token= hunter2`),
/// path parameters (`;jsessionid= hunter2`), a path that ends in `=` or `:`, a last segment, query
/// name or host that is a secret name. Path parameters, a query or a fragment cut the text at
/// their start unless every parameter in them is allowed and has a value, and a URL whose end
/// names a value cuts the text after it.
@Suite("Redaction corpus: URLs written in text")
struct RedactionWrittenURLTests {
    static let secret = "Kp7Zw3Qx9"

    /// Where the URL starts: schemes, addresses, ports and user info.
    static let starts = [
        "http://x.example", "HTTPS://X.EXAMPLE", "ftp://files.example", "wss://rt.example", "postgres://app@db.example:5432",
        "https://[::1]:8443", "https://10.0.0.1", "https://x.example:8443", "https://bob@x.example", "myapp://callback",
        "mongodb+srv://c.example",
    ]

    /// How the URL ends: with a name whose value comes after it.
    static let ends = [
        "/a?token=", "/a;token=", "/a;jsessionid=", "/password=", "/v1/password=", "/a#access_token=", "/v1/api_key:", "/password",
        "/a?secret", "/a?api_key", "/api/password/", "/a?x=1&pin=", "/a?page=2&pin=", "/a?b=1#password", "/t%6Fken=", "/a?t%6Fken=",
        "/a?t\u{043E}ken=", "/a?TOKEN=", "/?PASSWORD=", "/a?q=", "/oauth?client_secret=",
    ]

    /// What can stand between the URL and the value.
    static let gaps = [
        " ", "\"", "'", "`", "<", ">", "\n", "\r", "\r\n", "\t", ". ", ", ", ") ", "] ", "; ", "! ", "? ", ": ", "=\"",
        "\u{0B}", "\u{0C}", "\u{85}", "\u{A0}", "\u{3000}", "\u{2028}", "\u{2029}",
    ]

    /// Every place free text is read: a log line, a log message, after an allowed key, a
    /// text/plain body, a JSON string, a form value and a multipart text part.
    static func places(_ line: String) -> [(String, String)] {
        let redactor = Redactor(allowedTextKeys: ["note", "url"])
        let store = LogStore(configuration: .init(systemLogSubsystem: nil))
        store.info("see " + line)
        let json = String(decoding: (try? JSONSerialization.data(withJSONObject: ["msg": line])) ?? Data(), as: UTF8.self)
        let form = "note=" + RedactionPolicy.formEncoded(line)
        let multipart = "--B\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\n" + line + "\r\n--B--\r\n"
        return [
            ("text", redactor.redact("see " + line)),
            ("log", store.entries.first?.message ?? ""),
            ("allowed key", redactor.redact("status=200 path=" + line)),
            ("text/plain", redactor.redact(body: Data(line.utf8), contentType: "text/plain")),
            ("JSON", redactor.redact(body: Data(json.utf8), contentType: "application/json")),
            ("JSON array", redactor.redact(body: Data("[\(json)]".utf8), contentType: "application/json")),
            ("form", redactor.redact(body: Data(form.utf8), contentType: "application/x-www-form-urlencoded")),
            ("multipart", redactor.redact(body: Data(multipart.utf8), contentType: "multipart/form-data; boundary=B")),
        ]
    }

    @Test("no value after a URL whose end names it shows, in any place, after any scheme and gap", arguments: starts)
    func valueAfterURLIsHidden(start: String) {
        for end in Self.ends {
            for gap in Self.gaps {
                let line = start + end + gap + Self.secret + " 200"
                for (place, output) in Self.places(line) {
                    #expect(!output.contains(Self.secret), "\(place): \(line.debugDescription) -> \(output.debugDescription)")
                }
            }
        }
    }

    @Test("the reviews' examples are cut at the query, the fragment, the path parameters or the end of the URL", arguments: [
        ("GET https://a.example/x?api_key= hunter2", "GET https://a.example/x?[REDACTED]"),
        ("redirect to https://a.example/login?password= hunter2", "redirect to https://a.example/login?[REDACTED]"),
        ("see https://a.example/cb#access_token= hunter2", "see https://a.example/cb#[REDACTED]"),
        ("see https://a.example/x;jsessionid= hunter2", "see https://a.example/x;[REDACTED]"),
        ("see https://a.example/x?secret=\nhunter2", "see https://a.example/x?[REDACTED]"),
        ("see https://a.example/x?q=abc hunter2", "see https://a.example/x?[REDACTED]"),
        ("GET https://api.example/v1/items?password=\"Zk3Pq9Lm\" 200", "GET https://api.example/v1/items?[REDACTED]"),
        ("POST https://h.example/oauth?client_secret=\"X1\" 400", "POST https://h.example/oauth?[REDACTED]"),
        ("see https://h.example/a?api_key=`X1`", "see https://h.example/a?[REDACTED]"),
        ("see https://h.example/a?q='X1'", "see https://h.example/a?[REDACTED]"),
        ("see https://h.example/a?q=<X1>", "see https://h.example/a?[REDACTED]"),
        ("see HTTP://H.EXAMPLE/?PASSWORD= X1", "see HTTP://H.EXAMPLE/?[REDACTED]"),
        ("see https://h.example/a?api_key X1", "see https://h.example/a?[REDACTED]"),
        ("[docs](https://x.example/a?token=) X1", "[docs](https://x.example/a?[REDACTED]"),
        ("open(\"https://x.example/a?token=\", \"X1\")", "open(\"https://x.example/a?[REDACTED]"),
        ("see https://x.example/a?t\u{043E}ken= X1", "see https://x.example/a?[REDACTED]"),
        ("see https://x.example/v1/api_key: X1", "see https://x.example/v1/api_key: [REDACTED]"),
        ("see https://x.example/v1/password= X1", "see https://x.example/v1/password= [REDACTED]"),
        ("see https://x.example/a/password X1", "see https://x.example/a/password [REDACTED]"),
        ("see https://password X1", "see https://password [REDACTED]"),
        ("see myapp://pass%77ord X1", "see myapp://[REDACTED]"),
        ("see myapp://password= X1", "see myapp://[REDACTED]"),
        ("connect myapp://password=hunter2 ok", "connect myapp://[REDACTED] ok"),
    ])
    func reviewExamples(input: String, expected: String) {
        #expect(Redactor().redact(input) == expected)
    }

    @Test("the same URLs in a JSON string, a text/plain body and a form value are cut too")
    func carriers() {
        let redactor = Redactor(allowedTextKeys: ["note"])
        let json = #"{"msg":"redirect https://a.example/cb?api_key= hunter2"}"#
        #expect(redactor.redact(body: Data(json.utf8), contentType: "application/json") == #"{"msg":"redirect https://a.example/cb?[REDACTED]"}"#)
        let plain = "GET https://a.example/x?password= hunter2 200"
        #expect(redactor.redact(body: Data(plain.utf8), contentType: "text/plain") == "GET https://a.example/x?[REDACTED]")
        let form = "note=see+https%3A%2F%2Fh.example%2F%3Fpassword%3D%22hunter2%22+200"
        let formOutput = redactor.redact(body: Data(form.utf8), contentType: "application/x-www-form-urlencoded")
        #expect(!formOutput.contains("hunter2"))
        #expect(formOutput.hasPrefix("note=see+https%3A%2F%2Fh.example%2F%3F"))
        #expect(redactor.redact("status=200 path=https://h.example/?token= hunter2") == "status=200 path=https://h.example/?[REDACTED]")
    }

    @Test("a URL past the limits of segments or parameters cuts the text after its host")
    func limits() {
        let segments = "see https://x.example" + String(repeating: "/a", count: RedactionPolicy.maximumPathSegments + 6) + "?token= X1"
        #expect(Redactor().redact(segments) == "see https://x.example[REDACTED]")
        let parameters = "see https://x.example/a?" + String(repeating: "b=1&", count: RedactionPolicy.maximumQueryParameters + 1) + "token= X1"
        #expect(Redactor().redact(parameters) == "see https://x.example[REDACTED]")
    }

    // The library stays useful: a URL whose parameters are all allowed and have values, and one
    // without parameters whose end names nothing, keep the text after them.
    @Test("a URL that leaves nothing for the text after it keeps that text")
    func usefulURLsAreKept() {
        let redactor = Redactor(allowedQueryParameters: ["page", "sort", "q"])
        for line in [
            "GET https://x.example/a?page=2 status=200 duration_ms=12",
            "GET https://x.example/a?page=2&sort=name status=200",
            "GET https://x.example/a;page=2/b status=200",
            "see https://x.example/a?q=abc hunter2",
            "see https://x.example/docs/getting-started. status=200",
            "see https://x.example status=200",
            "GET https://x.example/v1/items/42 status=200",
        ] {
            #expect(redactor.redact(line) == line)
        }
        #expect(redactor.redact("GET https://x.example/users/12345678 status=200") == "GET https://x.example/users/:id status=200")
        #expect(redactor.redact("GET https://bob:pw@x.example/a?page=2 status=200") == "GET https://x.example/a?page=2 status=200")
    }

    @Test("an allowed parameter without a value, or one that names a secret as a value, still cuts")
    func allowedButOpen() {
        let redactor = Redactor(allowedQueryParameters: ["q", "label"])
        #expect(redactor.redact("see https://x.example/a?q= hunter2") == "see https://x.example/a?[REDACTED]")
        #expect(redactor.redact("see https://x.example/a?label=password hunter2") == "see https://x.example/a?[REDACTED]")
        #expect(redactor.redact("see https://x.example/a?q=abc#frag hunter2") == "see https://x.example/a?q=abc#[REDACTED]")
    }

    @Test("the same text without a scheme is cut as it was")
    func withoutScheme() {
        #expect(Redactor().redact("GET /v1/items?api_key='X1' 200") == "GET /v1/items?api_key='[REDACTED]")
        #expect(Redactor().redact("GET /x?api_key= hunter2") == "GET /x?api_key= [REDACTED]")
    }
}
