import Foundation
import Testing
@testable import iOSDevelopmentTools

/// URLs read with `URLComponents`: no credentials or fragment, query values only on an allowlist,
/// identifiers in the path as `:id`.
@Suite("Redaction corpus: URLs")
struct RedactionURLTests {
    let redactor = Redactor()

    // In text, a URL that is not clean — a query, a fragment, path parameters, user info, a port,
    // an escape — cuts the text where it starts (see RedactionWrittenURLTests); a clean one is
    // recorded as `redact(url:)` records it and the text after it is read on.
    @Test("drops user info and the fragment, hides query values and identifiers in the path", arguments: [
        ("https://example.com/users/12345678/reset?code=ft14", "https://example.com/users/:id/reset?code=[REDACTED]", "[REDACTED]"),
        ("https://bob:hunter2@example.com/a/b?x=1#frag", "https://example.com/a/b?x=[REDACTED]", "[REDACTED]"),
        ("https://bob@example.com:8443/", "https://example.com:8443/", "[REDACTED]"),
        ("https://example.com/orders/550e8400-e29b-41d4-a716-446655440000", "https://example.com/orders/:id", "https://example.com/orders/:id done"),
        ("https://example.com/files/0123456789abcdef0123456789abcdef", "https://example.com/files/:id", "https://example.com/files/:id done"),
        ("https://example.com/s/aB3dE5fG7hJ9kL1m", "https://example.com/s/:id", "https://example.com/s/:id done"),
        ("https://example.com/u/alice@example.com/x", "https://example.com/u/:id/:id", "[REDACTED]"),
        ("https://example.com/cart;jsessionid=abc/view", "https://example.com", "[REDACTED]"),
        ("https://example.com/a?flag&q=", "https://example.com/a?[REDACTED]&q=", "[REDACTED]"),
        ("https://example.com/a?p%61ssword=x&%E2%80%8Btoken=y", "https://example.com/a?p%61ssword=[REDACTED]&[REDACTED]=[REDACTED]", "[REDACTED]"),
        ("https://example.com/v1/items/42?page=2", "https://example.com/v1/items/42?page=[REDACTED]", "[REDACTED]"),
        ("https://example.com/health", "https://example.com/health", "https://example.com/health done"),
    ])
    func urls(input: String, expected: String, inText: String) throws {
        #expect(redactor.redact(url: try #require(URL(string: input))) == expected)
        #expect(redactor.redact("GET \(input) done") == "GET \(inText)")
    }

    @Test("query values on the allowlist are kept, read as free text")
    func allowedQueryParameters() throws {
        let custom = Redactor(allowedQueryParameters: ["page", "sort", "token"])
        let url = try #require(URL(string: "https://example.com/a?page=2&sort=name%20asc&token=abc&q=x&note=user%3Dbob"))
        #expect(custom.redact(url: url) == "https://example.com/a?page=2&sort=name%20asc&token=[REDACTED]&q=[REDACTED]&note=[REDACTED]")
        // An allowed value is free text: `user` is not an allowed text key, `status` is.
        let pageNote = try #require(URL(string: "https://example.com/a?page=user%3Dbob"))
        #expect(custom.redact(url: pageNote) == "https://example.com/a?page=user%3D[REDACTED]")
        let pageStatus = try #require(URL(string: "https://example.com/a?page=status%3D2"))
        #expect(custom.redact(url: pageStatus) == "https://example.com/a?page=status%3D2")
        let pageToken = try #require(URL(string: "https://example.com/a?page=token%3Dabc"))
        #expect(custom.redact(url: pageToken) == "https://example.com/a?page=token%3D[REDACTED]")
    }

    @Test("host only records the scheme, host and port")
    func hostOnly() throws {
        let hostOnly = Redactor(urlDetail: .hostOnly)
        #expect(hostOnly.redact(url: try #require(URL(string: "https://bob:pw@api.example.com:8443/users/42?q=1#x"))) == "https://api.example.com:8443")
        #expect(hostOnly.redact("see https://example.com/reset now") == "see https://example.com now")
        #expect(hostOnly.redact("see https://example.com/reset?code=1 now") == "see [REDACTED]")
    }

    @Test("a clean URL in text ends at white space or at one mark before it; one that is not clean cuts the text where it starts")
    func urlsInText() {
        #expect(redactor.redact("(see https://example.com/r/1) now.") == "(see https://example.com/r/1) now.")
        #expect(redactor.redact("see https://example.com/r/1.") == "see https://example.com/r/1.")
        // Two marks, or a quote, after a URL leave where it ends open.
        #expect(redactor.redact("(see https://example.com/r/1).") == "(see [REDACTED]")
        #expect(redactor.redact("(see https://example.com/r?code=1).") == "(see [REDACTED]")
        #expect(redactor.redact("url=\"https://example.com/r?code=1\" ok") == "url=\"[REDACTED]")
        #expect(redactor.redact("path=\"https://example.com/r/1\" ok") == "path=\"[REDACTED]")
        #expect(redactor.redact("path=\"https://example.com/r?code=1\" ok") == "path=\"[REDACTED]")
        #expect(redactor.redact("path=https://example.com/r?code=1 ok") == "path=[REDACTED]")
        // The allowed query parameters apply to the URL of a request, not to a URL in text.
        #expect(Redactor(allowedQueryParameters: ["code"]).redact("path=https://example.com/r?code=1 ok") == "path=[REDACTED]")
        #expect(redactor.redact("redis://:hunter2@cache.local:6379/0 up") == "[REDACTED]")
        #expect(redactor.redact("git clone https://bob:hunter2@github.com/x/y.git") == "git clone [REDACTED]")
    }

