import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The review after the twenty-sixth found that a string longer than 256 characters in a member
/// that holds no name was not read at all, so the label at its end kept the value beside it:
/// 252 characters and ` PIN:` in `{"title":…,"value":…}` showed the value where 251 hid it, and
/// `{"question":"<276 characters> What is your PIN?","answer":…}` showed the answer, in JSON,
/// forms, multipart bodies and allowed query parameters alike. A string is now read at any length,
/// in one pass, its long words too.
@Suite("Redaction corpus: labels at the end of long strings")
struct RedactionLongLabelTests {
    private static let secret = "Qz27Lg5m"

    private static func json(_ text: String) -> String {
        Redactor.largeBodies.redact(body: Data(text.utf8), contentType: "application/json")
    }

    private static func form(_ text: String) -> String {
        Redactor.largeBodies.redact(body: Data(text.utf8), contentType: "application/x-www-form-urlencoded")
    }

    private static func multipart(_ fields: [(String, String)]) -> String {
        var body = ""
        for (name, value) in fields { body += "--B0und\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n" }
        return Redactor.largeBodies.redact(body: Data((body + "--B0und--").utf8), contentType: "multipart/form-data; boundary=B0und")
    }

    private static func query(_ title: String) -> String {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        return Redactor(allowedQueryParameters: ["title", "value"])
            .redact(url: URL(string: "https://api.example.com/v1/items?title=\(encoded)&value=\(secret)")!)
    }

    /// The value beside `title` on every path that reads it.
    private static func outputs(title: String) -> [String] {
        let s = secret
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        return [
            json(#"{"title":"\#(title)","value":"\#(s)"}"#),
            form("title=\(encoded)&value=\(s)"),
            multipart([("title", title), ("value", s)]),
            title.utf8.count < 6_000 ? query(title) : "",
        ]
    }

    /// Text of `length` characters in words, as a description is written.
    private static func prose(_ length: Int) -> String {
        String(String(repeating: "This form asks for a few details about you. ", count: length / 44 + 1).prefix(length))
    }

    @Test("a label at the end of a long string hides the value beside it", arguments: [251, 252, 256, 257, 300, 1_000, 10_000, 100_000])
    func longLabels(length: Int) {
        let titles = [
            String(repeating: "a", count: length) + " PIN:",
            Self.prose(length) + " PIN:",
            Self.prose(length) + " Enter PIN (4 digits)",
            String(repeating: "x", count: length) + "PIN:",
            Self.prose(length) + " ΡΙΝ:",
        ]
        let shown = titles.flatMap(Self.outputs).filter { $0.contains(Self.secret) }
        #expect(shown.isEmpty, "\(shown.count) shown")
    }

    @Test("the review's question of 276 characters hides the answer")
    func reviewQuestion() {
        let question = Self.prose(276) + " What is your PIN?"
        #expect(Self.json(#"{"question":"\#(question)","answer":"\#(Self.secret)"}"#).hasSuffix(#""answer":"[REDACTED]"}"#))
    }

    /// The name is a word longer than 256 characters, which the free-text rule hides too.
    @Test("a member that holds a name hides the value beside a long name, as before")
    func longHeldName() {
        let name = String(repeating: "a", count: 300)
        #expect(Self.json(#"{"name":"\#(name)","value":"\#(Self.secret)"}"#) == #"{"name":"[REDACTED]","value":"[REDACTED]"}"#)
        let words = String(repeating: "region ", count: 50)
        #expect(Self.json(#"{"name":"\#(words)","value":"\#(Self.secret)"}"#) == #"{"name":"\#(words)","value":"[REDACTED]"}"#)
    }

    /// Long strings that hold no label keep what is beside them: prose, a URL, Base64 and an
    /// embedded JSON document, each read in one pass. The string itself is read by the free-text
    /// rule, so only the member beside it is compared.
    @Test("long strings that name nothing keep the members beside them", arguments: [300, 5_000, 100_000])
    func usefulness(length: Int) {
        let strings = [
            Self.prose(length),
            "https://cdn.example.com/" + String(repeating: "img/", count: length / 4) + "x.png",
            String(repeating: "QUJD", count: length / 4) + "==",
            #"{\"items\":[\#(Array(repeating: #"\"a\""#, count: length / 4).joined(separator: ","))]}"#,
            String(repeating: "&a;", count: length / 3),
        ]
        for string in strings {
            let output = Self.json(#"{"description":"\#(string)","id":"7"}"#)
            #expect(output.hasSuffix(#","id":"7"}"#), "\(string.prefix(40))…")
        }
    }

    @Test("a long string of control characters and spaces hides the value beside it")
    func longBlank() {
        let blank = String(repeating: #"\n "#, count: 400)
        #expect(Self.json(#"{"title":"\#(blank)","data":"\#(Self.secret)"}"#) == #"{"title":"\#(blank)","data":"[REDACTED]"}"#)
    }
}

/// Bodies of long strings in members that hold no name, timed and measured as the other shapes
/// are: each string is read for its label at any length, and must still be read in one pass.
enum LongLabelShapes {
    private static func repeated(_ unit: String, to total: Int) -> String {
        String(repeating: unit, count: max(1, total / unit.utf8.count))
    }

    static func bodies(size: Int, redactor: Redactor) -> [TimedInput] {
        let json: @Sendable (String) -> String = { redactor.redact(body: Data($0.utf8), contentType: "application/json") }
        let form: @Sendable (String) -> String = { redactor.redact(body: Data($0.utf8), contentType: "application/x-www-form-urlencoded") }
        let shapes: [(String, @Sendable () -> String, @Sendable (String) -> String)] = [
            ("a JSON title of prose that ends in a label", {
                #"{"title":""# + repeated("This form asks for details. ", to: size - 64) + #"PIN:","value":"x"}"#
            }, json),
            ("a JSON title of one long word that ends in a label", {
                #"{"title":""# + repeated("x", to: size - 64) + #"PIN:","value":"x"}"#
            }, json),
            ("a JSON title of character references", { #"{"title":""# + repeated("&a;", to: size - 64) + #"","value":"x"}"# }, json),
            ("a JSON title of Greek words that ends in a label", {
                #"{"title":""# + repeated("ΑΒΓ ", to: size - 64) + #"ΡΙΝ:","value":"x"}"#
            }, json),
            ("a JSON title of separators after Greek letters", { #"{"title":""# + repeated("Α: ", to: size - 64) + #"","value":"x"}"# }, json),
            ("a JSON array of objects with titles of 400 characters", {
                let object = #"{"title":""# + String(repeating: "word ", count: 80) + #"","value":"x"},"#
                return "[" + repeated(object, to: size - 4) + "{}]"
            }, json),
            ("a form title of prose that ends in a label", { "title=" + repeated("word+", to: size - 32) + "PIN%3A&value=x" }, form),
        ]
        return shapes.map { name, make, run in TimedInput(testDescription: name, make: make, redact: run) }
    }
}
