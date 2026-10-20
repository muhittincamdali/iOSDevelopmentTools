import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A secret name written as a value — `name="password"`, `<string name="api_key">`,
/// `<key>password</key>` — names what follows it. In free text, a text/plain body and text inside a
/// JSON string, that is hidden: the rest of the line, and in XML and HTML the element's text, its
/// other attribute values and the lines up to its end tag. In a JSON object, the other members.
@Suite("Redaction corpus: secret names written as values")
struct RedactionNameAsValueTests {
    let redactor = Redactor()
    static let secret = "S3CR3Tq"

    /// The text as a log line, as a text/plain body and as a string in a JSON body.
    func outputs(_ text: String) -> [String] {
        let json = try! JSONSerialization.data(withJSONObject: ["note": text])
        return [
            redactor.redact(text),
            redactor.redact(body: Data(text.utf8), contentType: "text/plain"),
            redactor.redact(body: json, contentType: "application/json"),
        ]
    }

    @Test("the ninth review's probes hide the secret after the name", arguments: [
        #"<string name="api_key">S3CR3Tq</string>"#,
        #"<entry key="db.password">S3CR3Tq</entry>"#,
        #"<field id="pin">S3CR3Tq</field>"#,
        #"<param name="token" value="x">S3CR3Tq</param>"#,
        #"<string name="password" />S3CR3Tq"#,
        #"field name="password" S3CR3Tq"#,
        "name='token' S3CR3Tq",
        #"id: "pin" S3CR3Tq"#,
        #"header="Authorization" S3CR3Tq end"#,
        #"label="password", S3CR3Tq"#,
        "note=\"password\"\nS3CR3Tq",
        #"{"xml":"<string name=\"password\">S3CR3Tq</string>"}"#,
    ])
    func reviewProbes(input: String) {
        for output in outputs(input) {
            #expect(!output.contains(Self.secret), "\(input.debugDescription) -> \(output.debugDescription)")
        }
    }

