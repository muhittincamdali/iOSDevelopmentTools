import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Redaction corpus: bodies")
struct RedactionBodyTests {
    let redactor = Redactor()

    private func redact(_ body: String, _ contentType: String?) -> String {
        redactor.redact(body: Data(body.utf8), contentType: contentType)
    }

    // MARK: JSON

    @Test("hides every value under a secret name in a JSON body and stays valid JSON")
    func json() throws {
        let body = #"{"user":"bob","password":"hunter2","nested":[{"token":{"a":[1,2]}},{"Token":42,"secret":null}],"password":"again"}"#
        let output = redact(body, "application/json; charset=utf-8")
        #expect(output == #"{"user":"bob","password":"[REDACTED]","nested":[{"token":"[REDACTED]"},{"Token":"[REDACTED]","secret":"[REDACTED]"}],"password":"[REDACTED]"}"#)
        #expect(try JSONSerialization.jsonObject(with: Data(output.utf8)) is NSDictionary)
    }

    @Test("compares JSON names after decoding their escapes")
    func jsonEscapedNames() {
        #expect(redact(#"{"pass\u0077ord":"hunter2","user":"bob"}"#, "application/json") == #"{"pass\u0077ord":"[REDACTED]","user":"bob"}"#)
        #expect(redact(#"{"pаssword":"hunter2"}"#, "application/problem+json") == #"{"pаssword":"[REDACTED]"}"#)
    }

    @Test("reads JSON inside a JSON string")
    func jsonInString() {
        let body = #"{"query":"mutation","variables":"{\"password\":\"hunter2\",\"user\":\"bob\"}"}"#
        #expect(redact(body, "application/json") == #"{"query":"mutation","variables":"{\"password\":\"[REDACTED]\",\"user\":\"bob\"}"}"#)
    }

    @Test("omits JSON that does not parse completely", arguments: [
        #"{"password":"hunter2""#,
        #"{"password":"hunter2",}"#,
        #"{"password":"hunter2"} trailing"#,
        #"{"a":"\ud800"}"#,
        "{\"a\":\"line\nbreak\"}",
        #"// comment"# + "\n{}",
    ])
    func malformedJSON(body: String) {
        #expect(redact(body, "application/json") == "[body omitted: \(body.utf8.count) bytes, application/json]")
    }

    @Test("omits JSON nested deeper than the parser reads")
    func deepJSON() {
        let depth = Nesting.maximumDepth + 1
        let body = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
        #expect(redact(body, "application/json") == "[body omitted: \(depth * 2) bytes, application/json]")
    }

    @Test("omits a body that is not UTF-8")
    func notUTF8() {
        #expect(redactor.redact(body: Data([0x7B, 0xFF, 0x7D]), contentType: "application/json") == "[body omitted: 3 bytes, application/json]")
        #expect(redact("{}", "application/json; charset=utf-16") == "[body omitted: 2 bytes, application/json]")
    }

    // MARK: Forms

    @Test("hides form fields by their decoded name", arguments: [
        ("user=bob&password=hunter2&next=%2Fhome", "user=bob&password=[REDACTED]&next=%2Fhome"),
        ("pass%77ord=hunter2&a=1", "pass%77ord=[REDACTED]&a=1"),
        ("pass+word=hunter2", "pass+word=[REDACTED]"),
        ("user%5Bpassword%5D=hunter2&user%5Bname%5D=bob", "user%5Bpassword%5D=[REDACTED]&user%5Bname%5D=[REDACTED]"),
        ("p%D0%B0ssword=hunter2", "p%D0%B0ssword=[REDACTED]"),
        ("user=bob%20smith&note=paid+4111+1111+1111+1111", "user=bob%20smith&note=paid+[REDACTED]"),
        ("note=status%3D1+user%3Dbob", "note=status%3D1+user%3D[REDACTED]"),
        ("password=hunter2&password=again", "password=[REDACTED]&password=[REDACTED]"),
        ("q=%7B%22password%22%3A%22hunter2%22%7D", "q=%7B%22password%22%3A%22[REDACTED]%22%7D"),
        ("flag&password=hunter2", "flag&password=[REDACTED]"),
    ])
    func form(body: String, expected: String) {
        #expect(redact(body, "application/x-www-form-urlencoded") == expected)
    }

