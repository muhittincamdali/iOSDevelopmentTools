import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The fifth review of the rebuilt redactor: a host that names a secret was written whole, with
/// its port, while only the path and query after it were hidden. The value can be in the host
/// itself (`myapp://password.Qz057Wk5m`, `https://pin-Qz864Wk5m.x.example`) or in the port that
/// `URLComponents` reads after it (`myapp://pin:4831`). Such a host is now recorded as the scheme
/// and `[REDACTED]`, on every path that records a URL.
@Suite("Redaction corpus: values written in a host that names a secret")
struct RedactionURLHostValueTests {
    let redactor = Redactor()

    /// The review's probes, by the set and number it gave them, and the value in each.
    static let probes: [(url: String, value: String)] = [
        ("https://pin-Qz864Wk5m.x.example/a", "Qz864Wk5m"),  // new25#864
        ("myapp://password.Qz057Wk5m", "Qz057Wk5m"),  // new22#57
        ("myapp://pin.Qz058Wk5m.example/", "Qz058Wk5m"),  // new22#58
        ("myapp://token.Qa283Zk7m/", "Qa283Zk7m"),  // a2new#283
        ("myapp://token.Qb625Zk3m", "Qb625Zk3m"),  // a3new#625
        ("https://Qx751Np7v.password.h.example/", "Qx751Np7v"),  // a-18#751
        ("https://token.Qd531Wn4p.x.example/a", "Qd531Wn4p"),
        ("https://password-Qd045Wn4p.example.com/", "Qd045Wn4p"),
        ("myapp://pin:4831/a", "4831"),
        ("myapp://pin:4831", "4831"),
        ("https://session.example.com:48311/a", "48311"),
    ]

    @Test("a probe records the scheme only, with any URL detail and allowlist", arguments: probes)
    func probe(url text: String, value: String) throws {
        let url = try #require(URL(string: text))
        let expected = try RedactionEarlierRuleTests.hiddenHost(text)
        #expect(redactor.redact(url: url) == expected)
        #expect(Redactor(urlDetail: .hostOnly).redact(url: url) == expected)
        #expect(Redactor(allowedQueryParameters: ["a"]).redact(url: url) == expected)
    }

    @Test("no path that records a URL shows the value of a probe", arguments: probes)
    func everyPath(url text: String, value: String) throws {
        let url = try #require(URL(string: text))
        let escaped = try #require(text.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
        let outputs = [
            redactor.redact(url: url),
            LoggedOutput.request(URLRequest(url: url)),
            LoggedOutput.request(URLRequest(url: url), redactor: RedactionPolicy(urlDetail: .hostOnly)),
            redactor.redact("open \(text) now"),
            redactor.redact(body: Data(#"{"u":"\#(text)"}"#.utf8), contentType: "application/json"),
            redactor.redact(body: Data("u=\(escaped)".utf8), contentType: "application/x-www-form-urlencoded"),
        ]
        for output in outputs {
            #expect(!output.contains(value), "\(text): \(output)")
        }
    }

    /// Secret names as a label of a host, with the value before or after them in the same label or
    /// in the next one, or in the port.
    @Test("no generated host that names a secret shows the value written in it")
    func generated() throws {
        let value = "Qz9W1hunter"
        let names = ["pin", "token", "password", "passwd", "pwd", "secret", "otp", "apikey", "api-key", "session", "sid", "auth",
                     "cookie", "key", "signature", "cvv", "ssn", "iban", "card", "credential", "passcode", "access-token"]
        let hosts = ["{name}.{value}", "{name}-{value}", "{value}.{name}", "{value}-{name}.example", "{name}.{value}.example.com",
                     "{value}.{name}.example.com", "x.{name}-{value}.example"]
        var shown: [String] = []
        for name in names {
            for scheme in ["myapp", "https"] {
                for host in hosts {
                    let written = host.replacingOccurrences(of: "{name}", with: name).replacingOccurrences(of: "{value}", with: value)
                    for text in ["\(scheme)://\(written)", "\(scheme)://\(written)/a?b=1", "\(scheme)://\(name):4831/a"] {
                        guard let url = URL(string: text) else { continue }
                        let output = redactor.redact(url: url)
                        if output != scheme + "://" + RedactionPolicy.replacement { shown.append("\(text) -> \(output)") }
                    }
                }
            }
        }
        #expect(shown.isEmpty, "\(shown.count) URLs show a host: \(shown.prefix(10))")
    }

    /// Hosts whose labels only start or end with a secret word, or that are addresses, are kept
    /// with their port and read on.
    @Test("a host that names no secret keeps its port, path and query names", arguments: [
        "https://keycloak.example.com:8443/realms/main", "https://pinterest.example.com/boards", "https://author.example.com/posts",
        "myapp://settings:8080/profile", "https://api.example.com/v1/items?page=[REDACTED]", "http://10.0.0.1:8080/status",
    ])
    func kept(text: String) throws {
        let url = try #require(URL(string: text.replacingOccurrences(of: "[REDACTED]", with: "2")))
        #expect(redactor.redact(url: url) == text)
    }
}
