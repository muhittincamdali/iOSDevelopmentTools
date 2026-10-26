import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The review after the twenty-sixth found that a label written in one script outside ASCII and
/// ended by a separator, in a member that holds no name, kept the value beside it:
/// `{"title":"ΡΙΝ:","value":…}`, `{"prompt":"Enter your pɑsswoʀd:","answer":…}`,
/// `{"ParameterKey":"tɵkɛn:","ParameterValue":…}`, `{"title":"Şifre:"}`, `{"prompt":"Пароль:"}`,
/// `{"title":"비밀번호:"}`, and the same in forms, multipart bodies and allowed query parameters:
/// 200 of 200. The same label hid its value in free text and in a member that holds a name, and
/// the label was read only for its words. A label is a key written as a value: one that is not
/// plain ASCII now hides the value beside it whatever it says, on every path.
@Suite("Redaction corpus: labels written outside ASCII")
struct RedactionLabelOutsideASCIITests {
    private static let secret = "Qz27Lb5m"

    /// The members that hold no name in which the review wrote the labels.
    static let fields = ["title", "prompt", "question", "description", "text", "ParameterKey", "Tag"]

    /// The labels of the review.
    static let reviewLabels = ["ΡΙΝ:", "pɑsswoʀd:", "Enter your pɑsswoʀd:", "tɵkɛn:", "Şifre:", "Пароль:", "비밀번호:"]

    private static func json(_ text: String) -> String {
        Redactor().redact(body: Data(text.utf8), contentType: "application/json")
    }

    private static func form(_ text: String) -> String {
        Redactor().redact(body: Data(text.utf8), contentType: "application/x-www-form-urlencoded")
    }

    private static func multipart(_ fields: [(String, String)]) -> String {
        var body = ""
        for (name, value) in fields { body += "--B0und\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n" }
        return Redactor().redact(body: Data((body + "--B0und--").utf8), contentType: "multipart/form-data; boundary=B0und")
    }

