import Foundation

/// Multipart bodies, written again part by part from what the parser read.
extension RedactionPolicy {
    /// The transfer encodings that leave the content as it is.
    private static let identityTransferEncodings: Set<String> = ["7bit", "8bit", "binary"]

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
    /// `type/subtype`; other headers by the header rule (see ``redact(headers:)``), with a name
    /// that is not on ``allowedHeaders``, or in which a value detector finds something, written as
    /// ``replacement`` with its value. A file name is never written. Header names are keys of the
    /// part: the app or a library writes them into the body, so a name may hold what its value
    /// would.
    private func renderedHeaders(of part: MultipartBody.Part, nesting: Nesting, compatibility: CompatibilityText) -> [String] {
        let fieldName = redactedName(part.name, nesting: nesting, compatibility: compatibility)
        var lines = ["Content-Disposition: form-data; name=\"\(Self.quotedStringContent(fieldName))\""]
        if let contentType = part.contentType { lines.append("Content-Type: " + contentType.essence) }
        let reader = headerValueReader
        for header in part.headers {
            let name = header.name.lowercased()
            guard name != "content-disposition", name != "content-type" else { continue }
            let value = header.value.trimmingCharacters(in: .whitespaces)
            guard !hidesHeader(named: header.name),
                  detectorSpans(in: NormalizedText(Array(header.name.unicodeScalars), compatibility: compatibility)).isEmpty
            else {
                lines.append(Self.replacement + ": " + Self.replacement)
                continue
            }
            lines.append(header.name + ": " + reader.redactedHeaderValue(name: header.name, value: value, compatibility: compatibility))
        }
        return lines
    }

    /// The content of a part, read as a body one level inside the multipart body. A part is a
    /// document found in the body, so it takes its length from the reading budget, and is omitted
    /// when the budget does not cover it.
    private func redactedContent(of part: MultipartBody.Part, nesting: Nesting, compatibility: CompatibilityText) -> String {
        if hidesValue(ofKey: part.name.unicodeScalars) { return Self.replacement }
        let defaultType = part.filename == nil ? "text/plain" : "application/octet-stream"
        guard let type = part.contentType ?? MediaType(defaultType) else { return Self.omitted(part.content.count, defaultType) }
        let encodings = Self.transferEncodings(of: part)
        guard part.filename == nil, !type.essence.hasPrefix("multipart/"), encodings.allSatisfy(Self.identityTransferEncodings.contains),
              encodings.count <= 1, let inner = nesting.enteringDocument(), inner.reads(Self.scalarCount(part.content))
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
        guard part.filename == nil, part.contentType.map(\.isPlainText) ?? true, part.contentType?.isUTF8 ?? true else { return nil }
        let encodings = transferEncodings(of: part)
        guard encodings.count <= 1, encodings.allSatisfy(identityTransferEncodings.contains) else { return nil }
        return BodyText.utf8(part.content, dropsByteOrderMark: true)
    }

    /// The transfer encodings a part names, lowercased; servers differ in which of several they
    /// read.
    private static func transferEncodings(of part: MultipartBody.Part) -> [String] {
        part.headers.filter { $0.name.lowercased() == "content-transfer-encoding" }
            .map { $0.value.trimmingCharacters(in: .whitespaces).lowercased() }
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