    // A mark or a joiner after `&`, `=` or `+` forms one Character with it. Written as it is, such
    // a form is not strict and is omitted; percent-encoded, it is decoded scalar by scalar after
    // the split, so `%CC%81status` is a field of its own whose name is not plain ASCII.
    @Test("reads percent-encoded marks and joiners after & and = as part of the next field", arguments: [
        ("note=hi&%CC%81status=hunter2", "note=hi&%CC%81status=[REDACTED]"),
        ("x=1&%E2%80%8Dstatus=hunter2", "x=1&%E2%80%8Dstatus=[REDACTED]"),
        ("user=bob&%E2%83%9Dtoken=abc", "user=bob&%E2%83%9Dtoken=[REDACTED]"),
        ("status=200&%CC%81=hunter2", "status=200&%CC%81=[REDACTED]"),
        ("password=%CC%81x", "password=[REDACTED]"),
    ])
    func formScalars(body: String, expected: String) {
        let output = redact(body, "application/x-www-form-urlencoded")
        #expect(Array(output.unicodeScalars) == Array(expected.unicodeScalars), "\(output.debugDescription)")
    }

    @Test("omits a form with a bad escape", arguments: ["password=%ZZ", "a=%", "a=%C3%28", "a=1&b=%2", "%=x"])
    func malformedForm(body: String) {
        #expect(redact(body, "application/x-www-form-urlencoded") == "[body omitted: \(body.utf8.count) bytes, application/x-www-form-urlencoded]")
    }

    @Test("omits a body without a content type, even one that parses as JSON")
    func noContentType() {
        #expect(redact(#"{"password":"hunter2"}"#, nil) == "[body omitted: 22 bytes, no known content type]")
        #expect(redact("user=bob&password=hunter2", nil) == "[body omitted: 25 bytes, no known content type]")
        #expect(redact("password hunter2", nil) == "[body omitted: 16 bytes, no known content type]")
        #expect(redact(#""hunter2""#, nil) == "[body omitted: 9 bytes, no known content type]")
    }

    @Test("omits a body larger than the maximum size without parsing it")
    func oversized() {
        let body = Data(("{\"a\":\"" + String(repeating: "x", count: RedactionPolicy.maximumCheckedBodySize) + "\"}").utf8)
        #expect(redactor.redact(body: body, contentType: "application/json") == "[body omitted: \(body.count) bytes, application/json]")
        #expect(redactor.redact(body: body, contentType: nil) == "[body omitted: \(body.count) bytes, no known content type]")
    }

    // MARK: Multipart

    private func multipart(_ parts: [String], boundary: String = "XyZ") -> String {
        parts.map { "--\(boundary)\r\n\($0)\r\n" }.joined() + "--\(boundary)--\r\n"
    }

    @Test("reads each multipart part by its name and content type")
    func multipartParts() {
        let body = multipart([
            "Content-Disposition: form-data; name=\"user\"\r\n\r\nbob",
            "Content-Disposition: form-data; name=\"password\"\r\n\r\nhunter2",
            "Content-Disposition: form-data; name=\"p\u{0430}ssword\"\r\n\r\nhunter2",
            "Content-Disposition: form-data; name=\"meta\"\r\nContent-Type: application/json\r\n\r\n{\"token\":\"abc\",\"n\":1}",
            "Content-Disposition: form-data; name=\"note\"\r\n\r\nlogin with api_key=abc123",
            "Content-Disposition: form-data; name=\"avatar\"; filename=\"a.png\"\r\nContent-Type: image/png\r\n\r\n\u{1}PNG",
        ])
        let expected = multipart([
            "Content-Disposition: form-data; name=\"user\"\r\n\r\nbob",
            "Content-Disposition: form-data; name=\"password\"\r\n\r\n[REDACTED]",
            "Content-Disposition: form-data; name=\"p\u{0430}ssword\"\r\n\r\n[REDACTED]",
            "Content-Disposition: form-data; name=\"meta\"\r\nContent-Type: application/json\r\n\r\n{\"token\":\"[REDACTED]\",\"n\":1}",
            "Content-Disposition: form-data; name=\"note\"\r\n\r\nlogin with api_key=[REDACTED]",
            "Content-Disposition: form-data; name=\"avatar\"\r\nContent-Type: image/png\r\n\r\n[body omitted: 4 bytes, image/png]",
        ])
        // The output ends as the body does: here with the line break after the closing boundary.
        #expect(redact(body, "multipart/form-data; boundary=XyZ") == expected)
    }

