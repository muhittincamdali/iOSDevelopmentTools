import Foundation

/// Decides what is hidden before a request, a response or a log message is stored.
///
/// The policy follows one rule: what it does not fully understand is hidden, never shown.
///
/// - **Keys** (JSON fields, query and form names, header names, `key=value` in text) are folded:
///   escapes are decoded, then NFKC, case folding, and `_`, `-`, `.` and spaces are removed. Only a
///   key that is then plain ASCII letters and digits is compared with ``secretNames``. Any other
///   key, for example one with a Cyrillic letter, a zero-width character or a `[`, has its value
///   hidden.
/// - **Values** of secret keys are hidden whole, whatever their type. Other values are scanned
///   for JWTs, bearer tokens, long hex or Base64 strings, card numbers, IBANs and email addresses.
/// - **Headers** keep their value only when the name is on ``allowedHeaders``.
/// - **URLs** lose their user info and fragment; query values are hidden unless the name is on
///   ``allowedQueryParameters``, and path segments that look like identifiers become `:id`.
/// - **Bodies** are parsed (JSON, forms, multipart, plain text). A body that cannot be parsed,
///   has an unknown content type, was cut off or is larger than ``maximumCheckedBodySize`` is
///   replaced by a note such as `[body omitted: 512 bytes, application/xml]`.
///
/// Redaction is a safety net, not a guarantee. Keep secrets out of logs in the first place.
public struct RedactionPolicy: Sendable, Hashable {
    /// How much of a URL is recorded.
    public enum URLDetail: Sendable, Hashable {
        /// Scheme, host, port, path and query, redacted.
        case full
        /// Scheme, host and port only.
        case hostOnly
    }

    /// The text that replaces a hidden value.
    public static let replacement = "[REDACTED]"

    /// The text that replaces a path segment that looks like an identifier or a secret.
    public static let identifierPlaceholder = ":id"

    /// What is recorded for a URL that cannot be parsed and has no host.
    public static let unparsedURL = "<unparsed URL>"

    /// Bodies larger than this are omitted without being parsed: 1 MiB.
    public static let maximumCheckedBodySize = 1_048_576

    /// The names whose values are always hidden: the shared list, then this library's extensions
    /// (`passphrase`, `credential`, `cvc`, `sessid`).
    ///
    /// A folded key matches a name of five or more letters when it contains it (`newPassword`,
    /// `x_refresh_token`), and a shorter name when one of its words is that name or it ends with
    /// it (`api-key`, `userPin`, `creditcard`).
    public static let defaultSecretNames: [String] = [
        "password", "passwd", "pwd", "secret", "token", "access_token", "refresh_token", "id_token",
        "api_key", "apikey", "key", "auth", "authorization", "cookie", "set-cookie", "session", "sid",
        "otp", "pin", "cvv", "card", "iban", "ssn", "private_key", "client_secret", "signature",
        "passphrase", "credential", "cvc", "sessid",
    ]

    /// The headers whose values are kept by default.
    public static let defaultAllowedHeaders: [String] = [
        "Accept", "Accept-Encoding", "Accept-Language", "Cache-Control", "Content-Encoding",
        "Content-Length", "Content-Type", "ETag", "User-Agent",
    ]

    /// The default policy: the default secret names and header allowlist, no query values kept.
    public static let `default` = RedactionPolicy()

    /// A policy that stores everything as it was sent and received. Use it only with test
    /// servers and test accounts.
    public static let disabled = RedactionPolicy(isEnabled: false, secretNames: [], allowedHeaders: [], allowedQueryParameters: [], urlDetail: .full)

    /// Whether the policy changes anything at all.
    public let isEnabled: Bool

    /// The folded secret names: ``defaultSecretNames`` and the names passed to the initializer.
    public let secretNames: Set<String>

    /// The folded names of the headers whose values are kept.
    public let allowedHeaders: Set<String>

    /// The folded names of the query parameters whose values are kept. Empty by default.
    public let allowedQueryParameters: Set<String>

    /// How much of a URL is recorded.
    public let urlDetail: URLDetail

    let secretNameMatcher: SecretNameMatcher

    /// Creates a policy.
    ///
    /// - Parameters:
    ///   - additionalSecretNames: Names to hide in addition to ``defaultSecretNames``. The default
    ///     names cannot be removed.
    ///   - allowedHeaders: The headers whose values are kept. Headers that are always hidden
    ///     (`Authorization`, `Cookie`, names with `token`, `key`, …) stay hidden when listed.
    ///   - allowedQueryParameters: The query parameters whose values are kept. A secret name
    ///     stays hidden when listed.
    ///   - urlDetail: How much of a URL is recorded.
    public init(
        additionalSecretNames: [String] = [],
        allowedHeaders: [String] = RedactionPolicy.defaultAllowedHeaders,
        allowedQueryParameters: [String] = [],
        urlDetail: URLDetail = .full
    ) {
        self.init(
            isEnabled: true, secretNames: Self.defaultSecretNames + additionalSecretNames,
            allowedHeaders: allowedHeaders, allowedQueryParameters: allowedQueryParameters, urlDetail: urlDetail)
    }

    private init(isEnabled: Bool, secretNames: [String], allowedHeaders: [String], allowedQueryParameters: [String], urlDetail: URLDetail) {
        self.isEnabled = isEnabled
        self.secretNames = Self.plainNames(secretNames)
        secretNameMatcher = SecretNameMatcher(names: self.secretNames)
        self.allowedHeaders = Self.plainNames(allowedHeaders)
        self.allowedQueryParameters = Self.plainNames(allowedQueryParameters)
        self.urlDetail = urlDetail
    }

    /// The folded names that can match a key; names that are empty or not plain ASCII after
    /// folding can match nothing and are dropped.
    private static func plainNames(_ names: [String]) -> Set<String> {
        Set(names.map(FoldedKey.init).filter { $0.isPlain && !$0.folded.isEmpty }.map(\.folded))
    }

    /// Whether a value under this key (a JSON field, a query or form name, a header name) is
    /// hidden: the key is a secret name, or it is not plain ASCII after folding.
    public func isSensitive(name: String) -> Bool {
        isEnabled && hidesValue(of: FoldedKey(name))
    }
}
