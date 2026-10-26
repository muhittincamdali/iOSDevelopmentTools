import Foundation

/// Decides what is hidden before a request, a response or a log message is stored.
///
/// The policy follows one rule: what it does not fully understand is hidden, never shown. It is a
/// safety net for mistakes, not a guarantee: keep secrets out of logs in the first place.
///
/// - **Keys** (JSON member names, form, query and multipart field names, header names) are read
///   after their escapes are decoded. Only a key made of ASCII letters, digits, `_`, `-`, `.` and
///   spaces is compared with ``secretNames``; the separators are folded away and the letters
///   lowercased, so `PASS-WORD` reads as `password`. Any other key, for example one with a
///   Cyrillic letter, a full-width letter, a zero-width character or a `[`, has its value hidden.
///   One function makes this decision for every path, also for names written as values
///   (`{"name":"Authorization","value":…}`, JSON Patch `path`, two-element arrays).
/// - **Values** of secret keys are hidden whole, whatever their type. Other values are scanned
///   for JWTs, bearer tokens, long hex or Base64 strings, card numbers, IBANs and email addresses.
/// - **Free text** (log messages, error descriptions, kept header values, `text/plain` bodies,
///   strings in JSON and forms) has no grammar, so it has one cut point: from the first trigger,
///   such as a key that is not on ``allowedTextKeys`` (`x=…`), a secret name or a quote that does
///   not close, everything to the end of the text is hidden. JSON written in the text is read
///   with its parser; a URL in it is shown only when it is clean. See ``redact(text:)``.
/// - **Headers** keep their value only when the name is on ``allowedHeaders``.
/// - **URLs** lose their user info and fragment; query values are hidden unless the name is on
///   ``allowedQueryParameters``, path segments that look like identifiers become `:id`, and a
///   host that names a secret is hidden with everything after it.
/// - **Bodies** are parsed (JSON, forms, multipart, plain text). A body that cannot be parsed,
///   has an unknown content type, was cut off or is larger than ``maximumBodySize`` (256 KiB by
///   default) is replaced by a note such as `[body omitted: 512 bytes, application/xml]`.
///
/// See <doc:RedactingSensitiveData> for the full rules, the limits and what they do not find.
public struct RedactionPolicy: Sendable, Hashable {
    /// How much of a URL is recorded.
    public enum URLDetail: Sendable, Hashable {
        /// Scheme, host, port, path and query, redacted.
        case full
        /// Scheme, host and port only.
        case hostOnly
    }

    /// What a finding is, kept with each replacement so that overlapping findings join into one.
    struct Kinds: OptionSet, Sendable, Hashable {
        let rawValue: Int

        static let cardNumbers = Kinds(rawValue: 1 << 0)
        static let emailAddresses = Kinds(rawValue: 1 << 1)
        static let jsonWebTokens = Kinds(rawValue: 1 << 2)
        static let bearerTokens = Kinds(rawValue: 1 << 3)
        /// Values hidden by their key, by the free-text rule or by the URL rules, and the password
        /// in `user:password@host` in text.
        static let secretFields = Kinds(rawValue: 1 << 4)
        static let ibans = Kinds(rawValue: 1 << 5)
        static let longTokens = Kinds(rawValue: 1 << 6)
        static let all: Kinds = [.cardNumbers, .emailAddresses, .jsonWebTokens, .bearerTokens, .secretFields, .ibans, .longTokens]
    }

    /// A finding in a text: what it is and where.
    struct Match: Sendable, Hashable {
        let kind: Kinds
        let range: Range<String.Index>
    }

    /// The text that replaces a hidden value.
    public static let replacement = "[REDACTED]"

    /// The text that replaces a path segment that looks like an identifier or a secret.
    public static let identifierPlaceholder = ":id"

    /// What is recorded for a URL that `URLComponents` cannot parse or that has no scheme and host.
    public static let unparsedURL = "<unparsed URL>"

    /// The default of ``maximumBodySize``: 256 KiB.
    public static let defaultMaximumBodySize = 262_144

    /// The largest value ``maximumBodySize`` accepts: 16 MiB.
    public static let bodySizeLimit = 16 * 1_048_576

    /// The most JSON objects and arrays open at once, counted across every document a text is in:
    /// 64. JSON in a string inside one object may open 63 more.
    public static let maximumJSONDepth = Nesting.maximumDepth

    /// The most documents read one inside another: 4. A body, JSON in a line of text, a URL and a
    /// multipart part each count; JSON in a string of a JSON body is the second.
    public static let maximumNestedDocuments = Nesting.maximumLevel

    /// A URL whose path has more segments than this is recorded with its scheme, host and port
    /// only: 64.
    public static let maximumPathSegments = 64

    /// A URL whose query has more parameters than this is recorded with its scheme, host and
    /// port only: 128.
    public static let maximumQueryParameters = 128

