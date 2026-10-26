import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A label written as a sentence in a member that holds no name (`question`, `prompt`, `title`,
/// `text`, `ParameterKey`, `setting`, `Tag`, `variable`) kept the value beside it when the
/// sentence held punctuation, a quote or a bracket: `{"question":"What's your PIN?","answer":…}`
/// showed the answer, while `What is your PIN?` hid it. The review found 108 such values on JSON,
/// form, multipart, query, logger and `curl` paths. An apostrophe between letters is now part of
/// a word, and a sentence names a secret when a secret word in it has no value written after it,
/// as a label has none (see ``WrittenName/Shape/sentence``).
@Suite("Redaction corpus: labels written as sentences")
struct RedactionSentenceLabelTests {
    private static let secret = "Qb7Zk3m"

    static let labels = [
        "What's your PIN?", "Enter PIN (4 digits)", "PIN, 4 digits", "PIN: required", "Password; again",
        "\"Password\" field", "Password [required]", "Password {required}", "Password <required>", "Password = new",
        "Password (min. 8 characters)", "Your password, please", "What's your password?", "Kart CVV (3 hane)",
        "API key (prod)", "Token: paste here", "Kartın CVV'si", "PIN'in", "DbPassword (prod)", "Db Password, prod",
        "prod:DbPassword", "api_token[0]", "secrets['API_TOKEN']", "env(\"API_TOKEN\")", "aws:secret-access-key",
        "Password\u{2028}(required)", "Don't share your token", "Password, again", "PIN:", "[PIN]",
        "Password (required)", "Password: required", "What is your PIN?",
    ]

    static let fieldPairs = [
        ("question", "answer"), ("prompt", "response"), ("title", "value"), ("text", "input"),
        ("ParameterKey", "ParameterValue"), ("setting", "value"), ("Tag", "Value"), ("variable", "val"),
    ]

    private static func quoted(_ text: String) -> String {
        String(decoding: try! JSONEncoder().encode(text), as: UTF8.self)
    }

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

    private static func percentEncoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved)!
    }

    private static func multipart(_ fields: [(String, String)]) -> String {
        fields.map { "--B0und\r\nContent-Disposition: form-data; name=\"\($0.0)\"\r\n\r\n\($0.1)\r\n" }.joined() + "--B0und--"
    }

    /// Every way the label and the value beside it reach a log: a JSON, form and multipart body, a
    /// JSON object in an array and in a string, a URL query with the value allowed, and the
    /// logger's line and `curl` command for a JSON request.
    private static func outputs(label: String, field: String, valueField: String) -> [String] {
        let redactor = Redactor()
        let s = secret
        let object = "{\(quoted(field)):\(quoted(label)),\(quoted(valueField)):\(quoted(s))}"
        var request = URLRequest(url: URL(string: "https://api.example.com/f")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(object.utf8)
        let query = "https://x.example/f?\(field)=\(percentEncoded(label))&\(valueField)=\(s)"
        return [
            redactor.redact(body: Data(object.utf8), contentType: "application/json"),
            redactor.redact(body: Data("{\"form\":{\"fields\":[\(object)]}}".utf8), contentType: "application/json"),
            redactor.redact(body: Data("{\"data\":\(quoted(object))}".utf8), contentType: "application/json"),
            redactor.redact(body: Data("\(field)=\(percentEncoded(label))&\(valueField)=\(s)".utf8), contentType: "application/x-www-form-urlencoded"),
            redactor.redact(body: Data(multipart([(field, label), (valueField, s)]).utf8), contentType: "multipart/form-data; boundary=B0und"),
            Redactor(allowedQueryParameters: [valueField]).redact(url: URL(string: query)!),
            LoggedOutput.request(request),
        ]
    }

    @Test("a label written as a sentence hides the value beside it on every path", arguments: labels)
    func sentenceLabels(label: String) {
        var shown: [String] = []
        for (field, valueField) in Self.fieldPairs {
            shown += Self.outputs(label: label, field: field, valueField: valueField).filter { $0.contains(Self.secret) }
        }
        #expect(shown.isEmpty, "\(label.debugDescription): \(shown)")
    }

    @Test("a sentence whose secret word has a value after it, or that names no secret, keeps the members beside it", arguments: [
        (#"{"msg":"Error: token expired","user":"bob"}"#, #"{"msg":"Error: [REDACTED]","user":"bob"}"#),
        (#"{"error":"Error: invalid PIN 1234","user":"bob"}"#, #"{"error":"Error: [REDACTED]","user":"bob"}"#),
        (#"{"msg":"Error: pin","user":"bob"}"#, #"{"msg":"Error: [REDACTED]","user":"bob"}"#),
        (#"{"note":"pin=1234, retry","user":"bob"}"#, #"{"note":"pin=[REDACTED]","user":"bob"}"#),
        (#"{"text":"invalid, token\nretry","color":"blue"}"#, #"{"text":"invalid, token[REDACTED]","color":"blue"}"#),
        (#"{"note":"Don't forget","id":"7"}"#, #"{"note":"Don't forget","id":"7"}"#),
        (#"{"city":"İstanbul'a","id":"7"}"#, #"{"city":"İstanbul'a","id":"7"}"#),
        (#"{"title":"Order (2 items)","id":"7"}"#, #"{"title":"Order (2 items)","id":"7"}"#),
        (#"{"query":"mutation","variables":"{\"password\":\"x\"}"}"#, #"{"query":"mutation","variables":"{[REDACTED]"}"#),
    ])
    func sentencesKeepSiblings(input: String, expected: String) {
        #expect(Redactor().redact(body: Data(input.utf8), contentType: "application/json") == expected)
    }

    @Test("a secret word before `: ` is a label, so a note that writes `password: hunter2` hides the members beside it too")
    func colonPairsHideSiblings() {
        let redactor = Redactor()
        #expect(redactor.redact(body: Data(#"{"note":"password: hunter2","user":"bob"}"#.utf8), contentType: "application/json")
            == #"{"note":"password: [REDACTED]","user":"[REDACTED]"}"#)
        #expect(redactor.redact(body: Data(#"{"note":"password=hunter2","user":"bob"}"#.utf8), contentType: "application/json")
            == #"{"note":"password=[REDACTED]","user":"bob"}"#)
    }

    @Test("the README's and the logging guide's examples of labels and sentences")
    func documentedExamples() {
        let json = { (text: String) in Redactor().redact(body: Data(text.utf8), contentType: "application/json") }
        #expect(!json(#"{"question":"What's your PIN?","answer":"1234"}"#).contains("1234"))
        #expect(!json(#"{"title":"PIN (4 digits)","value":"1234"}"#).contains("1234"))
        #expect(json(#"{"error":"Error: PIN expired","answer":"1234"}"#) == #"{"error":"Error: [REDACTED]","answer":"1234"}"#)
        #expect(json(#"{"note":"login with api_key=abc123","user":"bob"}"#) == #"{"note":"login with api_key=[REDACTED]","user":"bob"}"#)
    }

    @Test("the review's controls stay hidden", arguments: [
        #"{"question":"What is your PIN?","answer":"Qb7Zk3m"}"#, #"["What is your PIN?","Qb7Zk3m"]"#,
        #"{"question":"Enter PIN","answer":"Qb7Zk3m"}"#, #"["PIN 4 digits","Qb7Zk3m"]"#,
        #"{"question":"Your password please","answer":"Qb7Zk3m"}"#, #"["Enter PIN (4 digits)","Qb7Zk3m"]"#,
        #"{"label":"Enter PIN (4 digits)","value":"Qb7Zk3m"}"#, #"{"label":"What's your PIN?","value":"Qb7Zk3m"}"#,
        #"["Password, again","Qb7Zk3m"]"#, #"{"label":"Password, again","value":"Qb7Zk3m"}"#,
    ])
    func controls(input: String) {
        #expect(!Redactor().redact(body: Data(input.utf8), contentType: "application/json").contains(Self.secret))
    }

    @Test("an apostrophe between letters is part of a word; other marks make a sentence; a JSON document is no name")
    func shapes() {
        let compatibility = CompatibilityText()
        let shape = { (text: String) in WrittenName.shape(of: Array(text.unicodeScalars), compatibility: compatibility) }
        for name in ["What's your PIN?", "Kartın CVV'si", "PIN'in", "Don't share your token", "'PIN'"] {
            #expect(shape(name) == .plain, "\(name)")
        }
        for name in ["Enter PIN (4 digits)", "PIN, 4 digits", "PIN: required", "aws:secret-access-key", "'PIN' field"] {
            #expect(shape(name) == .sentence, "\(name)")
        }
        #expect(shape(#"{"password":"x"}"#) == nil && shape(#"["PIN","x"]"#) == nil)
        #expect(shape("{PIN}") == .plain && shape("[PIN]") == .plain)
        let label = { (text: String) in String(String.UnicodeScalarView(WrittenName.labelPart(of: Array(text.unicodeScalars)))) }
        #expect(label("Error: token expired") == "Error" && label("PIN: required") == "PIN" && label("Password = new") == "Password ")
        #expect(label("aws:secret-access-key") == "aws:secret-access-key" && label("pin=1234") == "pin=1234" && label(": PIN") == ": PIN")
    }
}

extension RedactionTimeLimitTests {
    /// Bodies of a megabyte of objects whose members hold labels and messages written as
    /// sentences, each read for a secret word with no value after it.
    static let sentenceLabels: [TimedInput] = [
        TimedInput(testDescription: "a JSON body of objects with labels written as sentences", make: {
            let object = #"{"question":"What's your PIN (4 digits)?","answer":"x","note":"Error: token expired, retry"},"#
            return "[" + String(repeating: object, count: size / object.utf8.count) + "{}]"
        }, redact: { largeBodies.redact(body: Data($0.utf8), contentType: "application/json") }),
        TimedInput(testDescription: "a JSON body of objects with sentences that name no secret", make: {
            let object = #"{"title":"Order (2 items), total: 12.50","city":"İstanbul'a","id":"7"},"#
            return "[" + String(repeating: object, count: size / object.utf8.count) + "{}]"
        }, redact: { largeBodies.redact(body: Data($0.utf8), contentType: "application/json") }),
    ]
}
