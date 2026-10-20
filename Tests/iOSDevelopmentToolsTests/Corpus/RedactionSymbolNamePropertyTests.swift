import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Names that are not plain ASCII written where a name is held — the value of `name`, `label`,
/// `type`, `id`, … , the first element of a pair, `name=` and `label=` in free text, an XML
/// attribute — count as secret: the value beside them never shows, on any path a JSON object
/// takes. The names are generated from symbols (So, Sk), emoji, circled, squared and
/// parenthesized letters, mathematical alphanumerics, full-width letters and words in other
/// scripts, with or without a secret word in them. Plain-ASCII names without a secret word keep
/// the value.
@Suite("Redaction corpus: symbol name property tests")
struct RedactionSymbolNamePropertyTests {
    let redactor = Redactor()

    static let holdingFields = ["name", "key", "field", "label", "type", "header", "param", "id", "k", "n", "Label", "TYPE"]
    static let words = ["password", "pin", "token", "apikey", "secret", "status", "user", "display name", "region", "count"]
    /// The first letter `a` of the styled alphabets: circled small and capital, squared, negative
    /// squared, parenthesized, mathematical bold, script and monospace, and full-width.
    static let alphabets: [UInt32] = [0x24D0, 0x24B6, 0x1F130, 0x1F170, 0x249C, 0x1D41A, 0x1D4B6, 0x1D68A, 0xFF41]
    static let symbols = ["★", "☂", "♠", "✓", "⚙", "™", "©", "°", "¨", "˜", "˚", "∞", "€", "🔑", "🔐", "😀", "👍🏽", "🇹🇷", "⌘", "↗"]
    static let otherScripts = ["Şifre", "Пароль", "パスワード", "密码", "비밀번호", "Größe", "статус", "Ünvan", "κωδικός", "סיסמה"]

    /// The fields that hold a name in records too: beside a name of theirs written in another
    /// script only the fields that carry a value are hidden (see ``WrittenName/recordFields``).
    static let recordFields: Set<String> = ["name", "type", "id"]
    static let valueFields = ["value", "input", "answer", "data"]

    /// A name with no plain-ASCII reading.
    static func name(using random: inout SeededRandom) -> String {
        switch Int.random(in: 0..<4, using: &random) {
        case 0:
            let base = alphabets.randomElement(using: &random)!
            return String(String.UnicodeScalarView(words.randomElement(using: &random)!.unicodeScalars.map { scalar in
                ("a"..."z").contains(scalar) ? Unicode.Scalar(base + scalar.value - 0x61) ?? scalar : scalar
            }))
        case 1:
            return (0..<Int.random(in: 1...4, using: &random)).map { _ in symbols.randomElement(using: &random)! }.joined()
        case 2:
            return otherScripts.randomElement(using: &random)!
        default:
            return words.randomElement(using: &random)! + symbols.randomElement(using: &random)!
        }
    }

    /// JSON objects and arrays that hold name `n` beside value `v`.
    static func jsonShapes(_ n: String, _ v: String, using random: inout SeededRandom) -> [String] {
        let field = holdingFields.randomElement(using: &random)!
        // A word in another script under `name`, `type` or `id` may be a person or a place, so
        // only a field that carries a value is hidden beside it.
        let isRecordName = recordFields.contains(field.lowercased()) && otherScripts.contains(n)
        let other = (isRecordName ? valueFields : valueFields + ["x"]).randomElement(using: &random)!
        return [
            #"{"\#(field)":"\#(n)","\#(other)":"\#(v)"}"#,
            #"[{"\#(other)":{"a":["\#(v)"]},"\#(field)":"\#(n)"}]"#,
            #"{"op":"replace","path":"/a/\#(n)","value":"\#(v)"}"#,
            #"{"headers":[["\#(n)","\#(v)"]]}"#,
        ]
    }

    /// The paths a JSON object takes: a JSON body, a text/plain body, a log line, a JSON string,
    /// a form value, an allowed query parameter and a multipart part.
    func outputs(of object: String) -> [String] {
        let encoded = object.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let string = String(data: try! JSONSerialization.data(withJSONObject: ["log": object]), encoding: .utf8)!
        let part = "--B0und\r\nContent-Disposition: form-data; name=\"blob\"\r\nContent-Type: application/json\r\n\r\n\(object)\r\n--B0und--"
        return [
            redactor.redact(body: Data(object.utf8), contentType: "application/json"),
            redactor.redact(body: Data(object.utf8), contentType: "text/plain"),
            redactor.redact("status=200 \(object) done"),
            redactor.redact(body: Data(string.utf8), contentType: "application/json"),
            redactor.redact(body: Data("data=\(encoded)".utf8), contentType: "application/x-www-form-urlencoded"),
            Redactor(allowedQueryParameters: ["data"]).redact(url: URL(string: "https://x.example/a?data=\(encoded)")!),
            redactor.redact(body: Data(part.utf8), contentType: "multipart/form-data; boundary=B0und"),
        ]
    }

    @Test("no name without a plain-ASCII reading lets the value beside it show")
    func symbolNames() {
        var random = SeededRandom(seed: 0xA1_2B_0100)
        for _ in 0..<400 {
            let name = Self.name(using: &random)
            let value = RedactionCorpusPropertyTests.value(using: &random)
            for object in Self.jsonShapes(name, value, using: &random) {
                for output in outputs(of: object) {
                    #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(object.debugDescription) -> \(output.debugDescription)")
                }
            }
            let text = [
                "label=\"\(name)\" \(value) end", "name='\(name)' \(value)", "key=\"\(name)\"\n\(value)",
                "<string name=\"\(name)\">\(value)</string>", "<field id=\"\(name)\">\n\(value)\n</field>", "<key>\(name)</key>\n<string>\(value)</string>",
            ].randomElement(using: &random)!
            for output in [redactor.redact(text), redactor.redact(body: Data(text.utf8), contentType: "text/plain")] {
                #expect(!RedactionCorpusPropertyTests.leaks(value, in: output), "\(text.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    @Test("plain-ASCII names without a secret word keep the value beside them in structured input, and in text after an allowed key")
    func plainNamesKeepValues() {
        var random = SeededRandom(seed: 0xA1_2B_0101)
        for name in ["status", "user", "display name", "region", "count", "user_id", "Content-Type", "a.b"] {
            // Without vowels, `s`, `p`, `c`, `k`, `v` and `w` the value spells no secret word.
            let value = String((0..<12).map { _ in "BDFGHJLMNRTXYZ23456789".randomElement(using: &random)! })
            let field = Self.holdingFields.randomElement(using: &random)!
            let object = #"{"\#(field)":"\#(name)","value":"\#(value)"}"#
            #expect(redactor.redact(body: Data(object.utf8), contentType: "application/json") == object)
            // The paths that read the object as JSON keep the value; on the paths that read it as
            // free text its members follow the rule for keys in text, which cuts the text.
            let all = outputs(of: object)
            for output in [all[0], all[6]] {
                #expect(output.contains(value), "\(object.debugDescription) -> \(output.debugDescription)")
            }
            #expect(Redactor(allowedTextKeys: [field, "value"]).redact("status=200 \(object) done").contains(value))
            #expect(redactor.redact(body: Data(#"[["\#(name)","\#(value)"]]"#.utf8), contentType: "application/json").contains(value))
            #expect(Redactor(allowedTextKeys: ["label"]).redact("label=\"\(name)\" \(value)").contains(value))
            #expect(!redactor.redact("label=\"\(name)\" \(value)").contains(value))
        }
    }
}