    /// The names whose values are always hidden, folded: the list the redaction rules share with
    /// other packages (`password`, `passwd`, `pwd`, `secret`, `token`, `accesstoken`,
    /// `refreshtoken`, `idtoken`, `apikey`, `key`, `auth`, `authorization`, `cookie`, `session`,
    /// `sid`, `otp`, `pin`, `cvv`, `card`, `iban`, `ssn`, `privatekey`, `clientsecret`,
    /// `signature`) and this library's extensions (`passphrase`, `passcode`, `credential`, `cvc`,
    /// `sessid`, `pincode`, `verificationcode`, `cardnumber`, `bearer`, `pass`, `pw`, …).
    ///
    /// Words of five or more letters count anywhere in a key (`dbPassword`, `session_data`),
    /// shorter ones and `token`, `secret` and `bearer` as a word of the key or at its end
    /// (`user_pin`, `X-Auth-Key`, `apitoken`), `pass`, `pw` and `sid` only as a word (`DB_PASS`,
    /// but not `bypass` or `inside`). A plural `s` after the word counts too (`tokens`).
    public static let defaultSecretNames: [String] = SecretNameTable.defaultWords

    /// The headers whose values are kept by default.
    public static let defaultAllowedHeaders: [String] = [
        "Accept", "Accept-Encoding", "Accept-Language", "Cache-Control", "Content-Encoding",
        "Content-Length", "Content-Type", "ETag", "User-Agent",
    ]

    /// The keys after which free text is read on by default: names that logs use for a response
    /// status, a request method and route, a duration and a count. After any other key, free text
    /// is hidden to its end (see ``redact(text:)``). The keys passed to the initializer are added
    /// to them.
    public static let defaultAllowedTextKeys: [String] = ["status", "method", "path", "duration_ms", "count"]

    /// The default policy: the default secret names, allowed headers and allowed text keys, no
    /// query values kept.
    public static let `default` = RedactionPolicy()

    /// A policy that stores everything as it was sent and received. Use it only with test
    /// servers and test accounts.
    public static let disabled = RedactionPolicy(
        isEnabled: false, secretNames: [], allowedHeaders: [], allowedQueryParameters: [], allowedTextKeys: [],
        maximumBodySize: defaultMaximumBodySize, urlDetail: .full)

    /// A policy with the default settings, made once and shared by the readings that need one
    /// inside a redaction: the words of an array element, the value detectors of a path segment.
    static let standard = RedactionPolicy()

    /// Whether the policy changes anything at all.
    public let isEnabled: Bool

    /// The folded secret names: ``defaultSecretNames`` and the names passed to the initializer.
    public var secretNames: Set<String> { secretNameTable.words }

    /// The secret words and where they count, built once for the policy: the default ones and the
    /// names passed to the initializer.
    let secretNameTable: SecretNameTable

    /// The folded names of the headers whose values are kept. A name that is not plain ASCII or
    /// names a secret is never on it.
    public let allowedHeaders: Set<String>

    /// The folded names of the query parameters whose values are kept. Empty by default. A name
    /// that is not plain ASCII or names a secret is never on it. It applies to URLs that are
    /// recorded as URLs (``redact(url:)``, a request's URL), not to a URL written in free text,
    /// which is shown only when it is clean and has no query at all (see ``redact(text:)``).
    public let allowedQueryParameters: Set<String>

    /// The folded keys after which free text is read on: ``defaultAllowedTextKeys`` and the keys
    /// passed to the initializer, lowercased and without `_`, `-`, `.` and spaces. A name that is
    /// not plain ASCII or names a secret is never on it.
    public let allowedTextKeys: Set<String>

    /// How much of a URL is recorded.
    public let urlDetail: URLDetail

    /// Bodies larger than this, in bytes, are omitted without being parsed. Reading a body takes
    /// memory in proportion to its size: the tests check that a body of 256 KiB in any shape takes
    /// less than 16 MB more.
    public let maximumBodySize: Int

    /// Creates a policy.
    ///
    /// - Parameters:
    ///   - additionalSecretNames: Names to hide in addition to ``defaultSecretNames``. The default
    ///     names cannot be removed. An added name of five or more letters counts anywhere in a
    ///     key, a shorter one as a word of it or at its end; in free text and in names written as
    ///     values it is read as the default names are. A name that is not plain ASCII is dropped:
    ///     it could only match keys that are hidden anyway.
    ///   - allowedHeaders: The headers whose values are kept. Headers that are always hidden
    ///     (`Authorization`, `Cookie`, names with `token`, `key`, …) stay hidden when listed.
    ///   - allowedQueryParameters: The query parameters whose values are kept in a recorded URL. A
    ///     secret name stays hidden when listed. A URL in free text does not use them.
    ///   - allowedTextKeys: Keys after which free text is read on, in addition to
    ///     ``defaultAllowedTextKeys``. A key that is not plain ASCII or names a secret is dropped.
    ///   - maximumBodySize: Bodies larger than this, in bytes, are omitted unread. Kept between 0
    ///     and ``bodySizeLimit``. A larger limit costs memory in proportion (see
    ///     ``maximumBodySize``).
    ///   - urlDetail: How much of a URL is recorded.
    public init(
        additionalSecretNames: [String] = [],
        allowedHeaders: [String] = RedactionPolicy.defaultAllowedHeaders,
        allowedQueryParameters: [String] = [],
        allowedTextKeys: [String] = [],
        maximumBodySize: Int = RedactionPolicy.defaultMaximumBodySize,
        urlDetail: URLDetail = .full
    ) {
        self.init(
            isEnabled: true, secretNames: additionalSecretNames, allowedHeaders: allowedHeaders, allowedQueryParameters: allowedQueryParameters,
            allowedTextKeys: RedactionPolicy.defaultAllowedTextKeys + allowedTextKeys, maximumBodySize: maximumBodySize, urlDetail: urlDetail)
    }

