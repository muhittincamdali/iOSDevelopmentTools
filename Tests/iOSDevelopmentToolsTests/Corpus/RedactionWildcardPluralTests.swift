import Foundation
import Testing
@testable import iOSDevelopmentTools

/// One letter that has no ASCII form, put in right after a short secret word. The seventh review
/// of the spec branch found that the match stopped as soon as the word was spelled whole: the
/// letter was read neither as the plural `s` (`tokenꞏ` for `tokens`) nor as no letter before a
/// plural `s` (`tokenꞏs`), so the word's placement failed. The guide reads one such letter as any
/// letter and counts a plural `s`, and the ASCII forms (`tokens Qx`, `/a/tokens/Qx`) were hidden.
@Suite("Redaction corpus: a wildcard where the plural s goes")
struct RedactionWildcardPluralTests {
    static let secret = "Gp001Nd4u"

    static let words = [
        "tokenꞏs", "secretꞏs", "pinꞏs", "keyꞏs", "otpꞏs", "cvvꞏs", "authꞏs", "cardꞏs", "ibanꞏs", "bearerꞏs", "pwdꞏs", "ssnꞏs",
        "tokenɑs", "tokenꞏ", "secretꞏ", "pinꞏ", "keyꞏ", "otpꞏ", "cardꞏ", "tokenǃ", "tokenı", "tokenꞌ", "tokenʔ", "tokenø",
        "tokenß", "secretß", "otpł", "TOKENꞏS", "userPinꞏs", "api_keyꞏ",
    ]

    @Test("the word is found in every place free text is read", arguments: words)
    func freeText(word: String) {
        let line = "\(word) \(Self.secret)"
        var outputs = RedactionWrittenURLTests.places(line)
        let header = RedactionPolicy.default.redact(headers: [HTTPHeader(name: "User-Agent", value: "MyApp/1.0 " + line)])[0].value
        outputs.append(("User-Agent", header))
        for (place, output) in outputs {
            #expect(!output.contains(Self.secret), "\(place): \(line.debugDescription) -> \(output.debugDescription)")
        }
    }

    @Test("the word is found as a URL segment, a record name and an allowed query value", arguments: [
        "tokenꞏ", "tokenꞏs", "keyꞏ", "pinꞏs", "otpł",
    ])
    func structured(word: String) {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let redactor = Redactor(allowedQueryParameters: ["q"])
        var outputs = [
            redactor.redact(url: URL(string: "https://x.example/a/\(encoded)/\(Self.secret)")!),
            redactor.redact(url: URL(string: "https://x.example/a?q=\(encoded)+\(Self.secret)")!),
        ]
        for json in [#"{"name":"\#(word)","note":"\#(Self.secret)"}"#, #"{"msg":"\#(word) \#(Self.secret)"}"#] {
            outputs.append(redactor.redact(body: Data(json.utf8), contentType: "application/json"))
        }
        for output in outputs {
            #expect(!output.contains(Self.secret), "\(word) -> \(output.debugDescription)")
        }
    }

    @Test("a URL segment after the word is replaced as after its ASCII plural")
    func pathSegment() {
        let redactor = Redactor()
        let ascii = redactor.redact(url: URL(string: "https://x.example/a/tokens/Qx1abc")!)
        #expect(!ascii.contains("Qx1abc"))
        for word in ["token%EA%9E%8F", "token%EA%9E%8Fs"] {
            let output = redactor.redact(url: URL(string: "https://x.example/a/\(word)/Qx1abc")!)
            #expect(!output.contains("Qx1abc"), "\(word) -> \(output)")
        }
    }

    @Test("ordinary words with a letter without an ASCII form after a short word stay readable", arguments: [
        "Kullanıcı sisteme başarıyla giriş yaptı", "kapıdaki ılgın ağaçları", "bjørn dæhlie kom hjem", "Øresund bridge",
        "keyboard ayarı açıldı", "spinner döndü", "author ılık", "tokenizer çalıştı",
    ])
    func ordinaryWords(line: String) {
        #expect(Redactor().redact(line) == line)
    }
}
