import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The library stays useful (section 7 of the redaction rules): a record whose `name`, `id` or
/// `type` is written outside plain ASCII — a Turkish name, a product with parentheses, a media
/// type — keeps its other fields. The fifth review of this branch found every field of such a
/// record hidden (`{"id":42,"name":"Ayşe Yılmaz","price":12.5}` lost its id and price), because a
/// name that is not plain ASCII hid every member beside it. Now only the fields that carry the
/// value of a pair are hidden beside it, and pairs keep the stricter rule.
@Suite("Redaction corpus: records stay readable")
struct RedactionRecordUsefulnessTests {
    let redactor = Redactor()

    private func json(_ text: String) -> String { redactor.redact(body: Data(text.utf8), contentType: "application/json") }
    private func form(_ text: String) -> String { redactor.redact(body: Data(text.utf8), contentType: "application/x-www-form-urlencoded") }

    @Test("the review's records keep every field", arguments: [
        #"{"id":42,"name":"Ayşe Yılmaz","city":"İstanbul","tags":["a","b"],"active":true,"price":12.5,"note":"hi"}"#,
        #"{"type":"image/png","size":12345,"width":640}"#,
        #"{"id":1,"name":"iPhone 15 Pro (256 GB)","price":999}"#,
        #"{"name":"John O'Brien","age":40}"#,
        #"{"id":"user/123","active":true}"#,
        #"[{"id":7,"name":"Søren Kierkegaard","country":"Danmark"},{"id":8,"name":"Paweł Łukasz","country":"Polska"}]"#,
        #"{"name":"张伟","dept":"研发","level":3}"#,
        #"{"type":"application/json","encoding":"utf-8","length":512}"#,
    ])
    func recordsKeepFields(input: String) {
        #expect(json(input) == input)
    }

    @Test("a form with a name outside plain ASCII keeps its other fields")
    func forms() {
        #expect(form("name=Ay%C5%9Fe&page=2") == "name=Ay%C5%9Fe&page=2")
        #expect(form("name=Ay%C5%9Fe&value=x&page=2") == "name=Ay%C5%9Fe&value=[REDACTED]&page=2")
    }

    @Test("beside such a name, a field that carries a value is still hidden")
    func valueFieldsAreHidden() {
        #expect(json(#"{"name":"Ayşe","value":"S3CR3Tq"}"#) == #"{"name":"Ayşe","value":"[REDACTED]"}"#)
        #expect(json(#"{"name":"Şifre","data":"S3CR3Tq","id":1}"#) == #"{"name":"Şifre","data":"[REDACTED]","id":1}"#)
        #expect(json(#"{"type":"image/png","data":"AAAA","size":4}"#) == #"{"type":"image/png","data":"[REDACTED]","size":4}"#)
        #expect(json(#"{"name":"Ayşe","ParameterValue":"S3CR3Tq"}"#) == #"{"name":"Ayşe","ParameterValue":"[REDACTED]"}"#)
    }

    // `{"label":"Şifre","value":…}` is hidden on purpose, and so is every member beside a name
    // that names a secret, has no letter or digit, is written in styled letters or is held by a
    // field that only pairs use.
    @Test("pairs keep the stricter rule", arguments: [
        (#"{"label":"Şifre","value":"S3CR3Tq"}"#, #"{"label":"Şifre","value":"[REDACTED]"}"#),
        (#"{"label":"Şifre","extra":"S3CR3Tq"}"#, #"{"label":"Şifre","extra":"[REDACTED]"}"#),
        (#"{"param":"パスワード","x":"S3CR3Tq"}"#, #"{"param":"パスワード","x":"[REDACTED]"}"#),
        (#"{"label":"Password","value":"x","extra":"S3CR3Tq"}"#, #"{"label":"Password","value":"[REDACTED]","extra":"[REDACTED]"}"#),
        (#"{"label":"Password","op":"S3CR3Tq"}"#, #"{"label":"Password","op":"[REDACTED]"}"#),
        (#"{"name":"password","x":"S3CR3Tq"}"#, #"{"name":"password","x":"[REDACTED]"}"#),
        (#"{"name":"🔑","x":"S3CR3Tq"}"#, #"{"name":"🔑","x":"[REDACTED]"}"#),
        (#"{"name":"ⓟⓘⓝ","x":"S3CR3Tq"}"#, #"{"name":"[REDACTED]","x":"[REDACTED]"}"#),
        (#"{"type":"🔑","data":"S3CR3Tq"}"#, #"{"type":"🔑","data":"[REDACTED]"}"#),
        // A name that compatibility normalization changes, decomposed letters included, is not
        // read as a record's name.
        (#"{"name":"Ayse\u0301","x":"S3CR3Tq"}"#, #"{"name":"Ayse\u0301","x":"[REDACTED]"}"#),
        (#"{"name":"Ayşe\u200b","x":"S3CR3Tq"}"#, #"{"name":"[REDACTED]","x":"[REDACTED]"}"#),
        (#"{"name":"P\u0430ssword","x":"S3CR3Tq"}"#, #"{"name":"[REDACTED]","x":"[REDACTED]"}"#),
    ])
    func pairs(input: String, expected: String) {
        #expect(json(input) == expected)
    }

    @Test("a form that names a secret hides every other field")
    func secretForms() {
        #expect(form("id=password&x=S3CR3Tq") == "id=password&x=[REDACTED]")
        #expect(form("label=%C5%9Eifre&x=S3CR3Tq") == "label=%C5%9Eifre&x=[REDACTED]")
    }
}
