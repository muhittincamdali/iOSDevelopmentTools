import Foundation
import Testing
@testable import iOSDevelopmentTools

@Suite("Redaction: bodies")
struct BodyRedactionTests {
    let policy = RedactionPolicy.default
    let redacted = RedactionPolicy.replacement

    private func json(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("JSON keys are redacted at every depth, in objects and arrays")
    func nestedJSON() throws {
        let body = Data(#"{"user":{"name":"Ada","password":"p","tokens":[{"refresh_token":"r"}]},"items":[{"api_key":1}],"page":2}"#.utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "application/json")
        #expect(outcome == .redacted)
        let object = try json(data)
        let user = try #require(object["user"] as? [String: Any])
        #expect(user["name"] as? String == "Ada")
        #expect(user["password"] as? String == redacted)
        // "tokens" itself is sensitive, so the whole array goes.
        #expect(user["tokens"] as? String == redacted)
        let items = try #require(object["items"] as? [[String: Any]])
        #expect(items.first?["api_key"] as? String == redacted)
        #expect(object["page"] as? Int == 2)
    }

    @Test("Unicode escapes in keys do not hide a sensitive name")
    func escapedKeys() throws {
        let body = Data(#"{"password":"secret"}"#.utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "application/json")
        #expect(outcome == .redacted)
        #expect(try json(data)["password"] as? String == redacted)
        #expect(!String(decoding: data, as: UTF8.self).contains("secret"))
    }

    @Test("Duplicate keys cannot smuggle a value through")
    func duplicateKeys() {
        let body = Data(#"{"token":"a","token":"b"}"#.utf8)
        let (data, _) = policy.redact(body: body, contentType: "application/json")
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("\"a\"") && !text.contains("\"b\""))
    }

    @Test("JSON sent with a non-JSON content type is still checked")
    func mislabeledJSON() throws {
        let body = Data("  \n{\"secret\":\"s\"}".utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "text/plain")
        #expect(outcome == .redacted)
        #expect(try json(data)["secret"] as? String == redacted)
    }

    @Test("JSON inside a JSON string is checked too, as in GraphQL variables")
    func jsonInString() throws {
        let body = Data(#"{"query":"{ me }","variables":"{\"input\":{\"password\":\"hunter2\",\"name\":\"ada\"}}","note":"[not json"}"#.utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "application/json")
        #expect(outcome == .redacted)
        let object = try json(data)
        #expect(object["query"] as? String == "{ me }")
        #expect(object["note"] as? String == "[not json")
        let variables = try #require((object["variables"] as? String).map { Data($0.utf8) })
        let input = try #require(try json(variables)["input"] as? [String: Any])
        #expect(input["password"] as? String == redacted)
        #expect(input["name"] as? String == "ada")
    }

    @Test("JSON after a byte order mark is still recognized and checked")
    func byteOrderMark() throws {
        let body = Data([0xEF, 0xBB, 0xBF]) + Data(#" {"password":"hunter2"}"#.utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "text/plain")
        #expect(outcome == .redacted)
        #expect(try json(data)["password"] as? String == redacted)
    }

    @Test("JSON without sensitive keys keeps its exact bytes")
    func unchangedJSON() {
        let body = Data(#"{"b": 1.50, "a": [true, null]}"#.utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "application/json")
        #expect(outcome == .unchanged)
        #expect(data == body)
    }

    @Test("Truncated, malformed or too deeply nested JSON is withheld", arguments: [
        (#"{"password":"abc"#, false),
        (#"{"password": }"#, true),
        (String(repeating: "[", count: 200) + "1" + String(repeating: "]", count: 200), true),
    ])
    func uncheckedJSON(text: String, isComplete: Bool) {
        let (data, outcome) = policy.redact(body: Data(text.utf8), contentType: "application/json", isComplete: isComplete)
        #expect(outcome == .withheld)
        #expect(data.isEmpty)
    }

    @Test("A number outside Double's range makes the body unchecked, not a crash")
    func hugeNumbers() {
        let body = Data(#"{"password":"x","n":1e400,"m":-1e400}"#.utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "application/json")
        // JSONSerialization rejects numbers outside Double's range, so the body cannot be checked.
        #expect(outcome == .withheld)
        #expect(data.isEmpty)
    }

    @Test("Without withholding, unchecked bodies are stored as they were")
    func withholdingOff() {
        let lenient = RedactionPolicy(withholdsUncheckedBodies: false)
        let body = Data(#"{"password":"#.utf8)
        let (data, outcome) = lenient.redact(body: body, contentType: "application/json")
        #expect(outcome == .unchanged)
        #expect(data == body)
    }

    @Test("Form fields are redacted, including encoded names")
    func formBody() {
        let body = Data("user=ada&pass%77ord=s3cret&remember=1".utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "application/x-www-form-urlencoded; charset=utf-8")
        #expect(outcome == .redacted)
        #expect(String(decoding: data, as: UTF8.self) == "user=ada&pass%77ord=\(redacted)&remember=1")
    }

    @Test("A cut-off form body is still redacted up to where it ends")
    func truncatedForm() {
        let body = Data("user=ada&password=s3".utf8)
        let (data, _) = policy.redact(body: body, contentType: "application/x-www-form-urlencoded", isComplete: false)
        #expect(String(decoding: data, as: UTF8.self) == "user=ada&password=\(redacted)")
    }

    @Test("A body without a content type is checked as a form, as URLSession sends it")
    func formWithoutContentType() {
        let body = Data("user=ada&password=hunter2".utf8)
        let (data, outcome) = policy.redact(body: body, contentType: nil)
        #expect(outcome == .redacted)
        #expect(String(decoding: data, as: UTF8.self) == "user=ada&password=\(redacted)")
        // JSON without a content type is still read as JSON, and other text keeps its bytes.
        #expect(policy.redact(body: Data(#"{"token":"t"}"#.utf8), contentType: nil).outcome == .redacted)
        let binary = Data([0x00, 0xFF, 0x3D, 0x01])
        #expect(policy.redact(body: binary, contentType: nil) == (binary, .unchanged))
    }

    @Test("Plain text and binary bodies are not checked")
    func otherBodies() {
        let text = Data("password=hunter2 in a log line".utf8)
        #expect(policy.redact(body: text, contentType: "text/plain").outcome == .unchanged)
        let binary = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF])
        #expect(policy.redact(body: binary, contentType: "image/png") == (binary, .unchanged))
        #expect(policy.redact(body: Data(), contentType: "application/json") == (Data(), .unchanged))
    }

    // MARK: Multipart

    private func multipart(_ parts: [(headers: String, content: String)], boundary: String = "XyZ") -> Data {
        var text = ""
        for part in parts {
            text += "--\(boundary)\r\n\(part.headers)\r\n\r\n\(part.content)\r\n"
        }
        text += "--\(boundary)--\r\n"
        return Data(text.utf8)
    }

    @Test("Multipart fields are redacted by name, other parts keep their bytes")
    func multipartFields() {
        let body = multipart([
            ("Content-Disposition: form-data; name=\"user\"", "ada"),
            ("Content-Disposition: form-data; name=\"password\"", "s3cret"),
            ("Content-Disposition: form-data; name=\"avatar\"; filename=\"a.png\"\r\nContent-Type: image/png", "PNGDATA"),
        ])
        let (data, outcome) = policy.redact(body: body, contentType: "multipart/form-data; boundary=XyZ")
        #expect(outcome == .redacted)
        let expected = multipart([
            ("Content-Disposition: form-data; name=\"user\"", "ada"),
            ("Content-Disposition: form-data; name=\"password\"", redacted),
            ("Content-Disposition: form-data; name=\"avatar\"; filename=\"a.png\"\r\nContent-Type: image/png", "PNGDATA"),
        ])
        #expect(data == expected)
    }

    @Test("A quoted name with a semicolon is read as one name")
    func quotedSemicolon() {
        let body = multipart([("Content-Disposition: form-data; name=\"a;password\"", "s3cret")])
        let (data, outcome) = policy.redact(body: body, contentType: "multipart/form-data; boundary=\"XyZ\"")
        #expect(outcome == .redacted)
        #expect(!String(decoding: data, as: UTF8.self).contains("s3cret"))
    }

    @Test("Parameter parsing handles escapes, extended names and bare values")
    func parameterParsing() {
        #expect(RedactionPolicy.parameterValues("name", in: #"form-data; name="a\"b"; filename="x""#) == [#"a"b"#])
        #expect(RedactionPolicy.parameterValues("name*", in: "form-data; name*=utf-8''pass%77ord") == ["utf-8''pass%77ord"])
        #expect(RedactionPolicy.parameterValues("name", in: "form-data; filename=x; name = token ") == ["token"])
        #expect(RedactionPolicy.parameterValues("name", in: "form-data") == [])
        #expect(RedactionPolicy.parameterValues("name", in: "form-data; ;; =; name") == [""])
        #expect(RedactionPolicy.parameterValues("name", in: #"form-data; name="a"; NAME=b"#) == ["a", "b"])
    }

    @Test("Every Content-Disposition name of a part is checked", arguments: [
        "Content-Disposition: form-data; name=\"note\"\r\nContent-Disposition: form-data; name=\"password\"",
        "Content-Disposition: form-data; name=\"note\"; name=\"password\"",
        "Content-Disposition: form-data; name=\"note\"; name*=utf-8''password",
    ])
    func repeatedNames(headers: String) {
        let body = multipart([(headers, "hunter2")])
        let (data, outcome) = policy.redact(body: body, contentType: "multipart/form-data; boundary=XyZ")
        #expect(outcome == .redacted)
        #expect(data == multipart([(headers, redacted)]))
    }

    @Test("A part with two content types is withheld")
    func repeatedContentType() {
        let headers = "Content-Disposition: form-data; name=\"a\"\r\nContent-Type: text/plain\r\nContent-Type: application/json"
        let body = multipart([(headers, #"{"token":"t"}"#)])
        #expect(policy.redact(body: body, contentType: "multipart/form-data; boundary=XyZ") == (Data(), .withheld))
    }

    @Test("A JSON part is checked by its own content type")
    func jsonPart() {
        let body = multipart([("Content-Disposition: form-data; name=\"metadata\"\r\nContent-Type: application/json", #"{"token":"t","title":"x"}"#)])
        let (data, outcome) = policy.redact(body: body, contentType: "multipart/related; boundary=XyZ")
        #expect(outcome == .redacted)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"title\":\"x\"") && !text.contains("\"t\""))
    }

    @Test("Multipart bodies that cannot be checked are withheld", arguments: [
        ("multipart/form-data; boundary=XyZ", "no delimiter here", true),
        ("multipart/form-data; boundary=XyZ", "--XyZ\r\nContent-Disposition: form-data; name=\"a\"", true),
        ("multipart/form-data; boundary=XyZ", "--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n", true),
        ("multipart/form-data", "--XyZ\r\n\r\nv\r\n--XyZ--", true),
        ("multipart/form-data; boundary=" + String(repeating: "b", count: 71), "x", true),
        ("multipart/form-data; boundary=XyZ", "--XyZ\r\n\r\nv\r\n--XyZ--", false),
    ])
    func uncheckedMultipart(contentType: String, text: String, isComplete: Bool) {
        let (data, outcome) = policy.redact(body: Data(text.utf8), contentType: contentType, isComplete: isComplete)
        #expect(outcome == .withheld)
        #expect(data.isEmpty)
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
        #expect(text.contains("name=\"password\"\r\n\r\n\(redacted)\r\n--B--"))
    }

    @Test("A boundary or a header line break after a bare CR or LF withholds the body", arguments: [
        // Werkzeug reads a password part here, after the LF that ends "hi".
        "--B\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\nhi\n--B\n"
            + "Content-Disposition: form-data; name=\"password\"\n\nhunter2\r\n--B--",
        "--B\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\nhi\r--B\r\n"
            + "Content-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--B--",
        "\n--B\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--B--",
        // Headers that end at "\n\n" put hunter2 in the content for such a server.
        "--B\r\nContent-Disposition: form-data; name=\"password\"\n\nhunter2\r\n\r\nv\r\n--B--",
    ])
    func bareLineBreaks(text: String) {
        #expect(policy.redact(body: Data(text.utf8), contentType: "multipart/form-data; boundary=B") == (Data(), .withheld))
    }

    @Test("A line that starts with the boundary but goes on withholds the body", arguments: [
        // A server that matches "--B" by prefix ends the password part at "abc".
        "--B\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nabc\r\n--BX\r\n\r\nhunter2\r\n--B--",
        "--B\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--B",
        "--B \r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--B x\r\n\r\nw\r\n--B--",
    ])
    func boundaryPrefix(text: String) {
        #expect(policy.redact(body: Data(text.utf8), contentType: "multipart/form-data; boundary=B") == (Data(), .withheld))
    }

    @Test("Spaces and tabs between a delimiter and its line break are allowed")
    func transportPadding() {
        let body = Data("--B \t\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--B--\r\n".utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "multipart/form-data; boundary=B")
        #expect(outcome == .redacted)
        #expect(String(decoding: data, as: UTF8.self) == "--B \t\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\n\(redacted)\r\n--B--\r\n")
    }

    @Test("Text before the first or after the closing delimiter withholds the body", arguments: [
        "preamble\r\n--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--XyZ--\r\n",
        "--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--XyZ--\r\nepilogue",
        // A second body after the closing delimiter, as a hostile client could append.
        "--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--XyZ--\r\n"
            + "--XyZ\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n--XyZ--\r\n",
    ])
    func preambleAndEpilogue(text: String) {
        #expect(policy.redact(body: Data(text.utf8), contentType: "multipart/form-data; boundary=XyZ") == (Data(), .withheld))
    }

    @Test("Line breaks around the delimiters keep the body as it was")
    func surroundingLineBreaks() {
        let body = Data("\r\n--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n--XyZ--\r\n\r\n".utf8)
        #expect(policy.redact(body: body, contentType: "multipart/form-data; boundary=XyZ") == (body, .unchanged))
    }

    @Test("A multipart body with too many parts is withheld instead of tracked part by part")
    func tooManyParts() {
        let limit = RedactionPolicy.maximumMultipartParts
        let allowed = multipart(Array(repeating: ("Content-Disposition: form-data; name=\"a\"", "v"), count: limit))
        #expect(policy.redact(body: allowed, contentType: "multipart/form-data; boundary=XyZ").outcome == .unchanged)
        let excessive = multipart(Array(repeating: ("Content-Disposition: form-data; name=\"a\"", "v"), count: limit + 1))
        #expect(policy.redact(body: excessive, contentType: "multipart/form-data; boundary=XyZ").outcome == .withheld)
        // Nothing but delimiters, as a hostile server could send.
        let delimiters = Data(String(repeating: "--b", count: 100_000).utf8)
        #expect(policy.redact(body: delimiters, contentType: "multipart/form-data; boundary=b").outcome == .withheld)
    }

    @Test("A captured body records its size, truncation and outcome")
    func capturedBody() {
        let body = CapturedBody.capture(prefix: Data(#"{"tok"#.utf8), byteCount: 100, contentType: "application/json", policy: policy)
        #expect(body.isTruncated)
        #expect(body.byteCount == 100)
        #expect(body.redaction == .withheld)
        #expect(body.data.isEmpty)
    }

    @Test("Text of a truncated body drops a character split by the limit")
    func splitCharacter() {
        let full = Data("ab€".utf8) // € is three bytes
        let body = CapturedBody(data: full.prefix(4), byteCount: full.count, isTruncated: true, redaction: .unchanged)
        #expect(body.text == "ab")
        let invalid = CapturedBody(data: Data([0xFF, 0xFE]), byteCount: 2, isTruncated: false, redaction: .unchanged)
        #expect(invalid.text == nil)
    }

    @Test("Pretty-printed JSON only for complete JSON")
    func prettyJSON() {
        let complete = CapturedBody(data: Data(#"{"b":1,"a":2}"#.utf8), byteCount: 13, isTruncated: false, redaction: .unchanged)
        #expect(complete.prettyPrintedJSON == "{\n  \"a\" : 2,\n  \"b\" : 1\n}")
        let cut = CapturedBody(data: Data(#"{"b":1"#.utf8), byteCount: 13, isTruncated: true, redaction: .unchanged)
        #expect(cut.prettyPrintedJSON == nil)
        let fragment = CapturedBody(data: Data("42".utf8), byteCount: 2, isTruncated: false, redaction: .unchanged)
        #expect(fragment.prettyPrintedJSON == nil)
    }
}
