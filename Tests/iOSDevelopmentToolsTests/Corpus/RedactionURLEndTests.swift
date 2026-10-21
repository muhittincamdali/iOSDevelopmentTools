import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Where a URL in free text ends. A clean URL may be followed only by white space, a line break or
/// the end of the text, or by one of `.`, `,`, `!` and `)` and then one of those. Any other
/// character after it — a quote, a backtick, `>`, `]`, `}`, a second mark, or a `?`, `#`, `;` or
/// `:` — leaves open where the URL ends, so the text is cut where the URL starts. The tenth review
/// of this package found that a URL followed by a quote, `>`, a backtick or two marks
/// (`see https://a.example/v1/x), ok`, `x'y ok`, `x> ok`) stayed visible, and that one followed by
/// `"` was cut at the quote with the URL showing.
@Suite("Redaction corpus: where a URL in text ends")
struct RedactionURLEndTests {
    static let secret = "Qx31Sec"
    /// The marks that may end a sentence right after a clean URL.
    static let sentenceEnds = [".", ",", "!", ")"]

    /// The tenth review's inputs and the shapes around them; the secret never shows.
    static let reviewInputs = [
        "see https://a.example/v1/x), Qx31Sec", "see https://a.example/v1/x'y Qx31Sec", "see https://a.example/v1/x>y Qx31Sec",
        "see https://a.example/v1/x` Qx31Sec", "see https://a.example/v1/x> Qx31Sec", "see https://a.example/v1/x\"y Qx31Sec",
        "see <https://a.example/v1> Qx31Sec", "see https://a.example/v1/x.. Qx31Sec", "see https://a.example/v1/x] Qx31Sec",
        "see https://a.example/v1/x} Qx31Sec", "see https://example.com/it's/a#Qx31Sec", "see https://example.com/a'?Qx31Sec tail",
        "see https://example.com/a';Qx31Sec tail", "see https://example.com/a>#Qx31Sec tail", "see https://example.com/a>?Qx31Sec",
        "see https://example.com/a\"#Qx31Sec\" tail", "see https://example.com/a`#Qx31Sec` tail", "see https://example.com/a'#Qx31Sec tail",
        "see https://example.com/it's?Qx31Sec", "see https://example.com/a'b?Qx31Sec", "see https://example.com'#Qx31Sec",
        "see https://example.com/a'/b?Qx31Sec", "see https://example.com/a' #Qx31Sec", "see https://example.com/a'\n#Qx31Sec",
        "see 'https://example.com/a'#Qx31Sec", "see https://example.com/a'?api_key=Qx31Sec", "see https://example.com/a'?page=1&Qx31Sec",
        "see https://example.com/a)#Qx31Sec", "see https://example.com/a.#Qx31Sec", "see https://example.com/a.?Qx31Sec",
        "see https://example.com/a,#Qx31Sec", "see https://example.com/a!#Qx31Sec", "see https://example.com/a?#Qx31Sec",
        "see https://[::1]/#Qx31Sec", "see https://[::1]:8080/a?x=Qx31Sec", "see https://example.com/a%23Qx31Sec",
        "see https://example.com/a%3Ftoken%3DQx31Sec", "see https://user:Qx31Sec@example.com/", "see https://Qx31Sec@example.com/",
        "see https://exa_mple.com/Qx31Sec", "see https://example.com/a;jsessionid=Qx31Sec", "see https://example.com/a#access_token=Qx31Sec",
        "see https://example.com/a?page=2&token=Qx31Sec", "see https://example.com/a?page=Qx31Sec", "see https://example.com/Qx31Sec?",
        "see https://example.com/a:Qx31Sec", "see https://example.com/to ken Qx31Sec", "see https://example.com/pass word Qx31Sec",
        "see https://example.com/pwd/Qx31Sec", "(https://example.com/a)?Qx31Sec", "[docs](https://example.com/a)#Qx31Sec",
        "see https://example.com/a]#Qx31Sec", "see https://example.com/a}?Qx31Sec", "see https://example.com/a).Qx31Sec",
        "see https://example.com/a)#Qx31Sec tail", "see https://example.com/a!?Qx31Sec",
    ]

    /// Every place the inputs are read: the places of ``RedactionWrittenURLTests/places(_:)`` and
    /// of ``RedactionCutRuleTests/everyPath(_:)``, and with allowed keys.
    static func outputs(_ line: String) -> [(String, String)] {
        let allowing = Redactor(allowedQueryParameters: ["page", "q"], allowedTextKeys: ["user", "note", "page", "q"])
        let json = try! JSONSerialization.data(withJSONObject: ["note": line])
        let unprefixed = line.hasPrefix("see ") ? String(line.dropFirst(4)) : line
        return RedactionWrittenURLTests.places(unprefixed) + RedactionCutRuleTests.everyPath(line).map { ($0.path, $0.output) } + [
            ("allowed keys", allowing.redact(line)),
            ("JSON string, allowed keys", allowing.redact(body: json, contentType: "application/json")),
        ]
    }

    @Test("the review's inputs hide their secret in every place", arguments: reviewInputs)
    func reviewInputsAreHidden(input: String) {
        for (place, output) in Self.outputs(input) {
            #expect(!output.contains(Self.secret), "\(place): \(input.debugDescription) -> \(output.debugDescription)")
        }
    }

