import Foundation
import Testing
@testable import iOSDevelopmentTools

/// On iOS 18.6, `String(data:encoding: .utf8)` keeps a byte order mark at the start as U+FEFF; on
/// iOS 26.5 and macOS 27 it leaves it out. The review's probe `a-18#788`, a JSON body of a UTF-8
/// byte order mark and `{"x":"Qx788Np7v"}`, was therefore shown on one and omitted on the other,
/// as JSON allows no U+FEFF. Bodies are now decoded by ``BodyText``, which leaves out one byte
/// order mark at the start of a body on every version and keeps every other one. These tests run
/// on the iOS 18 simulator as well as on macOS and iOS 26.
@Suite("Redaction corpus: byte order marks")
struct RedactionByteOrderMarkTests {
    private static let mark: [UInt8] = [0xEF, 0xBB, 0xBF]

    private static func redacted(_ bytes: [UInt8], _ contentType: String) -> (text: String, outcome: RedactionOutcome, body: Data) {
        let (body, outcome) = RedactionPolicy.default.redact(body: Data(bytes), contentType: contentType)
        return (String(decoding: body, as: UTF8.self), outcome, body)
    }

    @Test("the review's probe a-18#788: a JSON body after a UTF-8 byte order mark is shown as it was sent")
    func reviewProbe() {
        let bytes = Self.mark + Array(#"{"x":"Qx788Np7v"}"#.utf8)
        let result = Self.redacted(bytes, "application/json")
        #expect(result.outcome == .unchanged && result.body == Data(bytes))
        let captured = CapturedBody.capture(prefix: Data(bytes), byteCount: bytes.count, contentType: "application/json", policy: .default)
        #expect(captured.redaction == .unchanged && captured.text?.hasSuffix(#"{"x":"Qx788Np7v"}"#) == true)
    }

    @Test("a JSON body after the byte order mark of UTF-8, UTF-16 or UTF-32 is read, and a secret in it is hidden", arguments: [
        String.Encoding.utf8, .utf16LittleEndian, .utf16BigEndian, .utf32LittleEndian, .utf32BigEndian,
    ])
    func jsonInEveryEncoding(encoding: String.Encoding) {
        let marks: [String.Encoding: [UInt8]] = [
            .utf8: Self.mark, .utf16LittleEndian: [0xFF, 0xFE], .utf16BigEndian: [0xFE, 0xFF],
            .utf32LittleEndian: [0xFF, 0xFE, 0, 0], .utf32BigEndian: [0, 0, 0xFE, 0xFF],
        ]
        let shown = marks[encoding]! + Array(#"{"x":"Qx788Np7v"}"#.data(using: encoding)!)
        #expect(Self.redacted(shown, "application/json").text == (encoding == .utf8 ? String(decoding: shown, as: UTF8.self) : #"{"x":"Qx788Np7v"}"#))
        let hidden = marks[encoding]! + Array(#"{"password":"hunter2","x":1}"#.data(using: encoding)!)
        #expect(Self.redacted(hidden, "application/json").text == #"{"password":"[REDACTED]","x":1}"#)
    }

    @Test("a second byte order mark is kept, and a JSON body with one is omitted on every version")
    func secondMark() {
        let result = Self.redacted(Self.mark + Self.mark + Array(#"{"x":"Qx788Np7v"}"#.utf8), "application/json")
        #expect(result.outcome == .omitted && !result.text.contains("Qx788Np7v"))
        #expect(BodyText.utf8(Self.mark + Self.mark + [0x61], dropsByteOrderMark: true) == "\u{FEFF}a")
        #expect(BodyText.utf8(Self.mark + [0x61], dropsByteOrderMark: false) == "\u{FEFF}a")
        #expect(BodyText.utf8([0x61, 0xFF], dropsByteOrderMark: true) == nil)
    }

    @Test("a text or form body after a byte order mark is read as the text after it")
    func textAndForm() {
        let text = Self.mark + Array("status=200 method=GET".utf8)
        #expect(Self.redacted(text, "text/plain").outcome == .unchanged)
        #expect(Self.redacted(Self.mark + Array("login password=hunter2".utf8), "text/plain").text == "login password=[REDACTED]")
        let form = Self.mark + Array("user=bob&status=200".utf8)
        #expect(Self.redacted(form, "application/x-www-form-urlencoded").outcome == .unchanged)
        #expect(Self.redacted(Self.mark + Array("password=hunter2&user=bob".utf8), "application/x-www-form-urlencoded").text
            == "password=[REDACTED]&user=bob")
    }

    @Test("a multipart part's headers keep a byte order mark, which omits the body; a part's text leaves it out")
    func multipart() {
        let type = "multipart/form-data; boundary=B"
        let header = Array("--B\r\n".utf8) + Self.mark + Array("Content-Disposition: form-data; name=\"a\"\r\n\r\nQx788Np7v\r\n--B--".utf8)
        #expect(Self.redacted(header, type).outcome == .omitted)
        func labelled(_ label: String) -> [UInt8] {
            Array("--B\r\nContent-Disposition: form-data; name=\"label\"\r\n\r\n".utf8) + Self.mark + Array(label.utf8)
                + Array("\r\n--B\r\nContent-Disposition: form-data; name=\"value\"\r\n\r\nQx788Np7v\r\n--B--".utf8)
        }
        #expect(!Self.redacted(labelled("Password"), type).text.contains("Qx788Np7v"))
        #expect(Self.redacted(labelled("Status"), type).text.contains("Qx788Np7v"))
    }
}
