import Foundation

/// Decides which values are replaced before a request or response is stored.
///
/// A header, query parameter, form field, multipart field or JSON key is sensitive when its
/// normalized name contains one of the policy's name fragments. Normalizing lowercases the name,
/// removes percent-encoding and drops every character that is not an ASCII letter or digit, so
/// `Authorization`, `X-API-Key`, `api_key`, `apiKey`, `API%5FKEY` and `pass\u{200B}word` all
/// match the fragments `authorization`, `apikey` and `password`.
///
/// Matching on fragments errs on the side of hiding too much: with the default fragments a JSON
/// key named `author` is hidden because it contains `auth`. Pass your own fragments to change that.
public struct RedactionPolicy: Sendable, Hashable {
    /// The text that replaces a sensitive value.
    public static let replacement = "[REDACTED]"

    /// The name fragments that the default policy treats as sensitive.
    public static let defaultNameFragments: [String] = [
        "auth", "cookie", "token", "secret", "password", "passwd", "passphrase", "apikey",
        "session", "signature", "credential", "privatekey", "cardnumber", "cvv", "cvc",
    ]

    /// The default policy: ``defaultNameFragments``, and bodies that cannot be checked are withheld.
    public static let `default` = RedactionPolicy()

    /// A policy that stores everything as it was sent and received.
    public static let disabled = RedactionPolicy(nameFragments: [], withholdsUncheckedBodies: false)

    /// The normalized name fragments. Empty fragments are dropped, because they would match every name.
    public let nameFragments: Set<String>

    /// Whether a body that looks structured (JSON, a form, multipart) but cannot be parsed, or was
    /// cut off at the capture limit, is withheld instead of stored unchecked.
    ///
    /// A truncated JSON body cannot be parsed, so without this a secret in its first bytes would
    /// be stored as it was sent.
    public let withholdsUncheckedBodies: Bool

    /// Creates a policy.
    ///
    /// - Parameters:
    ///   - nameFragments: Names, or parts of names, to treat as sensitive. They are normalized
    ///     the same way as the names they are compared with.
    ///   - withholdsUncheckedBodies: Whether to withhold structured bodies that cannot be checked.
    public init(
        nameFragments: some Sequence<String> = RedactionPolicy.defaultNameFragments,
        withholdsUncheckedBodies: Bool = true
    ) {
        self.nameFragments = Set(nameFragments.map(Self.normalized).filter { !$0.isEmpty })
        self.withholdsUncheckedBodies = withholdsUncheckedBodies
    }

    /// Whether the policy changes anything at all.
    public var isEnabled: Bool { !nameFragments.isEmpty }

    /// Whether a header, parameter or field with this name has its value replaced.
    public func isSensitive(name: String) -> Bool {
        guard isEnabled else { return false }
        let normalizedName = Self.normalized(name)
        guard !normalizedName.isEmpty else { return false }
        return nameFragments.contains { normalizedName.contains($0) }
    }

    /// The name reduced to lowercase ASCII letters and digits, after removing percent-encoding.
    ///
    /// Decoding is repeated (at most four times) so a doubly encoded name is caught as well.
    static func normalized(_ name: String) -> String {
        var decoded = name.replacingOccurrences(of: "+", with: " ")
        for _ in 0..<4 {
            guard decoded.contains("%"), let next = decoded.removingPercentEncoding, next != decoded else { break }
            decoded = next
        }
        var result = String.UnicodeScalarView()
        for scalar in decoded.unicodeScalars where scalar.isASCII {
            switch scalar.value {
            case 0x30...0x39, 0x61...0x7A: result.append(scalar)
            case 0x41...0x5A: result.append(Unicode.Scalar(UInt8(scalar.value + 0x20)))
            default: continue
            }
        }
        return String(result)
    }
}
