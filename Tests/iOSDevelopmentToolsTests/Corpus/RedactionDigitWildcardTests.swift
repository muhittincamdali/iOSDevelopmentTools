import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A decimal digit of another script in a secret name is the one wildcard of section 0 of the
/// redaction spec. The eighteenth review of this package put such a digit, which has no ASCII form,
/// in place of one letter of a name (`t၀ken` with a Myanmar zero, `p١n` with an Arabic-Indic one,
/// `c๐okie` with a Thai zero, `passw०rd` with a Devanagari zero) or into it (`to၀ken`, `pi၀n`). The
/// scanned text reads every decimal digit as its ASCII digit, for numbers and the value detectors,
/// and a word read that digit too: `t၀ken` was `t0ken`, which names nothing. The value after it
/// showed in free text, a log line, JSON strings, forms, multipart text parts, an allowed query
/// value and the `User-Agent` header, and beside a name written as a value.
@Suite("Redaction corpus: digits of other scripts as the wildcard")
struct RedactionDigitWildcardTests {
    static let secret = "Yk019Wq7z"

    /// A zero or a one of 20 scripts: Myanmar, Devanagari, Arabic-Indic, Extended Arabic-Indic,
    /// Bengali, Thai, Lao, Khmer, Mongolian, Oriya, Gujarati, Gurmukhi, Tamil, Telugu, Kannada,
    /// Malayalam, Tibetan, NKo, Osmanya and Adlam.
    static let digits: [Unicode.Scalar] = [
        "\u{1040}", "\u{0966}", "\u{0660}", "\u{0661}", "\u{06F1}", "\u{09E6}", "\u{0E50}", "\u{0ED0}", "\u{17E0}", "\u{1810}",
        "\u{0B66}", "\u{0AE6}", "\u{0A66}", "\u{0BE6}", "\u{0C66}", "\u{0CE6}", "\u{0D66}", "\u{0F20}", "\u{07C0}", "\u{104A0}",
        "\u{1E950}",
    ]

    /// Names with `{D}` in place of one of their letters or put into them.
    static let shapes = [
        "t{D}ken", "p{D}n", "c{D}okie", "passw{D}rd", "sessi{D}n", "cre{D}ential", "to{D}ken", "pi{D}n", "{D}tp", "api_k{D}y",
        "t{D}ken{D}",
    ]

    static func names(_ digit: Unicode.Scalar) -> [String] {
        shapes.map { $0.replacingOccurrences(of: "{D}", with: String(digit)) }
    }

    @Test("a name with a digit of another script hides what follows it, in every place free text is read", arguments: digits)
    func freeText(digit: Unicode.Scalar) throws {
        for name in Self.names(digit) {
            let line = "login \(name) \(Self.secret)"
            var outputs = RedactionWrittenURLTests.places(line)
            let header = RedactionPolicy.default.redact(headers: [HTTPHeader(name: "User-Agent", value: "MyApp/1.0 " + line)])[0].value
            outputs.append(("User-Agent", header))
            let query = try #require(URL(string: "https://x.example/a?page=" + RedactionPolicy.formEncoded(line)))
            outputs.append(("query value", Redactor(allowedQueryParameters: ["page"]).redact(url: query)))
            for (place, output) in outputs {
                #expect(!output.contains(Self.secret), "\(place): \(line.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    @Test("a name with a digit of another script written as a value hides the value beside it", arguments: digits)
    func nameAsValue(digit: Unicode.Scalar) {
        let redactor = Redactor()
        for name in Self.names(digit) {
            let bodies = [
                "{\"name\":\"\(name)\",\"note\":\"\(Self.secret)\"}", "{\"title\":\"\(name)\",\"value\":\"\(Self.secret)\"}",
                "{\"ParameterKey\":\"\(name)\",\"ParameterValue\":\"\(Self.secret)\"}", "[\"a\",\"\(name)\",\"\(Self.secret)\"]",
                "{\"msg\":\"login \(name) \(Self.secret)\"}",
            ]
            for body in bodies {
                let output = redactor.redact(body: Data(body.utf8), contentType: "application/json")
                #expect(!output.contains(Self.secret), "\(body.debugDescription) -> \(output.debugDescription)")
            }
            let form = "title=" + RedactionPolicy.formEncoded(name) + "&value=" + Self.secret
            let formOutput = redactor.redact(body: Data(form.utf8), contentType: "application/x-www-form-urlencoded")
            #expect(!formOutput.contains(Self.secret), "\(form.debugDescription) -> \(formOutput.debugDescription)")
        }
    }

    @Test("numbers written in digits of other scripts stay readable", arguments: [
        "price \u{0661}\u{0662}\u{0663} ok", "order \u{0664}\u{0665}\u{0666}\u{0667}\u{0668}\u{0669} shipped", "count \u{1041}\u{1042} items",
        "v\u{0661}.\u{0662} ok", "status=\u{0662}\u{0660}\u{0660} ok", "\u{0967}\u{0968}\u{0969} \u{0E51}\u{0E52} \u{09E7}\u{09E8}",
    ])
    func numbersStayReadable(line: String) {
        #expect(Redactor().redact(line) == line)
    }

    @Test("a card number in Arabic-Indic digits is still found")
    func cardNumber() {
        let card = "\u{0664}\u{0661}\u{0661}\u{0661} \u{0661}\u{0661}\u{0661}\u{0661} \u{0661}\u{0661}\u{0661}\u{0661} \u{0661}\u{0661}\u{0661}\u{0661}"
        let output = Redactor().redact("card \(card) ok")
        #expect(output.hasPrefix("card [REDACTED]") && !output.contains("\u{0661}"), "\(output.debugDescription)")
    }

    /// A digit that decomposes to an ASCII digit is that digit, as the guide says: `passw０rd` reads
    /// as `passw0rd`, which names nothing.
    @Test("a digit with an ASCII form is read as its digit", arguments: ["passw\u{FF10}rd", "passw\u{1D7CE}rd", "passw\u{1FBF0}rd"])
    func digitWithASCIIForm(name: String) {
        #expect(Redactor().redact("login \(name) \(Self.secret)").contains(Self.secret))
    }

    /// The table of four ranges is the compatibility decomposition: every decimal digit outside
    /// ASCII has no ASCII form, apart from the ones in it.
    @Test("the digits without an ASCII form are the ones whose decomposition is not ASCII")
    func digitsWithoutASCIIForm() {
        var count = 0
        for value in UInt32(0x80)...0x10FFFF {
            guard let scalar = Unicode.Scalar(value), ScalarClass.decimalDigit(scalar) != nil else { continue }
            let form = String(scalar).decomposedStringWithCompatibilityMapping.unicodeScalars
            let hasASCIIForm = form.allSatisfy(\.isASCII)
            #expect(ScalarClass.isDigitWithoutASCIIForm(scalar) == !hasASCIIForm, "U+\(String(value, radix: 16, uppercase: true))")
            if !hasASCIIForm { count += 1 }
        }
        #expect(count > 500)
    }
}