    @Test("a URL in text that is not clean cuts the text where it starts, whether it parses or not")
    func unparsed() {
        #expect(redactor.redact("go https://[::1/x?code=1 now") == "go [REDACTED]")
        #expect(redactor.redact("go https://exa%ZZmple.com/?code=1") == "go [REDACTED]")
        #expect(redactor.redact("go https://x.com:abc/?code=1") == "go [REDACTED]")
        #expect(redactor.redact("go https://example.com/%ZZ?code=1") == "go [REDACTED]")
        #expect(redactor.redact("go https://例え.jp/パス?code=1") == "go [REDACTED]")
        #expect(redactor.redact("go https://example.jp/パス now") == "go [REDACTED]")
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

    @Test("a URL with more path segments or parameters than the limits records its scheme, host and port")
    func limits() throws {
        let segments = RedactionPolicy.maximumPathSegments
        let parameters = RedactionPolicy.maximumQueryParameters
        let longest = "https://example.com:8443" + String(repeating: "/a", count: segments) + "?b=1"
        #expect(redactor.redact(url: try #require(URL(string: longest))) == "https://example.com:8443" + String(repeating: "/a", count: segments) + "?b=[REDACTED]")
        let cases = [
            "https://example.com:8443" + String(repeating: "/a", count: segments + 1),
            "https://example.com:8443/a?" + (0...parameters).map { "k\($0)=1" }.joined(separator: "&"),
            "https://example.com:8443/a" + String(repeating: ";k=1", count: parameters + 1),
            "https://example.com:8443" + String(repeating: "/pin/4831", count: segments / 2 + 1) + "?password=hunter2",
        ]
        for input in cases {
            #expect(redactor.redact(url: try #require(URL(string: input))) == "https://example.com:8443")
            #expect(redactor.redact("GET \(input) done") == "GET [REDACTED]")
        }
        let most = "https://example.com/a?" + (1...parameters).map { "k\($0)=1" }.joined(separator: "&")
        #expect(redactor.redact(url: try #require(URL(string: most))).hasSuffix("&k\(parameters)=[REDACTED]"))
    }

    @Test("a segment read once keeps its reading where it comes again, after a label or not")
    func repeatedSegments() throws {
        let url = try #require(URL(string: "https://example.com/pin/pin/users/4831/users/pin/4831/a%40b.com/a%40b.com/users"))
        #expect(redactor.redact(url: url) == "https://example.com/pin/:id/:id/4831/users/pin/:id/:id/:id/:id")
    }
}

/// The host of a URL is a key of the URL (section 6 of the redaction rules): written only when it
/// is a host name or an address in which no value detector finds anything.
@Suite("Redaction corpus: URL hosts")
struct RedactionURLHostTests {
    let redactor = Redactor()

    @Test("a host that is not a host name or an address, or holds a finding, is hidden with the rest of the URL", arguments: [
        ("myapp://password=hunter2", "myapp://[REDACTED]"), ("myapp://token;hunter2/x", "myapp://[REDACTED]"),
        ("https://my_host.local/x", "https://[REDACTED]"), ("https://4111111111111111.example.com/a", "https://[REDACTED]"),
        ("https://0123456789abcdef0123456789abcdef.example.com/", "https://[REDACTED]"), ("https://-x.example.com/", "https://[REDACTED]"),
        ("https://a..b/", "https://[REDACTED]"), ("https://[fe80::1%25en0]/x", "https://[REDACTED]"),
        ("https://xn--mnchen-3ya.de/", "https://[REDACTED]"),
    ])
    func hiddenHosts(url: String, expected: String) throws {
        #expect(redactor.redact(url: try #require(URL(string: url))) == expected)
        // In text such a URL is not clean, so the text is cut where it starts.
        #expect(redactor.redact("see \(url) now") == "see [REDACTED]")
    }

    @Test("host names and addresses are written", arguments: [
        ("https://api.example.com:8443/a", "https://api.example.com:8443/a"), ("https://127.0.0.1/x", "https://127.0.0.1/x"),
        ("https://[::1]:8080/x", "https://[::1]:8080/x"), ("https://[2001:db8::1]/", "https://[2001:db8::1]/"),
        ("file:///tmp/a", "file:///tmp/a"), ("https://localhost./", "https://localhost./"),
    ])
    func shownHosts(url: String, expected: String) throws {
        #expect(redactor.redact(url: try #require(URL(string: url))) == expected)
    }
}