    @Test("writes part headers again: the field name, the type, and other headers only when they are kept")
    func multipartHeaders() {
        let body = multipart([
            "Content-Disposition: form-data; name=\"note\"; filename=\"alice-passport.txt\"\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nx",
            "content-disposition: form-data; name=\"bio\"\r\nX-Secret: s3cr3t\r\nContent-Length: 2\r\n\r\nhi",
            "Content-Disposition: form-data; name=\"data\"\r\nContent-Transfer-Encoding: base64\r\n\r\naHVudGVyMg==",
            "Content-Disposition: form-data; name=\"a=b\"\r\n\r\nok",
        ])
        let expected = multipart([
            "Content-Disposition: form-data; name=\"note\"\r\nContent-Type: text/plain\r\n\r\n[body omitted: 1 bytes, text/plain]",
            "Content-Disposition: form-data; name=\"bio\"\r\nX-Secret: [REDACTED]\r\nContent-Length: 2\r\n\r\nhi",
            "Content-Disposition: form-data; name=\"data\"\r\nContent-Transfer-Encoding: [REDACTED]\r\n\r\n[body omitted: 12 bytes, text/plain]",
            "Content-Disposition: form-data; name=\"a=[REDACTED]\"\r\n\r\n[REDACTED]",
        ])
        let output = redact(body, "multipart/form-data; boundary=XyZ")
        #expect(output == expected)
        #expect(!output.contains("passport") && !output.contains("s3cr3t") && !output.contains("aHVudGVyMg"))
    }

    @Test("finds the colon of a part header among the scalars, also before a mark")
    func multipartHeaderColon() {
        let body = multipart(["Content-Disposition: form-data; name=\"bio\"\r\nX-Note:\u{301}s3cr3t\r\n\r\nhi"])
        let expected = multipart(["Content-Disposition: form-data; name=\"bio\"\r\nX-Note: [REDACTED]\r\n\r\nhi"])
        #expect(redact(body, "multipart/form-data; boundary=XyZ") == expected)
    }

    @Test("omits multipart bodies that servers could split differently", arguments: [
        "preamble\r\n--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nx\r\n--XyZ--",
        "--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nx\r\n--XyZ--\r\nepilogue",
        "--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nx\r\n--XyZX\r\n--XyZ--",
        "--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nx",
        "--XyZ\r\nContent-Disposition: form-data\r\n\r\nx\r\n--XyZ--",
        "--XyZ\r\nContent-Disposition: form-data; name=\"a\"; name=\"password\"\r\n\r\nx\r\n--XyZ--",
        "--XyZ\r\nContent-Disposition: form-data; name*=UTF-8''password\r\n\r\nx\r\n--XyZ--",
        "--XyZ\r\nContent-Disposition: form-data;\r\n name=\"password\"\r\n\r\nx\r\n--XyZ--",
        "--XyZ\r\nContent-Disposition: form-data; name=\"a\"\nContent-Type: text/plain\r\n\r\nx\r\n--XyZ--",
        "--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\nContent-Disposition: form-data; name=\"b\"\r\n\r\nx\r\n--XyZ--",
        "--XyZ\r\nContent-Disposition: attachment; name=\"a\"\r\n\r\nx\r\n--XyZ--",
        "--XyZ\r\nContent-Disposition:\u{301} form-data; name=\"password\"\r\n\r\nhunter2\r\n--XyZ--",
    ])
    func malformedMultipart(body: String) {
        #expect(redact(body, "multipart/form-data; boundary=XyZ") == "[body omitted: \(body.utf8.count) bytes, multipart/form-data]")
    }

    @Test("omits multipart bodies with a missing, repeated or invalid boundary", arguments: [
        "multipart/form-data",
        "multipart/form-data; boundary=XyZ; boundary=Other",
        "multipart/form-data; boundary=XyZ; boundary*=UTF-8''XyZ",
        "multipart/form-data; boundary=\"Xy\\Z\"",
        "multipart/form-data; boundary=\"XyZ \"",
    ])
    func badBoundary(contentType: String) {
        let body = "--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nx\r\n--XyZ--"
        #expect(redact(body, contentType) == "[body omitted: \(body.utf8.count) bytes, multipart/form-data]")
    }

    // MARK: Other types

    @Test("reads plain text with the free-text rule")
    func plainText() {
        #expect(redact("login password=hunter2 ok=1", "text/plain; charset=us-ascii") == "login password=[REDACTED]")
        #expect(redact("status=200 method=GET", "text/plain") == "status=200 method=GET")
    }

    @Test("omits bodies of other types and with no known content types", arguments: [
        ("<a><password>hunter2</password></a>", "application/xml", "application/xml"),
        ("<p>password=hunter2</p>", "text/html", "text/html"),
        ("password=hunter2", "application/octet-stream", "application/octet-stream"),
        ("password=hunter2", "json", "no known content type"),
        ("password=hunter2", "application/json; charset", "no known content type"),
        ("x", "text/csv", "text/csv"),
    ])
    func otherTypes(body: String, contentType: String, described: String) {
        let count = body.utf8.count
        #expect(redact(body, contentType) == "[body omitted: \(count) bytes, \(described)]")
    }

    @Test("an empty body stays empty")
    func emptyBody() {
        #expect(redactor.redact(body: Data(), contentType: "application/octet-stream") == "")
    }

}
