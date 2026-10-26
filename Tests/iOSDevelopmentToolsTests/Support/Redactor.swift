import Foundation
@testable import iOSDevelopmentTools

/// The redaction calls of the shared redaction test corpus in `Corpus/`, mapped onto
/// ``RedactionPolicy``: free text, bodies read back as text, and URLs. The corpus was first
/// written for the same redaction rules in iOSSecurityTools; keeping its calls lets the cases be
/// compared one to one.
struct Redactor: Sendable {
    let policy: RedactionPolicy

    init(_ policy: RedactionPolicy = .default) {
        self.policy = policy
    }

    /// The default policy with the body limit raised to 1 MiB, for the tests that time and read
    /// bodies of a megabyte.
    static let largeBodies = Redactor(RedactionPolicy(maximumBodySize: 1_048_576))

    init(
        allowedTextKeys: [String] = [], allowedQueryParameters: [String] = [], urlDetail: RedactionPolicy.URLDetail = .full,
        maximumBodySize: Int = RedactionPolicy.defaultMaximumBodySize
    ) {
        policy = RedactionPolicy(
            allowedQueryParameters: allowedQueryParameters, allowedTextKeys: allowedTextKeys, maximumBodySize: maximumBodySize, urlDetail: urlDetail)
    }

    var allowedTextKeys: Set<String> { policy.allowedTextKeys }
    var allowedQueryParameters: Set<String> { policy.allowedQueryParameters }
    var maximumBodySize: Int { policy.maximumBodySize }

    /// Free text, as ``RedactionPolicy/redact(text:)`` stores it.
    func redact(_ text: String) -> String {
        policy.redact(text: text)
    }

    /// A body as the stored bytes read as UTF-8.
    func redact(body: Data, contentType: String?) -> String {
        String(decoding: policy.redact(body: body, contentType: contentType).body, as: UTF8.self)
    }

    func redact(url: URL) -> String {
        policy.redact(url: url)
    }

    func allowsTextKey(_ name: some Collection<Unicode.Scalar>) -> Bool {
        policy.allowsTextKey(name)
    }

    func matches(in text: String) -> [RedactionPolicy.Match] {
        policy.matches(in: text)
    }

    func textSpans(
        in scalars: [Unicode.Scalar], text: NormalizedText, compatibility: CompatibilityText, role: FreeTextScanner.Role = .text,
        nesting: Nesting, detectsInRegions: Bool = false
    ) -> [RedactionPolicy.Span] {
        policy.textSpans(in: scalars, text: text, compatibility: compatibility, role: role, nesting: nesting, detectsInRegions: detectsInRegions)
    }
}

extension NormalizedText {
    /// The bytes of the scanning copy in `range`, as text.
    func string(_ range: Range<Int>) -> String {
        String(decoding: bytes[range], as: UTF8.self)
    }

    /// The addresses the email detector finds in the whole text.
    func emailSpans() -> [RedactionPolicy.Span] {
        var sink = SpanSink(capacity: count)
        emailSpans(into: &sink)
        return sink.spans
    }

    /// The tokens the bearer detector finds in the whole text.
    func bearerSpans() -> [RedactionPolicy.Span] {
        var sink = SpanSink(capacity: count)
        bearerSpans(into: &sink)
        return sink.spans
    }
}

/// The value detectors of ``RedactionPolicy`` alone, without the free-text rule and the key rule. The
/// shared corpus was written for a redactor that could be limited to some kinds of findings; here
/// the detectors of those kinds are run on their own, which is what such a redactor did with free
/// text.
struct DetectorRedactor: Sendable {
    let kinds: RedactionPolicy.Kinds

    init(kinds: RedactionPolicy.Kinds) {
        self.kinds = kinds
    }

    private func spans(in scalars: [Unicode.Scalar]) -> [RedactionPolicy.Span] {
        guard !scalars.isEmpty, !kinds.isEmpty else { return [] }
        let text = NormalizedText(scalars, compatibility: CompatibilityText(length: scalars.count))
        return RedactionPolicy.merged(RedactionPolicy.standard.detectorSpans(in: text).filter { !$0.kind.isDisjoint(with: kinds) })
    }

    func redact(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        let found = spans(in: scalars)
        return found.isEmpty ? text : RedactionPolicy.replacing(found, in: scalars)
    }

    func matches(in text: String) -> [(kind: RedactionPolicy.Kinds, text: String)] {
        let scalars = Array(text.unicodeScalars)
        return spans(in: scalars).map { ($0.kind, String(String.UnicodeScalarView(scalars[$0.start..<$0.end]))) }
    }
}
