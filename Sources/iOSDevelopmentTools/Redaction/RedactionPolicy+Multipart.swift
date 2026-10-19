import Foundation

/// Redaction of multipart bodies. The body is written again from its parts: each part keeps its
/// field name, a `Content-Type` reduced to `type/subtype`, and other headers by the header rule.
extension RedactionPolicy {
    /// The multipart body with secrets hidden and whether anything was hidden; `nil` when it does
    /// not parse (see ``MultipartParser``) or a part's headers are malformed or ambiguous.
    ///
    /// File parts (with a `filename` parameter) are always omitted. A field whose name is a
    /// secret or not plain ASCII is hidden. Other fields are parsed by their own content type,
    /// `text/plain` when they have none (RFC 7578); one that does not parse, or is sent in a
    /// transfer encoding other than `7bit`, `8bit` or `binary`, is omitted.
    func redact(multipart body: Data, boundary: String) -> (Data, Bool)? {
        guard let parts = MultipartParser.parts(of: body, boundary: boundary) else { return nil }
        var output = Data()
        var changed = false
        for part in parts {
            guard let (rendered, partChanged) = redact(part: part) else { return nil }
            output.append(Data("--\(boundary)\r\n".utf8))
            output.append(rendered)
            output.append(Data("\r\n".utf8))
            changed = changed || partChanged
        }
        output.append(Data("--\(boundary)--\r\n".utf8))
        return (output, changed)
    }

    /// A part's headers, a blank line and its content, with secrets hidden.
    private func redact(part: MultipartParser.Part) -> (Data, Bool)? {
        guard let headers = Self.partHeaders(part.headers) else { return nil }
        // Servers differ in which of several dispositions, names or content types they read.
        let dispositions = headers["content-disposition"] ?? []
        let contentTypes = headers["content-type"] ?? []
        let transferEncodings = headers["content-transfer-encoding"] ?? []
        guard dispositions.count <= 1, contentTypes.count <= 1, transferEncodings.count <= 1 else { return nil }
        var field: PartField?
        if let disposition = dispositions.first {
            guard let parsed = PartField(disposition: disposition) else { return nil }
            field = parsed
        }
        let (lines, headersChanged) = renderedHeaders(headers, field: field, contentType: contentTypes.first)
        // Content in base64, quoted-printable or another transfer encoding is not decoded.
        let isEncoded = transferEncodings.first.map { !Self.identityTransferEncodings.contains($0.lowercased()) } ?? false
        // A part without a Content-Type is text/plain (RFC 7578).
        let (content, contentChanged) = redact(
            partContent: part.content, field: field, contentType: contentTypes.first ?? "text/plain", isEncoded: isEncoded)
        let headerBlock = lines.map { $0 + "\r\n" }.joined() + "\r\n"
        return (Data(headerBlock.utf8) + content, headersChanged || contentChanged)
    }

    /// The header lines of a part: the disposition with only its type and field name, the content
    /// type reduced to `type/subtype` (hidden when the header rule hides `Content-Type`), and other
    /// headers by the header rule.
    private func renderedHeaders(_ headers: [String: [String]], field: PartField?, contentType: String?) -> ([String], Bool) {
        var lines: [String] = []
        var changed = false
        if let field { lines.append("Content-Disposition: " + renderedDisposition(field)) }
        if let contentType {
            let shown = hidesHeader(named: "Content-Type") ? nil : MediaType(contentType)?.description
            lines.append("Content-Type: " + (shown ?? Self.replacement))
            changed = shown == nil
        }
        for (name, values) in headers.sorted(by: { $0.key < $1.key }) where name != "content-disposition" && name != "content-type" {
            let hidden = hidesHeader(named: name)
            changed = changed || hidden
            lines += values.map { "\(name): " + (hidden ? Self.replacement : redact(text: $0)) }
        }
        return (lines, changed)
    }

    /// The transfer encodings that leave the content as it is.
    private static let identityTransferEncodings: Set<String> = ["7bit", "8bit", "binary"]

    private func redact(partContent content: Data, field: PartField?, contentType: String, isEncoded: Bool) -> (Data, Bool) {
        let mediaType = MediaType(contentType)
        let omitted = (Data(Self.omissionNote(byteCount: content.count, mediaType: mediaType).utf8), true)
        if field?.isFile == true { return omitted }
        if let name = field?.name, hidesValue(of: FoldedKey(name)) { return (Data(Self.replacement.utf8), true) }
        guard !content.isEmpty else { return (content, false) }
        if isEncoded { return omitted }
        // A multipart part inside a part is not parsed.
        guard let mediaType, !mediaType.isMultipart,
              let result = redact(body: content, as: mediaType, contentType: contentType)
        else { return omitted }
        return result
    }

    /// The parsed `Content-Disposition` of a part.
    private struct PartField {
        /// The disposition type (`form-data`, `attachment`, `inline`), lowercased.
        let type: String
        let name: String?
        /// Whether a `filename` or `filename*` parameter makes it a file.
        let isFile: Bool

        /// `nil` when the type is not a token, a parameter is malformed, or there is more than
        /// one name (see ``RedactionPolicy/fieldNames(in:)``).
        init?(disposition: String) {
            guard let type = RedactionPolicy.dispositionType(disposition),
                  let parameters = RedactionPolicy.parameters(in: disposition),
                  let names = RedactionPolicy.fieldNames(in: disposition), names.count <= 1
            else { return nil }
            self.type = type
            name = names.first
            isFile = parameters.contains { $0.name == "filename" || $0.name.hasPrefix("filename*") }
        }
    }

    /// The disposition type (`form-data`, `attachment`, `inline`), lowercased; `nil` when it is
    /// not a token.
    static func dispositionType(_ disposition: String) -> String? {
        let bytes = Array(disposition.utf8)
        var type = bytes[..<(bytes.firstIndex(of: UInt8(ascii: ";")) ?? bytes.count)]
        while let first = type.first, isSpaceOrTab(first) { type = type.dropFirst() }
        while let last = type.last, isSpaceOrTab(last) { type = type.dropLast() }
        guard !type.isEmpty, type.allSatisfy(isTokenByte) else { return nil }
        return String(decoding: type, as: UTF8.self).lowercased()
    }

    /// `form-data; name="…"`, with the name as ``redact(text:)`` shows it, quotes and
    /// backslashes escaped. A file name is never written.
    private func renderedDisposition(_ field: PartField) -> String {
        let type = field.type
        guard let name = field.name else { return type }
        var escaped = String.UnicodeScalarView()
        for scalar in redact(text: name).unicodeScalars {
            if scalar == "\"" || scalar == "\\" { escaped.append("\\") }
            escaped.append(scalar)
        }
        return "\(type); name=\"\(String(escaped))\""
    }
}
