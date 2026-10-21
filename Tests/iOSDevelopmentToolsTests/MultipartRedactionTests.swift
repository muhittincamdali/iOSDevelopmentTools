import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Redaction: multipart")
struct MultipartRedactionTests {
    let policy = RedactionPolicy.default
    let redacted = RedactionPolicy.replacement
    let contentType = "multipart/form-data; boundary=XyZ"

    private func multipart(_ parts: [(headers: String, content: String)], boundary: String = "XyZ") -> Data {
        var text = ""
        for part in parts {
            text += "--\(boundary)\r\n\(part.headers)\r\n\r\n\(part.content)\r\n"
        }
        text += "--\(boundary)--\r\n"
        return Data(text.utf8)
    }

    // Section 6 of the redaction rules: a part header name outside the header allowlist is written
    // as `[REDACTED]`, and the value detectors read the names too.
    @Test("A part header name outside the allowlist, or with a finding in it, is written as [REDACTED] with its value")
    func partHeaderNames() {
        let lenient = RedactionPolicy(allowedHeaders: ["X-Note", "X-4111111111111111"])
        let body = multipart([("Content-Disposition: form-data; name=\"a\"\r\nX-Note: hi\r\nX-4111111111111111: v\r\nX-Other: v", "ok")])
        let (data, _) = lenient.redact(body: body, contentType: contentType)
        #expect(data == multipart([("Content-Disposition: form-data; name=\"a\"\r\nX-Note: hi\r\n\(redacted): \(redacted)\r\n\(redacted): \(redacted)", "ok")]))
    }

