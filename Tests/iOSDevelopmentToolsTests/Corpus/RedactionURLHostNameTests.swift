import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The sixteenth review's URL hosts: with a scheme of the app's own `URLComponents` reads the first
/// part after `//` as the host, so in `myapp://pin/4831` the host is `pin` and the path `/4831`.
/// The host was checked only for its shape, and the path was read as if nothing came before it,
/// so `redact(url:)`, the network inspector's `url` and `path`, the HAR archive and the cURL
/// command all kept `4831`, while free text cut the same URL (`open myapp://pin/4831 now` was
/// stored as `open [REDACTED]`). A host that names a secret now records the scheme, host and port
/// only, as a path that servers resolve differently does.
@Suite("Redaction corpus: URL hosts that name a secret")
struct RedactionURLHostNameTests {
    let redactor = Redactor()

    /// The URLs the review measured, each with what is recorded.
    static let measured = [
        ("myapp://pin/4831", "myapp://pin"), ("myapp://password/hunter2", "myapp://password"), ("myapp://token/abc123", "myapp://token"),
        ("myapp://session/s3cr3t", "myapp://session"), ("https://pin/4831", "https://pin"),
        ("https://auth.example.com/x/4831", "https://auth.example.com"),
    ]

    /// Secret names as hosts with a value `Qz…Wk5m` after them, in the shapes a host, its user
    /// information, its port and the path can take.
    static let probes = [
        "myapp://pin/Qz001Wk5m", "myapp://PIN/Qz002Wk5m", "myapp://otp/Qz003Wk5m", "myapp://token/Qz004Wk5m", "myapp://password/Qz005Wk5m",
        "myapp://passwd/Qz006Wk5m", "myapp://pwd/Qz007Wk5m", "myapp://secret/Qz008Wk5m", "myapp://auth/Qz009Wk5m", "myapp://oauth/Qz010Wk5m",
        "myapp://apikey/Qz011Wk5m", "myapp://api-key/Qz012Wk5m", "myapp://sessionid/Qz013Wk5m", "myapp://session/Qz014Wk5m",
        "myapp://sid/Qz015Wk5m", "myapp://cvv/Qz016Wk5m", "myapp://cvc/Qz017Wk5m", "myapp://ssn/Qz018Wk5m", "myapp://iban/Qz019Wk5m",
        "myapp://card/Qz020Wk5m", "myapp://credential/Qz021Wk5m", "myapp://credentials/Qz022Wk5m", "myapp://passcode/Qz023Wk5m",
        "myapp://reset-password/Qz024Wk5m", "myapp://password-reset/Qz025Wk5m", "myapp://user-pin/Qz026Wk5m", "myapp://pincode/Qz027Wk5m",
        "myapp://otp-code/Qz028Wk5m", "myapp://verification-code/Qz029Wk5m", "myapp://access-token/Qz030Wk5m",
        "myapp://refresh-token/Qz031Wk5m", "myapp://id-token/Qz032Wk5m", "myapp://client-secret/Qz033Wk5m", "myapp://private-key/Qz034Wk5m",
        "myapp://signature/Qz035Wk5m", "myapp://cookie/Qz036Wk5m", "myapp://key/Qz037Wk5m", "myapp://keys/Qz038Wk5m",
        "myapp://tokens/Qz039Wk5m", "myapp://pins/Qz040Wk5m", "myapp://authcode/Qz041Wk5m", "myapp://securitycode/Qz042Wk5m",
        "myapp://magic-token/Qz043Wk5m", "myapp://login-token/Qz044Wk5m", "myapp://pin/Qz045Wk5m/confirm",
        "myapp://token/Qz046Wk5m?source=mail", "myapp://pin:8080/Qz047Wk5m", "MYAPP://PIN/Qz048Wk5m", "myapp://pin./Qz049Wk5m",
        "myapp://token//Qz050Wk5m", "com.example.app://auth/Qz051Wk5m", "https://token/Qz054Wk5m", "http://pin/Qz055Wk5m",
        "myapp://pin/Qz056Wk5m/", "myapp://pin/%7BQz057Wk5m%7D", "myapp://user@pin/Qz058Wk5m", "myapp://user:pw@token/Qz059Wk5m",
        "myapp://Pin/Qz060Wk5m", "myapp://pIn/Qz061Wk5m", "myapp://p-i-n/Qz062Wk5m", "myapp://pin-code/Qz063Wk5m",
        "myapp://reset.password/Qz064Wk5m", "myapp://login.token/Qz065Wk5m", "https://auth.example.com/x/Qz066Wk5m",
        "myapp://session/Qz067Wk5m#frag", "myapp://pin/a/b/Qz068Wk5m",
    ]

