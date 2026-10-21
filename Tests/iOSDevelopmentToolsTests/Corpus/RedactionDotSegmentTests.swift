import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Dot segments in a recorded URL: a path that servers resolve differently from how it is written
/// (RFC 3986 §5.2.4) is recorded as its scheme and host only, so the segment after a secret name
/// cannot hide behind `.`, `..`, `%2E`, a `;` (raw or `%3B`) or a double escape. No parameter after
/// a `;` is parsed.
@Suite("Redaction corpus: dot segments in URLs")
struct RedactionDotSegmentTests {
    let redactor = Redactor()

    /// The review's paths, in which the value after a secret name kept its place after a segment
    /// that reset the rule that makes it `:id` (`/v1/pin/./4831` was stored as
    /// `/v1/pin/:id/4831`), and other spellings of the same segments.
    static let paths = [
        "/v1/pin/./4831", "/password/./hunter2Zq", "/token/%2E/hunter2Zq", "/token/%2e/hunter2Zq", "/token/%2E%2e/hunter2Zq",
        "/token/;/hunter2Zq", "/token/;x=1/hunter2Zq", "/token/.;/hunter2Zq", "/token/..;x/hunter2Zq", "/token/x/../hunter2Zq",
        "/token/./././hunter2Zq", "/token/%252E/hunter2Zq", "/token/%2525/hunter2Zq", "/token/%25%32%45/hunter2Zq", "/./token/hunter2Zq",
        "/a/b/..", "/a/.",
    ]

    /// Paths with a `;` anywhere, raw or as `%3B` in either case. The review of the 14th round
    /// found matrix parameters still parsed (`/a;jsessionid=X/x` was stored as
    /// `/a;jsessionid=[REDACTED]/x`, `/pin;x/4831` as `/pin;[REDACTED]/:id`) and `%3B` not
    /// checked at all (`/a%3Bb/c` was stored as it is).
    static let semicolonPaths = [
        "/a;jsessionid=X/x", "/users;id=7", "/pin;x/4831", "/a%3Bb/c", "/a%3bb/c", "/token;v=1/X", "/cart;jsessionid=abc/view",
        "/shop;jsessionid=ABC123/cart", "/x;x=1", "/;x=1", "/a;", "/a;/b", "/token%3B/hunter2Zq", "/pin%3bv=1/4831",
        "/v1/users/12345678;v=2/orders", "/a/b;c=d;e=f/g",
    ]

    @Test("a path with a dot segment, a `;` or a double escape is recorded as scheme and host only", arguments: paths + semicolonPaths)
    func hostOnly(path: String) throws {
        let url = try #require(URL(string: "https://h.example:8443\(path)?page=2#f"))
        #expect(redactor.redact(url: url) == "https://h.example:8443")
        #expect(RedactionPolicy.default.redactedPath(of: url).isEmpty)
        // The network inspector records the same.
        let entry = NetworkEntry(startDate: Date(), request: URLRequest(url: url), body: nil, policy: .default)
        #expect(entry.url == "https://h.example:8443")
        #expect(entry.host == "h.example")
        #expect(entry.path.isEmpty)
    }

    @Test("`URL.standardized` resolves the review's paths to the segment after the name")
    func serversResolveThem() throws {
        let url = try #require(URL(string: "https://h.example/v1/pin/./4831"))
        #expect(url.standardized.path() == "/v1/pin/4831")
        let parent = try #require(URL(string: "https://h.example/token/x/../4831"))
        #expect(parent.standardized.path() == "/token/4831")
    }

    @Test("paths without dot segments are read as before", arguments: [
        ("/v1/pin/4831", "/v1/pin/:id"), ("/v1/items.json", "/v1/items.json"), ("/a//b", "/a//b"), ("/.../x", "/.../x"),
        ("/a.b/c..d", "/a.b/c..d"), ("/token//4831", "/token//:id"), ("/v1/users/12345678/orders", "/v1/users/:id/orders"),
        ("/50%25off", "/50%25off"), ("/a%2Cb", "/a%2Cb"),
    ])
    func otherPaths(path: String, expected: String) throws {
        let url = try #require(URL(string: "https://h.example\(path)"))
        #expect(redactor.redact(url: url) == "https://h.example\(expected)")
    }

    @Test("a clean URL with a dot segment in free text is cut where it starts")
    func dotSegmentsInText() {
        #expect(redactor.redact("see https://h.example/v1/status/./4831 ok") == "see [REDACTED]")
        #expect(redactor.redact("see https://h.example/v1/a/../b ok") == "see [REDACTED]")
        #expect(redactor.redact("see https://h.example/v1/items ok") == "see https://h.example/v1/items ok")
    }
}
