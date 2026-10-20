import Foundation

/// Decides what is hidden before a request, a response or a log message is stored.
///
/// The policy follows one rule: what it does not fully understand is hidden, never shown.
///
/// - **Keys** (JSON member names, form, query and multipart field names, header names) are read
///   after their escapes are decoded. Only a key made of ASCII letters, digits, `_`, `-`, `.` and
///   spaces is compared with ``secretNames``; the separators are folded away and the letters
///   lowercased, so `PASS-WORD` reads as `password`. Any other key, for example one with a
///   Cyrillic letter, a full-width letter, a zero-width character or a `[`, has its value hidden.
/// - **Values** of secret keys are hidden whole, whatever their type. Other values are scanned
///   for JWTs, bearer tokens, long hex or Base64 strings, card numbers, IBANs and email addresses.
/// - **Free text** (log messages, error descriptions, kept header values, `text/plain` bodies)
///   has no grammar, so it works the other way round: the value of a `key=value`, `key: value` or
///   `"key":"value"` pair, also inside JSON written in the text, is kept only when the key is on
///   ``allowedTextKeys``. See ``redact(text:)``.
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

    /// The most JSON objects and arrays open at once, counted across every document a text is in:
    /// 64. JSON in a string inside one object may open 63 more.
    public static let maximumJSONDepth = Nesting.maximumDepth

    /// The most documents read one inside another: 4. A body, JSON in a line of text, a URL and a
    /// multipart part each count; JSON in a string of a JSON body is the second.
    public static let maximumNestedDocuments = Nesting.maximumLevel

    /// A URL whose path has more segments than this is recorded with its scheme, host and port
    /// only: 64.
    public static let maximumPathSegments = 64

    /// A URL whose query, or whose path, has more parameters than this is recorded with its
    /// scheme, host and port only: 128.
    public static let maximumQueryParameters = 128

    /// The names whose values are always hidden, folded: the list the redaction rules share with
    /// other packages (`password`, `passwd`, `pwd`, `secret`, `token`, `accesstoken`,
    /// `refreshtoken`, `idtoken`, `apikey`, `key`, `auth`, `authorization`, `cookie`, `session`,
    /// `sid`, `otp`, `pin`, `cvv`, `card`, `iban`, `ssn`, `privatekey`, `clientsecret`,
    /// `signature`) and this library's extensions (`passphrase`, `passcode`, `credential`, `cvc`,
    /// `sessid`, `pincode`, `verificationcode`, `cardnumber`, `pass`, `pw`, …).
    ///
    /// Words of five or more letters count anywhere in a key (`dbPassword`), shorter ones as a
    /// word of the key or at its end (`user_pin`, `X-Auth-Key`, `apitoken`), `pass`, `pw` and
    /// `sid` only as a word (`DB_PASS`, but not `bypass` or `inside`). A plural `s` after the word
    /// counts too (`tokens`).
    public static let defaultSecretNames: [String] = SecretNameTable.defaultWords

    /// The headers whose values are kept by default.
    public static let defaultAllowedHeaders: [String] = [
        "Accept", "Accept-Encoding", "Accept-Language", "Cache-Control", "Content-Encoding",
        "Content-Length", "Content-Type", "ETag", "User-Agent",
    ]

    /// The keys whose values free text keeps: harmless names that logs use for numbers and routes.
    /// The keys passed to the initializer are added to them.
    public static let defaultAllowedTextKeys: [String] = [
        "status", "status_code", "method", "path", "duration", "duration_ms", "count", "size", "bytes",
        "page", "limit", "offset", "attempt", "level",
    ]

    /// The default policy: the default secret names, header and text key allowlists, no query
    /// values kept.
    public static let `default` = RedactionPolicy()

    /// A policy that stores everything as it was sent and received. Use it only with test
    /// servers and test accounts.
    public static let disabled = RedactionPolicy(
        isEnabled: false, secretNames: [], allowedHeaders: [], allowedQueryParameters: [], allowedTextKeys: [], urlDetail: .full)

    /// Whether the policy changes anything at all.
    public let isEnabled: Bool

    /// The folded secret names: ``defaultSecretNames`` and the names passed to the initializer.
    public var secretNames: Set<String> { secretNameTable.words }

    /// The folded names of the headers whose values are kept. A name that is not plain ASCII or
    /// names a secret is never on it.
    public let allowedHeaders: Set<String>

    /// The folded names of the query parameters whose values are kept. Empty by default. A name
    /// that is not plain ASCII or names a secret is never on it.
    public let allowedQueryParameters: Set<String>

    /// The folded keys whose values free text keeps: ``defaultAllowedTextKeys`` and the keys passed
    /// to the initializer. A key that is not plain ASCII or names a secret is never on it.
    public private(set) var allowedTextKeys: Set<String>

    /// How much of a URL is recorded.
    public let urlDetail: URLDetail

    /// The secret words and where they count, built once for the policy.
    let secretNameTable: SecretNameTable

    /// The keys whose values a kept header value keeps: ``allowedTextKeys`` and the parameters of
    /// the default allowed headers.
    let headerValueKeys: Set<String>

    /// Creates a policy.
    ///
    /// - Parameters:
    ///   - additionalSecretNames: Names to hide in addition to ``defaultSecretNames``. The default
    ///     names cannot be removed. A name that is not plain ASCII is dropped: it could only match
    ///     keys that are hidden anyway.
    ///   - allowedHeaders: The headers whose values are kept. Headers that are always hidden
    ///     (`Authorization`, `Cookie`, names with `token`, `key`, …) stay hidden when listed.
    ///   - allowedQueryParameters: The query parameters whose values are kept. A secret name
    ///     stays hidden when listed.
    ///   - allowedTextKeys: Keys whose values free text keeps, in addition to
    ///     ``defaultAllowedTextKeys``. A secret name stays hidden when listed.
    ///   - urlDetail: How much of a URL is recorded.
    public init(
        additionalSecretNames: [String] = [],
        allowedHeaders: [String] = RedactionPolicy.defaultAllowedHeaders,
        allowedQueryParameters: [String] = [],
        allowedTextKeys: [String] = [],
        urlDetail: URLDetail = .full
    ) {
        self.init(
            isEnabled: true, secretNames: additionalSecretNames, allowedHeaders: allowedHeaders,
            allowedQueryParameters: allowedQueryParameters, allowedTextKeys: Self.defaultAllowedTextKeys + allowedTextKeys,
            urlDetail: urlDetail)
    }

    private init(
        isEnabled: Bool, secretNames: [String], allowedHeaders: [String], allowedQueryParameters: [String],
        allowedTextKeys: [String], urlDetail: URLDetail
    ) {
        self.isEnabled = isEnabled
        let added = Set(secretNames.compactMap { PlainName($0.unicodeScalars)?.folded })
        let table = added.isEmpty ? SecretNameTable.standard : SecretNameTable(words: added)
        func allowable(_ names: [String]) -> Set<String> {
            Set(names.compactMap { name in
                PlainName(name.unicodeScalars).flatMap { $0.namesSecret(in: table) ? nil : $0.folded }
            })
        }
        secretNameTable = table
        self.allowedHeaders = allowable(allowedHeaders)
        self.allowedQueryParameters = allowable(allowedQueryParameters)
        let textKeys = allowable(allowedTextKeys)
        self.allowedTextKeys = textKeys
        headerValueKeys = textKeys.union(allowable(Self.headerParameterNames))
        self.urlDetail = urlDetail
    }

    /// The parameters of the default allowed headers: `charset` and `boundary` of
    /// `Content-Type`, the `q` of `Accept` lists and the `Cache-Control` directives with a value.
    static let headerParameterNames = [
        "charset", "boundary", "q", "max-age", "s-maxage", "max-stale", "min-fresh", "stale-while-revalidate", "stale-if-error",
    ]

    /// Whether a value under this key (a JSON field, a query or form name, a header name) is
    /// hidden: the key is a secret name, or it is not plain ASCII.
    public func isSensitive(name: String) -> Bool {
        isEnabled && hidesValue(ofKey: name.unicodeScalars)
    }

    /// This policy with `keys` as the keys whose values free text keeps.
    func allowingTextKeys(_ keys: Set<String>) -> RedactionPolicy {
        var policy = self
        policy.allowedTextKeys = keys
        return policy
    }
}