    @Test("Fields are redacted by name, file parts omitted, other part headers follow the header rule and hide their names")
    func fields() {
        let body = multipart([
            ("Content-Disposition: form-data; name=\"user\"", "ada"),
            ("Content-Disposition: form-data; name=\"password\"", "s3cret"),
            ("Content-Disposition: form-data; name=\"avatar\"; filename=\"secret-plan.png\"\r\nContent-Type: image/png\r\nX-Token: abc", "PNGDATA"),
        ])
        let (data, outcome) = policy.redact(body: body, contentType: contentType)
        #expect(outcome == .redacted)
        #expect(data == multipart([
            ("Content-Disposition: form-data; name=\"user\"", "ada"),
            ("Content-Disposition: form-data; name=\"password\"", redacted),
            ("Content-Disposition: form-data; name=\"avatar\"\r\nContent-Type: image/png\r\n\(redacted): \(redacted)", "[body omitted: 7 bytes, image/png]"),
        ]))
    }

    @Test("A part is parsed by its own content type")
    func partContentTypes() {
        let body = multipart([
            ("Content-Disposition: form-data; name=\"meta\"\r\nContent-Type: application/json", #"{"token":"t","title":"x"}"#),
            ("Content-Disposition: form-data; name=\"form\"\r\nContent-Type: application/x-www-form-urlencoded", "token;x=hunter2"),
            ("Content-Disposition: form-data; name=\"note\"", "a\r\npassword: hunter2"),
            ("Content-Disposition: form-data; name=\"xml\"\r\nContent-Type: application/xml", "<a/>"),
        ])
        let (data, outcome) = policy.redact(body: body, contentType: contentType)
        #expect(outcome == .redacted)
        #expect(data == multipart([
            ("Content-Disposition: form-data; name=\"meta\"\r\nContent-Type: application/json", #"{"token":"[REDACTED]","title":"x"}"#),
            ("Content-Disposition: form-data; name=\"form\"\r\nContent-Type: application/x-www-form-urlencoded", "[body omitted: 15 bytes, application/x-www-form-urlencoded]"),
            ("Content-Disposition: form-data; name=\"note\"", "a\r\npassword: \(redacted)"),
            ("Content-Disposition: form-data; name=\"xml\"\r\nContent-Type: application/xml", "[body omitted: 4 bytes, application/xml]"),
        ]))
        // Only `multipart/form-data` names its fields, so other multipart types are omitted.
        #expect(policy.redact(body: body, contentType: "multipart/related; boundary=XyZ").outcome == .omitted)
    }

    @Test("A field name that is not plain ASCII hides the value; a quoted boundary or name* omits the body")
    func fieldNames() throws {
        let body = multipart([
            ("Content-Disposition: form-data; name=\"a;password\"", "s3cret"),
            ("Content-Disposition: form-data; name=\"pаssword\"", "s3cret"),
        ])
        let (data, outcome) = policy.redact(body: body, contentType: contentType)
        #expect(outcome == .redacted)
        #expect(!String(decoding: data, as: UTF8.self).contains("s3cret"))
        #expect(policy.redact(body: body, contentType: "multipart/form-data; boundary=\"XyZ\"").outcome == .omitted)
        let extended = multipart([("Content-Disposition: form-data; name*=utf-8''pass%77ord", "s3cret")])
        #expect(policy.redact(body: extended, contentType: contentType).outcome == .omitted)
    }

    @Test("Disposition parameters: a quoted name may hold escapes; a file name is never written")
    func parameterParsing() {
        let quoted = multipart([("Content-Disposition: form-data; name=\"a\\\"b\"; filename=\"secret-plan.txt\"", "v")])
        let stored = String(decoding: policy.redact(body: quoted, contentType: contentType).body, as: UTF8.self)
        #expect(!stored.contains("secret-plan"))
        // A name with a `\` is not plain, so its value is hidden.
        #expect(stored.contains("\r\n\r\n[REDACTED]\r\n"))
        let token = multipart([("Content-Disposition: form-data;\tname=note", "v")])
        #expect(policy.redact(body: token, contentType: contentType).outcome == .redacted)
    }

    @Test("A malformed or repeated disposition parameter makes the body unreadable, so it is omitted", arguments: [
        "form-data; name = token", "form-data; name= token", "form-data; ;; =; name", "form-data; name",
        "form-data; name=", "form-data; name=a b", #"form-data; name="a"b"#, #"form-data; name="unclosed"#,
        #"form-data; x="a\"; name=password"#, "form-data; n\u{301}ame=a", "form-data; name=a;\u{301} name=password",
        "form-data; x=\"\u{301}; name=password", "form-data", #"form-data; name="a"; NAME=b"#, "form-data; name*=utf-8''pass%77ord",
    ])
    func malformedParameter(disposition: String) {
        let body = multipart([("Content-Disposition: \(disposition)", "hunter2")])
        let (data, outcome) = policy.redact(body: body, contentType: contentType)
        #expect(outcome == .omitted)
        #expect(!String(decoding: data, as: UTF8.self).contains("hunter2"))
    }

    @Test("Only a single plain boundary of RFC 2046 boundary characters is read", arguments: [
        ("multipart/form-data; boundary=\"B1/x\"", "B1/x", false), ("multipart/form-data; charset=utf-8; boundary=----WebKitFormBoundaryAbc123", "----WebKitFormBoundaryAbc123", true),
        ("multipart/form-data; boundary=X; boundary*=utf-8''Y", "X", false), ("multipart/form-data; boundary=X; boundary=X", "X", false),
        ("multipart/form-data; boundary=" + String(repeating: "b", count: 71), String(repeating: "b", count: 71), false),
        ("multipart/form-data; boundary=" + String(repeating: "b", count: 70), String(repeating: "b", count: 70), true),
    ])
    func boundaryCharacters(contentType: String, boundary: String, isRead: Bool) {
        let body = multipart([("Content-Disposition: form-data; name=\"a\"", "v")], boundary: boundary)
        #expect((policy.redact(body: body, contentType: contentType).outcome != .omitted) == isRead)
    }

    @Test("A boundary inside a line could end the part early for some server, so the body is omitted")
    func boundaryInsideLine() throws {
        let body = Data((
            "--B\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\nhello--B--\r\n"
            + "--B\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--B--\r\n"
        ).utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "multipart/form-data; boundary=B")
        #expect(outcome == .omitted)
        #expect(!String(decoding: data, as: UTF8.self).contains("hunter2"))
    }

    @Test("Line breaks before the first delimiter and transport padding after one are not read")
    func surroundingWhiteSpace() {
        let body = Data("\r\n--XyZ \t\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--XyZ--\r\n\r\n".utf8)
        #expect(policy.redact(body: body, contentType: contentType).outcome == .omitted)
    }

    @Test("A body with too many parts is omitted instead of tracked part by part")
    func tooManyParts() {
        let limit = MultipartBody.maximumPartCount
        let allowed = multipart(Array(repeating: ("Content-Disposition: form-data; name=\"a\"", "v"), count: limit))
        #expect(policy.redact(body: allowed, contentType: contentType).outcome == .unchanged)
        let excessive = multipart(Array(repeating: ("Content-Disposition: form-data; name=\"a\"", "v"), count: limit + 1))
        #expect(policy.redact(body: excessive, contentType: contentType).outcome == .omitted)
        let delimiters = Data(String(repeating: "--b", count: 100_000).utf8)
        #expect(policy.redact(body: delimiters, contentType: "multipart/form-data; boundary=b").outcome == .omitted)
    }

    @Test("A body written as the parser reads it is stored unchanged, with or without the last line break")
    func canonicalBody() {
        let body = multipart([("Content-Disposition: form-data; name=\"a\"", "v"), ("Content-Disposition: form-data; name=\"b\"", "w")])
        #expect(policy.redact(body: body, contentType: contentType) == (body, .unchanged))
        let withoutBreak = body.dropLast(2)
        #expect(policy.redact(body: Data(withoutBreak), contentType: contentType) == (Data(withoutBreak), .unchanged))
    }
}
