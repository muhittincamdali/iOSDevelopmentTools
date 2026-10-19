import Foundation

/// What redaction did to a stored body.
public enum RedactionOutcome: String, Sendable, Hashable, Codable {
    /// The body was parsed and nothing was hidden. JSON bodies are stored as re-serialized from
    /// the parse, with sorted keys and without white space.
    case unchanged
    /// The body was parsed and redaction changed it: one or more values were hidden, or line
    /// separators in its text were folded to line feeds.
    case redacted
    /// The body was not stored: it could not be parsed fully, its content type is not one that
    /// is parsed, it was cut off, or it was larger than
    /// ``RedactionPolicy/maximumCheckedBodySize``. The stored bytes are a note such as
    /// `[body omitted: 512 bytes, application/xml]`.
    case omitted
}

extension RedactionPolicy {
    /// The body with secrets hidden.
    ///
    /// Bodies are parsed by their content type: JSON (`application/json`, `+json`), forms
    /// (`application/x-www-form-urlencoded`), multipart and `text/plain`. Any other content type,
    /// no content type, a body that does not parse, a body that was cut off and a body larger
    /// than ``maximumCheckedBodySize`` are omitted: the result is a note such as
    /// `[body omitted: 512 bytes, application/xml]` and ``RedactionOutcome/omitted``.
    ///
    /// - Parameters:
    ///   - body: The bytes to check.
    ///   - contentType: The `Content-Type` header value, if any.
    ///   - isComplete: `false` when `body` holds only the first part of a longer body.
    public func redact(body: Data, contentType: String?, isComplete: Bool = true) -> (body: Data, outcome: RedactionOutcome) {
        redact(body: body, contentType: contentType, isComplete: isComplete, byteCount: body.count)
    }

    /// As ``redact(body:contentType:isComplete:)``, with the size of the whole body for the note.
    func redact(body: Data, contentType: String?, isComplete: Bool, byteCount: Int) -> (body: Data, outcome: RedactionOutcome) {
        guard isEnabled, !(body.isEmpty && isComplete) else { return (body, .unchanged) }
        let mediaType = MediaType(contentType)
        guard isComplete, body.count <= Self.maximumCheckedBodySize, let mediaType, let contentType,
              let (checked, changed) = redact(body: body, as: mediaType, contentType: contentType)
        else {
            return (Data(Self.omissionNote(byteCount: byteCount, mediaType: mediaType).utf8), .omitted)
        }
        return (checked, changed ? .redacted : .unchanged)
    }

    /// The note stored in place of an omitted body.
    static func omissionNote(byteCount: Int, mediaType: MediaType?) -> String {
        "[body omitted: \(byteCount) bytes, \(mediaType?.description ?? "no known content type")]"
    }

    /// The body parsed as its media type with secrets hidden, and whether anything was hidden;
    /// `nil` when it cannot be parsed or the media type is not one that is parsed.
    func redact(body: Data, as mediaType: MediaType, contentType: String) -> (Data, Bool)? {
        if mediaType.isJSON { return redact(jsonBody: body) }
        if mediaType.isMultipart {
            guard let boundary = MultipartParser.boundary(in: contentType) else { return nil }
            return redact(multipart: body, boundary: boundary)
        }
        guard mediaType.isUTF8, let text = String(data: body, encoding: .utf8) else { return nil }
        if mediaType.isForm {
            guard let redacted = redact(form: text) else { return nil }
            return (Data(redacted.utf8), redacted != text)
        }
        guard mediaType.isPlainText else { return nil }
        let redacted = redact(text: text)
        return (Data(redacted.utf8), redacted != text)
    }

    // MARK: Forms

    /// A form body or query string split on `&`, with every name and value percent-decoded with
    /// the platform API; `nil` when one does not decode.
    func redact(form text: String) -> String? {
        var fields: [String] = []
        for field in text.unicodeScalars.split(separator: "&", omittingEmptySubsequences: false) {
            guard let redacted = redact(formField: String(Substring(field))) else { return nil }
            fields.append(redacted)
        }
        return fields.joined(separator: "&")
    }

    private func redact(formField field: String) -> String? {
        let pair = field.unicodeScalars.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        let rawName = String(Substring(pair[0]))
        guard let name = Self.formDecoded(rawName) else { return nil }
        let shownName = redact(text: name) == name ? rawName : Self.replacement
        guard pair.count == 2 else { return shownName }
        let rawValue = String(Substring(pair[1]))
        guard let value = Self.formDecoded(rawValue) else { return nil }
        if hidesValue(of: FoldedKey(name)) { return shownName + "=" + Self.replacement }
        let redacted = redact(value: value, depth: 0)
        return shownName + "=" + (redacted == value ? rawValue : Self.formEncoded(redacted))
    }

    /// `+` read as a space, then percent-decoded; `nil` for an invalid `%` sequence or bytes
    /// that are not UTF-8.
    static func formDecoded(_ text: String) -> String? {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars { scalars.append(scalar == "+" ? " " : scalar) }
        return String(scalars).removingPercentEncoding
    }

    /// Percent-encoded for a form or query value. `[` and `]` stay as they are, so a replaced
    /// value still reads `[REDACTED]`.
    static func formEncoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: formValueCharacters) ?? replacement
    }

    private static let formValueCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~[]")
}

/// The `type/subtype` of a content type, lowercased, and its `charset`.
struct MediaType: CustomStringConvertible {
    let type: String
    let subtype: String
    let charset: String?

    /// `nil` when there is no content type, or its `type/subtype` is not two RFC 9110 tokens.
    init?(_ contentType: String?) {
        guard let contentType else { return nil }
        let bytes = Array(contentType.utf8)
        let essenceEnd = bytes.firstIndex(of: UInt8(ascii: ";")) ?? bytes.count
        var essence = bytes[..<essenceEnd]
        while let first = essence.first, RedactionPolicy.isSpaceOrTab(first) { essence = essence.dropFirst() }
        while let last = essence.last, RedactionPolicy.isSpaceOrTab(last) { essence = essence.dropLast() }
        let parts = essence.split(separator: UInt8(ascii: "/"), omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(RedactionPolicy.isTokenByte) }) else { return nil }
        type = String(decoding: parts[0], as: UTF8.self).lowercased()
        subtype = String(decoding: parts[1], as: UTF8.self).lowercased()
        let parameters = RedactionPolicy.parameters(in: contentType)
        charset = parameters?.last { $0.name == "charset" }?.value.lowercased()
        isWellFormed = parameters != nil
    }

    /// Whether the parameters after `;` are well formed.
    let isWellFormed: Bool

    var description: String { "\(type)/\(subtype)" }
    var isJSON: Bool { subtype == "json" || subtype.hasSuffix("+json") }
    var isForm: Bool { type == "application" && subtype == "x-www-form-urlencoded" }
    var isMultipart: Bool { type == "multipart" }
    var isPlainText: Bool { type == "text" && subtype == "plain" }
    /// Whether the text is UTF-8: no `charset`, or `utf-8` or `us-ascii`.
    var isUTF8: Bool { isWellFormed && (charset == nil || ["utf-8", "utf8", "us-ascii"].contains(charset)) }
}
