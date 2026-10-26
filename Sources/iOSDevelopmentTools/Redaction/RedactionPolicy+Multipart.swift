import Foundation

/// Multipart bodies, written again part by part from what the parser read.
extension RedactionPolicy {
    /// The part headers whose values are kept, besides the field name and the content type.
    private static let keptPartHeaders: Set<String> = ["content-length", "content-transfer-encoding"]

    /// The names of the other part headers that are written; any other name is a key that is not
    /// allowed, so it is written as ``replacement`` with its value. ``allowedHeaders`` lists
    /// request and response headers and does not apply here.
    private static let namedPartHeaders: Set<String> = keptPartHeaders.union([
        "content-description", "content-encoding", "content-id", "content-language", "content-location",
    ])

    /// The transfer encodings a part can name (RFC 2045), in lowercase.
    private static let transferEncodingNames: Set<String> = ["7bit", "8bit", "binary", "base64", "quoted-printable"]

    /// The transfer encodings that leave the content as it is.
    private static let identityTransferEncodings: Set<String> = ["7bit", "8bit", "binary"]

    /// The white space a header value may have around it (RFC 9110 `OWS`).
    private static let headerWhiteSpace = CharacterSet(charactersIn: " \t")

    /// The body is read only with one plain `boundary` parameter: servers differ in which of
    /// several they take, and in whether they undo the quotes and `\` escapes of a quoted one.
    func redactedMultipart(_ body: Data, _ type: MediaType, nesting: Nesting, compatibility: CompatibilityText) -> String? {
        let parameters = type.parameters.filter { $0.name == "boundary" || $0.name == "boundary*" }
        guard parameters.count == 1, let parameter = parameters.first, parameter.name == "boundary", !parameter.isQuoted,
              MultipartBody.isValidBoundary(parameter.value),
              let multipart = MultipartBody(Array(body), boundary: parameter.value)
        else { return nil }
        let boundary = parameter.value
        let naming = NamingFields(multipart.parts.lazy.map(Self.namingField), compatibility: compatibility)
        var output = ""
        for (index, part) in multipart.parts.enumerated() {
            output += "--\(boundary)\r\n"
            output += renderedHeaders(of: part, nesting: nesting, compatibility: compatibility).map { $0 + "\r\n" }.joined()
            let hidesValue = naming.hidesValue(at: index, of: Self.namingField(part))
            output += "\r\n" + (hidesValue ? Self.replacement : redactedContent(of: part, nesting: nesting, compatibility: compatibility)) + "\r\n"
        }
        return output + "--\(boundary)--"
    }

    /// The disposition with only the field name, read as free text; the content type as
    /// `type/subtype`; other headers by name when the name is one of ``namedPartHeaders`` and as
    /// ``replacement`` otherwise, their values hidden unless they are kept, and a kept value
    /// written by its form (see ``keptValue(ofHeader:_:nesting:compatibility:)``). A file name is
    /// never written. Header names are keys of the part: the app or a library writes them into the
    /// body, so a name outside the list, such as one that holds a card number or a token, is never
    /// written.
    private func renderedHeaders(of part: MultipartBody.Part, nesting: Nesting, compatibility: CompatibilityText) -> [String] {
        let fieldName = redactedName(part.name, nesting: nesting, compatibility: compatibility)
        var lines = ["Content-Disposition: form-data; name=\"\(Self.quotedStringContent(fieldName))\""]
        if let contentType = part.contentType { lines.append("Content-Type: " + contentType.essence) }
        for header in part.headers {
            let name = header.name.lowercased()
            guard name != "content-disposition", name != "content-type" else { continue }
            let shownName = Self.namedPartHeaders.contains(name) ? header.name : Self.replacement
            let shownValue = keptValue(ofHeader: name, header.value, nesting: nesting, compatibility: compatibility)
            lines.append(shownName + ": " + (shownValue ?? Self.replacement))
        }
        return lines
    }

