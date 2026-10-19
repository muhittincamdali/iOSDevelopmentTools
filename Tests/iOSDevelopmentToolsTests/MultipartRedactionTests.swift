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

    @Test("Fields are redacted by name, file parts omitted, other part headers follow the header rule")
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
            ("Content-Disposition: form-data; name=\"avatar\"\r\nContent-Type: image/png\r\nx-token: \(redacted)", "[body omitted: 7 bytes, image/png]"),
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
        let (data, outcome) = policy.redact(body: body, contentType: "multipart/related; boundary=XyZ")
        #expect(outcome == .redacted)
        #expect(data == multipart([
            ("Content-Disposition: form-data; name=\"meta\"\r\nContent-Type: application/json", #"{"title":"x","token":"[REDACTED]"}"#),
            ("Content-Disposition: form-data; name=\"form\"\r\nContent-Type: application/x-www-form-urlencoded", "\(redacted)=\(redacted)"),
            ("Content-Disposition: form-data; name=\"note\"", "a\r\npassword: \(redacted)"),
            ("Content-Disposition: form-data; name=\"xml\"\r\nContent-Type: application/xml", "[body omitted: 4 bytes, application/xml]"),
        ]))
    }

    @Test("A field name that is not plain ASCII hides the value, and names are shown redacted")
    func fieldNames() throws {
        let body = multipart([
            ("Content-Disposition: form-data; name=\"a;password\"", "s3cret"),
            ("Content-Disposition: form-data; name=\"pаssword\"", "s3cret"),
            ("Content-Disposition: form-data; name*=utf-8''pass%77ord", "s3cret"),
        ])
        let (data, outcome) = policy.redact(body: body, contentType: "multipart/form-data; boundary=\"XyZ\"")
        #expect(outcome == .redacted)
        #expect(!String(decoding: data, as: UTF8.self).contains("s3cret"))
    }

    @Test("Parameter parsing handles escapes, extended names and token values")
    func parameterParsing() {
        #expect(RedactionPolicy.fieldNames(in: #"form-data; name="a\"b"; filename="x""#) == [#"a"b"#])
        #expect(RedactionPolicy.fieldNames(in: "form-data; name*=utf-8''pass%77ord") == ["utf-8''pass%77ord"])
        #expect(RedactionPolicy.fieldNames(in: "form-data;; filename=x ;\tname=token ") == ["token"])
        #expect(RedactionPolicy.fieldNames(in: "form-data") == [])
        #expect(RedactionPolicy.fieldNames(in: #"form-data; name="a"; NAME=b"#) == ["a", "b"])
    }

    @Test("A malformed disposition parameter makes the names unreadable", arguments: [
        "form-data; name = token", "form-data; name= token", "form-data; ;; =; name", "form-data; name",
        "form-data; name=", "form-data; name=a b", #"form-data; name="a"b"#, #"form-data; name="unclosed"#,
        #"form-data; x="a\"; name=password"#, "form-data; n\u{301}ame=a", "form-data; name=a;\u{301} name=password",
        "form-data; x=\"\u{301}; name=password",
    ])
    func malformedParameter(disposition: String) {
        #expect(RedactionPolicy.fieldNames(in: disposition) == nil)
    }

    @Test("A boundary is a single token or quoted string of RFC 2046 boundary characters")
    func boundaryCharacters() {
        #expect(MultipartParser.boundary(in: "multipart/form-data; boundary=\"B1/x y:z\"") == "B1/x y:z")
        #expect(MultipartParser.boundary(in: "multipart/form-data; charset=utf-8; boundary=----WebKitFormBoundaryAbc123") == "----WebKitFormBoundaryAbc123")
        #expect(MultipartParser.boundary(in: "multipart/form-data; boundary=\"B1%22x\"") == nil)
        #expect(MultipartParser.boundary(in: "multipart/form-data; boundary=\"B1\\\\x\"") == nil)
        #expect(MultipartParser.boundary(in: "multipart/form-data; boundary=\"B1 \"") == nil)
        #expect(MultipartParser.boundary(in: "multipart/form-data; boundary=\"\"") == nil)
        #expect(MultipartParser.boundary(in: "multipart/form-data; boundary=X; boundary*=utf-8''Y") == nil)
    }

    @Test("A boundary inside a line is content, so it cannot end the body early")
    func boundaryInsideLine() throws {
        let body = Data((
            "--B\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\nhello--B--\r\n"
            + "--B\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--B--\r\n"
        ).utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "multipart/form-data; boundary=B")
        #expect(outcome == .redacted)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("hunter2"))
        #expect(text.contains("hello--B--\r\n--B\r\n"))
    }

    @Test("Line breaks around the delimiters and transport padding are not kept")
    func surroundingWhiteSpace() {
        let body = Data("\r\n--XyZ \t\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--XyZ--\r\n\r\n".utf8)
        #expect(policy.redact(body: body, contentType: contentType) == (multipart([("Content-Disposition: form-data; name=\"a\"", "v")]), .unchanged))
    }

    @Test("A body with too many parts is omitted instead of tracked part by part")
    func tooManyParts() {
        let limit = MultipartParser.maximumParts
        let allowed = multipart(Array(repeating: ("Content-Disposition: form-data; name=\"a\"", "v"), count: limit))
        #expect(policy.redact(body: allowed, contentType: contentType).outcome == .unchanged)
        let excessive = multipart(Array(repeating: ("Content-Disposition: form-data; name=\"a\"", "v"), count: limit + 1))
        #expect(policy.redact(body: excessive, contentType: contentType).outcome == .omitted)
        let delimiters = Data(String(repeating: "--b", count: 100_000).utf8)
        #expect(policy.redact(body: delimiters, contentType: "multipart/form-data; boundary=b").outcome == .omitted)
    }
}