    @Test("the review's URLs that a mark or quote follows are cut where they start", arguments: [
        ("see https://a.example/v1/x), ok", "see [REDACTED]"), ("see https://a.example/v1/x'y ok", "see [REDACTED]"),
        ("see https://a.example/v1/x>y ok", "see [REDACTED]"), ("see https://a.example/v1/x` ok", "see [REDACTED]"),
        ("see https://a.example/v1/x> ok", "see [REDACTED]"), ("see https://a.example/v1/x\"y ok", "see [REDACTED]"),
        ("see <https://a.example/v1> ok", "see [REDACTED]"), ("see https://a.example/v1/x.. ok", "see [REDACTED]"),
        ("see https://a.example/v1/x] ok", "see [REDACTED]"), ("see https://a.example/v1/x} ok", "see [REDACTED]"),
        ("see https://a.example/v1/x. ok", "see https://a.example/v1/x. ok"), ("see https://a.example/v1/x! ok", "see https://a.example/v1/x! ok"),
        ("see https://a.example/v1/x) ok", "see https://a.example/v1/x) ok"), ("see https://a.example/v1/x, ok", "see https://a.example/v1/x, ok"),
    ])
    func reviewExamples(input: String, expected: String) {
        #expect(Redactor().redact(input) == expected)
    }

    static let urls = [
        "https://example.com/a", "https://example.com", "http://10.0.0.1/health", "myapp://callback/x", "https://example.com/it",
        "https://x.example/v1/items/42",
    ]
    /// What may come right after a URL and make it not clean.
    static let followers = [
        "'", "\"", "`", ">", "<", "]", "}", "?", "#", ";", ":", "=", "&", "|", "~", "*", "^", "{", "[", "\\", ").", "..", ".,", ",.",
        "!?", "!!", ".'", ")'", ".\"", ",x", "!x", ")x", "'s", "?.", ";.", ":.", "\u{00A0}", "\u{3002}", "\u{FF09}", "\u{200B}",
    ]

    @Test("a URL followed by anything but white space or one mark that ends a sentence cuts the text where it starts", arguments: followers)
    func followersCut(follower: String) {
        // Dots glued to more text are part of the URL's last segment (`/a..b`).
        let glues = follower == ".." ? ["#", "?", ";", " ", "\n"] : ["", "#", "?", ";", " ", "\n"]
        for url in Self.urls {
            for glue in glues {
                let line = "see " + url + follower + glue + Self.secret + " tail"
                #expect(Redactor().redact(line) == "see [REDACTED]", "\(line.debugDescription)")
                for (place, output) in Self.outputs(line) {
                    #expect(!output.contains(Self.secret), "\(place): \(line.debugDescription) -> \(output.debugDescription)")
                }
            }
        }
    }

    @Test("a URL followed by white space, a line break, the end of the text or one mark that ends a sentence keeps the text")
    func cleanEnds() {
        let redactor = Redactor()
        var ends = ["", " tail", "\ntail", "\r\ntail", "\ttail"]
        for mark in Self.sentenceEnds { ends += [mark, mark + " tail", mark + "\ntail"] }
        for url in Self.urls {
            for end in ends {
                let line = "see " + url + end
                #expect(redactor.redact(line) == line, "\(line.debugDescription)")
            }
        }
    }

    /// URLs with the secret after a character that may end them, and clean ones.
    static func differentialURLs() -> [String] {
        var urls: [String] = []
        for url in Self.urls {
            for follower in ["'", ">", "`", "\"", ")", ".", "!", ",", "]", "}"] {
                for glue in ["#", "?", ";", "?x=", "#a=", ";a="] { urls.append(url + follower + glue + Self.secret) }
            }
            urls += [url, url + "/" + Self.secret, url + "#" + Self.secret, url + "?q=" + Self.secret, url + ";s=" + Self.secret]
        }
        return urls
    }

    @Test("free text never shows more of a URL than redact(url:) does, and shows a clean URL as it does")
    func differentialWithRedactURL() {
        let redactor = Redactor()
        var compared = 0
        for written in Self.differentialURLs() {
            guard let url = URL(string: written) else { continue }
            compared += 1
            let structured = redactor.redact(url: url)
            let free = redactor.redact("see " + written)
            if !structured.contains(Self.secret) {
                #expect(!free.contains(Self.secret), "\(written.debugDescription): redact(url:) -> \(structured.debugDescription), text -> \(free.debugDescription)")
            }
            // Free text either cuts the URL where it starts or shows it as redact(url:) writes it.
            #expect(free == "see [REDACTED]" || free == "see " + structured, "\(written.debugDescription): \(structured.debugDescription) / \(free.debugDescription)")
        }
        #expect(compared > 300)
    }

    @Test("the last segment of a clean URL and the word after it are read as one, as two words are")
    func lastSegmentWithNextWord() {
        let redactor = Redactor()
        #expect(redactor.redact("see https://example.com/to ken Qx31Sec") == "see https://example.com/to ken [REDACTED]")
        #expect(redactor.redact("see https://to ken Qx31Sec") == "see https://to ken [REDACTED]")
        #expect(redactor.redact("see https://example.com/a/pass word Qx31Sec") == "see [REDACTED]")
        #expect(redactor.redact("see https://example.com/to day ok") == "see https://example.com/to day ok")
        #expect(redactor.redact("see https://example.com/to/ ken ok") == "see https://example.com/to/ ken ok")
    }
}
