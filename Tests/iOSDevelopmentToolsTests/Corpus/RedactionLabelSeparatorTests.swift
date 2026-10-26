import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The last review found two kinds of separator after a label outside ASCII that did not end it,
/// so the value beside the label was kept on every structured path while the ASCII twin was hidden:
/// a bracket or a quote mark with no ASCII form (`【暗証番号】`, `«Пароль»`, `Пароль“`, `ΡΙΝ⩴ `),
/// 81 leaks, and a `:` or an `=` with a mark after it (`Пароль:*`, `ΡΙΝ:)`, `Şifre=?`), 26 leaks.
/// The guide counts every punctuation mark with no ASCII form but a sentence end, a dash and `…`
/// as a separator, and a separator now ends a label when anything but a letter or a digit
/// follows it.
@Suite("Redaction corpus: separators after a label outside ASCII")
struct RedactionLabelSeparatorTests {
    private static let secret = "Lb033Pz6y"
    private typealias Corpus = RedactionLabelOutsideASCIITests

    /// The review's brackets, quote marks and connectors, and the symbols that read as more than
    /// one `:` or `=`.
    static let bracketLabels = [
        "【暗証番号】", "「パスワード」", "『暗証番号』", "«Пароль»", "Пароль»", "Введите «пароль»", "“Пароль”", "„Пароль“",
        "‹Şifre›", "⟨ΡΙΝ⟩", "❨Пароль❩", "⦅ΡΙΝ⦆", "Пароль‿", "Пароль⁀", "ΡΙΝ⩴ ", "ΡΙΝ⩵", "Şifre⩶", "Пароль≔",
    ]

    /// The review's marks after a `:` or an `=`.
    static let markLabels = [
        "Пароль:*", "Şifre:-", "Пароль:.", "Пароль:!", "Şifre:?", "Şifre:…", "Пароль:—", "ΡΙΝ:)", "パスワード：*", "Şifre=*",
        "Пароль:_", "Пароль:#",
    ]

    @Test("a bracket or a quote mark after a label outside ASCII hides the value on every path", arguments: Corpus.fields)
    func brackets(field: String) {
        let shown = Self.bracketLabels.flatMap { Self.outputs(field: field, label: $0) }.filter { $0.contains(Self.secret) }
        #expect(shown.isEmpty, "\(shown.count) shown: \(shown.prefix(5))")
    }

    @Test("a mark after a `:` or an `=` ends a label outside ASCII on every path", arguments: Corpus.fields)
    func marks(field: String) {
        let shown = Self.markLabels.flatMap { Self.outputs(field: field, label: $0) }.filter { $0.contains(Self.secret) }
        #expect(shown.isEmpty, "\(shown.count) shown: \(shown.prefix(5))")
    }

    /// The paths of the earlier suite, and a nested member, an object or an array as the value,
    /// and the logger's lines for a response and a request.
    static func outputs(field: String, label: String) -> [String] {
        let s = secret
        let json = { (text: String) in Redactor().redact(body: Data(text.utf8), contentType: "application/json") }
        var request = URLRequest(url: URL(string: "https://api.example.com/v1/items")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"\#(field)":"\#(label)","value":"\#(s)"}"#.utf8)
        return Corpus.outputs(field: field, label: label) + [
            json(#"{"fields":[{"\#(field)":"\#(label)","value":"\#(s)"}]}"#),
            json(#"{"\#(field)":"\#(label)","value":{"v":"\#(s)"}}"#),
            json(#"{"\#(field)":"\#(label)","value":["\#(s)"]}"#),
            LoggedOutput.responseBody(Data(#"{"\#(field)":"\#(label)","value":"\#(s)"}"#.utf8), contentType: "application/json"),
            LoggedOutput.request(request),
        ]
    }

    @Test("the review's probes, as written")
    func reviewProbes() {
        let s = Self.secret
        let json = { (text: String) in Redactor().redact(body: Data(text.utf8), contentType: "application/json") }
        #expect(!json(#"{"title":"【暗証番号】","value":"\#(s)"}"#).contains(s))
        #expect(!json(#"["note","«Пароль»","\#(s)"]"#).contains(s))
        #expect(!json(#"{"title":"«Пароль»","value":{"v":"\#(s)"}}"#).contains(s))
        #expect(!json(#"{"title":"Пароль:*","value":"\#(s)"}"#).contains(s))
        #expect(!Redactor().redact(body: Data("title=%C2%AB%D0%9F%D0%B0%D1%80%D0%BE%D0%BB%D1%8C%C2%BB&value=\(s)".utf8), contentType: "application/x-www-form-urlencoded").contains(s))
    }

    /// The logging guide's new examples and the limit it states, as written there.
    @Test("the guide's examples of brackets and marks read as it says")
    func guideExamples() {
        let s = Self.secret
        let json = { (text: String) in Redactor().redact(body: Data(text.utf8), contentType: "application/json") }
        #expect(!json(#"{"title":"【暗証番号】","value":"\#(s)"}"#).contains(s))
        #expect(!json(#"{"title":"ΡΙΝ:)","value":"\#(s)"}"#).contains(s))
        // The free-text rule reads the title itself; the label rule hides the member beside it.
        #expect(json(#"{"title":"«Привет»","id":7}"#).hasSuffix(#","id":"[REDACTED]"}"#))
        #expect(json(#"{"title":"「パスワード」を入力","value":"\#(s)"}"#).contains(s))
    }

    /// A separator followed by a letter or a digit is still inside the string's words, so the
    /// earlier usefulness examples keep what is beside them.
    @Test("a separator before a letter or a digit does not end a label", arguments: [
        "Saat 12:30", "Привет «мир", "Ayşe Yılmaz", "Kapitel 1 – Einleitung", "Загрузка…", "İstanbul'a", "ありがとうございます。",
    ])
    func stillWords(text: String) {
        let kept = Redactor().redact(body: Data(#"{"title":"\#(text)","id":"7"}"#.utf8), contentType: "application/json")
        #expect(kept.hasSuffix(#","id":"7"}"#), "\(text)")
    }
}
