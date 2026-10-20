import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The safe alphabet of free text (section 6 of the redaction rules): letters, marks and digits
/// of any script, white space, line breaks and ASCII are text; the first other character with
/// text after it, an escape and a word longer than 256 characters are triggers.
@Suite("Redaction: the safe alphabet of free text")
struct RedactionSafeAlphabetTests {
    let policy = RedactionPolicy.default
    static let secret = "hunter2"

    /// The text as every path that reads free text stores it: a log message, a text/plain body,
    /// a JSON string and a kept header value.
    private func stored(_ text: String) -> [String] {
        let store = LogStore(configuration: .init(systemLogSubsystem: nil))
        store.info(text)
        let json = try! JSONSerialization.data(withJSONObject: ["note": text])
        let jsonBody = String(decoding: policy.redact(body: json, contentType: "application/json").body, as: UTF8.self)
        let plain = String(decoding: policy.redact(body: Data(text.utf8), contentType: "text/plain").body, as: UTF8.self)
        let header = RedactionPolicy(allowedHeaders: ["X-Note"]).redact(headers: [HTTPHeader(name: "X-Note", value: text)])[0].value
        return [policy.redact(text: text), store.entries.first?.message ?? "", plain, jsonBody, header]
    }

    /// Punctuation marks and symbols outside ASCII, from the blocks of general punctuation, arrows,
    /// mathematical operators, technical and miscellaneous symbols, dingbats, CJK punctuation,
    /// vertical, small and full-width forms, and emoji; also those that compatibility normalization
    /// reads as ASCII (`‥`, `︰`, `＝`, `（`).
    static let unsafeScalars: [Unicode.Scalar] = {
        let blocks: [ClosedRange<UInt32>] = [
            0x00A1...0x00BF, 0x2010...0x205E, 0x2190...0x23FF, 0x2500...0x27BF, 0x2900...0x2BFF, 0x3001...0x303F,
            0xA700...0xA71F, 0xA789...0xA78A, 0xFE30...0xFE4F, 0xFE50...0xFE6B, 0xFF5F...0xFF65, 0x1F300...0x1F64F,
        ]
        return blocks.flatMap { $0 }.compactMap(Unicode.Scalar.init).filter { scalar in
            switch scalar.properties.generalCategory {
            case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation, .finalPunctuation,
                 .otherPunctuation, .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol:
                return true
            default:
                return false
            }
        }
    }()

    @Test("every punctuation mark and symbol outside ASCII hides the value after it, on every path")
    func unsafeCharacters() {
        #expect(Self.unsafeScalars.count > 2_000)
        for scalar in Self.unsafeScalars {
            let c = String(scalar)
            for text in ["user\(c)\(Self.secret)", "user\(c) \(Self.secret)", "user \(c) \(Self.secret)", "\(c)\(Self.secret)"] {
                let output = policy.redact(text: text)
                #expect(!output.contains(Self.secret), "U+\(String(scalar.value, radix: 16, uppercase: true)): \(text.debugDescription) -> \(output.debugDescription)")
            }
        }
        for text in ["user\u{2014} \(Self.secret)", "note\u{2192}\(Self.secret)", "ok \u{1F511} \(Self.secret)", "x\u{E000}\(Self.secret)", "x\u{0378}\(Self.secret)", "a\u{2800}\(Self.secret)", "ok \u{07} \(Self.secret)", "ok \u{85}x \u{9F} \(Self.secret)", "ok\u{1680}\(Self.secret)"] {
            for output in stored(text) {
                #expect(!output.contains(Self.secret), "\(text.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    // The thirteenth review of the shared rules: two dots, a vertical colon and an ellipsis that
    // compatibility normalization reads as ASCII dots were read as dots, which are text.
    @Test("a mark that compatibility normalization reads as ASCII is judged as itself", arguments: [
        "\u{FE30}", "\u{FE19}", "\u{2025}", "\u{2026}", "\u{FE13}", "\u{FF1D}", "\u{FF0C}", "\u{FF08}", "\u{FE63}", "\u{FF0D}", "\u{2122}",
    ])
    func compatibilityPunctuation(mark: String) {
        for text in ["user\(mark)Zk069Hv3m", "user\(mark) Zk069Hv3m", "ok \(mark)Zk069Hv3m", "status=200 \(mark) Zk069Hv3m"] {
            for output in stored(text) {
                #expect(!output.contains("Zk069Hv3m"), "\(text.debugDescription) -> \(output.debugDescription)")
            }
        }
    }

    @Test("letters, marks and digits of any script are text", arguments: [
        "Kullanıcı İstanbul'da giriş yaptı", "Straße naïve café", "Zaloguj się, użytkownik", "заказ 42 отправлен", "张伟 登录成功",
        "ユーザー登録", "Γειά σου κόσμε", "שלום עולם", "مرحبا بالعالم", "١٢٣ ٤٥٦", "½ cup, x² + y²", "took 120µs", "ｆｕｌｌ ｗｉｄｔｈ",
        "done \u{1F44D}", "status=200 \u{2026}", "a\u{A0}b\u{3000}c\u{2003}d",
    ])
    func safeText(text: String) {
        #expect(policy.redact(text: text) == text)
    }

    @Test("an escape in free text is a trigger where it starts and is never decoded", arguments: [
        "%41", "%u0041", "&#65;", "&#x41;", "&#65", "&amp;", "&lt;", "&hellip;", "&NotNestedGreaterGreater;", "\\101", "\\0", "\\x41", "\\u0041", "\\u{41}",
    ])
    func escapes(escape: String) {
        for text in ["ok \(escape) \(Self.secret)", "ok a\(escape)b \(Self.secret)", "\(escape)\(Self.secret)"] {
            for output in stored(text) {
                #expect(!output.contains(Self.secret), "\(text.debugDescription) -> \(output.debugDescription)")
            }
        }
        #expect(policy.redact(text: "ok a\(escape)b \(Self.secret)") == "ok a\(RedactionPolicy.replacement)")
    }

    @Test("a percent sign, an ampersand or a backslash that starts no escape is text", arguments: [
        "100% done", "50%off", "Tom & Jerry", "a&b", "&;", "path\\name", "a\\b", "%ZZ", "%4", "&#;",
    ])
    func notEscapes(text: String) {
        #expect(policy.redact(text: text) == text)
    }

    @Test("a word longer than 256 characters is a trigger where it starts")
    func opaqueWords() {
        // Letters that no detector reads as a hex or Base64 token.
        let longest = String(repeating: "word", count: FreeTextScanner.longestWord / 4)
        #expect(policy.redact(text: "ok \(longest) \(Self.secret)") == "ok \(longest) \(Self.secret)")
        for output in stored("ok \(longest)b \(Self.secret)") {
            #expect(!output.contains(Self.secret) && !output.contains(longest), "\(output.prefix(80).debugDescription)")
        }
        #expect(policy.redact(text: "ok \(longest)b \(Self.secret)") == "ok \(RedactionPolicy.replacement)")
        // The length counts the scalars of the word, an emoji or a letter of another script as one.
        #expect(policy.redact(text: String(repeating: "ı", count: 300) + " ok") == RedactionPolicy.replacement)
    }
}