    @Test("what follows the name is hidden to the end of its line", arguments: [
        (#"<string name="api_key">S3CR3Tq</string>"#, #"<string name="[REDACTED]"[REDACTED]"#),
        (#"field name="password" S3CR3Tq"#, #"field name="[REDACTED]"[REDACTED]"#),
        ("name=`token` S3CR3Tq", "name=`[REDACTED]`[REDACTED]"),
        (#"name=\"token\" S3CR3Tq"#, #"name=\"[REDACTED]\"[REDACTED]"#),
        ("note=\"password\"\u{2028}S3CR3Tq", "note=\"[REDACTED]\"\n[REDACTED]"),
        // The name is read as any word of a line is: disguised, escaped or split.
        ("name=\"p\u{0430}ssword\" S3CR3Tq", "name=\"[REDACTED]\"[REDACTED]"),
        ("name=\"pass\u{200B}word\" S3CR3Tq", "name=\"[REDACTED]\"[REDACTED]"),
        ("name=\"p&#97;ssword\" S3CR3Tq", "name=\"[REDACTED]\"[REDACTED]"),
        ("name=\"pass word\" S3CR3Tq", "name=\"[REDACTED]\"[REDACTED]"),
        ("name=\"API Key\" S3CR3Tq", "name=\"[REDACTED]\"[REDACTED]"),
    ])
    func restOfLine(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("other attributes of the element and its text are hidden", arguments: [
        (#"<input path="S3CR3Tq" name="password">"#, #"<input path="[REDACTED]" name="[REDACTED]"[REDACTED]"#),
        (#"<input value="S3CR3Tq" name="password">"#, #"<input value="[REDACTED]" name="[REDACTED]"[REDACTED]"#),
        (#"<input name="password" value="S3CR3Tq">"#, #"<input name="[REDACTED]"[REDACTED]"#),
        (#"<add key="DbPassword" value="S3CR3Tq" />"#, #"<add key="[REDACTED]"[REDACTED]"#),
        (#"<property name="spring.datasource.password" value="S3CR3Tq"/>"#, #"<property name="[REDACTED]"[REDACTED]"#),
        (#"<p title="password">S3CR3Tq</p>"#, #"<p title="[REDACTED]"[REDACTED]"#),
        (#"<string name="api_key"><![CDATA[S3CR3Tq]]></string>"#, #"<string name="[REDACTED]"[REDACTED]"#),
        ("<td>password</td><td>S3CR3Tq</td>", "<td>password[REDACTED]"),
    ])
    func sameElement(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("an element that goes on below its line is hidden up to its end tag", arguments: [
        ("<string name=\"password\">\n  S3CR3Tq\n</string>\nstatus=200", "<string name=\"[REDACTED]\"[REDACTED]\n  [REDACTED]\n</string>\nstatus=200"),
        (
            "<string name=\"private_key\">-----BEGIN-----\nS3CR3Tq1\nS3CR3Tq2\n-----END-----</string>\nstatus=200",
            "<string name=\"[REDACTED]\"[REDACTED]\n[REDACTED]\n[REDACTED]\n[REDACTED]</string>\nstatus=200"
        ),
        ("<input\n  name=\"password\"\n  value=\"S3CR3Tq\">\n<p>after</p>", "<input\n  name=\"[REDACTED]\"\n  [REDACTED]\n[REDACTED]"),
        ("<string name=\"password\"\n  >S3CR3Tq</string>", "<string name=\"[REDACTED]\"\n  [REDACTED]</string>"),
        ("<param name=\"token\" value=\"x\">\n  S3CR3Tq\n</param>\nstatus=200", "<param name=\"[REDACTED]\"[REDACTED]\n  [REDACTED]\n</param>\nstatus=200"),
    ])
    func linesBelow(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("the element after a key in a property list is its value", arguments: [
        ("<key>password</key><string>S3CR3Tq</string>", "<key>[REDACTED]"),
        ("<dict>\n\t<key>password</key>\n\t<string>S3CR3Tq\nS3CR3Tq2</string>\n</dict>", "<dict>\n\t<key>[REDACTED]\n\t[REDACTED]\n[REDACTED]</string>\n</dict>"),
        ("<key>password</key> <!-- note -->\n<string>S3CR3Tq</string>", "<key>[REDACTED]\n[REDACTED]</string>"),
        ("<key>password</key>\nS3CR3Tq\nnext line", "<key>[REDACTED]\n[REDACTED]\nnext line"),
        ("<label>Password</label>\n<input value=\"S3CR3Tq\">\n<p>after</p>", "<label>Password[REDACTED]\n[REDACTED]\n<p>after</p>"),
    ])
    func siblingElement(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("files that write secrets by name keep the rest readable", arguments: [
        // Android strings.xml
        (
            "<resources>\n    <string name=\"app_name\">My App</string>\n    <string name=\"api_key\">S3CR3Tq</string>\n    <string name=\"title\">Hello</string>\n</resources>",
            "<resources>\n    <string name=\"[REDACTED]\">My App</string>\n    <string name=\"[REDACTED]\"[REDACTED]\n    <string name=\"[REDACTED]\">Hello</string>\n</resources>"
        ),
        // Java Properties XML
        (
            "<properties>\n<entry key=\"db.user\">bob</entry>\n<entry key=\"db.password\">\nS3CR3Tq\n</entry>\n<entry key=\"db.url\">jdbc</entry>\n</properties>",
            "<properties>\n<entry key=\"[REDACTED]\">bob</entry>\n<entry key=\"[REDACTED]\"[REDACTED]\n[REDACTED]\n</entry>\n<entry key=\"[REDACTED]\">jdbc</entry>\n</properties>"
        ),
        // .NET appSettings
        (
            "<add key=\"ConnectionString\" value=\"Server=x;Password=S3CR3Tq\" />\n<add key=\"Mode\" value=\"fast\" />",
            "<add key=\"[REDACTED]\" value=\"[REDACTED]\"[REDACTED]\n<add key=\"[REDACTED]\" value=\"[REDACTED]\" />"
        ),
        // Spring beans
        (
            "<bean id=\"ds\"><property name=\"password\" value=\"S3CR3Tq\"/><property name=\"url\" value=\"jdbc:x\"/></bean>",
            "<bean id=\"[REDACTED]\"><property name=\"[REDACTED]\"[REDACTED]"
        ),
    ])
    func configurationFiles(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("names that are not secret keep what follows them", arguments: [
        (#"name="status" ok"#, #"name="[REDACTED]" ok"#),
        (#"<string name="status">200</string> status=200"#, #"<string name="[REDACTED]">200</string> status=200"#),
        (#"user="bob" status=200 path=/x"#, #"user="[REDACTED]" status=200 path=/x"#),
        ("login <password> required\nnext line\nlast line", "login <password> [REDACTED]\nnext line\nlast line"),
        ("<token>unclosed\nnext line", "<token>[REDACTED]\nnext line"),
    ])
    func plainNames(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a JSON member that names a secret hides the other members", arguments: [
        #"{"label":"Password","value":"S3CR3Tq"}"#,
        #"{"type":"password","value":"S3CR3Tq"}"#,
        #"{"variable":"API_KEY","value":"S3CR3Tq"}"#,
        #"{"ParameterKey":"DbPassword","ParameterValue":"S3CR3Tq"}"#,
        #"{"key":"pin","text":"S3CR3Tq"}"#,
        #"{"label":"API Key:","input":"S3CR3Tq"}"#,
        #"{"title":"pаssword","data2":["S3CR3Tq"]}"#,
        #"{"label":"Password","value":{"x":"S3CR3Tq"}}"#,
        #"[{"op":"replace","path":"/user/password","value":"S3CR3Tq"}]"#,
    ])
    func jsonMembers(input: String) {
        for output in [redactor.redact(body: Data(input.utf8), contentType: "application/json"), redactor.redact("body=" + input)] {
            #expect(!output.contains(Self.secret), "\(input.debugDescription) -> \(output.debugDescription)")
        }
    }

    @Test("JSON members beside names that are not secret, sentences and operations stay", arguments: [
        (#"{"label":"Status","value":"ok"}"#, #"{"label":"Status","value":"ok"}"#),
        (#"{"label":"Password","value":"x","op":"add"}"#, #"{"label":"Password","value":"[REDACTED]","op":"add"}"#),
        (#"{"name":"Cookie","value":"a=b","comment":"x"}"#, #"{"name":"Cookie","value":"[REDACTED]","comment":"[REDACTED]"}"#),
        (#"{"msg":"Error: token expired","user":"bob"}"#, #"{"msg":"Error: [REDACTED]","user":"bob"}"#),
        (#"{"query":"mutation","variables":"{\"password\":\"x\"}"}"#, #"{"query":"mutation","variables":"{\"password\":\"[REDACTED]\"}"}"#),
    ])
    func jsonKeepsPlainMembers(input: String, expected: String) {
        #expect(redactor.redact(body: Data(input.utf8), contentType: "application/json") == expected)
    }

    @Test("the logging guide's examples of names written as values")
    func guideExamples() {
        #expect(redactor.redact("field name=\"password\" hunter2") == "field name=\"[REDACTED]\"[REDACTED]")
        #expect(redactor.redact(#"<string name="api_key">k-1</string>"#) == #"<string name="[REDACTED]"[REDACTED]"#)
        #expect(redactor.redact("<key>password</key>\n<string>k-1</string>") == "<key>[REDACTED]\n[REDACTED]</string>")
        let pair = #"{"label":"Password","value":"hunter2"}"#
        #expect(redactor.redact(body: Data(pair.utf8), contentType: "application/json") == #"{"label":"Password","value":"[REDACTED]"}"#)
    }
}
