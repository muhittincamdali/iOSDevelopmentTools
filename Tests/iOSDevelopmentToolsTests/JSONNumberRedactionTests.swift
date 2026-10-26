import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Card numbers written as JSON numbers. A review of 2.0.0 (round a-2, probes 964–987) found that a
/// card number written with an exponent was stored as it was: `{"amount":4111111111111111e0}`,
/// and `4.111111111111111E15` as Jackson and Gson write a `double`. The same value written plainly
/// was hidden. A number with an exponent is now read as the decimal it stands for.
@Suite("Redaction: JSON numbers")
struct JSONNumberRedactionTests {
    let redactor = Redactor()
    static let hidden = "\"\(RedactionPolicy.replacement)\""

    /// Every card number of the review written with an exponent, and more of the same kind.
    static let exponentCards = [
        "4111111111111111e0", "4111111111111111E0", "4111111111111111e+0", "4.111111111111111E15", "4.111111111111111e+15",
        "41111111111111110e-1", "0.4111111111111111e16", "411111111111111.1e1", "4111111111111111.00e0", "5555555555554444e0",
        "378282246310005e0", "6011111111111117E0", "-4111111111111111e0", "-4.111111111111111E15", "4111111111111111e-0",
        "4111111111111111E00", "51051051051051e2", "4111111111111111.5e0", "411111111111111110e-2",
    ]

    @Test("a card number written with an exponent is hidden whole, as a member and in an array", arguments: exponentCards)
    func exponentCard(number: String) throws {
        let member = redactor.redact(body: Data("{\"amount\":\(number),\"id\":1}".utf8), contentType: "application/json")
        #expect(member == "{\"amount\":\(Self.hidden),\"id\":1}")
        #expect(redactor.redact(body: Data("[\(number)]".utf8), contentType: "application/json") == "[\(Self.hidden)]")
        #expect(try JSONSerialization.jsonObject(with: Data(member.utf8)) is NSDictionary)
    }

    /// JSON inside a JSON string, a form value, a multipart part and a log line is read by the
    /// same parser, so its numbers are read the same way.
    @Test("a card number written with an exponent is hidden in JSON inside other text", arguments: exponentCards)
    func exponentCardInsideText(number: String) throws {
        let json = "{\"status\":\(number)}"
        let outputs = [
            redactor.redact(body: try JSONSerialization.data(withJSONObject: ["query": json]), contentType: "application/json"),
            redactor.redact(body: Data(("q=" + percentEncodedASCII(json)).utf8), contentType: "application/x-www-form-urlencoded"),
            redactor.redact(
                body: Data("--B\r\nContent-Disposition: form-data; name=\"p\"\r\nContent-Type: application/json\r\n\r\n\(json)\r\n--B--\r\n".utf8),
                contentType: "multipart/form-data; boundary=B"),
            redactor.redact("saved \(json) ok"),
        ]
        let card = Self.digits(of: number)
        for output in outputs {
            #expect(!Self.digits(of: output).contains(card.prefix(12)), "\(number) -> \(output)")
        }
    }

    @Test("a card number written without an exponent keeps its sign and its fraction", arguments: [
        ("4111111111111111", Self.hidden),
        ("-4111111111111111", "\"-\(RedactionPolicy.replacement)\""),
        ("4111111111111111.5", "\"\(RedactionPolicy.replacement).5\""),
        ("4111111111111111.0", "\"\(RedactionPolicy.replacement).0\""),
    ])
    func plainCard(number: String, expected: String) {
        #expect(redactor.redact(body: Data("{\"amount\":\(number)}".utf8), contentType: "application/json") == "{\"amount\":\(expected)}")
    }

