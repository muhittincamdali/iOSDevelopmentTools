import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The one wildcard rule of the redaction spec (section 0): one letter, mark or number with no
/// ASCII form inside an ASCII word stands for any one letter or for none. The sixteenth review
/// found two kinds of such a character that the matcher did not read as a letter: a combining mark
/// written in place of a letter (`t\u{0366}ken`, `p\u{0365}n`, `s\u{0364}cret`), which the scanned
/// text leaves out, and a number without an ASCII form (`passw\u{3007}rd`, U+3007 in place of the
/// `o`). Both showed the value after them in free text, JSON strings, forms, multipart parts,
/// plain-text bodies and URL paths.
@Suite("Redaction corpus: one wildcard")
struct RedactionOneWildcardTests {
    static let secret = "Yk017Wq7z"

    /// The review's names, and more of the same kinds.
    static let names = [
        "t\u{0366}ken", "p\u{0365}n", "passw\u{0366}rd", "s\u{0364}cret", "p\u{0301}ssword", "toke\u{0366}", "\u{0366}token",
        "passw\u{3007}rd", "t\u{3007}ken", "api_k\u{0364}y", "Authoriz\u{0363}tion", "pass\u{16EE}word", "c\u{0368}v",
    ]

    @Test("a name with one such character hides what follows it, in every place free text is read", arguments: names)
    func freeText(name: String) {
        let line = "\(name) \(Self.secret)"
        var outputs = RedactionWrittenURLTests.places(line)
        let header = RedactionPolicy.default.redact(headers: [HTTPHeader(name: "User-Agent", value: "MyApp/1.0 " + line)])[0].value
        outputs.append(("User-Agent", header))
        outputs.append(("status", Redactor().redact("status=200 " + line)))
        for (place, output) in outputs {
            #expect(!output.contains(Self.secret), "\(place): \(line.debugDescription) -> \(output.debugDescription)")
        }
    }

    @Test("such a name as a URL path segment hides the segment after it", arguments: names)
    func pathSegment(name: String) throws {
        let encoded = try #require(name.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
        for text in ["https://x.example/\(encoded)/\(Self.secret)", "https://x.example/user/\(encoded)/\(Self.secret)/info"] {
            let url = try #require(URL(string: text))
            #expect(!Redactor().redact(url: url).contains(Self.secret), "\(text)")
            #expect(!RedactionPolicy.default.redactedPath(of: url).contains(Self.secret), "\(text)")
            #expect(!Redactor().redact("GET \(text) done").contains(Self.secret), "\(text)")
        }
    }

    // Section 5 of the spec: a path segment that is not plain ASCII once decoded is a label, as
    // a field name is, so the segment after it is a value.
    @Test("a path segment that is not plain ASCII once decoded makes the next one :id", arguments: [
        ("/caf%C3%A9/menu", "/caf%C3%A9/:id"), ("/%C5%9Eifre/1234", "/%C5%9Eifre/:id"), ("/p%D0%B0ssword/x", "/:id/:id"),
        ("/%F0%9F%94%91/x", "/%F0%9F%94%91/:id"), ("/a+b/c", "/a+b/:id"), ("/@me/posts", "/@me/:id"), ("/-/x", "/-/:id"),
        ("/v1/t%CD%A6ken/x/y", "/v1/t%CD%A6ken/:id/y"),
    ])
    func notPlainSegment(path: String, expected: String) throws {
        let url = try #require(URL(string: "https://h.example\(path)"))
        #expect(Redactor().redact(url: url) == "https://h.example\(expected)")
    }

    @Test("plain segments keep the segment after them", arguments: [
        "/v1/users/me/settings", "/files/report-final.pdf/download", "/2026-10-21/report", "/en_US/help/topics", "/a b/c",
    ])
    func plainSegments(path: String) throws {
        let encoded = try #require(path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed))
        let url = try #require(URL(string: "https://h.example\(encoded)"))
        #expect(Redactor().redact(url: url) == "https://h.example\(encoded)")
    }

    /// Characters with no ASCII form that stand for a letter: combining Latin letters and other
    /// marks, letters and numbers of other scripts that read as no ASCII.
    static let wildcards: [Unicode.Scalar] = Array((0x0300...0x036F).compactMap(Unicode.Scalar.init))
        + ["\u{0251}", "\u{0131}", "\u{A78F}", "\u{0280}", "\u{025B}", "\u{00F8}", "\u{3007}", "\u{16EE}", "\u{2185}", "\u{0E31}"]

    /// A secret name with one of its letters replaced by a wildcard, or with one put in.
    static func disguised(using random: inout SeededRandom) -> String {
        let name = Array(["password", "token", "secret", "pin", "api_key", "passwd", "cvv", "otp", "session", "signature"]
            .randomElement(using: &random)!.unicodeScalars)
        let wildcard = wildcards.randomElement(using: &random)!
        let index = Int.random(in: 0..<name.count, using: &random)
        var scalars = name
        if Bool.random(using: &random), name[index].properties.isAlphabetic {
            scalars[index] = wildcard
        } else {
            scalars.insert(wildcard, at: index + 1)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    @Test("no value after a name with one wildcard shows, in text, a JSON string, a form and a URL path", arguments: 0..<4)
    func property(seed: Int) throws {
        var random = SeededRandom(seed: 0x17_0000 + UInt64(seed))
        let redactor = Redactor()
        for _ in 0..<600 {
            let name = Self.disguised(using: &random)
            let value = RedactionCorpusPropertyTests.value(using: &random)
            let line = "\(name) \(value)"
            let json = String(decoding: try JSONSerialization.data(withJSONObject: ["note": line]), as: UTF8.self)
            let encoded = try #require(name.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
            let outputs = [
                redactor.redact(line), redactor.redact("status=200 " + line),
                redactor.redact(body: Data(json.utf8), contentType: "application/json"),
                redactor.redact(body: Data(("note=" + RedactionPolicy.formEncoded(line)).utf8), contentType: "application/x-www-form-urlencoded"),
                redactor.redact(url: try #require(URL(string: "https://x.example/\(encoded)/\(value)"))),
            ]
            for output in outputs {
                #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(line.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    @Test("words with marks on their letters and numbers outside ASCII stay readable", arguments: [
        "Jose\u{0301} Pin\u{0303}a cafe\u{0301} nai\u{0308}ve", "Nguye\u{0302}\u{0303}n Va\u{0306}n", "Kullanıcı sisteme başarıyla giriş yaptı",
        "Ayşe ılgın", "bjørn dæhlie kom hjem", "\u{3007} items", "Ångström and Zürich",
    ])
    func ordinaryWords(line: String) {
        #expect(Redactor().redact(line) == line)
    }
}