    /// The value of a kept header in the one form it takes, nil for any other value. It is not
    /// read as free text, which keeps the text before a finding (`pin-4831` would keep `pin`) and
    /// all of a value without a trigger (`12 hunter2`): a `Content-Length` is written only as
    /// ASCII digits, and only when the value detectors find nothing in them (a card number);
    /// a `Content-Transfer-Encoding` only as one of ``transferEncodingNames``, in lowercase.
    private func keptValue(ofHeader name: String, _ value: String, nesting: Nesting, compatibility: CompatibilityText) -> String? {
        switch name {
        case "content-length":
            let digits = value.trimmingCharacters(in: Self.headerWhiteSpace)
            guard !digits.isEmpty, digits.utf8.allSatisfy(ASCII.isDigit),
                  textSpans(in: Array(digits.unicodeScalars), compatibility: compatibility, nesting: nesting).isEmpty
            else { return nil }
            return digits
        case "content-transfer-encoding":
            return Self.transferEncoding(value)
        default:
            return nil
        }
    }

    /// The content of a part, read as a body one level inside the multipart body. A part is a
    /// document found in the body, so it takes its length from the reading budget, and is omitted
    /// when the budget does not cover it.
    private func redactedContent(of part: MultipartBody.Part, nesting: Nesting, compatibility: CompatibilityText) -> String {
        if hidesValue(ofKey: part.name.unicodeScalars) { return Self.replacement }
        let defaultType = part.filename == nil ? "text/plain" : "application/octet-stream"
        guard let type = part.contentType ?? MediaType(defaultType) else { return Self.omitted(part.content.count, defaultType) }
        guard part.filename == nil, !type.essence.hasPrefix("multipart/"), Self.leavesContentAsSent(part),
              let inner = nesting.enteringDocument(), inner.reads(Self.scalarCount(part.content))
        else {
            return Self.omitted(part.content.count, type.essence)
        }
        guard let (content, _) = redact(body: Data(part.content), as: type, nesting: inner, compatibility: compatibility) else {
            return Self.omitted(part.content.count, type.essence)
        }
        return String(decoding: content, as: UTF8.self)
    }

    /// The parts that name the field another part holds (`label` and `value` parts). A part's
    /// content is read as a name only when it is plain UTF-8 text without a transfer encoding;
    /// any other content of a part that holds a name (`label` in base64, as JSON, in another
    /// charset, as a file) cannot be read as one, so it counts as naming a secret, as an array or
    /// object does in JSON.
    private static func namingField(_ part: MultipartBody.Part) -> NamingFields.Field {
        let value: NamingFields.Value = plainText(of: part).map { .string(Array($0.unicodeScalars)) } ?? .structure
        return (Array(part.name.unicodeScalars), value)
    }

    /// The content of a field sent as plain UTF-8 text without a transfer encoding; nil for a
    /// file, a part of another type or charset, or encoded content.
    private static func plainText(of part: MultipartBody.Part) -> String? {
        guard part.filename == nil, part.contentType.map(\.isPlainText) ?? true, part.contentType?.isUTF8 ?? true,
              leavesContentAsSent(part)
        else { return nil }
        return BodyText.utf8(part.content, dropsByteOrderMark: true)
    }

    /// Whether the part names no transfer encoding or one that leaves the content as it is.
    /// Servers differ in which of several they read, and a value written as ``replacement`` is
    /// one this package cannot read, so the content is read only when the header that is written
    /// says it is as sent.
    private static func leavesContentAsSent(_ part: MultipartBody.Part) -> Bool {
        let encodings = part.headers.filter { $0.name.lowercased() == "content-transfer-encoding" }.map { transferEncoding($0.value) }
        return encodings.count <= 1 && encodings.allSatisfy { $0.map(identityTransferEncodings.contains) ?? false }
    }

    /// The transfer encoding a header value names, in lowercase; nil when the value, without the
    /// white space around it, is not one of ``transferEncodingNames`` in any ASCII letter case.
    private static func transferEncoding(_ value: String) -> String? {
        let encoding = value.trimmingCharacters(in: headerWhiteSpace)
        guard encoding.utf8.allSatisfy({ $0 < 0x80 }) else { return nil }
        let lowercased = encoding.lowercased()
        return transferEncodingNames.contains(lowercased) ? lowercased : nil
    }

    /// The text with `"` and `\` escaped, for a quoted header parameter.
    private static func quotedStringContent(_ text: String) -> String {
        var escaped = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if scalar == "\"" || scalar == "\\" { escaped.append("\\") }
            escaped.append(scalar)
        }
        return String(escaped)
    }
}