    private init(
        isEnabled: Bool, secretNames: [String], allowedHeaders: [String], allowedQueryParameters: [String], allowedTextKeys: [String],
        maximumBodySize: Int, urlDetail: URLDetail
    ) {
        self.isEnabled = isEnabled
        let added = Set(secretNames.compactMap { PlainName($0.unicodeScalars)?.folded })
        let table = added.isEmpty ? SecretNameTable.standard : SecretNameTable(words: added)
        secretNameTable = table
        func allowable(_ names: [String]) -> Set<String> { Self.allowableFolds(names, names: table) }
        self.allowedHeaders = allowable(allowedHeaders)
        self.allowedQueryParameters = allowable(allowedQueryParameters)
        self.allowedTextKeys = allowable(allowedTextKeys)
        self.maximumBodySize = min(max(maximumBodySize, 0), Self.bodySizeLimit)
        self.urlDetail = urlDetail
    }

    /// A policy with the settings of `other` that reads free text on after `textKeys`, folded:
    /// for kept header values, which are also read on after the parameters their headers are
    /// written with (see ``headerParameterNames``).
    init(_ other: RedactionPolicy, textKeys: Set<String>) {
        isEnabled = other.isEnabled
        secretNameTable = other.secretNameTable
        allowedHeaders = other.allowedHeaders
        allowedQueryParameters = other.allowedQueryParameters
        allowedTextKeys = textKeys
        maximumBodySize = other.maximumBodySize
        urlDetail = other.urlDetail
    }

    /// The one table of readings of an input of `length` scalars, with this policy's secret names.
    func readings(length: Int) -> CompatibilityText {
        CompatibilityText(length: length, secretNames: secretNameTable)
    }

    static func allowableFolds(_ names: [String], names table: SecretNameTable = .standard) -> Set<String> {
        Set(names.compactMap { FieldName.allowableFold($0.unicodeScalars, names: table) })
    }

    /// Whether a value under this key (a JSON field, a query or form name, a header name) is
    /// hidden: the key is a secret name, or it is not plain ASCII.
    public func isSensitive(name: String) -> Bool {
        isEnabled && hidesValue(ofKey: name.unicodeScalars)
    }

    /// Whether the value under a key of structured input is hidden: the one rule for keys
    /// (``FieldName/hidesValue(_:names:)``), read with this policy's secret names.
    func hidesValue(ofKey name: some Collection<Unicode.Scalar>) -> Bool {
        FieldName.hidesValue(name, names: secretNameTable)
    }

    /// Whether free text is read on after the key `name`, the one decision for every key of free
    /// text (`key=value`, a quoted key, a JSON member name or pair in a line): it is plain
    /// ASCII without a space, names no secret and is on ``allowedTextKeys`` once folded. A key
    /// longer than ``PlainName/maximumKeyLength`` is turned down before it is read.
    func allowsTextKey(_ name: some Collection<Unicode.Scalar>) -> Bool {
        guard !name.contains(" "), let fold = FieldName.allowableFold(name, names: secretNameTable) else { return false }
        return allowedTextKeys.contains(fold)
    }

    /// The findings in a text, in order and without overlaps, as ``redact(text:)`` finds them.
    func matches(in text: String) -> [Match] {
        var spans = {
            let scalars = Array(text.unicodeScalars)
            return textSpans(in: scalars, compatibility: readings(length: scalars.count), nesting: .text(length: scalars.count))
        }()
        spans.removeAll { $0.kind.isEmpty }
        // The spans are in order and do not overlap, so one walk through the scalars finds the
        // index of each start and end; no index is kept for any other scalar.
        let view = text.unicodeScalars
        var current = view.startIndex
        var offset = 0
        func index(at target: Int) -> String.Index {
            current = view.index(current, offsetBy: target - offset)
            offset = target
            return current
        }
        var matches: [Match] = []
        matches.reserveCapacity(spans.count)
        for span in spans {
            let start = index(at: span.start)
            matches.append(Match(kind: span.kind, range: start..<index(at: span.end)))
        }
        return matches
    }
}