    /// The scheme, host and port of a URL as `URLComponents` reads them.
    static func hostOnly(_ text: String) throws -> String {
        let components = try #require(URLComponents(string: text))
        let host = try #require(components.scheme) + "://" + (components.percentEncodedHost ?? "")
        return components.port.map { host + ":\($0)" } ?? host
    }

    /// The value of a probe.
    static func value(in text: String) throws -> String {
        let range = try #require(text.range(of: #"Qz[0-9]{3}Wk5m"#, options: .regularExpression))
        return String(text[range])
    }

    @Test("the review's URLs record the scheme and host only", arguments: measured)
    func measuredURLs(text: String, expected: String) throws {
        let url = try #require(URL(string: text))
        #expect(redactor.redact(url: url) == expected)
        #expect(RedactionPolicy.default.redactedPath(of: url).isEmpty)
        #expect(redactor.redact("open \(text) now") == "open [REDACTED]")
    }

    @Test("each probe records the scheme, host and port only, also with allowed query parameters", arguments: probes)
    func probe(text: String) throws {
        let url = try #require(URL(string: text))
        let expected = try Self.hostOnly(text)
        #expect(redactor.redact(url: url) == expected)
        #expect(RedactionPolicy(allowedQueryParameters: ["page", "source"]).redact(url: url) == expected)
        #expect(RedactionPolicy(urlDetail: .hostOnly).redact(url: url) == expected)
        #expect(RedactionPolicy.default.redactedPath(of: url).isEmpty)
    }

