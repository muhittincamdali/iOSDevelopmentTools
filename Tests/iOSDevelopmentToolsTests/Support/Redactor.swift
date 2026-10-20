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

    init(allowedTextKeys: [String] = [], allowedQueryParameters: [String] = [], urlDetail: RedactionPolicy.URLDetail = .full) {
        policy = RedactionPolicy(allowedQueryParameters: allowedQueryParameters, allowedTextKeys: allowedTextKeys, urlDetail: urlDetail)
    }

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
}
