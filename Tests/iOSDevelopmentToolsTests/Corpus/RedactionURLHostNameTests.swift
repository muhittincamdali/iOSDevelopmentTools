import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The twenty-second review's URL probes: in a URL with a scheme of the app's own, `URLComponents`
/// reads the first part after `//` as the host, so in `myapp://pin/4831` the host is `pin` and the
/// path `/4831`. The path was read as if nothing came before it, and the segment after the host
/// showed, while free text, JSON, forms and multipart bodies hid it. A later review found the value
/// in the host itself (`myapp://password.Qz057Wk5m`, `https://pin-Qz864Wk5m.x.example`) and in the
/// port (`myapp://pin:4831`), which were written with the host. A host that names a secret is now
/// recorded as the scheme and `[REDACTED]`, with nothing after it.
@Suite("Redaction corpus: URL hosts that name a secret")
struct RedactionURLHostNameTests {
    let redactor = Redactor()

    /// The probes of the review (1 to 55, 740 to 765), each with its own value `Qz…Wk5m`.
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
        "myapp://token//Qz050Wk5m", "com.example.app://auth/Qz051Wk5m", "myapp://pin/Qz053Wk5m", "https://token/Qz054Wk5m",
        "http://pin/Qz055Wk5m", "myapp://pin/Qz740Wk5m/", "myapp://pin/%7BQz741Wk5m%7D", "myapp://user@pin/Qz743Wk5m",
        "myapp://token/Qz744Wk5m/", "myapp://token/%7BQz745Wk5m%7D", "myapp://user@token/Qz747Wk5m", "myapp://password/Qz748Wk5m/",
        "myapp://password/%7BQz749Wk5m%7D", "myapp://user@password/Qz751Wk5m", "myapp://otp/Qz752Wk5m/", "myapp://otp/%7BQz753Wk5m%7D",
        "myapp://user@otp/Qz755Wk5m", "myapp://secret/Qz756Wk5m/", "myapp://secret/%7BQz757Wk5m%7D", "myapp://user@secret/Qz759Wk5m",
        "myapp://Pin/Qz760Wk5m", "myapp://pIn/Qz761Wk5m", "myapp://p-i-n/Qz762Wk5m", "myapp://pin-code/Qz763Wk5m",
        "myapp://reset.password/Qz764Wk5m", "myapp://login.token/Qz765Wk5m",
    ]

    /// The value of a probe.
    static func value(in text: String) throws -> String {
        let range = try #require(text.range(of: #"Qz[0-9]{3}Wk5m"#, options: .regularExpression))
        return String(text[range])
    }

    @Test("each probe records the scheme only, also with allowed query parameters", arguments: probes)
    func probe(text: String) throws {
        let url = try #require(URL(string: text))
        let expected = try RedactionEarlierRuleTests.hiddenHost(text)
        #expect(redactor.redact(url: url) == expected)
        #expect(Redactor(allowedQueryParameters: ["page", "source"]).redact(url: url) == expected)
        #expect(Redactor(urlDetail: .hostOnly).redact(url: url) == expected)
    }

    /// The same URL in free text, a JSON string, a form value, a multipart part and a text/plain
    /// body, the paths that already hid it, against ``Redactor/redact(url:)``.
    @Test("no path shows the value of a probe, redact(url:) among them", arguments: probes)
    func everyPathHidesTheValue(text: String) throws {
        let value = try Self.value(in: text)
        let escaped = text.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let outputs = [
            redactor.redact(url: try #require(URL(string: text))),
            redactor.redact("open \(text) now"),
            redactor.redact(text),
            redactor.redact(body: Data(#"{"u":"\#(text)"}"#.utf8), contentType: "application/json"),
            redactor.redact(body: Data("u=\(escaped)".utf8), contentType: "application/x-www-form-urlencoded"),
            redactor.redact(body: Data("--B0und\r\nContent-Disposition: form-data; name=\"u\"\r\n\r\n\(text)\r\n--B0und--".utf8), contentType: "multipart/form-data; boundary=B0und"),
            redactor.redact(body: Data(text.utf8), contentType: "text/plain"),
        ]
        for output in outputs {
            #expect(!output.contains(value), "\(text): \(output)")
        }
    }

    /// Secret names as hosts, spelled the ways a host can be, with a scheme, user info, a port and
    /// a path of the shapes the review tried.
    @Test("no generated URL whose host names a secret shows a path segment")
    func generated() throws {
        let value = "Qz9W1hunter"
        let names = ["pin", "PIN", "Pin", "token", "tokens", "password", "passwd", "pwd", "secret", "auth", "oauth", "otp", "apikey", "api-key",
                     "session", "sessionid", "sid", "cvv", "ssn", "iban", "card", "cookie", "key", "keys", "signature", "user-pin", "otp-code",
                     "reset-password", "reset.password", "login.token", "auth.example.com", "p-i-n", "pin-code", "access-token"]
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
                        if redactor.redact(url: url).contains(value) { shown.append(text) }
                    }
                }
            }
        }
        #expect(shown.isEmpty, "\(shown.count) URLs show a value: \(shown.prefix(10))")
    }

    @Test("a host that names no secret, or is an address, keeps its path read segment by segment")
    func otherHostsStay() throws {
        let kept = [
            "myapp://settings/profile", "myapp://open/items/42", "https://api.example.com/users/:id/reset",
            "https://api.example.com/v1/items", "http://192.168.0.1:8080/status", "http://[::1]:8080/status", "https://keycloak.example.com/realms/main",
            "file:///tmp/report.txt",
        ]
        for text in kept {
            let url = try #require(URL(string: text))
            #expect(redactor.redact(url: url) == text, "\(text)")
            #expect(RedactionPolicy.default.redactedPath(of: url) == url.path(percentEncoded: true), "\(text)")
        }
        #expect(redactor.redact(url: try #require(URL(string: "https://api.example.com/users/12345678/reset"))) == "https://api.example.com/users/:id/reset")
        #expect(redactor.redact(url: try #require(URL(string: "myapp://open/pin/4831"))) == "myapp://open/pin/:id")
        // The network inspector records the host and path of such a URL apart.
        let entry = NetworkEntry(startDate: Date(), request: URLRequest(url: try #require(URL(string: "myapp://callback/x"))), body: nil, policy: .default)
        #expect(entry.url == "myapp://callback/x")
        #expect(entry.host == "callback")
        #expect(entry.path == "/x")
        #expect(redactor.redact(url: try #require(URL(string: "https://api.example.com:8443/v1/items"))) == "https://api.example.com:8443/v1/items")
        // A host that names a secret is hidden whole, by design: `auth` is a secret name.
        #expect(redactor.redact(url: try #require(URL(string: "https://auth.example.com/oauth/authorize?client_id=x"))) == "https://[REDACTED]")
    }
}
