import Foundation
import Testing
@testable import iOSDevelopmentTools

/// A span keeps its offsets in 28 bits. 2.1.1 kept the low 28 bits of an offset that did not fit,
/// so the span that hides a text longer than ``RedactionPolicy/maximumTextLength`` ended near its
/// start and the rest of the text was written as it was (spec §8.1 #17c, KL-D5b).
@Suite("Redaction: a span whose offsets do not fit")
struct RedactionSpanOffsetTests {
    static let secret = "hunter2"
    static let scalars = Array(("status=200 " + String(repeating: "ok ", count: 100) + secret).unicodeScalars)
    static let beyond = 1 << 28

    @Test("hides the whole text", arguments: [
        (0, beyond + 100), (0, beyond), (0, 2 * beyond + 5), (beyond + 150, beyond + 160), (5, beyond + 1), (-1, 10),
    ])
    func hidesWholeText(start: Int, end: Int) {
        let span = RedactionPolicy.Span(start: start, end: end, kind: .secretFields, replacement: RedactionPolicy.replacement)
        #expect(RedactionPolicy.replacing([span], in: Self.scalars) == RedactionPolicy.replacement)
        #expect(RedactionPolicy.replacing(RedactionPolicy.merged([span]), in: Self.scalars) == RedactionPolicy.replacement)
    }

    @Test("hides the whole text with the replacement, whatever it was made to write")
    func writesTheReplacement() {
        let span = RedactionPolicy.Span(start: 0, end: Self.beyond + 100, kind: .secretFields, replacement: "https://example.com/" + Self.secret)
        #expect(RedactionPolicy.replacing([span], in: Self.scalars) == RedactionPolicy.replacement)
    }

    @Test("joins the spans beside it into one replacement")
    func joinsOtherSpans() {
        let spans = [
            RedactionPolicy.Span(start: 3, end: 6, kind: .cardNumbers, replacement: RedactionPolicy.replacement),
            RedactionPolicy.Span(start: 0, end: Self.beyond + 100, kind: .secretFields, replacement: RedactionPolicy.replacement),
            RedactionPolicy.Span(start: 20, end: 30, kind: .emailAddresses, replacement: "x"),
        ]
        let merged = RedactionPolicy.merged(spans)
        #expect(merged.count == 1)
        #expect(RedactionPolicy.replacing(merged, in: Self.scalars) == RedactionPolicy.replacement)
    }

    @Test("keeps offsets that fit, up to the longest text that is read")
    func keepsOffsetsThatFit() {
        let longest = RedactionPolicy.maximumTextLength
        let span = RedactionPolicy.Span(start: longest - 1, end: longest, kind: .cardNumbers, replacement: "x")
        #expect(span.start == longest - 1 && span.end == longest && span.kind == .cardNumbers)
        let short = RedactionPolicy.Span(start: 3, end: 6, kind: .cardNumbers, replacement: "x")
        #expect(RedactionPolicy.replacing([short], in: Array("abcdefgh".unicodeScalars)) == "abcxgh")
    }

    /// A setter made a new span from the offsets the old one reported, and a span that hides the
    /// whole text reports 0 and `Int.max`: setting its end to an offset that fits made it hide
    /// only the scalars before that offset.
    @Test("keeps the offsets it was made with: neither can be set afterwards")
    func offsetsAreFixed() {
        #expect(!(\RedactionPolicy.Span.start as AnyKeyPath is WritableKeyPath<RedactionPolicy.Span, Int>))
        #expect(!(\RedactionPolicy.Span.end as AnyKeyPath is WritableKeyPath<RedactionPolicy.Span, Int>))
    }

    /// A span made for a longer text has offsets that mean nothing in this one; what it shows of
    /// this text is not known to be safe.
    @Test("hides the whole text when a span ends past it", arguments: [(5, 19), (17, 40), (18, 19), (0, 19)])
    func spanPastTheText(start: Int, end: Int) {
        let scalars = Array("status=200 hunter2".unicodeScalars)
        let span = RedactionPolicy.Span(start: start, end: end, kind: .secretFields, replacement: RedactionPolicy.replacement)
        let inside = RedactionPolicy.Span(start: 0, end: 2, kind: .cardNumbers, replacement: "x")
        #expect(RedactionPolicy.replacing([span], in: scalars) == RedactionPolicy.replacement)
        #expect(RedactionPolicy.replacing(RedactionPolicy.merged([inside, span]), in: scalars) == RedactionPolicy.replacement)
    }

    @Test("the limits fit the span: the longest text, every body, a log message and the kinds")
    func limitsFit() {
        #expect(RedactionPolicy.maximumTextLength == RedactionPolicy.Span.maximumOffset)
        #expect(RedactionPolicy.maximumTextLength == (1 << 28) - 1)
        #expect(RedactionPolicy.bodySizeLimit <= RedactionPolicy.maximumTextLength)
        #expect(LogStore.maximumRedactedMessageLength <= RedactionPolicy.maximumTextLength)
        #expect(RedactionPolicy.Kinds.all.rawValue <= 0x7F)
        #expect(RedactionPolicy.default.textLengthLimit == RedactionPolicy.maximumTextLength)
        #expect(RedactionPolicy(.default, textLengthLimit: .max).textLengthLimit == RedactionPolicy.maximumTextLength)
        #expect(RedactionPolicy(.default, textLengthLimit: -1).textLengthLimit == 0)
    }
}

