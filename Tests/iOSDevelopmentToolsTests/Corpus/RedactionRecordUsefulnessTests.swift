import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A record whose `name`, `id`, `type` or other field that holds a name is written outside plain
/// ASCII — a Turkish name, a product with parentheses, a media type — hides the values beside it
/// (section 2.5 of the redaction spec: one function classifies every name, and a name that is not
/// plain ASCII counts as secret). An earlier version of this package kept the other fields of such
/// a record; the shared rule hides them on purpose, and the documentation says so. The names
/// themselves stay readable, and a record with a plain ASCII name keeps everything.
@Suite("Redaction corpus: records with a name that is not plain ASCII")
struct RedactionRecordUsefulnessTests {
    let redactor = Redactor()

    private func json(_ text: String) -> String { redactor.redact(body: Data(text.utf8), contentType: "application/json") }
    private func form(_ text: String) -> String { redactor.redact(body: Data(text.utf8), contentType: "application/x-www-form-urlencoded") }

    @Test("a record keeps its name and hides the values beside a name that is not plain ASCII", arguments: [
        (
            #"{"id":42,"name":"Ayşe Yılmaz","city":"İstanbul","tags":["a","b"],"active":true,"price":12.5,"note":"hi"}"#,
            #"{"id":"[REDACTED]","name":"Ayşe Yılmaz","city":"[REDACTED]","tags":"[REDACTED]","active":"[REDACTED]","price":"[REDACTED]","note":"[REDACTED]"}"#
        ),
        (#"{"type":"image/png","size":12345,"width":640}"#, #"{"type":"image/png","size":"[REDACTED]","width":"[REDACTED]"}"#),
        (#"{"id":1,"name":"iPhone 15 Pro (256 GB)","price":999}"#, #"{"id":"[REDACTED]","name":"iPhone 15 Pro (256 GB)","price":"[REDACTED]"}"#),
        (#"{"name":"John O'Brien","age":40}"#, #"{"name":"John O'Brien","age":"[REDACTED]"}"#),
        (#"{"id":"user/123","active":true}"#, #"{"id":"user/123","active":"[REDACTED]"}"#),
        (
            #"[{"id":7,"name":"Søren Kierkegaard","country":"Danmark"},{"id":8,"name":"Paweł Łukasz","country":"Polska"}]"#,
            #"[{"id":"[REDACTED]","name":"Søren Kierkegaard","country":"[REDACTED]"},{"id":"[REDACTED]","name":"Paweł Łukasz","country":"[REDACTED]"}]"#
        ),
        (#"{"name":"张伟","dept":"研发","level":3}"#, #"{"name":"张伟","dept":"[REDACTED]","level":"[REDACTED]"}"#),
        (#"{"type":"application/json","encoding":"utf-8","length":512}"#, #"{"type":"application/json","encoding":"[REDACTED]","length":"[REDACTED]"}"#),
    ])
    func recordsHideValuesBesideAName(input: String, expected: String) {
        #expect(json(input) == expected)
    }

    @Test("a record with plain ASCII names keeps every field", arguments: [
        #"{"id":42,"name":"Ayse Yilmaz","city":"Istanbul","tags":["a","b"],"active":true,"price":12.5,"note":"hi"}"#,
        #"{"type":"image","size":12345,"width":640}"#,
        #"[{"id":7,"name":"Soren","country":"Danmark"},{"id":8,"name":"Pawel","country":"Polska"}]"#,
    ])
    func plainRecordsKeepFields(input: String) {
        #expect(json(input) == input)
    }

    @Test("a form with a name outside plain ASCII hides its other fields")
    func forms() {
        #expect(form("name=Ay%C5%9Fe&page=2") == "name=Ay%C5%9Fe&page=[REDACTED]")
        #expect(form("name=Ay%C5%9Fe&value=x&page=2") == "name=Ay%C5%9Fe&value=[REDACTED]&page=[REDACTED]")
        #expect(form("id=%C4%B0z&id=%C4%B0z&value=v&page=2") == "id=[REDACTED]&id=[REDACTED]&value=[REDACTED]&page=[REDACTED]")
        #expect(form("name=Ayse&page=2") == "name=Ayse&page=2")
    }

    @Test("beside such a name, a field that carries a value is hidden")
    func valueFieldsAreHidden() {
        #expect(json(#"{"name":"Ayşe","value":"S3CR3Tq"}"#) == #"{"name":"Ayşe","value":"[REDACTED]"}"#)
        #expect(json(#"{"name":"Şifre","data":"S3CR3Tq","id":1}"#) == #"{"name":"Şifre","data":"[REDACTED]","id":"[REDACTED]"}"#)
        #expect(json(#"{"type":"image/png","data":"AAAA","size":4}"#) == #"{"type":"image/png","data":"[REDACTED]","size":"[REDACTED]"}"#)
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
        (#"{"name":"🔑","x":"S3CR3Tq"}"#, #"{"name":"[REDACTED]","x":"[REDACTED]"}"#),
        (#"{"name":"ⓟⓘⓝ","x":"S3CR3Tq"}"#, #"{"name":"[REDACTED]","x":"[REDACTED]"}"#),
        (#"{"type":"🔑","data":"S3CR3Tq"}"#, #"{"type":"[REDACTED]","data":"[REDACTED]"}"#),
        // A name that compatibility normalization changes, decomposed letters included, is not
        // read as a record's name.
        (#"{"name":"Ayse\u0301","x":"S3CR3Tq"}"#, #"{"name":"Ayse\u0301","x":"[REDACTED]"}"#),
        (#"{"name":"Ayşe\u200b","x":"S3CR3Tq"}"#, #"{"name":"[REDACTED]","x":"[REDACTED]"}"#),
        (#"{"name":"P\u0430ssword","x":"S3CR3Tq"}"#, #"{"name":"[REDACTED]","x":"[REDACTED]"}"#),
        // Several names that are not plain ASCII hide each other's values as well.
        (#"{"name":"Ayşe","name":"Ayşe","label":"Şifre","x":"S3CR3Tq"}"#, #"{"name":"Ayşe","name":"Ayşe","label":"[REDACTED]","x":"[REDACTED]"}"#),
        (#"{"label":"Şifre","name":"Ayşe","x":"S3CR3Tq","value":"v"}"#, #"{"label":"[REDACTED]","name":"Ayşe","x":"[REDACTED]","value":"[REDACTED]"}"#),
        (#"{"label":"Şifre","label":"Пароль","x":"S3CR3Tq"}"#, #"{"label":"[REDACTED]","label":"[REDACTED]","x":"[REDACTED]"}"#),
        (
            #"{"label":"Şifre","name":"Ayşe","label":"Пароль","note":"n"}"#,
            #"{"label":"[REDACTED]","name":"Ayşe","label":"[REDACTED]","note":"[REDACTED]"}"#
        ),
        (#"{"label":{"x":1},"label":"Şifre","y":"1"}"#, #"{"label":"[REDACTED]","label":"[REDACTED]","y":"[REDACTED]"}"#),
    ])
    func pairs(input: String, expected: String) {
        #expect(json(input) == expected)
    }

    @Test("a form that names a secret hides every other field")
    func secretForms() {
        #expect(form("id=password&x=S3CR3Tq") == "id=password&x=[REDACTED]")
        #expect(form("label=%C5%9Eifre&x=S3CR3Tq") == "label=%C5%9Eifre&x=[REDACTED]")
        #expect(form("name=Ay%C5%9Fe&name=Ay%C5%9Fe&label=%C5%9Eifre&x=S3CR3Tq") == "name=Ay%C5%9Fe&name=Ay%C5%9Fe&label=[REDACTED]&x=[REDACTED]")
        #expect(form("label=%C5%9Eifre&label=%D0%9F%D0%B0%D1%80%D0%BE%D0%BB%D1%8C&x=1") == "label=[REDACTED]&label=[REDACTED]&x=[REDACTED]")
    }
}
