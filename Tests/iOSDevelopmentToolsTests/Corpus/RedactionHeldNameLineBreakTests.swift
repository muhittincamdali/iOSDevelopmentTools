import Foundation
import Testing
@testable import iOSDevelopmentTools

/// Values named by a field that holds a secret name are hidden, and a name that cannot be read is
/// one (section 0 of the redaction spec). The nineteenth review found that a field outside the
/// fields that hold names (`setting`, `attribute`, `env`, `Parameter`, `ParameterKey`) holding a
/// secret name with a line break (`password` and a line feed, `api`, a line feed and `key`) or a
/// character reference (`&#x0070;in`, `pass&#119;ord`) named nothing: such a string was taken for
/// a sentence, not a name, and the value beside it showed, in JSON, forms, multipart bodies and URL
/// queries with allowed names.
@Suite("Redaction corpus: names written with line breaks and character references")
struct RedactionHeldNameLineBreakTests {
    static let secret = "Yk019Wq7z"

    /// The review's JSON objects, with `{S}` for the value; the line breaks are JSON escapes.
    static let objects = [
        #"{"setting":"password\n","value":"{S}"}"#, #"{"attribute":"client_secret\r","value":"{S}"}"#,
        #"{"env":"token\n\n","val":"{S}"}"#, #"{"Parameter":"api\nkey","Value":"{S}"}"#,
        #"{"ParameterKey":"DbPassword\n","ParameterValue":"{S}"}"#, #"{"ParameterKey":"&#x0070;in","ParameterValue":"{S}"}"#,
        #"{"setting":"pass&#119;ord","value":"{S}"}"#, #"{"setting":"\npassword","value":"{S}"}"#,
        #"{"setting":"pass\r\nword","value":"{S}"}"#, #"{"OptionName":"secret\n","OptionValue":"{S}"}"#,
        #"[{"setting":"password\n","value":"{S}"}]"#, #"{"a":{"setting":"password\n","value":"{S}"}}"#,
    ]

    @Test("the value beside such a name is hidden in JSON", arguments: objects)
    func json(object: String) {
        let body = object.replacingOccurrences(of: "{S}", with: Self.secret)
        let output = Redactor().redact(body: Data(body.utf8), contentType: "application/json")
        #expect(!output.contains(Self.secret), "\(body.debugDescription) -> \(output.debugDescription)")
    }

    static let names = ["password\n", "client_secret\r", "token\n\n", "api\nkey", "DbPassword\n", "&#x0070;in", "pass&#119;ord", "\npassword"]

    @Test("the value beside such a name is hidden in a form, a multipart body and a URL query", arguments: names)
    func formsAndQueries(name: String) throws {
        let redactor = Redactor(allowedQueryParameters: ["setting", "value"])
        let form = "setting=" + RedactionPolicy.formEncoded(name) + "&value=" + Self.secret
        let formOutput = redactor.redact(body: Data(form.utf8), contentType: "application/x-www-form-urlencoded")
        #expect(!formOutput.contains(Self.secret), "\(form.debugDescription) -> \(formOutput.debugDescription)")
        let multipart = "--B\r\nContent-Disposition: form-data; name=\"setting\"\r\n\r\n\(name)\r\n"
            + "--B\r\nContent-Disposition: form-data; name=\"value\"\r\n\r\n\(Self.secret)\r\n--B--\r\n"
        let multipartOutput = redactor.redact(body: Data(multipart.utf8), contentType: "multipart/form-data; boundary=B")
        #expect(!multipartOutput.contains(Self.secret), "\(multipart.debugDescription) -> \(multipartOutput.debugDescription)")
        let url = try #require(URL(string: "https://x.example/a?setting=" + RedactionPolicy.formEncoded(name) + "&value=" + Self.secret))
        let urlOutput = redactor.redact(url: url)
        #expect(!urlOutput.contains(Self.secret), "\(url) -> \(urlOutput)")
    }

    // A string with a line break that is a sentence, not a name, keeps its `:` or `,` once the
    // line break is read as a space, so the record beside it stays (the sentence itself is free
    // text); a name with a line break that names no secret names nothing.
    @Test("sentences and names that name no secret, with line breaks, leave the fields beside them", arguments: [
        (#"{"message":"Error: token\nexpired","value":"blue"}"#, #""value":"blue""#),
        (#"{"text":"invalid, token\nretry","code":"blue"}"#, #""code":"blue""#),
        (#"{"setting":"color\n","value":"blue"}"#, #""value":"blue""#),
        (#"{"note":"line one\nline two","value":"blue"}"#, #""value":"blue""#),
        (#"{"setting":"Q&amp;A\n","value":"blue"}"#, #""value":"blue""#),
    ])
    func controls(body: String, kept: String) {
        let output = Redactor().redact(body: Data(body.utf8), contentType: "application/json")
        #expect(output.contains(kept), "\(body.debugDescription) -> \(output.debugDescription)")
    }
}
