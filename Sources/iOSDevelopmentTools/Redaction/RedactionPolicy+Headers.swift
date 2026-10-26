/// Redaction of request, response and multipart part headers.
extension RedactionPolicy {
    /// The headers with every value hidden, except those of headers on ``allowedHeaders``.
    ///
    /// `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, any header
    /// whose folded name contains `token`, `secret`, `key`, `auth`, `session` or `signature`, a
    /// header with a secret name and a header whose name is not an ASCII token of letters, digits,
    /// `-`, `_` and `.` are hidden even when listed. So is a kept value that starts with an
    /// authentication scheme and credentials (`Bearer …`, `Basic …`, `Token …`). Other kept
    /// values go through the free-text rule (``redact(text:)``), which reads on after the keys on
    /// ``allowedTextKeys`` and after the parameters that the default headers are written with
    /// (see ``headerParameterNames``): `text/html; charset=utf-8`, `en-US,en;q=0.9` and
    /// `max-age=3600` are kept, while any other parameter hides the rest of the value
    /// (`text/plain; x=…`).
    public func redact(headers: [HTTPHeader]) -> [HTTPHeader] {
        guard isEnabled else { return headers }
        // One table of readings and one reader of values serve every header of the list.
        let compatibility = readings(length: headers.reduce(0) { $0 + $1.value.utf8.count })
        let reader = headerValueReader
        return headers.map { header in
            HTTPHeader(name: header.name, value: reader.redactedHeaderValue(name: header.name, value: header.value, compatibility: compatibility))
        }
    }

    /// One header value as ``redact(headers:)`` stores it, read by ``headerValueReader``.
    func redactedHeaderValue(name: String, value: String, compatibility: CompatibilityText) -> String {
        guard !hidesHeader(named: name), !Self.startsWithAuthenticationScheme(value) else { return Self.replacement }
        let scalars = Array(value.unicodeScalars)
        let spans = textSpans(in: scalars, compatibility: compatibility, nesting: .text(length: scalars.count))
        return spans.isEmpty ? value : Self.replacing(spans, in: scalars)
    }

    /// This policy, reading free text on after ``allowedTextKeys`` and the parameters of
    /// ``headerParameterNames``, for header values.
    var headerValueReader: RedactionPolicy { RedactionPolicy(self, textKeys: allowedTextKeys.union(Self.headerParameterFolds)) }

    private static let headerParameterFolds = allowableFolds(headerParameterNames)

    /// The parameters that the values of the default ``allowedHeaders`` are written with, which
    /// a kept header value reads on after, besides ``allowedTextKeys``: `charset` and `boundary`
    /// of a media type (RFC 9110), the weight `q` of `Accept`, `Accept-Encoding` and
    /// `Accept-Language`, and the `Cache-Control` directives with a value (RFC 9111, RFC 5861).
    public static let headerParameterNames: [String] = [
        "charset", "boundary", "q", "max-age", "s-maxage", "max-stale", "min-fresh", "stale-while-revalidate", "stale-if-error",
    ]

    private static let alwaysHiddenHeaders: Set<String> = ["authorization", "proxyauthorization", "cookie", "setcookie", "xapikey"]
    private static let hiddenHeaderNameParts = ["token", "secret", "key", "auth", "session", "signature"]

    /// Whether a header's value is hidden: it is not on ``allowedHeaders``, or it is always hidden.
    func hidesHeader(named name: String) -> Bool {
        guard !alwaysHidesHeader(named: name), let fold = FieldName.allowableFold(name.unicodeScalars, names: secretNameTable) else { return true }
        return !allowedHeaders.contains(fold)
    }

    /// Whether a header's value is hidden whatever it holds and whatever ``allowedHeaders`` lists.
    func alwaysHidesHeader(named name: String) -> Bool {
        let scalars = name.unicodeScalars
        guard !scalars.isEmpty, scalars.allSatisfy(HeaderValueReader.isTokenCharacter), !hidesValue(ofKey: scalars),
              let folded = FieldName.allowableFold(scalars, names: secretNameTable)
        else { return true }
        return Self.alwaysHiddenHeaders.contains(folded) || Self.hiddenHeaderNameParts.contains(where: folded.contains)
    }

    /// The schemes of the IANA HTTP Authentication Scheme Registry and widespread vendor schemes:
    /// `NTLM`, `Token` (GitHub and others), `Bot` (Discord), `AWS4-HMAC-SHA256` and `SharedKey`.
    private static let authenticationSchemes: Set<String> = [
        "basic", "bearer", "concealed", "digest", "dpop", "gnap", "hoba", "mutual", "negotiate",
        "privatetoken", "scram-sha-1", "scram-sha-256", "vapid",
        "ntlm", "token", "bot", "aws4-hmac-sha256", "sharedkey", "sharedkeylite",
    ]

    /// Whether the value's first word is an authentication scheme and credentials follow it.
    private static func startsWithAuthenticationScheme(_ value: String) -> Bool {
        let isSeparator = { (scalar: Unicode.Scalar) in scalar.properties.isWhitespace || scalar == "," }
        let words = value.unicodeScalars.drop(while: isSeparator).split(maxSplits: 1, whereSeparator: isSeparator)
        guard words.count == 2 else { return false }
        return authenticationSchemes.contains(String(String.UnicodeScalarView(words[0])).lowercased())
    }
}