    @Test("the network inspector, the HAR archive and the cURL command record no value", arguments: probes)
    func inspectorAndExports(text: String) throws {
        let value = try Self.value(in: text)
        let url = try #require(URL(string: text))
        let logger = NetworkLogger()
        let id = try #require(logger.record(
            request: URLRequest(url: url), response: nil, body: nil, error: nil, startDate: Date(), endDate: Date()))
        let entry = try #require(logger.entry(id: id))
        #expect(entry.url == (try Self.hostOnly(text)))
        #expect(entry.path.isEmpty)
        #expect(entry.host.map { !$0.contains(value) } ?? true)
        #expect(!entry.curlCommand().contains(value))
        let archive = String(decoding: try HTTPArchive(entries: [entry]).jsonData(), as: UTF8.self)
        #expect(!archive.contains(value), "\(archive)")
    }

    /// The same URL in free text, a JSON string, a form value, a multipart part and a text/plain
    /// body, the paths that already hid it, against ``RedactionPolicy/redact(url:)``.
    @Test("no path shows the value of a probe, redact(url:) among them", arguments: probes)
    func everyPathHidesTheValue(text: String) throws {
        let value = try Self.value(in: text)
        let escaped = try #require(text.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
        let outputs = [
            redactor.redact(url: try #require(URL(string: text))),
            redactor.redact("open \(text) now"),
            redactor.redact(text),
            redactor.redact(body: Data(#"{"u":"\#(text)"}"#.utf8), contentType: "application/json"),
            redactor.redact(body: Data("u=\(escaped)".utf8), contentType: "application/x-www-form-urlencoded"),
            redactor.redact(
                body: Data("--B0und\r\nContent-Disposition: form-data; name=\"u\"\r\n\r\n\(text)\r\n--B0und--".utf8),
                contentType: "multipart/form-data; boundary=B0und"),
            redactor.redact(body: Data(text.utf8), contentType: "text/plain"),
        ]
        for output in outputs {
            #expect(!output.contains(value), "\(text): \(output)")
        }
    }

    /// Secret names as hosts, spelled the ways a host can be, with a scheme, user information, a
    /// port and a path of the shapes the review tried.
    @Test("no generated URL whose host names a secret shows a path segment")
    func generated() throws {
        let value = "Qz9W1hunter"
        let names = [
            "pin", "PIN", "Pin", "token", "tokens", "password", "passwd", "pwd", "secret", "auth", "oauth", "otp", "apikey", "api-key",
            "session", "sessionid", "sid", "cvv", "ssn", "iban", "card", "cookie", "key", "keys", "signature", "user-pin", "otp-code",
            "reset-password", "reset.password", "login.token", "auth.example.com", "p-i-n", "pin-code", "access-token",
        ]
        let schemes = ["myapp", "MYAPP", "com.example.app", "https", "http", "x-app+v1"]
        let authorities = ["{name}", "user@{name}", "user:pw@{name}", "{name}:8080", "{name}."]
        let paths = ["/{value}", "/{value}/", "//{value}", "/{value}/confirm", "/%7B{value}%7D", "/{value}?source=mail", "/a/{value}"]
        var shown: [String] = []
        for name in names {
            for scheme in schemes {
                for authority in authorities {
                    for path in paths {
                        let text = scheme + "://" + authority.replacingOccurrences(of: "{name}", with: name) + path.replacingOccurrences(of: "{value}", with: value)
                        guard let url = URL(string: text) else { continue }
                        if redactor.redact(url: url).contains(value) || RedactionPolicy.default.redactedPath(of: url).contains(value) {
                            shown.append(text)
                        }
                    }
                }
            }
        }
        #expect(shown.isEmpty, "\(shown.count) URLs show a value: \(shown.prefix(10))")
    }

    @Test("a host that names no secret, or is an address, keeps its path read segment by segment")
    func otherHostsStay() throws {
        let kept = [
            "myapp://callback/x", "myapp://settings/profile", "myapp://open/items/42", "https://api.example.com/users/:id/reset",
            "https://api.example.com/v1/items", "http://192.168.0.1:8080/status", "http://[::1]:8080/status",
            "https://keycloak.example.com/realms/main", "https://www.example.org/docs/intro", "file:///tmp/report.txt",
        ]
        for text in kept {
            let url = try #require(URL(string: text))
            #expect(redactor.redact(url: url) == text, "\(text)")
            #expect(RedactionPolicy.default.redactedPath(of: url) == url.path(percentEncoded: true), "\(text)")
        }
        #expect(redactor.redact(url: try #require(URL(string: "https://api.example.com/users/12345678/reset"))) == "https://api.example.com/users/:id/reset")
        #expect(redactor.redact(url: try #require(URL(string: "myapp://open/pin/4831"))) == "myapp://open/pin/:id")
        let entry = NetworkEntry(startDate: Date(), request: URLRequest(url: try #require(URL(string: "myapp://callback/x"))), body: nil, policy: .default)
        #expect(entry.url == "myapp://callback/x")
        #expect(entry.host == "callback")
        #expect(entry.path == "/x")
    }

    /// A host that is hidden is not followed by its path in the network inspector either: the
    /// path of `myapp://pin_x/4831` was kept as `/4831` while its URL was `myapp://[REDACTED]`.
    @Test("a hidden host leaves the recorded path empty", arguments: ["myapp://pin_x/4831", "https://my_host.local/pin/4831", "myapp://password=hunter2"])
    func hiddenHostLeavesNoPath(text: String) throws {
        let url = try #require(URL(string: text))
        #expect(redactor.redact(url: url).hasSuffix("://[REDACTED]"))
        #expect(RedactionPolicy.default.redactedPath(of: url).isEmpty)
    }
}