    @Test("numbers with an exponent and without a card number or a long token are kept as written")
    func ordinaryExponents() {
        let policy = RedactionPolicy.default
        let body = Data(#"{"rate":1.5e-3,"mole":6.02214076e23,"n":1E2,"tiny":-2.5E-7,"zero":0e0,"count":12e+3,"big":1.5e20}"#.utf8)
        #expect(policy.redact(body: body, contentType: "application/json") == (body, .unchanged))
    }

    /// Written out, such a number is a run of 32 digits or more, which is hidden as a long token
    /// when it is written plainly too.
    @Test("a number whose decimal has 32 digits or more is hidden as a long token", arguments: ["1e31", "1.7976931348623157e308", "1e-32"])
    func longDecimal(number: String) {
        #expect(redactor.redact(body: Data("[\(number)]".utf8), contentType: "application/json") == "[\(Self.hidden)]")
        #expect(redactor.redact(body: Data("[1e30,1e-31]".utf8), contentType: "application/json") == "[1e30,1e-31]")
    }

    @Test("the decimal a number stands for", arguments: [
        ("4.111111111111111E15", "4111111111111111"),
        ("41111111111111110e-1", "4111111111111111"),
        ("0.4111111111111111e16", "4111111111111111"),
        ("411111111111111.1e1", "4111111111111111"),
        ("-4111111111111111e+0", "4111111111111111"),
        ("4111111111111111.00e0", "4111111111111111"),
        ("51051051051051e2", "5105105105105100"),
        ("1.5e-3", "0.0015"),
        ("-2.5E-7", "0.00000025"),
        ("0e0", "0"),
        ("0.0e5", "0"),
        ("1e999999999", "1" + String(repeating: "0", count: JSONNumber.longestPadding)),
        ("1e-99999999999999999999", "0." + String(repeating: "0", count: JSONNumber.longestPadding) + "1"),
    ])
    func plainDecimal(literal: String, expected: String) {
        let plain = JSONNumber.plainDecimal(Array(literal.unicodeScalars)).map { String(String.UnicodeScalarView($0)) }
        #expect(plain == expected)
    }

    @Test("a number without an exponent is already written as its decimal", arguments: ["12", "-1.5", "0", "4111111111111111"])
    func noExponent(literal: String) {
        #expect(JSONNumber.plainDecimal(Array(literal.unicodeScalars)) == nil)
    }

    /// Generated card numbers of 13 to 19 digits, each written with its point moved anywhere
    /// in it and an exponent that moves it back, with zeros added, either case of `e`, a sign or
    /// none and leading zeros in the exponent. `JSONSerialization` rejects some long numbers
    /// whose exponent has leading zeros (`-6.5623489847850e+0012`); the two parsers then read the
    /// body differently and it is omitted, which shows nothing either.
    @Test("generated card numbers written with an exponent never show")
    func generatedExponentCards() {
        var random = SeededRandom(seed: 0x4A53_4F4E_4E55_4D42)
        for _ in 0..<500 {
            let card = Self.cardNumber(using: &random)
            let (number, padsExponent) = Self.exponentForm(of: card, using: &random)
            for (document, expected) in [("{\"v\":\(number)}", "{\"v\":\(Self.hidden)}"), ("[1,[\(number)]]", "[1,[\(Self.hidden)]]")] {
                let output = redactor.redact(body: Data(document.utf8), contentType: "application/json")
                let isOmitted = padsExponent && output.hasPrefix("[body omitted:")
                #expect(output == expected || isOmitted, "\(card) as \(number) -> \(output)")
            }
        }
    }

    /// Digits that start with 3 to 6 and pass the Luhn check, 13 to 19 of them.
    private static func cardNumber(using random: inout SeededRandom) -> [Int] {
        var digits = [Int.random(in: 3...6, using: &random)] + (0..<Int.random(in: 11...17, using: &random)).map { _ in Int.random(in: 0...9, using: &random) }
        digits.append((0...9).first { ValueDetectorsLuhn.passes(digits + [$0]) } ?? 0)
        return digits
    }

    /// The card number written with an exponent, and whether the exponent has leading zeros.
    private static func exponentForm(of card: [Int], using random: inout SeededRandom) -> (String, Bool) {
        let text = card.map(String.init).joined()
        let point = Int.random(in: 0...card.count, using: &random)
        let zeros = String(repeating: "0", count: Int.random(in: 0...2, using: &random))
        let mantissa = switch point {
        case 0: "0." + text + zeros
        case card.count: zeros.isEmpty ? text : text + "." + zeros
        default: String(text.prefix(point)) + "." + String(text.dropFirst(point)) + zeros
        }
        let exponent = card.count - point
        let sign = exponent == 0 ? ["", "+", "-"].randomElement(using: &random)! : ["", "+"].randomElement(using: &random)!
        let leadingZeros = String(repeating: "0", count: Int.random(in: 0...2, using: &random))
        let minus = Bool.random(using: &random) ? "-" : ""
        return (minus + mantissa + ["e", "E"].randomElement(using: &random)! + sign + leadingZeros + String(exponent), !leadingZeros.isEmpty)
    }

    private static func digits(of text: String) -> String {
        String(text.unicodeScalars.filter { ("0"..."9").contains($0) }.map(Character.init))
    }
}
