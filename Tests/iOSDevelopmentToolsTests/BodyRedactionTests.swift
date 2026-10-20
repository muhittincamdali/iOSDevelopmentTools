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

    private func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

    @Test("JSON values of secret keys are hidden whole at every depth, in objects and arrays")
    func nestedJSON() throws {
        let body = Data(#"{"user":{"name":"Ada","password":{"old":"p1","new":["p2"]},"tokens":[{"refresh_token":"r"}]},"items":[{"api_key":1}],"page":2}"#.utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "application/json; charset=utf-8")
        #expect(outcome == .redacted)
        let object = try json(data)
        let user = try #require(object["user"] as? [String: Any])
        #expect(user["name"] as? String == "Ada")
        #expect(user["password"] as? String == redacted)
        #expect(user["tokens"] as? String == redacted)
        let items = try #require(object["items"] as? [[String: Any]])
        #expect(items.first?["api_key"] as? String == redacted)
        #expect(object["page"] as? Int == 2)
    }

    @Test("JSON is stored as sent, with only hidden values replaced; without secrets the outcome is unchanged")
    func storedJSON() {
        let body = Data(#"{"b": 1.5, "a": [true, null], "c": "x"}"#.utf8)
        #expect(policy.redact(body: body, contentType: "application/problem+json") == (body, .unchanged))
        let secret = Data(#"{"b": 1.5, "token": ["x"], "c": "x"}"#.utf8)
        #expect(policy.redact(body: secret, contentType: "application/json") == (Data(#"{"b": 1.5, "token": "[REDACTED]", "c": "x"}"#.utf8), .redacted))
        #expect(policy.redact(body: Data(#""text""#.utf8), contentType: "application/json") == (Data(#""text""#.utf8), .unchanged))
    }

    @Test("Values of keys that are not secret go through the value detectors")
    func detectedJSONValues() throws {
        let body = Data(#"{"note":"mail ada@example.com","n":4111111111111111,"m":12,"flag":true,"jwt":"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2ln"}"#.utf8)
        let object = try json(policy.redact(body: body, contentType: "application/json").body)
        #expect(object["note"] as? String == "mail \(redacted)")
        #expect(object["n"] as? String == redacted)
        #expect(object["m"] as? Int == 12)
        #expect(object["flag"] as? Bool == true)
        #expect(object["jwt"] as? String == redacted)
    }

    @Test("JSON inside a JSON string is parsed and redacted, as in GraphQL variables")
    func jsonInString() throws {
        let body = Data(#"{"query":"{ me }","variables":"{\"input\":{\"password\":\"hunter2\",\"name\":\"ada\"}}","note":"[not json"}"#.utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "application/json")
        #expect(outcome == .redacted)
        let object = try json(data)
        #expect(object["query"] as? String == "{ me }")
        // A bracket that does not close is a trigger in text.
        #expect(object["note"] as? String == redacted)
        // A JSON string is free text: JSON in it is cut at the value of its first member that is
        // not on the allowed text keys.
        #expect(object["variables"] as? String == #"{"input":"# + redacted)
        let allowing = RedactionPolicy(allowedTextKeys: ["input", "name"])
        let variables = try #require((try json(allowing.redact(body: body, contentType: "application/json").body)["variables"] as? String))
        #expect(variables == #"{"input":{"password":"# + redacted)
    }

    @Test("Bodies that do not parse, were cut off, are too large or nested too deeply are omitted", arguments: [
        (#"{"password": }"#, "application/json", true),
        (#"{"password":"abc"#, "application/json", false),
        (#"{"password":"x","n":1e400}"#, "application/json", true),
        (String(repeating: "[", count: 200) + "1" + String(repeating: "]", count: 200), "application/json", true),
        ("user=ada&password=s3", "application/x-www-form-urlencoded", false),
        ("a=100%&password=x", "application/x-www-form-urlencoded", true),
        ("--XyZ\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\nv\r\n", "multipart/form-data; boundary=XyZ", true),
    ] as [(String, String, Bool)])
    func omittedBodies(body: String, contentType: String, isComplete: Bool) {
        let data = Data(body.utf8)
        let mediaType = MediaType(contentType)?.description ?? ""
        #expect(policy.redact(body: data, contentType: contentType, isComplete: isComplete)
            == (Data("[body omitted: \(data.count) bytes, \(mediaType)]".utf8), .omitted))
    }

    @Test("Unknown, missing and malformed content types are omitted", arguments: [
        "application/xml", "text/html", "image/png", "application/octet-stream", "application/x-www-form-urlencoded\u{301}",
        "multipart/\u{301}form-data; boundary=XyZ", "json", "text/plain; charset=utf-16", "text/plain; charset",
    ])
    func unknownContentTypes(contentType: String) {
        let (data, outcome) = policy.redact(body: Data("password=hunter2".utf8), contentType: contentType)
        #expect(outcome == .omitted)
        #expect(!text(data).contains("hunter2"))
        #expect(policy.redact(body: Data("{}".utf8), contentType: nil).outcome == .omitted)
    }

    @Test("A body over the size limit is omitted before it is parsed")
    func oversizedBody() {
        let body = Data(("{\"a\":\"" + String(repeating: "x", count: RedactionPolicy.maximumCheckedBodySize) + "\"}").utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "application/json")
        #expect(outcome == .omitted)
        #expect(text(data) == "[body omitted: \(body.count) bytes, application/json]")
    }

    @Test("Form fields are decoded with the platform API, and names re-encoded only when changed")
    func formBody() {
        let body = Data("user=ada&pass%77ord=s3cret&remember=1&q=a+b%21&data=%7B%22password%22%3A%22hunter2%22%7D".utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "application/x-www-form-urlencoded; charset=utf-8")
        #expect(outcome == .redacted)
        #expect(text(data) == "user=ada&pass%77ord=\(redacted)&remember=1&q=a+b%21&data=%7B%22password%22%3A\(redacted)")
    }

    @Test("A form value that holds pairs or JSON goes through the value rule; a `;` makes the form unreadable")
    func formValueRule() {
        let body = Data("b=x%26token%3Dhunter2&c=1".utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "application/x-www-form-urlencoded")
        #expect(outcome == .redacted)
        #expect(text(data) == "b=x%26token%3D\(redacted)&c=1")
        // Some servers also split a form at `;`, so a form with one is omitted.
        let split = Data("a=1;password=hunter2&token;x=hunter2".utf8)
        #expect(policy.redact(body: split, contentType: "application/x-www-form-urlencoded").outcome == .omitted)
    }

    @Test("Plain text bodies go through the free-text rule")
    func plainText() {
        let body = Data("status=ok\npassword: hunter2\nnext line".utf8)
        let (data, outcome) = policy.redact(body: body, contentType: "text/plain; charset=utf-8")
        #expect(outcome == .redacted)
        #expect(text(data) == "status=ok\npassword: \(redacted)")
        #expect(policy.redact(body: Data(), contentType: "application/json") == (Data(), .unchanged))
    }

    @Test("A captured body that was cut off is omitted with the size of the whole body")
    func capturedBody() {
        let body = CapturedBody.capture(prefix: Data(#"{"tok"#.utf8), byteCount: 100, contentType: "application/json", policy: policy)
        #expect(body.isTruncated)
        #expect(body.byteCount == 100)
        #expect(body.redaction == .omitted)
        #expect(body.text == "[body omitted: 100 bytes, application/json]")
    }

    @Test("Text of a truncated body drops a character split by the limit")
    func splitCharacter() {
        let full = Data("ab€".utf8)
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

    @Test("JSON whose bytes are in another encoding than its charset names is omitted", arguments: [
        ("application/json; charset=utf-16", String.Encoding.utf8), ("application/json; charset=utf-8", .utf16LittleEndian),
        ("application/json; charset=utf-16be", .utf16LittleEndian), ("application/json; charset=utf-32", .utf16BigEndian),
    ])
    func jsonCharsetAgreement(contentType: String, encoding: String.Encoding) throws {
        let body = try #require(#"{"note":"hunter2"}"#.data(using: encoding))
        #expect(policy.redact(body: body, contentType: contentType).outcome == .omitted)
    }

    @Test("JSON in UTF-16 or UTF-32 that its charset names is read and stored as UTF-8", arguments: [
        ("application/json; charset=utf-16", String.Encoding.utf16LittleEndian), ("application/json; charset=utf-16be", .utf16BigEndian),
        ("application/json", .utf32LittleEndian), ("application/json; charset=utf-32be", .utf32BigEndian),
    ])
    func wideJSON(contentType: String, encoding: String.Encoding) throws {
        let body = try #require(#"{"note":"x","token":"hunter2"}"#.data(using: encoding))
        let (data, outcome) = policy.redact(body: body, contentType: contentType)
        #expect(outcome == .redacted)
        #expect(text(data) == #"{"note":"x","token":"[REDACTED]"}"#)
    }
}
