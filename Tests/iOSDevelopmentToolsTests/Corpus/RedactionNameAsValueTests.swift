import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A secret name written as a value — `name="password"`, `<string name="api_key">`,
/// `<key>password</key>` — names what follows it, and in a tag the attributes written before it.
/// In free text, a text/plain body and text inside a JSON string, the text is hidden from there to
/// its end, and a tag from its `<`. In a JSON object, the other members are hidden.
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

    @Test("what follows the name is hidden to the end of the text", arguments: [
        (#"<string name="api_key">S3CR3Tq</string>"#, #"[REDACTED]"#),
        (#"field name="password" S3CR3Tq"#, #"field name="[REDACTED]"#),
        ("name=`token` S3CR3Tq", "name=`[REDACTED]"),
        (#"name=\"token\" S3CR3Tq"#, #"name=[REDACTED]"#),
        ("note=\"password\"\u{2028}S3CR3Tq", "note=\"[REDACTED]"),
        // The name is read as any word of a line is: disguised, escaped or split.
        ("name=\"p\u{0430}ssword\" S3CR3Tq", "name=\"[REDACTED]"),
        ("name=\"pass\u{200B}word\" S3CR3Tq", "name=\"[REDACTED]"),
        ("name=\"p&#97;ssword\" S3CR3Tq", "name=\"[REDACTED]"),
        ("name=\"pass word\" S3CR3Tq", "name=\"[REDACTED]"),
        ("name=\"API Key\" S3CR3Tq", "name=\"[REDACTED]"),
    ])
    func restOfLine(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("a name in a tag hides the tag from its <, the attributes before the name too", arguments: [
        (#"<input path="S3CR3Tq" name="password">"#, #"[REDACTED]"#),
        (#"<input value="S3CR3Tq" name="password">"#, #"[REDACTED]"#),
        (#"<input name="password" value="S3CR3Tq">"#, #"[REDACTED]"#),
        (#"<add key="DbPassword" value="S3CR3Tq" />"#, #"[REDACTED]"#),
        (#"<property name="spring.datasource.password" value="S3CR3Tq"/>"#, #"[REDACTED]"#),
        (#"<p title="password">S3CR3Tq</p>"#, #"[REDACTED]"#),
        (#"<string name="api_key"><![CDATA[S3CR3Tq]]></string>"#, #"[REDACTED]"#),
        ("<td>password</td><td>S3CR3Tq</td>", "<td>[REDACTED]"),
    ])
    func sameElement(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("an element that goes on below its line is hidden with everything after it", arguments: [
        ("<string name=\"password\">\n  S3CR3Tq\n</string>\nstatus=200", "[REDACTED]"),
        (
            "<string name=\"private_key\">-----BEGIN-----\nS3CR3Tq1\nS3CR3Tq2\n-----END-----</string>\nstatus=200",
            "[REDACTED]"
        ),
        ("<input\n  name=\"password\"\n  value=\"S3CR3Tq\">\n<p>after</p>", "[REDACTED]"),
        ("<string name=\"password\"\n  >S3CR3Tq</string>", "[REDACTED]"),
        ("<param name=\"token\" value=\"x\">\n  S3CR3Tq\n</param>\nstatus=200", "[REDACTED]"),
    ])
    func linesBelow(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("the element after a key in a property list is hidden with everything after it", arguments: [
        ("<key>password</key><string>S3CR3Tq</string>", "<key>[REDACTED]"),
        ("<dict>\n\t<key>password</key>\n\t<string>S3CR3Tq\nS3CR3Tq2</string>\n</dict>", "<dict>\n\t<key>[REDACTED]"),
        ("<key>password</key> <!-- note -->\n<string>S3CR3Tq</string>", "<key>[REDACTED]"),
        ("<key>password</key>\nS3CR3Tq\nnext line", "<key>[REDACTED]"),
        ("<label>Password</label>\n<input value=\"S3CR3Tq\">\n<p>after</p>", "<label>[REDACTED]"),
    ])
    func siblingElement(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("files that write secrets by name keep what comes before the first one readable", arguments: [
        // Android strings.xml
        (
            "<resources>\n    <string name=\"app_name\">My App</string>\n    <string name=\"api_key\">S3CR3Tq</string>\n    <string name=\"title\">Hello</string>\n</resources>",
            "<resources>\n    [REDACTED]"
        ),
        // Java Properties XML
        (
            "<properties>\n<entry key=\"db.user\">bob</entry>\n<entry key=\"db.password\">\nS3CR3Tq\n</entry>\n<entry key=\"db.url\">jdbc</entry>\n</properties>",
            "<properties>\n[REDACTED]"
        ),
        // .NET appSettings
        (
            "<add key=\"ConnectionString\" value=\"Server=x;Password=S3CR3Tq\" />\n<add key=\"Mode\" value=\"fast\" />",
            "[REDACTED]"
        ),
        // Spring beans
        (
            "<bean id=\"ds\"><property name=\"password\" value=\"S3CR3Tq\"/><property name=\"url\" value=\"jdbc:x\"/></bean>",
            "[REDACTED]"
        ),
    ])
    func configurationFiles(input: String, expected: String) {
        #expect(redactor.redact(input) == expected)
    }

    @Test("names that are not secret keep what follows them after allowed keys", arguments: [
        (#"name="status" ok"#, #"name="status" ok"#),
        (#"<string name="status">200</string> status=200"#, #"<string name="status">200</string> status=200"#),
        (#"user="bob" status=200 path=/x"#, #"user="bob" status=200 path=/x"#),
        ("login <password> required\nnext line\nlast line", "login <password[REDACTED]"),
        ("<token>unclosed\nnext line", "<token[REDACTED]"),
    ])
    func plainNames(input: String, expected: String) {
        let allowing = Redactor(allowedTextKeys: ["name", "string", "user"])
        #expect(allowing.redact(input) == expected)
        // By default `name=`, `user=` and the text of `<string>` are not allowed and cut the text.
        #expect(redactor.redact(input).hasSuffix(RedactionPolicy.replacement))
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
        (#"{"query":"mutation","variables":"{\"password\":\"x\"}"}"#, #"{"query":"mutation","variables":"{\"password\":[REDACTED]"}"#),
    ])
    func jsonKeepsPlainMembers(input: String, expected: String) {
        #expect(redactor.redact(body: Data(input.utf8), contentType: "application/json") == expected)
    }

    @Test("the logging guide's examples of names written as values")
    func guideExamples() {
        #expect(redactor.redact("field name=\"password\" hunter2") == "field name=\"[REDACTED]")
        #expect(redactor.redact(#"<string name="api_key">k-1</string>"#) == "[REDACTED]")
        #expect(redactor.redact("<key>password</key>\n<string>k-1</string>") == "<key>[REDACTED]")
        let pair = #"{"label":"Password","value":"hunter2"}"#
        #expect(redactor.redact(body: Data(pair.utf8), contentType: "application/json") == #"{"label":"Password","value":"[REDACTED]"}"#)
    }
}
