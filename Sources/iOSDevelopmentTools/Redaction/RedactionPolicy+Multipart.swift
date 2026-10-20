import Foundation

/// Multipart bodies, written again part by part from what the parser read.
extension RedactionPolicy {
    /// The transfer encodings that leave the content as it is.
    private static let identityTransferEncodings: Set<String> = ["7bit", "8bit", "binary"]

    /// A `multipart/form-data` body with secrets hidden, and whether what is stored differs from
    /// what was sent; nil when it is omitted. The body is read only with one plain `boundary`
    /// parameter: servers differ in which of several they take, and in whether they undo the
    /// quotes and `\` escapes of a quoted one.
    func redact(multipart body: Data, _ type: MediaType, nesting: Nesting) -> (Data, Bool)? {
        let parameters = type.parameters.filter { $0.name == "boundary" || $0.name == "boundary*" }
        guard parameters.count == 1, let parameter = parameters.first, parameter.name == "boundary", !parameter.isQuoted,
              MultipartBody.isValidBoundary(parameter.value),
              let multipart = MultipartBody(Array(body), boundary: parameter.value)
        else { return nil }
        let boundary = parameter.value
        let naming = namingParts(multipart.parts)
        var output = Data()
        for (index, part) in multipart.parts.enumerated() {
            var lines = "--\(boundary)\r\n"
            lines += renderedHeaders(of: part, nesting: nesting).map { $0 + "\r\n" }.joined() + "\r\n"
            output.append(contentsOf: lines.utf8)
            output.append(naming.hidesValue(at: index, of: Self.namingField(part)) ? Data(Self.replacement.utf8) : redactedContent(of: part, nesting: nesting))
            output.append(contentsOf: "\r\n".utf8)
        }
        output.append(contentsOf: "--\(boundary)--".utf8)
        // The parser takes a closing delimiter with or without the line break after it.
        if body.suffix(2).elementsEqual([13, 10]) { output.append(contentsOf: [13, 10]) }
        return (output, output != body)
    }

    /// The disposition with only the field name, read as free text; the content type as
    /// `type/subtype`; other headers by the header rule (see ``redact(headers:)``), with a name
    /// that is not on ``allowedHeaders``, or in which a value detector finds something, written as
    /// ``replacement`` too. A file name is never written.
    private func renderedHeaders(of part: MultipartBody.Part, nesting: Nesting) -> [String] {
        var lines = ["Content-Disposition: form-data; name=\"\(Self.quotedStringContent(redactedName(part.name, nesting: nesting)))\""]
        if let contentType = part.contentType { lines.append("Content-Type: " + contentType.essence) }
        for header in part.headers {
            let name = header.name.lowercased()
            guard name != "content-disposition", name != "content-type" else { continue }
            let value = header.value.trimmingCharacters(in: .whitespaces)
            let shownName = shownPartHeaderName(header.name)
            lines.append(shownName + ": " + (shownName == header.name ? redactedHeaderValue(name: header.name, value: value) : Self.replacement))
        }
        return lines
    }

    /// A part header's name as it is written: the name of a header whose value is kept, unless a
    /// value detector finds something in it; ``replacement`` for any other, whose value is hidden
    /// too. A part header is written by the app or a library into the body, so its name may hold
    /// what its value would.
    private func shownPartHeaderName(_ name: String) -> String {
        guard !hidesHeader(named: name) else { return Self.replacement }
        let scalars = Array(name.unicodeScalars)
        return detectorSpans(in: NormalizedText(scalars, compatibility: CompatibilityText())).isEmpty ? name : Self.replacement
    }

    /// The content of a part, read as a body one level inside the multipart body. A part is a
    /// document found in the body, so it takes its length from the reading budget, and is omitted
    /// when the budget does not cover it.
    private func redactedContent(of part: MultipartBody.Part, nesting: Nesting) -> Data {
        if hidesValue(ofKey: part.name.unicodeScalars) { return Data(Self.replacement.utf8) }
        let type = part.contentType ?? MediaType(part.filename == nil ? "text/plain" : "application/octet-stream")
        let omitted = Data(Self.omissionNote(byteCount: part.content.count, mediaType: type).utf8)
        let encodings = Self.transferEncodings(of: part)
        guard let type, part.filename == nil, !type.essence.hasPrefix("multipart/"),
              encodings.allSatisfy(Self.identityTransferEncodings.contains), encodings.count <= 1,
              let inner = nesting.enteringDocument(), inner.reads(Self.scalarCount(part.content))
        else { return omitted }
        return redact(body: Data(part.content), as: type, nesting: inner)?.0 ?? omitted
    }

    /// The parts that name the field another part holds (`label` and `value` parts). A part's
    /// content is read as a name only when it is plain UTF-8 text without a transfer encoding;
    /// any other content of a part that holds a name (`label` in base64, as JSON, in another
    /// charset, as a file) cannot be read as one, so it counts as naming a secret, as an array or
    /// object does in JSON.
    private func namingParts(_ parts: [MultipartBody.Part]) -> NamingFields {
        NamingFields(parts.lazy.map(Self.namingField), policy: self, compatibility: CompatibilityText())
    }

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
        return String(bytes: part.content, encoding: .utf8)
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