    private static func percentEncoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    }

    private static func jsonString(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Every path that reads a label beside a value: a JSON member, a form field, a multipart
    /// part, an allowed query parameter and an element of a JSON array.
    static func outputs(field: String, label: String) -> [String] {
        let s = secret
        let encoded = percentEncoded(label)
        let query = Redactor(allowedQueryParameters: [field, "value"])
        return [
            json(#"{"\#(field)":"\#(jsonString(label))","value":"\#(s)"}"#),
            json(#"[{"\#(field)":"\#(jsonString(label))","answer":"\#(s)"}]"#),
            form("\(field)=\(encoded)&value=\(s)"),
            multipart([(field, label), ("value", s)]),
            query.redact(url: URL(string: "https://api.example.com/v1/items?\(field)=\(encoded)&value=\(s)")!),
            json(#"["note","\#(jsonString(label))","\#(s)"]"#),
        ]
    }

    @Test("the review's labels hide the value beside them on every path", arguments: fields)
    func reviewProbes(field: String) {
        let shown = Self.reviewLabels.flatMap { Self.outputs(field: field, label: $0) }.filter { $0.contains(Self.secret) }
        #expect(shown.isEmpty, "\(shown)")
    }

    @Test("the review's JSON probes, as written")
    func reviewJSON() {
        let s = Self.secret
        let bodies = [
            #"{"title":"ΡΙΝ:","value":"\#(s)"}"#, #"{"title":"pɑsswoʀd:","value":"\#(s)"}"#,
            #"{"prompt":"Enter your pɑsswoʀd:","answer":"\#(s)"}"#, #"{"ParameterKey":"tɵkɛn:","ParameterValue":"\#(s)"}"#,
            #"{"title":"Şifre:","value":"\#(s)"}"#, #"{"prompt":"Пароль:","value":"\#(s)"}"#, #"{"title":"비밀번호:","value":"\#(s)"}"#,
        ]
        let shown = bodies.map(Self.json).filter { $0.contains(s) }
        #expect(shown.isEmpty, "\(shown)")
        #expect(!Self.form("title=%CE%A1%CE%99%CE%9D%3A&value=\(s)").contains(s))
    }

    /// Labels in several scripts, with the separators that read as `:` or `=` and those with no
    /// ASCII form, before white space, a line break or the end, and with a sentence before them.
    static let generatedLabels: [String] = {
        let names = ["ΡΙΝ", "Şifre", "Пароль", "비밀번호", "パスワード", "密码", "pɑsswoʀd", "Enter your pɑsswoʀd", "ＰＩＮ", "P\u{200B}IN", "Kennwort für Konto"]
        let separators = [":", ": ", " :", "=", " = ", "：", "﹕", "︓", "＝", "꞉", "∶", "⁚", "׃", "˸", ":\n", ":\u{200B}"]
        var labels: [String] = []
        for name in names {
            labels += separators.map { name + $0 }
            labels.append("Note: " + name + ": ")
            labels.append(name + ": x")
        }
        return labels
    }()

    @Test("a label outside ASCII with any separator hides the value beside it", arguments: fields)
    func generated(field: String) {
        let shown = Self.generatedLabels.flatMap { Self.outputs(field: field, label: $0) }.filter { $0.contains(Self.secret) }
        #expect(shown.isEmpty, "\(shown.count) shown: \(shown.prefix(5))")
    }

    /// Strings that are not labels, labels in printable ASCII that name nothing, and sentence
    /// ends keep what is beside them. The free-text rule still reads each string itself
    /// (`Name: Ayşe` keeps `Name:`), so only the member beside it is compared.
    @Test("strings that hold no label outside ASCII keep the members beside them", arguments: [
        "Café", "Ayşe Yılmaz", "Привет мир", "Name: Ayşe", "ありがとうございます。", "Note:", "Kapitel 1 – Einleitung", ":", "=", "Size: XL",
        "Загрузка…", "İstanbul'a", "Saat 12:30",
    ])
    func usefulness(text: String) {
        #expect(Self.json(#"{"title":"\#(text)","id":"7"}"#).hasSuffix(#","id":"7"}"#), "\(text)")
        #expect(Self.form("title=\(Self.percentEncoded(text))&id=7").hasSuffix("&id=7"), "\(text)")
        #expect(Self.json(#"["a","\#(text)","7"]"#).hasSuffix(#","7"]"#), "\(text)")
    }

    @Test("an ASCII label that carries its own value keeps the members beside it")
    func asciiSentences() {
        #expect(Self.json(#"{"title":"Error: token expired","value":"v1"}"#) == #"{"title":"Error: [REDACTED]","value":"v1"}"#)
        #expect(Self.form("title=Saat+12%3A30&id=7") == "title=Saat+12%3A30&id=7")
    }

    /// The limit the logging guide states: a dash or an ellipsis reads as ASCII, not as a
    /// separator, so a label in another language before one is read by its words, as
    /// `пароль hunter2` is in free text.
    @Test("a label before a dash is read by its words, as the guide says")
    func dashIsNoSeparator() {
        let s = Self.secret
        #expect(Self.json(#"{"title":"Пароль — ","value":"\#(s)"}"#) == #"{"title":"Пароль [REDACTED]","value":"\#(s)"}"#)
        #expect(Self.json(#"{"title":"Пароль","value":"\#(s)"}"#) == #"{"title":"Пароль","value":"\#(s)"}"#)
        #expect(Self.json(#"{"title":"Пароль:","value":"\#(s)"}"#) == #"{"title":"Пароль:","value":"[REDACTED]"}"#)
        #expect(Self.json(#"{"label":"Пароль","value":"\#(s)"}"#) == #"{"label":"Пароль","value":"[REDACTED]"}"#)
    }

    /// The examples of the logging guide, as written there.
    @Test("the guide's examples of labels written outside ASCII read as it says")
    func guideExamples() {
        let s = Self.secret
        for body in [
            #"{"title":"ΡΙΝ:","value":"\#(s)"}"#, #"{"prompt":"Enter your pɑsswoʀd:","answer":"\#(s)"}"#,
            #"{"title":"Şifre: zorunlu","value":"\#(s)"}"#, #"["note","Пароль:","\#(s)"]"#,
        ] {
            #expect(!Self.json(body).contains(s), "\(body)")
        }
        #expect(Self.json(#"{"title":"Цена: 100","id":7}"#) == #"{"title":"Цена: [REDACTED]","id":"[REDACTED]"}"#)
        #expect(Self.json(#"{"title":"Ayşe Yılmaz","id":7}"#) == #"{"title":"Ayşe Yılmaz","id":7}"#)
        #expect(Self.json(#"{"title":"Name: Ayşe","id":7}"#).hasSuffix(#""id":7}"#))
    }
}