/// Spec §8.1 #17c with the limit made short for the test: a text longer than the policy reads is
/// written as the replacement alone on every path that reads text, and never goes through a
/// span. The real limit is 2^28 − 1 scalars; a text of 2^28 + 99 took 1.6 GB to show the 2.1.1
/// leak, so the paths are checked at a limit of 64.
@Suite("Redaction: a text longer than the policy reads")
struct RedactionTextLengthLimitTests {
    static let limit = 64
    static let policy = RedactionPolicy(.default, textLengthLimit: limit)
    static let lengths = [limit + 1, limit + 100, 2 * limit + 5]
    static let replacement = RedactionPolicy.replacement

    /// A text of `length` scalars with no trigger, which free text reads to its end, and a secret
    /// without a label at the end: read, it is written as it is.
    static func text(length: Int) -> String {
        let head = "status=200 "
        let tail = " " + RedactionSpanOffsetTests.secret
        return head + String(repeating: "o", count: length - head.count - tail.count) + tail
    }

    /// The words of ``text(length:)`` for a query or a form, where `+` is a space: `length`
    /// scalars without a trigger, ending in the secret.
    static func formWords(length: Int) -> String {
        let tail = "+" + RedactionSpanOffsetTests.secret
        return String(String(repeating: "ok+", count: length).prefix(length - tail.count)) + tail
    }

    @Test("free text and a log message are the replacement alone", arguments: lengths)
    func freeText(length: Int) {
        let input = Self.text(length: length)
        #expect(input.unicodeScalars.count == length)
        #expect(RedactionPolicy.default.redact(text: input) == input)
        #expect(Self.policy.redact(text: input) == Self.replacement)
        #expect(Self.policy.redact(text: "password " + input) == Self.replacement)
        #expect(LogStore.redacted(input, with: Self.policy) == Self.replacement)
        #expect(Self.policy.matches(in: input).map(\.range) == [input.startIndex..<input.endIndex])
    }

    @Test("a text as long as the limit, or shorter, is read as before", arguments: [limit, limit - 1, 40])
    func atTheLimit(length: Int) {
        let input = Self.text(length: length)
        #expect(Self.policy.redact(text: input) == input)
        let cut = "login " + String(repeating: "o", count: length - 23) + " password=hunter2"
        #expect(cut.unicodeScalars.count == length)
        #expect(Self.policy.redact(text: cut) == RedactionPolicy.default.redact(text: cut))
        #expect(Self.policy.redact(text: cut).hasSuffix("password=" + Self.replacement))
        #expect(Self.policy.redact(headers: [HTTPHeader(name: "Accept", value: input)])[0].value == input)
    }

    @Test("a kept header value is the replacement alone", arguments: lengths)
    func headerValue(length: Int) {
        let headers = [HTTPHeader(name: "Accept", value: Self.text(length: length)), HTTPHeader(name: "Content-Length", value: "12")]
        #expect(Self.policy.redact(headers: headers).map(\.value) == [Self.replacement, "12"])
    }

    @Test("an allowed query value is the replacement alone, and a path segment hides the next", arguments: lengths)
    func url(length: Int) throws {
        let value = Self.formWords(length: length)
        let allowing = RedactionPolicy(RedactionPolicy(allowedQueryParameters: ["q"]), textLengthLimit: Self.limit)
        let query = try #require(URL(string: "https://example.com/a?q=\(value)&page=2"))
        #expect(RedactionPolicy(allowedQueryParameters: ["q"]).redact(url: query) == "https://example.com/a?q=\(value)&page=[REDACTED]")
        #expect(allowing.redact(url: query) == "https://example.com/a?q=[REDACTED]&page=[REDACTED]")
        // A token-shaped segment is `:id` at any length; only one longer than the limit hides the next.
        let segment = "ok-" + String(repeating: "o", count: length - 11) + "-" + RedactionSpanOffsetTests.secret
        let path = try #require(URL(string: "https://example.com/\(segment)/next"))
        #expect(RedactionPolicy.default.redact(url: path) == "https://example.com/:id/next")
        #expect(Self.policy.redact(url: path) == "https://example.com/:id/:id")
        #expect(Self.policy.redactedPath(of: path) == "/:id/:id")
    }

    @Test("a text/plain body, a JSON string and name and a form value are the replacement alone", arguments: lengths)
    func bodies(length: Int) {
        func body(_ text: String, _ type: String) -> String {
            String(decoding: Self.policy.redact(body: Data(text.utf8), contentType: type).body, as: UTF8.self)
        }
        let input = Self.text(length: length)
        #expect(body(input, "text/plain") == Self.replacement)
        #expect(body(#"{"note":"\#(input)","id":"7"}"#, "application/json") == #"{"note":"[REDACTED]","id":"7"}"#)
        // A name that is not plain hides its value whatever its length; read, the name shows.
        #expect(body(#"{"\#(input)":1}"#, "application/json") == #"{"[REDACTED]":"[REDACTED]"}"#)
        let form = "status=\(Self.formWords(length: length))&count=1"
        let formType = "application/x-www-form-urlencoded"
        #expect(String(decoding: RedactionPolicy.default.redact(body: Data(form.utf8), contentType: formType).body, as: UTF8.self) == form)
        #expect(body(form, formType) == "status=[REDACTED]&count=1")
    }

    @Test("a multipart text part and a field name are the replacement alone", arguments: lengths)
    func multipart(length: Int) {
        let input = Self.text(length: length)
        let type = "multipart/form-data; boundary=B0und"
        func part(name: String, content: String) -> String {
            "--B0und\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(content)\r\n--B0und--"
        }
        let redacted = { (text: String) in String(decoding: Self.policy.redact(body: Data(text.utf8), contentType: type).body, as: UTF8.self) }
        #expect(redacted(part(name: "note", content: input)) == part(name: "note", content: Self.replacement))
        // A field name that is not plain hides its content whatever its length; read, the name shows.
        #expect(redacted(part(name: input, content: "ok")) == part(name: Self.replacement, content: Self.replacement))
    }
}
